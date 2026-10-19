// Remedoo Pay — Cloudflare Worker (YouPI-style self-hosted UPI gateway)
//
// A Cloudflare-native re-implementation of the YouPI PG pattern:
// hosted UPI checkout page (Pay-with-UPI-app button), ONE payment at a
// time (no queue — a new payment can start only after the current one
// is paid, cancelled, or expires), and payment verification by a
// bank-SMS observer
// (a free SMS-forwarder app on the merchant's phone POSTs each bank
// credit SMS to /api/v1/observer/sms).
//
// API (compatible with what Remedoo's Supabase Edge Functions call):
//   POST /api/v1/payments            -> { paymentId, checkoutUrl, status, ... }
//   GET  /api/v1/payments/:id        -> { paymentId, status, ... }
//   POST /api/v1/checkout/:id/cancel -> { success, status: 'CANCELLED' }
//   GET  /checkout/:id               -> hosted checkout page (HTML)
//   POST /api/v1/observer/sms        -> bank SMS webhook (token protected)
//   GET  /api/v1/gmail/connect       -> start Gmail OAuth (bank email alerts)
//   GET  /api/v1/gmail/callback      -> Gmail OAuth callback
//   POST /api/v1/gmail/test          -> Gmail connection check (token protected)
//   POST /api/v1/gmail/poll          -> check Gmail now (token protected)
//   POST /api/v1/gmail/disconnect    -> disconnect Gmail (token protected)
//   GET  /                           -> health
//
// Gmail automation: when the merchant connects the Gmail account
// that receives the bank's credit-alert emails, a 1-minute cron
// (scheduled handler) polls it and feeds each credit email through
// the SAME parser/matching as the SMS observer — payments on the
// central UPI confirm themselves with zero action by anyone.
// OAuth client id/secret + refresh token live in secure_settings
// (keys gmail_*), set from Remedoo Admin > Remedoo Pay.
//
// Storage + config live in the merchant's existing Supabase project:
//   table  remedoo_pay_sessions           (payment sessions)
//   config app_config.key = 'payment_gateways' -> gateways.youpi
//          { vpa, payee_name }            (set in Remedoo Admin)
//   secret secure_settings.key = 'remedoo_pay_observer_token'
//
// Worker secrets (set in the Cloudflare dashboard, never in code):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

const ACTIVE_WINDOW_MS = 5 * 60 * 1000; // a payment gets 5 minutes

function clean(v, max = 200) {
  if (v === null || v === undefined) return '';
  return String(v).trim().slice(0, max);
}

// ------------------------------------------------------------------
// Supabase REST helpers (service role; server-side only)
// ------------------------------------------------------------------
async function sb(env, path, opts = {}) {
  const res = await fetch(`${env.SUPABASE_URL}/rest/v1/${path}`, {
    method: opts.method || 'GET',
    headers: {
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      Prefer: opts.prefer || 'return=representation',
    },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`Supabase ${res.status}: ${text.slice(0, 200)}`);
  return text ? JSON.parse(text) : null;
}

async function getYoupiConfig(env) {
  const rows = await sb(
    env,
    `app_config?key=eq.payment_gateways&select=value`
  );
  const gw = rows?.[0]?.value?.gateways?.youpi ?? {};
  return {
    vpa: (gw.vpa || '').trim(),
    payeeName: (gw.payee_name || 'Remedoo').trim() || 'Remedoo',
  };
}

async function getObserverToken(env) {
  const rows = await sb(
    env,
    `secure_settings?key=eq.remedoo_pay_observer_token&select=value`
  );
  return rows?.[0]?.value ?? '';
}

// Generic secure_settings access (Gmail config + state live here).
async function getSecureSetting(env, key) {
  const rows = await sb(
    env,
    `secure_settings?key=eq.${encodeURIComponent(key)}&select=value`
  );
  return rows?.[0]?.value ?? '';
}

async function setSecureSetting(env, key, value) {
  await sb(env, 'secure_settings?on_conflict=key', {
    method: 'POST',
    prefer: 'resolution=merge-duplicates,return=representation',
    body: { key, value: String(value ?? ''), updated_at: new Date().toISOString() },
  });
}

/// Reads several secure_settings keys in one query -> { key: value }.
async function getSecureSettings(env, keys) {
  const rows = await sb(
    env,
    `secure_settings?key=in.(${keys.join(',')})&select=key,value`
  );
  const out = {};
  for (const r of rows ?? []) out[r.key] = r.value ?? '';
  return out;
}

// ------------------------------------------------------------------
// Session helpers
// ------------------------------------------------------------------
async function getSession(env, id) {
  const rows = await sb(
    env,
    `remedoo_pay_sessions?id=eq.${encodeURIComponent(id)}&select=*`
  );
  return rows?.[0] ?? null;
}

async function patchSession(env, id, patch) {
  const rows = await sb(env, `remedoo_pay_sessions?id=eq.${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: patch,
  });
  return rows?.[0] ?? null;
}

/// Single-payment rule (no queue): at most one ACTIVE session.
/// Expires stale ACTIVE sessions (older than the 5-minute window)
/// and returns the still-open ACTIVE session, or null. Also rescues
/// a legacy QUEUED row (from the old queue build) when nothing is
/// active. Called lazily on every touch — no background process.
async function currentActive(env, targetVpa, centralVpa) {
  const actives = await sb(
    env,
    `remedoo_pay_sessions?status=eq.ACTIVE&select=id,activated_at,vpa&order=activated_at.asc`
  );
  const now = Date.now();
  let open = null;
  for (const a of actives ?? []) {
    if (now - new Date(a.activated_at).getTime() <= ACTIVE_WINDOW_MS) {
      // One open payment PER receiving UPI ID: a payment to Dr. A must
      // not block a payment to Dr. B. Rows without a vpa belong to the
      // central Remedoo UPI.
      const rowVpa = a.vpa || centralVpa;
      if (!open && (!targetVpa || rowVpa === targetVpa)) open = a;
    } else {
      await patchSession(env, a.id, { status: 'EXPIRED' });
    }
  }
  if (open) return open;
  // The legacy QUEUED rescue only applies to the central UPI.
  if (targetVpa && centralVpa && targetVpa !== centralVpa) return null;
  const queued = await sb(
    env,
    `remedoo_pay_sessions?status=eq.QUEUED&select=id&order=created_at.asc&limit=1`
  );
  if (queued && queued.length > 0) {
    const id = queued[0].id;
    await patchSession(env, id, {
      status: 'ACTIVE',
      activated_at: new Date().toISOString(),
    });
    return { id };
  }
  return null;
}

function publicSession(session, origin) {
  return {
    paymentId: session.id,
    orderId: session.order_id,
    amount: (session.amount_paise / 100).toFixed(2),
    amountPaise: String(session.amount_paise),
    currency: 'INR',
    status: session.status,
    queuePosition: 0,
    checkoutUrl: `${origin}/checkout/${session.id}`,
    ...(session.utr ? { utr: session.utr } : {}),
  };
}

// ------------------------------------------------------------------
// Bank SMS parsing (observer)
// ------------------------------------------------------------------
function parseBankSms(text) {
  const t = String(text || '');
  if (/debited|withdrawn|spent/i.test(t)) return null; // credits only
  if (!/credited|received|deposited|added/i.test(t)) return null;
  const amt = t.match(/(?:Rs\.?|INR|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)/i);
  if (!amt) return null;
  const paise = Math.round(parseFloat(amt[1].replace(/,/g, '')) * 100);
  const utrMatch =
    t.match(/(?:UTR|Ref(?:erence)?\s*(?:No|Number)?|Txn(?:\s*Id)?|UPI Ref)[:.\s]*([0-9]{9,22})/i) ||
    t.match(/\b(\d{12})\b/);
  // Who paid: a payer UPI handle in the SMS ("from name@bank",
  // "VPA name@bank") and, when present, a payer name after "from".
  const vpaMatch = t.match(/[a-zA-Z0-9._\-]{2,}@[a-zA-Z]{2,}/);
  let payerName = null;
  const nameMatch = t.match(
    /\bfrom\s+([A-Za-z][A-Za-z .']{2,40}?)(?:\s+(?:on|via|through|Ref|UTR)\b|[.,]|$)/i
  );
  if (nameMatch) {
    const n = nameMatch[1].trim();
    // Skip captures that are just the VPA itself or a bank word.
    if (n && !n.includes('@') && !/^(upi|a\/c|account)$/i.test(n)) {
      payerName = n;
    }
  }
  return {
    paise,
    utr: utrMatch ? utrMatch[1] : null,
    payerVpa: vpaMatch ? vpaMatch[0] : null,
    payerName,
  };
}

/// The SUCCESS patch for a matched credit — ONE shape shared by the
/// SMS observer and the Gmail poller so both confirm identically.
/// Only writes payer details the message actually carried — never
/// overwrites a captured value with null.
function creditSuccessPatch(parsed) {
  return {
    status: 'SUCCESS',
    utr: parsed.utr,
    paid_at: new Date().toISOString(),
    ...(parsed.payerVpa ? { payer_vpa: parsed.payerVpa } : {}),
    ...(parsed.payerName ? { payer_name: parsed.payerName } : {}),
  };
}

// ------------------------------------------------------------------
// Gmail automation (bank credit-alert emails -> same confirmation
// as the SMS observer). One Gmail account, connected once by the
// merchant via OAuth; its refresh token lives in secure_settings.
// Covers payments received on the CENTRAL UPI only (panelists'
// own-UPI alerts go to their own email accounts).
// ------------------------------------------------------------------
const GMAIL_SETTING_KEYS = [
  'gmail_client_id',
  'gmail_client_secret',
  'gmail_refresh_token',
  'gmail_connected_email',
  'gmail_oauth_state',
  'gmail_last_poll_at',
  'gmail_seen',
  'gmail_last_result',
];
const GMAIL_SEEN_CAP = 300;

function decodeB64Url(data) {
  const b64 = String(data || '').replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(b64);
  const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  return new TextDecoder('utf-8', { fatal: false }).decode(bytes);
}

function findMimePart(payload, mime) {
  if (!payload) return null;
  if (payload.mimeType === mime && payload.body && payload.body.data) {
    return payload.body.data;
  }
  for (const part of payload.parts ?? []) {
    const hit = findMimePart(part, mime);
    if (hit) return hit;
  }
  return null;
}

function stripHtml(html) {
  return String(html || '')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&#39;|&rsquo;/gi, "'")
    .replace(/&quot;/gi, '"')
    .replace(/\s+/g, ' ');
}

/// Plain-text body of a Gmail API message (format=full): text/plain
/// part when present, else the text/html part with tags stripped,
/// else the snippet.
function gmailMessageText(msg) {
  const plain = findMimePart(msg?.payload, 'text/plain');
  if (plain) return decodeB64Url(plain);
  const html = findMimePart(msg?.payload, 'text/html');
  if (html) return stripHtml(decodeB64Url(html));
  return msg?.snippet || '';
}

async function gmailTokenExchange(env, params) {
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(params).toString(),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.access_token) {
    throw new Error(
      `Google token exchange failed (${res.status}): ${data.error_description || data.error || 'unknown error'}`
    );
  }
  return data;
}

async function gmailApi(accessToken, path) {
  const res = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/${path}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(
      `Gmail API ${res.status}: ${data?.error?.message || 'request failed'}`
    );
  }
  return data;
}

/// A payer "VPA" whose domain part contains a dot is an email
/// address (e.g. a bank care address in the footer), not a UPI
/// handle — UPI bank handles never contain a dot. Drop those so a
/// refund is never aimed at an email address.
function sanitizeEmailPayer(parsed) {
  if (!parsed) return parsed;
  const vpa = parsed.payerVpa;
  if (vpa && vpa.includes('@') && vpa.split('@')[1].includes('.')) {
    return { ...parsed, payerVpa: null };
  }
  return parsed;
}

/// One Gmail poll: read recent credit-alert emails, feed each new
/// one through parseBankSms (the SMS observer's parser) and confirm
/// the matching ACTIVE central-UPI session. Every listed message id
/// is recorded in gmail_seen (parsed or not) so mail is read once.
async function gmailPoll(env) {
  const s = await getSecureSettings(env, GMAIL_SETTING_KEYS);
  const refreshToken = (s.gmail_refresh_token || '').trim();
  if (!refreshToken) return { ok: false, reason: 'not_connected' };
  const clientId = (s.gmail_client_id || '').trim();
  const clientSecret = (s.gmail_client_secret || '').trim();
  if (!clientId || !clientSecret) {
    return { ok: false, reason: 'credentials_missing' };
  }
  try {
    const tokens = await gmailTokenExchange(env, {
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    });
    const access = tokens.access_token;
    const query = encodeURIComponent(
      'newer_than:2d (credited OR "credit alert" OR "UPI Ref" OR "amount credited" OR received)'
    );
    const list = await gmailApi(access, `messages?maxResults=25&q=${query}`);
    const messages = list.messages ?? [];
    let seen = [];
    try {
      const parsedSeen = JSON.parse(s.gmail_seen || '[]');
      if (Array.isArray(parsedSeen)) seen = parsedSeen.map(String);
    } catch (_) {
      seen = [];
    }
    const seenSet = new Set(seen);
    const cfg = await getYoupiConfig(env);
    await currentActive(env); // expire stale sessions before matching
    let checked = 0;
    let matched = 0;
    for (const m of messages) {
      if (!m?.id || seenSet.has(m.id)) continue;
      const full = await gmailApi(access, `messages/${encodeURIComponent(m.id)}?format=full`);
      checked += 1;
      const parsed = sanitizeEmailPayer(parseBankSms(gmailMessageText(full)));
      if (parsed && cfg.vpa) {
        const actives = await sb(
          env,
          `remedoo_pay_sessions?status=eq.ACTIVE&amount_paise=eq.${parsed.paise}&select=id,vpa&order=activated_at.asc`
        );
        // Central UPI only: rows without a vpa belong to the central
        // UPI (same convention as currentActive).
        const hit = (actives ?? []).find(
          (a) => (a.vpa || cfg.vpa) === cfg.vpa
        );
        if (hit) {
          await patchSession(env, hit.id, creditSuccessPatch(parsed));
          matched += 1;
        }
      }
      seen.push(m.id);
      seenSet.add(m.id);
    }
    const result =
      `checked ${checked} email${checked === 1 ? '' : 's'}, ` +
      `matched ${matched} payment${matched === 1 ? '' : 's'}`;
    await setSecureSetting(env, 'gmail_seen', JSON.stringify(seen.slice(-GMAIL_SEEN_CAP)));
    await setSecureSetting(env, 'gmail_last_poll_at', new Date().toISOString());
    await setSecureSetting(env, 'gmail_last_result', result);
    return { ok: true, checked, matched, result };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    try {
      await setSecureSetting(env, 'gmail_last_poll_at', new Date().toISOString());
      await setSecureSetting(env, 'gmail_last_result', `error: ${msg.slice(0, 120)}`);
    } catch (_) {
      // Status write is best-effort; the summary below is the result.
    }
    return { ok: false, reason: 'poll_failed', error: msg };
  }
}

function htmlPage(title, message, status = 200) {
  return new Response(
    `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>${title} — Remedoo Pay</title>
<style>
  body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#f4f6fb;margin:0;padding:16px;color:#122}
  .card{max-width:420px;margin:40px auto;background:#fff;border-radius:16px;padding:28px;box-shadow:0 8px 30px rgba(20,20,60,.08);text-align:center}
  .brand{font-weight:800;color:#7C3AED;letter-spacing:.4px}
  h1{font-size:20px;margin:12px 0 8px}
  p{color:#556;font-size:14px;line-height:1.55}
</style></head><body>
<div class="card">
  <div class="brand">REMEDOO PAY</div>
  <h1>${title}</h1>
  <p>${message}</p>
</div>
</body></html>`,
    { status, headers: { 'Content-Type': 'text/html; charset=utf-8' } }
  );
}

// ------------------------------------------------------------------
// Checkout page
// ------------------------------------------------------------------
function checkoutPage(session, cfg) {
  const rupees = (session.amount_paise / 100).toFixed(2);
  // NPCI merchant-intent parameters: tid + tr (transaction reference,
  // alphanumeric, <=35 chars) — UPI apps' risk engines expect them on
  // gateway-style payment links; a bare pa/pn/am link gets flagged.
  const txnRef = session.id.replace(/[^a-zA-Z0-9]/g, '').slice(0, 35);
  // The receiving UPI for THIS payment: the provider's own when the
  // session carries one, otherwise the central Remedoo UPI.
  const effVpa = session.vpa || cfg.vpa;
  const effPayee = session.payee_name || cfg.payeeName;
  const upi =
    `upi://pay?pa=${encodeURIComponent(effVpa)}` +
    `&pn=${encodeURIComponent(effPayee)}` +
    `&am=${rupees}&cu=INR` +
    `&tid=${txnRef}&tr=${txnRef}` +
    `&tn=${encodeURIComponent('Remedoo ' + session.order_id)}`;
  const isActive = session.status === 'ACTIVE' || session.status === 'QUEUED';
  const isDone = session.status === 'SUCCESS';
  const isDead = ['EXPIRED', 'CANCELLED', 'FAILED'].includes(session.status);
  return `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Remedoo Pay — ₹${rupees}</title>
<style>
  body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#f4f6fb;margin:0;padding:16px;color:#122}
  .card{max-width:420px;margin:24px auto;background:#fff;border-radius:16px;padding:24px;box-shadow:0 8px 30px rgba(20,20,60,.08);text-align:center}
  .brand{font-weight:800;color:#7C3AED;letter-spacing:.4px}
  .amt{font-size:34px;font-weight:800;margin:6px 0}
  .muted{color:#667;font-size:14px}
  .apps a{display:block;margin:8px 0;padding:13px;border-radius:12px;background:#7C3AED;color:#fff;text-decoration:none;font-weight:700}
  .apps a.alt{background:#eef;color:#223;border:1px solid #ccd}
  .status{font-weight:700;margin-top:10px}
  .ok{color:#12805c}.bad{color:#c0392b}.wait{color:#b45309}
  code{background:#f0f0f5;padding:2px 6px;border-radius:6px}
</style></head><body>
<div class="card">
  <div class="brand">REMEDOO PAY</div>
  <div class="amt">₹${rupees}</div>
  <div class="muted">Pay to <b>${effPayee}</b> · <code>${effVpa}</code></div>
  ${
    isDone
      ? `<p class="status ok">✅ Payment received. Thank you!</p>
         <p class="muted">Returning to Remedoo…</p>`
      : isDead
        ? `<p class="status bad">This payment session is ${session.status.toLowerCase()}.</p>
           <p class="muted">Please go back to Remedoo and try booking again.</p>`
        : isActive
          ? `<div class="apps">
               <a href="${upi}">Pay with any UPI app</a>
             </div>
             <p class="muted">Tap the button — your UPI app (GPay / PhonePe / Paytm) opens with the amount ready. Payment confirms automatically when your payment lands — keep this page open.</p>
             <p class="status wait" id="st">Waiting for payment…</p>`
          : `<p class="status wait">This payment session is no longer open.</p>
             <p class="muted">Please go back to Remedoo and try booking again.</p>`
  }
</div>
<script>
  var done = ${isDone ? 'true' : 'false'};
  var returnUrl = ${JSON.stringify(session.return_url || 'https://remedoo-app.pages.dev/')};
  if (done) setTimeout(function(){ location.href = returnUrl; }, 2000);
  if (!done && !${isDead ? 'true' : 'false'}) {
    setInterval(async function(){
      try {
        var r = await fetch('/api/v1/payments/${session.id}');
        var d = await r.json();
        if (d.status === 'SUCCESS') location.reload();
        if (['EXPIRED','CANCELLED','FAILED'].indexOf(d.status) >= 0) location.reload();
        if (d.status === 'ACTIVE' && ${isActive ? 'false' : 'true'}) location.reload();
      } catch(e) {}
    }, 4000);
  }
</script>
</body></html>`;
}

// ------------------------------------------------------------------
// Router
// ------------------------------------------------------------------
function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'content-type, x-merchant-id, x-observer-token, idempotency-key',
    },
  });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const path = url.pathname;
    try {
      if (req.method === 'OPTIONS') return json({}, 204);

      if (path === '/' && req.method === 'GET') {
        return json({ ok: true, service: 'Remedoo Pay', version: 'cloud-2' });
      }

      // ---- Create payment session ----
      if (path === '/api/v1/payments' && req.method === 'POST') {
        const body = await req.json();
        const amount = parseFloat(body.amount);
        if (!body.orderId || !amount || amount <= 0) {
          return json({ error: 'orderId and a positive amount are required' }, 400);
        }
        const cfg = await getYoupiConfig(env);
        // Per-provider UPI: when the payment belongs to a provider who
        // added their own UPI ID, the money goes straight to them.
        const vpa = clean(body.vpa, 80) || cfg.vpa;
        const payeeName = clean(body.payeeName, 80) || cfg.payeeName;
        if (!vpa) {
          return json(
            { error: 'Remedoo Pay is not configured: set your UPI ID in Remedoo Admin > Payment System.' },
            503
          );
        }
        const busy = await currentActive(env, vpa, cfg.vpa);
        if (busy) {
          // "Pay New" escape hatch: the customer explicitly chose to
          // drop the pending payment and start a fresh one.
          if (body.forceNew === true) {
            await patchSession(env, busy.id, { status: 'CANCELLED' });
          } else {
            return json(
              {
                error:
                  'A payment is already in progress. It must be paid, cancelled, or expire (5 minutes) before a new payment can start.',
              },
              409
            );
          }
        }
        const rows = await sb(env, 'remedoo_pay_sessions', {
          method: 'POST',
          body: {
            order_id: String(body.orderId).slice(0, 64),
            amount_paise: Math.round(amount * 100),
            status: 'ACTIVE',
            customer: body.customer ?? null,
            description: body.description ?? null,
            return_url: body.returnUrl ?? null,
            vpa,
            payee_name: payeeName,
            // Who is paying (customer side), when the checkout
            // captured it — shown to the panelist, used for refunds.
            payer_vpa:
              clean(body.payer_vpa, 80) ||
              clean(body.customer?.upi, 80) ||
              null,
            payer_name:
              clean(body.payer_name, 80) ||
              clean(body.customer?.name, 80) ||
              null,
            provider_kind: clean(body.providerKind, 20) || null,
            provider_id: clean(body.providerId, 64) || null,
            provider_user_id: clean(body.providerUserId, 64) || null,
            activated_at: new Date().toISOString(),
          },
        });
        const session = rows[0];
        const fresh = await getSession(env, session.id);
        return json(publicSession(fresh, url.origin), 201);
      }

      // ---- Payment status ----
      const statusMatch = path.match(/^\/api\/v1\/payments\/([\w-]+)$/);
      if (statusMatch && req.method === 'GET') {
        await currentActive(env);
        const session = await getSession(env, statusMatch[1]);
        if (!session) return json({ error: 'Payment session not found' }, 404);
        return json(publicSession(session, url.origin));
      }

      // ---- Cancel session ----
      const cancelMatch = path.match(/^\/api\/v1\/checkout\/([\w-]+)\/cancel$/);
      if (cancelMatch && req.method === 'POST') {
        const session = await getSession(env, cancelMatch[1]);
        if (!session) return json({ error: 'Payment session not found' }, 404);
        if (['QUEUED', 'ACTIVE'].includes(session.status)) {
          await patchSession(env, session.id, { status: 'CANCELLED' });
        }
        return json({ success: true, status: 'CANCELLED' });
      }

      // ---- Hosted checkout page ----
      const checkoutMatch = path.match(/^\/checkout\/([\w-]+)$/);
      if (checkoutMatch && req.method === 'GET') {
        await currentActive(env);
        const session = await getSession(env, checkoutMatch[1]);
        if (!session) {
          return new Response('Payment session not found', { status: 404 });
        }
        const cfg = await getYoupiConfig(env);
        return new Response(checkoutPage(session, cfg), {
          headers: { 'Content-Type': 'text/html; charset=utf-8' },
        });
      }

      // ---- Observer: bank SMS webhook ----
      if (path === '/api/v1/observer/sms' && req.method === 'POST') {
        const token = await getObserverToken(env);
        const given = req.headers.get('x-observer-token') || url.searchParams.get('token') || '';
        if (!token || given !== token) {
          return json({ error: 'Invalid observer token' }, 401);
        }
        let text = '';
        const raw = await req.text();
        try {
          const parsed = JSON.parse(raw);
          text = parsed.text || parsed.message || parsed.sms || raw;
        } catch (_) {
          text = raw;
        }
        const parsedSms = parseBankSms(text);
        if (!parsedSms) return json({ matched: false, reason: 'not a credit SMS' });
        await currentActive(env);
        const actives = await sb(
          env,
          `remedoo_pay_sessions?status=eq.ACTIVE&amount_paise=eq.${parsedSms.paise}&select=id&order=activated_at.asc&limit=1`
        );
        if (!actives || actives.length === 0) {
          return json({ matched: false, reason: 'no active session for amount' });
        }
        await patchSession(env, actives[0].id, creditSuccessPatch(parsedSms));
        return json({ matched: true, paymentId: actives[0].id });
      }

      // ---- Gmail automation ----
      // OAuth connect/callback are browser flows (no token header);
      // the other gmail endpoints use the observer token, same as SMS.
      const gmailAuthed = async () => {
        const token = await getObserverToken(env);
        const given =
          req.headers.get('x-observer-token') || url.searchParams.get('token') || '';
        return !!token && given === token;
      };

      if (path === '/api/v1/gmail/connect' && req.method === 'GET') {
        const s = await getSecureSettings(env, GMAIL_SETTING_KEYS);
        const clientId = (s.gmail_client_id || '').trim();
        const clientSecret = (s.gmail_client_secret || '').trim();
        if (!clientId || !clientSecret) {
          return htmlPage(
            'Almost there',
            'Set the Client ID and Secret in Admin first — Remedoo Admin &gt; Payments &gt; Remedoo Pay &gt; Gmail Automation — then tap Connect Gmail again.',
            400
          );
        }
        const state = crypto.randomUUID();
        await setSecureSetting(env, 'gmail_oauth_state', state);
        const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
        authUrl.searchParams.set('client_id', clientId);
        authUrl.searchParams.set(
          'redirect_uri',
          `${url.origin}/api/v1/gmail/callback`
        );
        authUrl.searchParams.set('response_type', 'code');
        authUrl.searchParams.set(
          'scope',
          'https://www.googleapis.com/auth/gmail.readonly'
        );
        authUrl.searchParams.set('access_type', 'offline');
        authUrl.searchParams.set('prompt', 'consent');
        authUrl.searchParams.set('state', state);
        return Response.redirect(authUrl.toString(), 302);
      }

      if (path === '/api/v1/gmail/callback' && req.method === 'GET') {
        const s = await getSecureSettings(env, GMAIL_SETTING_KEYS);
        const storedState = (s.gmail_oauth_state || '').trim();
        const givenState = url.searchParams.get('state') || '';
        const code = url.searchParams.get('code') || '';
        if (!code || !storedState || givenState !== storedState) {
          return htmlPage(
            'Connection failed',
            'This sign-in link is no longer valid. Go back to Remedoo Admin and tap Connect Gmail again.',
            400
          );
        }
        const tokens = await gmailTokenExchange(env, {
          code,
          client_id: (s.gmail_client_id || '').trim(),
          client_secret: (s.gmail_client_secret || '').trim(),
          redirect_uri: `${url.origin}/api/v1/gmail/callback`,
          grant_type: 'authorization_code',
        });
        if (!tokens.refresh_token) {
          return htmlPage(
            'One more step needed',
            'Google did not return a long-term token for this account. Remove Remedoo Pay under your Google Account &gt; Security &gt; Third-party access, then reconnect — the connect flow uses prompt=consent so Google issues a fresh refresh token.',
            400
          );
        }
        await setSecureSetting(env, 'gmail_refresh_token', tokens.refresh_token);
        let email = '';
        try {
          const profile = await gmailApi(tokens.access_token, 'profile');
          email = (profile.emailAddress || '').trim();
        } catch (_) {
          // The connection still works without the profile email.
        }
        await setSecureSetting(env, 'gmail_connected_email', email);
        await setSecureSetting(env, 'gmail_oauth_state', '');
        return htmlPage(
          'Gmail connected ✅',
          `Bank credit alerts${email ? ` to <b>${email}</b>` : ''} will now confirm Remedoo Pay payments automatically. You can close this tab.`
        );
      }

      if (path === '/api/v1/gmail/test' && req.method === 'POST') {
        if (!(await gmailAuthed())) {
          return json({ error: 'Invalid observer token' }, 401);
        }
        const s = await getSecureSettings(env, GMAIL_SETTING_KEYS);
        const refreshToken = (s.gmail_refresh_token || '').trim();
        if (!refreshToken) {
          return json({ ok: false, error: 'Gmail is not connected yet. Tap Connect Gmail in Remedoo Admin first.' });
        }
        const clientId = (s.gmail_client_id || '').trim();
        const clientSecret = (s.gmail_client_secret || '').trim();
        if (!clientId || !clientSecret) {
          return json({ ok: false, error: 'Google Client ID and Secret are not saved yet. Add them in Remedoo Admin first.' });
        }
        const tokens = await gmailTokenExchange(env, {
          client_id: clientId,
          client_secret: clientSecret,
          refresh_token: refreshToken,
          grant_type: 'refresh_token',
        });
        const profile = await gmailApi(tokens.access_token, 'profile');
        return json({
          ok: true,
          email: profile.emailAddress || s.gmail_connected_email || '',
          messagesTotal: profile.messagesTotal ?? null,
        });
      }

      if (path === '/api/v1/gmail/poll' && req.method === 'POST') {
        if (!(await gmailAuthed())) {
          return json({ error: 'Invalid observer token' }, 401);
        }
        return json(await gmailPoll(env));
      }

      if (path === '/api/v1/gmail/disconnect' && req.method === 'POST') {
        if (!(await gmailAuthed())) {
          return json({ error: 'Invalid observer token' }, 401);
        }
        await setSecureSetting(env, 'gmail_refresh_token', '');
        await setSecureSetting(env, 'gmail_connected_email', '');
        await setSecureSetting(env, 'gmail_seen', '');
        await setSecureSetting(env, 'gmail_oauth_state', '');
        return json({ ok: true });
      }

      return json({ error: 'Not found' }, 404);
    } catch (e) {
      return json({ error: e instanceof Error ? e.message : String(e) }, 500);
    }
  },

  // Cron Trigger (set to every 1 minute in the Cloudflare dashboard):
  // poll Gmail for bank credit alerts and confirm waiting payments.
  // A failed poll must never crash the Worker — gmailPoll already
  // reports its own errors; this catch is belt and braces.
  async scheduled(event, env, ctx) {
    try {
      const summary = await gmailPoll(env);
      console.log('gmail scheduled poll:', JSON.stringify(summary));
    } catch (e) {
      console.log(
        'gmail scheduled poll failed:',
        e instanceof Error ? e.message : String(e)
      );
    }
  },
};

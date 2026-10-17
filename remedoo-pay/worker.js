// Remedoo Pay — Cloudflare Worker (YouPI-style self-hosted UPI gateway)
//
// A Cloudflare-native re-implementation of the YouPI PG pattern:
// hosted UPI checkout page (QR + app intent links), a single-active-
// payment FIFO queue, and payment verification by a bank-SMS observer
// (a free SMS-forwarder app on the merchant's phone POSTs each bank
// credit SMS to /api/v1/observer/sms).
//
// API (compatible with what Remedoo's Supabase Edge Functions call):
//   POST /api/v1/payments            -> { paymentId, checkoutUrl, status, ... }
//   GET  /api/v1/payments/:id        -> { paymentId, status, ... }
//   POST /api/v1/checkout/:id/cancel -> { success, status: 'CANCELLED' }
//   GET  /checkout/:id               -> hosted checkout page (HTML)
//   POST /api/v1/observer/sms        -> bank SMS webhook (token protected)
//   GET  /                           -> health
//
// Storage + config live in the merchant's existing Supabase project:
//   table  remedoo_pay_sessions           (payment sessions)
//   config app_config.key = 'payment_gateways' -> gateways.youpi
//          { vpa, payee_name }            (set in Remedoo Admin)
//   secret secure_settings.key = 'remedoo_pay_observer_token'
//
// Worker secrets (set in the Cloudflare dashboard, never in code):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

const ACTIVE_WINDOW_MS = 10 * 60 * 1000; // a payment gets 10 minutes

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

/// Expire a stale ACTIVE session and promote the oldest QUEUED one.
/// Called lazily on every touch — no background process needed.
async function promote(env) {
  const actives = await sb(
    env,
    `remedoo_pay_sessions?status=eq.ACTIVE&select=id,activated_at&order=activated_at.asc&limit=1`
  );
  const now = Date.now();
  if (actives && actives.length > 0) {
    const a = actives[0];
    if (now - new Date(a.activated_at).getTime() <= ACTIVE_WINDOW_MS) {
      return a.id; // still in its window
    }
    await patchSession(env, a.id, { status: 'EXPIRED' });
  }
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
    return id;
  }
  return null;
}

async function queuePosition(env, session) {
  if (session.status !== 'QUEUED') return 0;
  const rows = await sb(
    env,
    `remedoo_pay_sessions?status=eq.QUEUED&created_at=lt.${encodeURIComponent(
      session.created_at
    )}&select=id`
  );
  return (rows?.length ?? 0) + 1;
}

function publicSession(session, origin, position = 0) {
  return {
    paymentId: session.id,
    orderId: session.order_id,
    amount: (session.amount_paise / 100).toFixed(2),
    amountPaise: String(session.amount_paise),
    currency: 'INR',
    status: session.status,
    queuePosition: position,
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
  return { paise, utr: utrMatch ? utrMatch[1] : null };
}

// ------------------------------------------------------------------
// Checkout page
// ------------------------------------------------------------------
function checkoutPage(session, cfg, position) {
  const rupees = (session.amount_paise / 100).toFixed(2);
  const upi =
    `upi://pay?pa=${encodeURIComponent(cfg.vpa)}` +
    `&pn=${encodeURIComponent(cfg.payeeName)}` +
    `&am=${rupees}&cu=INR` +
    `&tn=${encodeURIComponent('Remedoo ' + session.order_id)}`;
  const isActive = session.status === 'ACTIVE';
  const isDone = session.status === 'SUCCESS';
  const isDead = ['EXPIRED', 'CANCELLED', 'FAILED'].includes(session.status);
  return `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Remedoo Pay — ₹${rupees}</title>
<script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
<style>
  body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#f4f6fb;margin:0;padding:16px;color:#122}
  .card{max-width:420px;margin:24px auto;background:#fff;border-radius:16px;padding:24px;box-shadow:0 8px 30px rgba(20,20,60,.08);text-align:center}
  .brand{font-weight:800;color:#7C3AED;letter-spacing:.4px}
  .amt{font-size:34px;font-weight:800;margin:6px 0}
  .muted{color:#667;font-size:14px}
  #qr{display:flex;justify-content:center;margin:16px 0}
  .apps a{display:block;margin:8px 0;padding:13px;border-radius:12px;background:#7C3AED;color:#fff;text-decoration:none;font-weight:700}
  .apps a.alt{background:#eef;color:#223;border:1px solid #ccd}
  .status{font-weight:700;margin-top:10px}
  .ok{color:#12805c}.bad{color:#c0392b}.wait{color:#b45309}
  code{background:#f0f0f5;padding:2px 6px;border-radius:6px}
</style></head><body>
<div class="card">
  <div class="brand">REMEDOO PAY</div>
  <div class="amt">₹${rupees}</div>
  <div class="muted">Pay to <b>${cfg.payeeName}</b> · <code>${cfg.vpa}</code></div>
  ${
    isDone
      ? `<p class="status ok">✅ Payment received. Thank you!</p>
         <p class="muted">Returning to Remedoo…</p>`
      : isDead
        ? `<p class="status bad">This payment session is ${session.status.toLowerCase()}.</p>
           <p class="muted">Please go back to Remedoo and try booking again.</p>`
        : isActive
          ? `<div id="qr"></div>
             <div class="apps">
               <a href="${upi}">Pay with any UPI app</a>
             </div>
             <p class="muted">Scan the QR with GPay / PhonePe / Paytm, or tap the button on your phone. Keep this page open — it confirms automatically when your payment lands.</p>
             <p class="status wait" id="st">Waiting for payment…</p>`
          : `<p class="status wait">You are in queue (position ${position}).</p>
             <p class="muted">Another payment is being completed first. This page updates automatically — please keep it open.</p>`
  }
</div>
<script>
  var qrEl = document.getElementById('qr');
  if (qrEl) new QRCode(qrEl, { text: ${JSON.stringify(upi)}, width: 220, height: 220 });
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
        return json({ ok: true, service: 'Remedoo Pay', version: 'cloud-1' });
      }

      // ---- Create payment session ----
      if (path === '/api/v1/payments' && req.method === 'POST') {
        const body = await req.json();
        const amount = parseFloat(body.amount);
        if (!body.orderId || !amount || amount <= 0) {
          return json({ error: 'orderId and a positive amount are required' }, 400);
        }
        const cfg = await getYoupiConfig(env);
        if (!cfg.vpa) {
          return json(
            { error: 'Remedoo Pay is not configured: set your UPI ID in Remedoo Admin > Payment System.' },
            503
          );
        }
        const rows = await sb(env, 'remedoo_pay_sessions', {
          method: 'POST',
          body: {
            order_id: String(body.orderId).slice(0, 64),
            amount_paise: Math.round(amount * 100),
            status: 'QUEUED',
            customer: body.customer ?? null,
            description: body.description ?? null,
            return_url: body.returnUrl ?? null,
          },
        });
        const session = rows[0];
        await promote(env);
        const fresh = await getSession(env, session.id);
        const pos = await queuePosition(env, fresh);
        return json(publicSession(fresh, url.origin, pos), 201);
      }

      // ---- Payment status ----
      const statusMatch = path.match(/^\/api\/v1\/payments\/([\w-]+)$/);
      if (statusMatch && req.method === 'GET') {
        await promote(env);
        const session = await getSession(env, statusMatch[1]);
        if (!session) return json({ error: 'Payment session not found' }, 404);
        const pos = await queuePosition(env, session);
        return json(publicSession(session, url.origin, pos));
      }

      // ---- Cancel session ----
      const cancelMatch = path.match(/^\/api\/v1\/checkout\/([\w-]+)\/cancel$/);
      if (cancelMatch && req.method === 'POST') {
        const session = await getSession(env, cancelMatch[1]);
        if (!session) return json({ error: 'Payment session not found' }, 404);
        if (['QUEUED', 'ACTIVE'].includes(session.status)) {
          await patchSession(env, session.id, { status: 'CANCELLED' });
          await promote(env);
        }
        return json({ success: true, status: 'CANCELLED' });
      }

      // ---- Hosted checkout page ----
      const checkoutMatch = path.match(/^\/checkout\/([\w-]+)$/);
      if (checkoutMatch && req.method === 'GET') {
        await promote(env);
        const session = await getSession(env, checkoutMatch[1]);
        if (!session) {
          return new Response('Payment session not found', { status: 404 });
        }
        const cfg = await getYoupiConfig(env);
        const pos = await queuePosition(env, session);
        return new Response(checkoutPage(session, cfg, pos), {
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
        await promote(env);
        const actives = await sb(
          env,
          `remedoo_pay_sessions?status=eq.ACTIVE&amount_paise=eq.${parsedSms.paise}&select=id&order=activated_at.asc&limit=1`
        );
        if (!actives || actives.length === 0) {
          return json({ matched: false, reason: 'no active session for amount' });
        }
        await patchSession(env, actives[0].id, {
          status: 'SUCCESS',
          utr: parsedSms.utr,
          paid_at: new Date().toISOString(),
        });
        await promote(env);
        return json({ matched: true, paymentId: actives[0].id });
      }

      return json({ error: 'Not found' }, 404);
    } catch (e) {
      return json({ error: e instanceof Error ? e.message : String(e) }, 500);
    }
  },
};

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

async function getSecret(supabase: any, key: string): Promise<string | null> {
  const { data } = await supabase
    .from('secure_settings')
    .select('value')
    .eq('key', key)
    .single();
  return data?.value ?? null;
}

async function getGatewayConfig(supabase: any) {
  const { data } = await supabase
    .from('app_config')
    .select('value')
    .eq('key', 'payment_gateways')
    .single();
  return data?.value ?? null;
}

function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// ---------- RAZORPAY: Payment Links ----------
async function razorpayCreate(supabase: any, gw: any, p: any) {
  const keyId = gw.key_id;
  const keySecret = await getSecret(supabase, 'razorpay_key_secret');
  if (!keyId || !keySecret) throw new Error('Razorpay keys not configured');
  const auth = btoa(`${keyId}:${keySecret}`);
  const res = await fetch('https://api.razorpay.com/v1/payment_links', {
    method: 'POST',
    headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      amount: Math.round(p.amount * 100),
      currency: 'INR',
      description: p.description || 'Remedoo Payment',
      customer: {
        ...(p.customer_name ? { name: p.customer_name } : {}),
        ...(p.contact ? { contact: p.contact } : {}),
        ...(p.email ? { email: p.email } : {}),
      },
      notify: { sms: false, email: false },
      reminder_enable: false,
      ...(p.reference_id ? { reference_id: String(p.reference_id).slice(0, 40) } : {}),
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data?.error?.description || 'Razorpay link failed');
  return { gateway: 'razorpay', payment_url: data.short_url, reference: data.id };
}

// ---------- CASHFREE: Payment Links ----------
async function cashfreeCreate(supabase: any, gw: any, p: any) {
  const appId = gw.key_id;
  const secret = await getSecret(supabase, 'cashfree_secret_key');
  if (!appId || !secret) throw new Error('Cashfree keys not configured');
  const base = gw.test_mode === false
    ? 'https://api.cashfree.com/pg'
    : 'https://sandbox.cashfree.com/pg';
  const linkId = `remedoo_${Date.now()}`;
  const res = await fetch(`${base}/links`, {
    method: 'POST',
    headers: {
      'x-client-id': appId,
      'x-client-secret': secret,
      'x-api-version': '2023-08-01',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      link_id: linkId,
      link_amount: p.amount,
      link_currency: 'INR',
      link_purpose: p.description || 'Remedoo Payment',
      customer_details: {
        customer_name: p.customer_name || 'Customer',
        customer_phone: p.contact || '9999999999',
        ...(p.email ? { customer_email: p.email } : {}),
      },
      link_notify: { send_sms: false, send_email: false },
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data?.message || 'Cashfree link failed');
  return { gateway: 'cashfree', payment_url: data.link_url, reference: linkId };
}

// ---------- INSTAMOJO: Payment Requests ----------
async function instamojoCreate(supabase: any, gw: any, p: any) {
  const apiKey = gw.key_id;
  const authToken = await getSecret(supabase, 'instamojo_auth_token');
  if (!apiKey || !authToken) throw new Error('Instamojo keys not configured');
  const base = gw.test_mode === false
    ? 'https://www.instamojo.com/api/1.1'
    : 'https://test.instamojo.com/api/1.1';
  const form = new URLSearchParams({
    purpose: (p.description || 'Remedoo Payment').slice(0, 30),
    amount: String(p.amount),
    buyer_name: p.customer_name || 'Customer',
    redirect_url: 'https://remedoo-app.pages.dev/',
    allow_repeated_payments: 'False',
  });
  if (p.email) form.set('email', p.email);
  if (p.contact) form.set('phone', p.contact);
  const res = await fetch(`${base}/payment-requests/`, {
    method: 'POST',
    headers: { 'X-Api-Key': apiKey, 'X-Auth-Token': authToken },
    body: form,
  });
  const data = await res.json();
  if (!res.ok || !data.success) {
    throw new Error(
      data?.message || JSON.stringify(data?.errors ?? {}) || 'Instamojo failed'
    );
  }
  const pr = data.payment_request;
  return { gateway: 'instamojo', payment_url: pr.longurl, reference: pr.id };
}

// ---------- PAYU: Hosted form (returns an auto-submit HTML page URL) ----------
// PayU has no link API; we return a URL pointing back at this function
// with mode=payu-form, which serves an HTML page that POSTs to PayU.
async function payuCreate(supabase: any, gw: any, p: any) {
  const txnid = `txn${Date.now()}`;
  // Store pending params in app_config scratch keyed by txnid
  await supabase.from('app_config').upsert({
    key: `payu_pending_${txnid}`,
    value: {
      amount: p.amount,
      description: p.description || 'Remedoo Payment',
      customer_name: p.customer_name || 'Customer',
      contact: p.contact || '',
      email: p.email || '',
      created_at: new Date().toISOString(),
    },
  });
  const url = `${SUPABASE_URL}/functions/v1/payment-create?mode=payu-form&txnid=${txnid}`;
  return { gateway: 'payu', payment_url: url, reference: txnid };
}

async function sha512(str: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-512', new TextEncoder().encode(str));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function payuFormPage(supabase: any, txnid: string) {
  const { data: cfgRow } = await supabase
    .from('app_config').select('value').eq('key', 'payment_gateways').single();
  const gw = cfgRow?.value?.gateways?.payu ?? {};
  const merchantKey = gw.key_id;
  const salt = await getSecret(supabase, 'payu_salt');
  const { data: pendingRow } = await supabase
    .from('app_config').select('value').eq('key', `payu_pending_${txnid}`).single();
  const p = pendingRow?.value;
  if (!merchantKey || !salt || !p) {
    return new Response('Payment configuration error', { status: 500 });
  }
  const amount = Number(p.amount).toFixed(2);
  const productinfo = 'RemedooPayment';
  const firstname = String(p.customer_name || 'Customer').split(' ')[0];
  const email = p.email || 'customer@remedoo.app';
  const phone = p.contact || '9999999999';
  const surl = 'https://remedoo-app.pages.dev/';
  const furl = 'https://remedoo-app.pages.dev/';
  const hashStr = `${merchantKey}|${txnid}|${amount}|${productinfo}|${firstname}|${email}|||||||||||${salt}`;
  const hash = await sha512(hashStr);
  const action = gw.test_mode === false
    ? 'https://secure.payu.in/_payment'
    : 'https://test.payu.in/_payment';
  const fields: Record<string, string> = {
    key: merchantKey, txnid, amount, productinfo, firstname, email, phone,
    surl, furl, hash,
  };
  const inputs = Object.entries(fields)
    .map(([k, v]) => `<input type="hidden" name="${k}" value="${String(v).replace(/"/g, '&quot;')}"/>`)
    .join('\n');
  const html = `<!DOCTYPE html><html><head><title>Redirecting to PayU…</title></head>
<body onload="document.forms[0].submit()">
<p>Redirecting to PayU secure payment page…</p>
<form method="post" action="${action}">${inputs}</form>
</body></html>`;
  return new Response(html, { headers: { 'Content-Type': 'text/html' } });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const url = new URL(req.url);

  // PayU form page (GET redirect target)
  if (req.method === 'GET' && url.searchParams.get('mode') === 'payu-form') {
    return await payuFormPage(supabase, url.searchParams.get('txnid') ?? '');
  }

  try {
    const body = await req.json();
    const config = await getGatewayConfig(supabase);
    const active = body.gateway || config?.active || 'razorpay';
    const gw = config?.gateways?.[active];
    if (!gw || gw.enabled !== true) {
      return json({ error: `Payment gateway '${active}' is not enabled. Configure it in Admin > Settings.` }, 400);
    }

    const p = {
      amount: Number(body.amount),
      description: body.description,
      customer_name: body.customer_name,
      contact: body.customer_contact,
      email: body.customer_email,
      reference_id: body.reference_id,
    };
    if (!p.amount || p.amount <= 0) return json({ error: 'Invalid amount' }, 400);

    let result;
    switch (active) {
      case 'razorpay': result = await razorpayCreate(supabase, gw, p); break;
      case 'cashfree': result = await cashfreeCreate(supabase, gw, p); break;
      case 'instamojo': result = await instamojoCreate(supabase, gw, p); break;
      case 'payu': result = await payuCreate(supabase, gw, p); break;
      default: return json({ error: `Unknown gateway '${active}'` }, 400);
    }

    return json({ ...result, status: 'created' });
  } catch (e) {
    console.error('payment-create error:', e);
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});

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

function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// Returns unified: { status: 'paid' | 'pending' | 'failed' | 'expired' | 'unknown', payment_id? }
async function razorpayStatus(supabase: any, gw: any, ref: string) {
  const keyId = gw.key_id || (await getSecret(supabase, 'razorpay_key_id'));
  const keySecret = await getSecret(supabase, 'razorpay_key_secret');
  const auth = btoa(`${keyId}:${keySecret}`);
  const res = await fetch(`https://api.razorpay.com/v1/payment_links/${ref}`, {
    headers: { Authorization: `Basic ${auth}` },
  });
  const d = await res.json();
  if (!res.ok) throw new Error('Razorpay status failed');
  const map: Record<string, string> = {
    paid: 'paid', created: 'pending', partially_paid: 'pending',
    cancelled: 'failed', expired: 'expired',
  };
  return { status: map[d.status] ?? 'unknown', payment_id: d.payments?.[0]?.payment_id ?? null };
}

async function cashfreeStatus(supabase: any, gw: any, ref: string) {
  const secret = await getSecret(supabase, 'cashfree_secret_key');
  const base = gw.test_mode === false
    ? 'https://api.cashfree.com/pg'
    : 'https://sandbox.cashfree.com/pg';
  const res = await fetch(`${base}/links/${ref}`, {
    headers: {
      'x-client-id': gw.key_id,
      'x-client-secret': secret ?? '',
      'x-api-version': '2023-08-01',
    },
  });
  const d = await res.json();
  if (!res.ok) throw new Error('Cashfree status failed');
  const s = String(d.link_status ?? '').toUpperCase();
  const status = s === 'PAID' ? 'paid'
    : s === 'EXPIRED' ? 'expired'
    : (s === 'CANCELLED' || s === 'TERMINATED') ? 'failed' : 'pending';
  return { status, payment_id: d.link_auto_reminders ? null : null };
}

async function instamojoStatus(supabase: any, gw: any, ref: string) {
  const authToken = await getSecret(supabase, 'instamojo_auth_token');
  const base = gw.test_mode === false
    ? 'https://www.instamojo.com/api/1.1'
    : 'https://test.instamojo.com/api/1.1';
  const res = await fetch(`${base}/payment-requests/${ref}/`, {
    headers: { 'X-Api-Key': gw.key_id, 'X-Auth-Token': authToken ?? '' },
  });
  const d = await res.json();
  if (!res.ok) throw new Error('Instamojo status failed');
  const pr = d.payment_request;
  const hasSuccessfulPayment = (pr.payments ?? []).some(
    (pay: any) => String(pay.status).toLowerCase() === 'successful'
  );
  const status = hasSuccessfulPayment ? 'paid'
    : pr.status === 'Completed' ? 'paid'
    : pr.status === 'Expired' ? 'expired' : 'pending';
  const payId = (pr.payments ?? []).find(
    (pay: any) => String(pay.status).toLowerCase() === 'successful'
  )?.payment_id ?? null;
  return { status, payment_id: payId };
}

async function sha512(str: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-512', new TextEncoder().encode(str));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function payuStatus(supabase: any, gw: any, ref: string) {
  const salt = await getSecret(supabase, 'payu_salt');
  const key = gw.key_id;
  const command = 'verify_payment';
  const hash = await sha512(`${key}|${command}|${ref}|${salt}`);
  const form = new URLSearchParams({ key, command, var1: ref, hash });
  const host = gw.test_mode === false
    ? 'https://info.payu.in/merchant/postservice.php?form=2'
    : 'https://test.payu.in/merchant/postservice.php?form=2';
  const res = await fetch(host, { method: 'POST', body: form });
  const d = await res.json();
  const txn = d?.transaction_details?.[ref];
  if (!txn) return { status: 'pending', payment_id: null };
  const s = String(txn.status ?? '').toLowerCase();
  const status = s === 'success' ? 'paid'
    : s === 'failure' ? 'failed' : 'pending';
  return { status, payment_id: txn.mihpayid ?? null };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    const { gateway, reference } = await req.json();
    if (!gateway || !reference) return json({ error: 'Missing gateway or reference' }, 400);

    const { data } = await supabase
      .from('app_config')
      .select('value')
      .eq('key', 'payment_gateways')
      .single();
    const gw = data?.value?.gateways?.[gateway] ?? {};

    let result;
    switch (gateway) {
      case 'razorpay': result = await razorpayStatus(supabase, gw, reference); break;
      case 'cashfree': result = await cashfreeStatus(supabase, gw, reference); break;
      case 'instamojo': result = await instamojoStatus(supabase, gw, reference); break;
      case 'payu': result = await payuStatus(supabase, gw, reference); break;
      default: return json({ error: `Unknown gateway '${gateway}'` }, 400);
    }

    return json({ gateway, reference, ...result });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});

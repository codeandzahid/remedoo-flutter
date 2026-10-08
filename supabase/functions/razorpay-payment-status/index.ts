import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

async function getSecret(supabase: any, key: string): Promise<string | null> {
  const { data } = await supabase
    .from('secure_settings')
    .select('value')
    .eq('key', key)
    .single();
  return data?.value ?? null;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    const RAZORPAY_KEY_ID = await getSecret(supabase, 'razorpay_key_id');
    const RAZORPAY_KEY_SECRET = await getSecret(supabase, 'razorpay_key_secret');

    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      return new Response(
        JSON.stringify({ error: 'Razorpay not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { payment_link_id } = await req.json();
    if (!payment_link_id) {
      return new Response(JSON.stringify({ error: 'Missing payment_link_id' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const auth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`);
    const rzpRes = await fetch(
      `https://api.razorpay.com/v1/payment_links/${payment_link_id}`,
      {
        headers: { 'Authorization': `Basic ${auth}` },
      }
    );

    const rzpData = await rzpRes.json();

    if (!rzpRes.ok) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch payment status' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // status: created, partially_paid, paid, cancelled, expired
    return new Response(
      JSON.stringify({
        status: rzpData.status,
        amount_paid: (rzpData.amount_paid ?? 0) / 100,
        payment_id: rzpData.payments?.[0]?.payment_id ?? null,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

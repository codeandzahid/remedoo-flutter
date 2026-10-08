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
        JSON.stringify({ error: 'Razorpay not configured', code: 'NOT_CONFIGURED' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const {
      amount, // in INR (will convert to paise)
      description,
      customer_name,
      customer_contact,
      customer_email,
      reference_id, // our order/appointment ID for tracking
      callback_url,
    } = await req.json();

    if (!amount || amount <= 0) {
      return new Response(JSON.stringify({ error: 'Invalid amount' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const amountPaise = Math.round(amount * 100);

    // Create Razorpay Payment Link
    const auth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`);
    const rzpRes = await fetch('https://api.razorpay.com/v1/payment_links', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amountPaise,
        currency: 'INR',
        description: description || 'Remedoo Payment',
        customer: {
          ...(customer_name ? { name: customer_name } : {}),
          ...(customer_contact ? { contact: customer_contact } : {}),
          ...(customer_email ? { email: customer_email } : {}),
        },
        notify: { sms: false, email: false },
        reminder_enable: false,
        ...(reference_id ? { reference_id } : {}),
        ...(callback_url
          ? { callback_url, callback_method: 'get' }
          : {}),
      }),
    });

    const rzpData = await rzpRes.json();

    if (!rzpRes.ok) {
      console.error('Razorpay payment link error:', rzpData);
      return new Response(
        JSON.stringify({
          error: rzpData?.error?.description || 'Failed to create payment link',
          code: 'RAZORPAY_ERROR',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({
        payment_link_id: rzpData.id,
        payment_url: rzpData.short_url,
        status: rzpData.status,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    console.error('payment-link error:', e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

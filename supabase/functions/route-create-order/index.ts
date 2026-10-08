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

// Platform commission percentage (configurable)
const PLATFORM_FEE_PERCENT = 5;

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

    const { amount, currency = 'INR', provider_type, provider_id, receipt, notes } = await req.json();

    if (!amount || !provider_type || !provider_id) {
      return new Response(JSON.stringify({ error: 'Missing amount, provider_type, or provider_id' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Get provider's Razorpay linked account
    const tableMap: Record<string, string> = {
      doctor: 'doctors',
      hospital: 'hospitals',
      lab: 'labs',
      pharmacy: 'pharmacies',
    };
    const table = tableMap[provider_type];
    if (!table) {
      return new Response(JSON.stringify({ error: 'Invalid provider type' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: provider, error: fetchError } = await supabase
      .from(table)
      .select('razorpay_account_id, name')
      .eq('id', provider_id)
      .single();

    if (fetchError || !provider?.razorpay_account_id) {
      return new Response(
        JSON.stringify({
          error: 'Provider has not completed Razorpay onboarding',
          code: 'PROVIDER_NOT_ONBOARDED',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const amountPaise = Math.round(amount * 100);
    const platformFeePaise = Math.round((amountPaise * PLATFORM_FEE_PERCENT) / 100);
    const providerAmountPaise = amountPaise - platformFeePaise;

    // Create Razorpay order with Route transfers
    const orderRes = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Basic ' + btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`),
      },
      body: JSON.stringify({
        amount: amountPaise,
        currency,
        receipt: receipt || `rcpt_${Date.now()}`,
        notes: notes || {},
        transfers: [
          {
            account: provider.razorpay_account_id,
            amount: providerAmountPaise,
            currency,
            notes: {
              provider_type,
              provider_id,
              provider_name: provider.name,
            },
            on_hold: false,
          },
        ],
      }),
    });

    const order = await orderRes.json();
    if (!orderRes.ok) {
      console.error('Order creation failed:', order);
      return new Response(JSON.stringify({ error: 'Failed to create order', details: order }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        order_id: order.id,
        amount: amountPaise,
        currency,
        key_id: RAZORPAY_KEY_ID, // Public key, safe to expose
        provider_amount: providerAmountPaise,
        platform_fee: platformFeePaise,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    console.error('Error:', e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

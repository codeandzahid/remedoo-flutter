import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID')!;
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { provider_type, provider_id, email, phone, business_name, account_number, ifsc, beneficiary_name } =
      await req.json();

    if (!provider_type || !provider_id || !account_number || !ifsc) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Step 1: Create Razorpay Linked Account (Route)
    const accountRes = await fetch('https://api.razorpay.com/v1/accounts', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Basic ' + btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`),
      },
      body: JSON.stringify({
        email: email || `${provider_id}@remedoo.app`,
        phone: phone || '9999999999',
        type: 'route',
        reference_id: `${provider_type}_${provider_id}`.substring(0, 40),
        legal_business_name: business_name || 'Remedoo Provider',
        business_type: 'individual',
        contact_name: beneficiary_name || business_name || 'Provider',
        profile: {
          category: 'healthcare',
          subcategory: 'clinic',
          addresses: {
            registered: {
              street1: 'Remedoo Platform',
              street2: '',
              city: 'Srinagar',
              state: 'Jammu and Kashmir',
              postal_code: '190001',
              country: 'IN',
            },
          },
        },
        legal_info: { pan: 'ABCDE1234F', gst: '' },
      }),
    });

    const account = await accountRes.json();
    if (!accountRes.ok) {
      console.error('Razorpay account creation failed:', account);
      return new Response(JSON.stringify({ error: 'Failed to create Razorpay account', details: account }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Step 2: Add bank fund account (payout destination)
    const fundRes = await fetch(`https://api.razorpay.com/v1/fund_accounts`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Basic ' + btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`),
      },
      body: JSON.stringify({
        account_id: account.id,
        account_type: 'bank_account',
        bank_account: {
          name: beneficiary_name || business_name || 'Provider',
          ifsc: ifsc,
          account_number: account_number,
        },
      }),
    });

    const fundAccount = await fundRes.json();
    if (!fundRes.ok) {
      console.error('Fund account creation failed:', fundAccount);
    }

    // Step 3: Save to database
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    const tableMap: Record<string, string> = {
      doctor: 'doctors',
      hospital: 'hospitals',
      lab: 'labs',
      pharmacy: 'pharmacies',
    };
    const table = tableMap[provider_type];
    if (table) {
      await supabase
        .from(table)
        .update({
          razorpay_account_id: account.id,
          route_onboarding_status: 'created',
        })
        .eq('id', provider_id);
    }

    return new Response(
      JSON.stringify({
        success: true,
        account_id: account.id,
        fund_account_id: fundAccount?.id,
        status: 'created',
        message: 'Razorpay Route account created. Complete KYC in Razorpay dashboard.',
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

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

async function verifySignature(body: string, signature: string, secret: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(body));
  const hex = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return hex === signature;
}

serve(async (req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Read webhook secret from admin-configured secure settings
    const { data: secretRow } = await supabase
      .from('secure_settings')
      .select('value')
      .eq('key', 'razorpay_webhook_secret')
      .single();
    const RAZORPAY_WEBHOOK_SECRET = secretRow?.value;

    if (!RAZORPAY_WEBHOOK_SECRET) {
      console.error('Webhook secret not configured');
      return new Response(JSON.stringify({ error: 'Not configured' }), { status: 500 });
    }

    const body = await req.text();
    const signature = req.headers.get('x-razorpay-signature') || '';

    const valid = await verifySignature(body, signature, RAZORPAY_WEBHOOK_SECRET);
    if (!valid) {
      console.error('Invalid webhook signature');
      return new Response(JSON.stringify({ error: 'Invalid signature' }), { status: 400 });
    }

    const event = JSON.parse(body);

    console.log('Webhook event:', event.event);

    if (event.event === 'payment.captured') {
      const payment = event.payload.payment.entity;
      const orderId = payment.order_id;

      // Log the successful Route payment with transfer details
      await supabase.from('route_payments').insert({
        razorpay_payment_id: payment.id,
        razorpay_order_id: orderId,
        amount: payment.amount / 100,
        currency: payment.currency,
        status: 'captured',
        transfers: payment.transfers || [],
        raw_payload: event,
      });

      console.log(`Payment ${payment.id} captured for order ${orderId}`);
    }

    if (event.event === 'transfer.processed') {
      const transfer = event.payload.transfer.entity;
      await supabase
        .from('route_payments')
        .update({ transfer_status: 'processed', transfer_id: transfer.id })
        .eq('razorpay_payment_id', transfer.source);
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('Webhook error:', e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});

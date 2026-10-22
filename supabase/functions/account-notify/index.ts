import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Account-deletion emails (owner order 2026-10-22).
//
// The database queues rows in public.email_outbox (written by
// request_account_deletion and reactivate_account). This function
// sends the queued rows through Resend and marks them sent.
//
// Deploy + setup (one dashboard sitting, with the migrations):
//   supabase functions deploy account-notify
//   supabase secrets set RESEND_API_KEY=... EMAIL_FROM="Remedoo <support@remedoo.app>"
// Trigger it on a schedule (e.g. every 15 minutes from an external
// cron hitting this URL with the service-role key as Bearer token),
// or invoke it manually after a reactivation. Without RESEND_API_KEY
// it reports how many emails are waiting and sends nothing — rows
// stay queued, never lost.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const EMAIL_FROM = Deno.env.get('EMAIL_FROM') ?? 'Remedoo <support@remedoo.app>';

function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

serve(async (req) => {
  try {
    const auth = req.headers.get('Authorization') ?? '';
    if (auth !== `Bearer ${SERVICE_KEY}`) {
      return json({ error: 'Service role key required.' }, 401);
    }
    const db = createClient(SUPABASE_URL, SERVICE_KEY);
    const { data: rows, error } = await db
      .from('email_outbox')
      .select('id, to_email, subject, body')
      .is('sent_at', null)
      .order('created_at', { ascending: true })
      .limit(50);
    if (error) return json({ error: error.message }, 500);
    if (!rows || rows.length === 0) return json({ sent: 0, waiting: 0 });
    if (!RESEND_API_KEY) {
      return json({ sent: 0, waiting: rows.length, note: 'RESEND_API_KEY not set' });
    }
    let sent = 0;
    for (const row of rows) {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: EMAIL_FROM,
          to: [row.to_email],
          subject: row.subject,
          text: row.body,
        }),
      });
      if (res.ok) {
        await db
          .from('email_outbox')
          .update({ sent_at: new Date().toISOString() })
          .eq('id', row.id);
        sent++;
      }
    }
    return json({ sent, waiting: rows.length - sent });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

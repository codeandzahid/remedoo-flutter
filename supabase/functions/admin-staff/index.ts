import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Admin > Team: the SUPER ADMIN creates and removes staff (employee
// admin) accounts. Staff get role 'staff' + a row in admin_permissions
// listing the admin sections they may use — the database enforces it
// via RLS, the app only shows those sections.
//
// POST { action: 'create', name, email, password, sections: string[] }
// POST { action: 'delete', user_id }
// Caller must hold the 'admin' role (checked from their JWT).

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const auth = req.headers.get('Authorization') ?? '';
    const token = auth.replace(/^Bearer\s+/i, '');
    if (!token) return json({ error: 'Sign-in required.' }, 401);

    // Who is calling? (their own JWT, RLS-scoped reads)
    const asUser = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: userData, error: userErr } = await asUser.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: 'Sign-in required.' }, 401);
    }
    const callerId = userData.user.id;

    const admin = createClient(SUPABASE_URL, SERVICE_KEY);
    const { data: roleRows } = await admin
      .from('user_roles')
      .select('role')
      .eq('user_id', callerId)
      .eq('role', 'admin')
      .limit(1);
    if (!roleRows || roleRows.length === 0) {
      return json({ error: 'Only the super admin can manage staff.' }, 403);
    }

    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? '');

    if (action === 'create') {
      const name = String(body.name ?? '').trim();
      const email = String(body.email ?? '').trim().toLowerCase();
      const password = String(body.password ?? '');
      const sections = Array.isArray(body.sections)
        ? body.sections.map((s: any) => String(s)).slice(0, 40)
        : [];
      if (!name || !email || !email.includes('@')) {
        return json({ error: 'Name and a valid email are required.' }, 400);
      }
      if (password.length < 8) {
        return json(
          { error: 'Password must be at least 8 characters.' }, 400);
      }
      const { data: created, error: createErr } =
        await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: { name },
        });
      if (createErr || !created?.user) {
        return json(
          { error: createErr?.message || 'Could not create the account.' },
          400);
      }
      const uid = created.user.id;
      await admin.from('user_roles').insert({ user_id: uid, role: 'staff' });
      await admin
        .from('admin_permissions')
        .insert({ user_id: uid, sections });
      // Profile row so the person shows up with a name in the panel.
      try {
        await admin
          .from('profiles')
          .insert({ id: uid, name, email });
      } catch (_) {
        // best effort — the account works without it
      }
      return json({ ok: true, user_id: uid });
    }

    if (action === 'delete') {
      const uid = String(body.user_id ?? '');
      if (!uid) return json({ error: 'user_id is required.' }, 400);
      if (uid === callerId) {
        return json({ error: 'You cannot delete your own account.' }, 400);
      }
      const { error: delErr } = await admin.auth.admin.deleteUser(uid);
      if (delErr) {
        return json({ error: delErr.message }, 400);
      }
      // user_roles + admin_permissions cascade on auth user delete;
      // clean the profile row too if it lingers.
      try {
        await admin.from('profiles').delete().eq('id', uid);
      } catch (_) {}
      return json({ ok: true });
    }

    return json({ error: 'Unknown action.' }, 400);
  } catch (e) {
    return json({ error: String((e as any)?.message ?? e) }, 500);
  }
});

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Admin > Team: the SUPER ADMIN creates and removes staff (employee
// admin) accounts. Staff get role 'staff' + a row in staff_permissions
// listing the admin sections they may use — the database enforces it
// via RLS, the app only shows those sections.
//
// POST { action: 'create', name, email, password, sections: string[] }
// POST { action: 'create_user', name, email, password, phone? }
//   — a plain patient/user account (role 'user', no staff sections);
//   powers Support > Users > Add user (owner order 2026-10-23).
// POST { action: 'delete', user_id }
// POST { action: 'update_email', user_id, email }   — any account
// POST { action: 'set_password', user_id, password } — any account
// Caller must hold the 'admin' role (checked from their JWT).
// update_email / set_password (owner order 2026-10-22) power the
// Admin > Users edit dialog: the app asks the admin for an email OTP
// before calling these; the function re-checks the admin role here.

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
      // Access levels (2026-10-23) can double the entry count —
      // a view-only option stores its key plus a 'view:' marker —
      // so the cap sits well above 41 options x 2.
      const sections = Array.isArray(body.sections)
        ? body.sections.map((s: any) => String(s)).slice(0, 120)
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
        .from('staff_permissions')
        .insert({ user_id: uid, sections });
      // The auth trigger already created a profile row (keyed by
      // user_id, display name in full_name) — put the name on it.
      try {
        await admin
          .from('profiles')
          .update({ full_name: name })
          .eq('user_id', uid);
      } catch (_) {
        // best effort — the account works without it
      }
      return json({ ok: true, user_id: uid });
    }

    if (action === 'create_user') {
      const name = String(body.name ?? '').trim();
      const email = String(body.email ?? '').trim().toLowerCase();
      const password = String(body.password ?? '');
      const phone = String(body.phone ?? '').trim();
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
      await admin.from('user_roles').insert({ user_id: uid, role: 'user' });
      try {
        await admin
          .from('profiles')
          .update({ full_name: name, ...(phone ? { phone } : {}) })
          .eq('user_id', uid);
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
      // user_roles + staff_permissions cascade on auth user delete;
      // clean the profile row too if it lingers.
      try {
        await admin.from('profiles').delete().eq('user_id', uid);
      } catch (_) {}
      return json({ ok: true });
    }

    if (action === 'update_email') {
      const uid = String(body.user_id ?? '');
      const email = String(body.email ?? '').trim().toLowerCase();
      if (!uid) return json({ error: 'user_id is required.' }, 400);
      if (!email || !email.includes('@')) {
        return json({ error: 'A valid email is required.' }, 400);
      }
      const { error: upErr } = await admin.auth.admin.updateUserById(uid, {
        email,
        email_confirm: true,
      });
      if (upErr) return json({ error: upErr.message }, 400);
      // Keep the profile row (what the app displays) in sync.
      try {
        await admin
          .from('profiles')
          .update({ email })
          .eq('user_id', uid);
      } catch (_) {}
      return json({ ok: true });
    }

    if (action === 'set_password') {
      const uid = String(body.user_id ?? '');
      const password = String(body.password ?? '');
      if (!uid) return json({ error: 'user_id is required.' }, 400);
      if (password.length < 8) {
        return json(
          { error: 'Password must be at least 8 characters.' }, 400);
      }
      const { error: upErr } = await admin.auth.admin.updateUserById(uid, {
        password,
      });
      if (upErr) return json({ error: upErr.message }, 400);
      return json({ ok: true });
    }

    return json({ error: 'Unknown action.' }, 400);
  } catch (e) {
    return json({ error: String((e as any)?.message ?? e) }, 500);
  }
});

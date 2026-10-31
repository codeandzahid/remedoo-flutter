import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Provider teams (owner order 2026-10-24): every panelist (doctor /
// hospital / lab / pharmacy) can create a team, and hospitals, labs
// and pharmacies can also add drivers.
//
// POST { action: 'create_team_member', name, email, password, access }
//   — a login account with the SAME role as the caller's provider,
//   linked through provider_team_members with a per-tab access map
//   { "<tab>": "full" | "view" | "none" }. Only the provider OWNER
//   (never a team member) may call this.
// POST { action: 'remove_team_member', user_id }
//   — owner only; deletes the account (membership row cascades).
// POST { action: 'create_driver', name, phone, vehicle_type,
//        vehicle_number, email, password, status? }
//   — hospital / lab / pharmacy owner only; creates a 'driver'
//   account + delivery_drivers row tagged with the adding provider,
//   so the driver joins the pool the provider assigns from.
//   The super admin may also add a general-pool driver with no
//   provider (Admin > Drivers, owner order 2026-10-31): the row
//   stays untagged and the status comes from the form
//   (default 'offline').
// POST { action: 'remove_driver', user_id }
//   — owner only; deactivates the driver row (history is kept, the
//   login stays so past deliveries still resolve).
// Caller must own a provider record (checked from their JWT via the
// service client); the super admin may also act for any provider.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const PROVIDER_TABLES: Record<string, string> = {
  doctor: 'doctors',
  hospital: 'hospitals',
  lab: 'labs',
  pharmacy: 'pharmacies',
};

// Tab keys each panel offers (must match the app's provider_team.dart).
const PANEL_TABS: Record<string, string[]> = {
  doctor: ['visits', 'profile', 'payments', 'reviews'],
  hospital: ['appointments', 'profile', 'payments', 'reviews', 'drivers'],
  lab: ['bookings', 'my_tests', 'profile', 'payments', 'reviews', 'drivers'],
  pharmacy: [
    'orders',
    'medicines',
    'profile',
    'payments',
    'reviews',
    'drivers',
  ],
};

function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function cleanAccess(providerType: string, raw: any): Record<string, string> {
  const allowed = new Set(PANEL_TABS[providerType] ?? []);
  const out: Record<string, string> = {};
  if (raw && typeof raw === 'object') {
    for (const [k, v] of Object.entries(raw)) {
      if (!allowed.has(k)) continue;
      const level = String(v);
      if (level === 'full' || level === 'view' || level === 'none') {
        out[k] = level;
      }
    }
  }
  // Every offered tab gets a level; anything missing is 'none'
  // (fail closed) except the work tab, which defaults to 'view'.
  for (const tab of allowed) {
    if (!(tab in out)) out[tab] = 'none';
  }
  return out;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const auth = req.headers.get('Authorization') ?? '';
    const token = auth.replace(/^Bearer\s+/i, '');
    if (!token) return json({ error: 'Sign-in required.' }, 401);

    const asUser = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: userData, error: userErr } = await asUser.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: 'Sign-in required.' }, 401);
    }
    const callerId = userData.user.id;
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // Resolve the caller's OWN provider record (owner only — team
    // members own no record, so they can never manage a team).
    let providerType: string | null = null;
    let providerId: string | null = null;
    for (const [type, table] of Object.entries(PROVIDER_TABLES)) {
      const { data } = await admin
        .from(table)
        .select('id')
        .eq('user_id', callerId)
        .limit(1);
      if (data && data.length > 0) {
        providerType = type;
        providerId = String(data[0].id);
        break;
      }
    }
    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? '');

    // Admin path: the provider comes from the body — except an
    // admin adding a general-pool driver (Admin > Drivers, owner
    // order 2026-10-31), who names no provider and the driver row
    // stays untagged.
    if (!providerType) {
      // Super admin may act for a provider named in the body.
      const { data: roleRows } = await admin
        .from('user_roles')
        .select('role')
        .eq('user_id', callerId)
        .eq('role', 'admin')
        .limit(1);
      if (!roleRows || roleRows.length === 0) {
        return json(
          { error: 'Only a provider owner can manage a team.' }, 403);
      }
      const namedType = String(body.provider_type ?? '');
      const namedId = String(body.provider_id ?? '');
      if (!namedType && !namedId && action === 'create_driver') {
        // General-pool driver: providerType/providerId stay null.
      } else if (namedType in PROVIDER_TABLES && namedId) {
        providerType = namedType;
        providerId = namedId;
      } else {
        return json(
          { error: 'provider_type and provider_id are required.' }, 400);
      }
    }

    if (action === 'create_team_member') {
      const name = String(body.name ?? '').trim();
      const email = String(body.email ?? '').trim().toLowerCase();
      const password = String(body.password ?? '');
      if (!name || !email || !email.includes('@')) {
        return json({ error: 'Name and a valid email are required.' }, 400);
      }
      if (password.length < 8) {
        return json(
          { error: 'Password must be at least 8 characters.' }, 400);
      }
      const access = cleanAccess(providerType, body.access);
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
      await admin
        .from('user_roles')
        .insert({ user_id: uid, role: providerType });
      const { error: linkErr } = await admin
        .from('provider_team_members')
        .insert({
          provider_type: providerType,
          provider_id: providerId,
          user_id: uid,
          name,
          email,
          access,
          created_by: callerId,
        });
      if (linkErr) {
        // Roll back the orphan login rather than leaving a
        // team-less account behind.
        await admin.auth.admin.deleteUser(uid);
        return json({ error: linkErr.message }, 400);
      }
      try {
        await admin
          .from('profiles')
          .update({ full_name: name })
          .eq('user_id', uid);
      } catch (_) {}
      return json({ ok: true, user_id: uid });
    }

    if (action === 'remove_team_member') {
      const uid = String(body.user_id ?? '');
      if (!uid) return json({ error: 'user_id is required.' }, 400);
      if (uid === callerId) {
        return json({ error: 'You cannot remove your own account.' }, 400);
      }
      // Only a member of THIS provider may be removed.
      const { data: rows } = await admin
        .from('provider_team_members')
        .select('id')
        .eq('provider_type', providerType)
        .eq('provider_id', providerId)
        .eq('user_id', uid)
        .limit(1);
      if (!rows || rows.length === 0) {
        return json(
          { error: 'That person is not on your team.' }, 403);
      }
      const { error: delErr } = await admin.auth.admin.deleteUser(uid);
      if (delErr) return json({ error: delErr.message }, 400);
      try {
        await admin.from('profiles').delete().eq('user_id', uid);
      } catch (_) {}
      return json({ ok: true });
    }

    if (action === 'create_driver') {
      // A provider adding a driver must be a hospital, lab or
      // pharmacy; a null provider means the super admin adding a
      // general-pool driver (Admin > Drivers).
      if (
        providerType !== null &&
        providerType !== 'hospital' &&
        providerType !== 'lab' &&
        providerType !== 'pharmacy'
      ) {
        return json(
          { error: 'Only hospitals, labs and pharmacies add drivers.' },
          403);
      }
      const name = String(body.name ?? '').trim();
      const phone = String(body.phone ?? '').trim();
      const vehicleType = String(body.vehicle_type ?? 'bike').trim();
      const vehicleNumber = String(body.vehicle_number ?? '').trim();
      const status =
        body.status === 'available' || body.status === 'offline'
          ? String(body.status)
          : 'offline';
      // A driver login needs an email; the panel builds a private
      // placeholder from the phone when none is given.
      const email = String(body.email ?? '').trim().toLowerCase();
      const password = String(body.password ?? '');
      if (!name) return json({ error: 'Name is required.' }, 400);
      if (!email || !email.includes('@')) {
        return json({ error: 'A valid email is required.' }, 400);
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
      await admin.from('user_roles').insert({ user_id: uid, role: 'driver' });
      const { error: drvErr } = await admin
        .from('delivery_drivers')
        .insert({
          user_id: uid,
          name,
          phone: phone || null,
          vehicle_type: vehicleType || 'bike',
          vehicle_number: vehicleNumber || null,
          status,
          is_active: true,
          added_by_provider_type: providerType,
          added_by_provider_id: providerId,
        });
      if (drvErr) {
        await admin.auth.admin.deleteUser(uid);
        return json({ error: drvErr.message }, 400);
      }
      try {
        await admin
          .from('profiles')
          .update({ full_name: name, ...(phone ? { phone } : {}) })
          .eq('user_id', uid);
      } catch (_) {}
      return json({ ok: true, user_id: uid });
    }

    if (action === 'remove_driver') {
      const uid = String(body.user_id ?? '');
      if (!uid) return json({ error: 'user_id is required.' }, 400);
      const { data: rows } = await admin
        .from('delivery_drivers')
        .select('id')
        .eq('user_id', uid)
        .eq('added_by_provider_type', providerType)
        .eq('added_by_provider_id', providerId)
        .limit(1);
      if (!rows || rows.length === 0) {
        return json(
          { error: 'That driver was not added by you.' }, 403);
      }
      // Deactivate only: past deliveries still resolve to the row.
      await admin
        .from('delivery_drivers')
        .update({ is_active: false, status: 'offline' })
        .eq('user_id', uid);
      return json({ ok: true });
    }

    return json({ error: 'Unknown action.' }, 400);
  } catch (e) {
    return json({ error: String((e as any)?.message ?? e) }, 500);
  }
});

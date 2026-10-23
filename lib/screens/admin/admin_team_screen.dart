import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/existing_user_lookup.dart';
import '../../widgets/widgets.dart';
import '../../widgets/form_kit.dart';
import '../../utils/staff_access.dart';

/// Assignable admin sections for staff accounts (key -> label).
/// 'team' is deliberately absent: only the super admin manages staff.
const kStaffSectionOptions = <(String, String)>[
  ('dashboard', 'Dashboard'),
  // Users
  ('doctors', 'Doctors'),
  ('hospitals', 'Hospitals'),
  ('labs', 'Labs'),
  ('pharmacies', 'Pharmacies'),
  ('users', 'Users'),
  // Catalog
  ('lab_tests', 'Lab Tests'),
  ('medicines', 'Medicines'),
  ('inventory', 'Inventory'),
  ('coupons', 'Coupons'),
  ('corporate', 'Corporate Plans'),
  ('packages', 'Healthcare Packages'),
  ('subscriptions', 'Subscriptions'),
  // Providers
  ('applications', 'Applications'),
  ('reviews', 'Reviews'),
  ('drivers', 'Drivers'),
  // Payments
  ('remedoo_pay', 'Remedoo Pay'),
  ('provider_payments', 'Payments (UPI)'),
  // Orders & Care
  ('orders', 'Orders'),
  ('appointments', 'Appointments'),
  ('refunds', 'Refunds'),
  ('emergencies', 'Emergencies'),
  ('ambulance', 'Ambulance'),
  // Support
  ('support', 'Support (Tickets, Chat, Account Deletion, Users)'),
  // Content
  ('announcements', 'Announcements'),
  ('broadcasts', 'Broadcasts'),
  ('faqs', 'FAQs'),
  ('legal_pages', 'Legal Pages'),
  ('slider_media', 'Home Slider'),
  ('ads', 'Ads'),
  // Insights
  ('revenue', 'Revenue'),
  ('analytics', 'Analytics'),
  ('export_data', 'Export Data'),
  // Settings
  ('settings', 'App Settings'),
  ('branding', 'Branding'),
  ('commission', 'Commission'),
  ('platform_settings', 'Platform Settings'),
  ('panel_style', 'Panel Style'),
  // Management ('team' itself is never assignable to staff)
  ('service_areas', 'Service Areas'),
  ('featured', 'Featured'),
];

String staffSectionLabel(String key) {
  for (final o in kStaffSectionOptions) {
    if (o.$1 == key) return o.$2;
  }
  return key;
}

/// The same options grouped by sidebar section, for the detailed
/// access picker (owner order 2026-10-23: choose per option, not
/// just per section). Dashboard stands alone at the top.
const kStaffSectionGroups = <(String, List<(String, String)>)>[
  ('Overview', [('dashboard', 'Dashboard')]),
  ('Users', [
    ('doctors', 'Doctors'),
    ('hospitals', 'Hospitals'),
    ('labs', 'Labs'),
    ('pharmacies', 'Pharmacies'),
    ('users', 'Users'),
  ]),
  ('Catalog', [
    ('lab_tests', 'Lab Tests'),
    ('medicines', 'Medicines'),
    ('inventory', 'Inventory'),
    ('coupons', 'Coupons'),
    ('corporate', 'Corporate Plans'),
    ('packages', 'Healthcare Packages'),
    ('subscriptions', 'Subscriptions'),
  ]),
  ('Providers', [
    ('applications', 'Applications'),
    ('reviews', 'Reviews'),
    ('drivers', 'Drivers'),
  ]),
  ('Payments', [
    ('remedoo_pay', 'Remedoo Pay'),
    ('provider_payments', 'Payments (UPI)'),
  ]),
  ('Orders & Care', [
    ('orders', 'Orders'),
    ('appointments', 'Appointments'),
    ('refunds', 'Refunds'),
    ('emergencies', 'Emergencies'),
    ('ambulance', 'Ambulance'),
  ]),
  ('Support', [
    ('support', 'Support (Tickets, Chat, Account Deletion, Users)'),
  ]),
  ('Content', [
    ('announcements', 'Announcements'),
    ('broadcasts', 'Broadcasts'),
    ('faqs', 'FAQs'),
    ('legal_pages', 'Legal Pages'),
    ('slider_media', 'Home Slider'),
    ('ads', 'Ads'),
  ]),
  ('Insights', [
    ('revenue', 'Revenue'),
    ('analytics', 'Analytics'),
    ('export_data', 'Export Data'),
  ]),
  ('Settings', [
    ('settings', 'App Settings'),
    ('branding', 'Branding'),
    ('commission', 'Commission'),
    ('platform_settings', 'Platform Settings'),
    ('panel_style', 'Panel Style'),
  ]),
  ('Management', [
    ('service_areas', 'Service Areas'),
    ('featured', 'Featured'),
  ]),
];

/// Admin > Team: the super admin creates staff (employee admin)
/// accounts and ticks exactly which admin sections each may use.
/// Enforced in the database (RLS), not just hidden in the menu.
class AdminTeamScreen extends StatefulWidget {
  const AdminTeamScreen({super.key});

  @override
  State<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends State<AdminTeamScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    final rows = await state.supabaseRepository.fetchStaffMembers();
    if (!mounted) return;
    setState(() {
      _members = rows;
      _loading = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _create() async {
    final state = AppStateScope.of(context);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const CreateStaffDialog(),
    );
    if (result == null) return;
    final err = await state.supabaseRepository.invokeAdminStaff({
      'action': 'create',
      'name': result['name'],
      'email': result['email'],
      'password': result['password'],
      'sections': result['sections'],
    });
    if (err != null) {
      _snack(err);
      return;
    }
    _snack('Staff account created.');
    _load();
  }

  /// Deactivate / reactivate a staff account (audit Admin
  /// gap 17: there was no way to pause an account short of
  /// deleting it). Deactivation clears all sections AND marks
  /// the profile suspended; reactivation restores the profile
  /// — sections are re-ticked by the super admin.
  Future<void> _toggleActive(Map<String, dynamic> m, bool active) async {
    final state = AppStateScope.of(context);
    final repo = state.supabaseRepository;
    final uid = '${m['user_id']}';
    // Full-check fix 2026-10-22: the section-clear result used to
    // be discarded — the message claimed "access removed" even
    // when clearing the sections had failed.
    var sectionsOk = true;
    if (!active) {
      sectionsOk = await repo.updateStaffSections(uid, const []);
    }
    final profileOk = await repo.adminUpdateProfile(
        uid, {'status': active ? 'active' : 'suspended'});
    final ok = sectionsOk && profileOk;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? (active
                  ? 'Account reactivated. Tick the sections they may use.'
                  : 'Account deactivated — access removed.')
              : 'Could not update the account.')),
    );
    if (ok) _load();
  }

  Future<void> _editAccess(Map<String, dynamic> m) async {
    final state = AppStateScope.of(context);
    final current = (m['sections'] as List).map((e) => '$e').toSet();
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _AccessDialog(
        title: 'Access for ${m['name'] ?? m['email']}',
        initial: current,
      ),
    );
    if (picked == null) return;
    final ok = await state.supabaseRepository
        .updateStaffSections('${m['user_id']}', picked.toList());
    _snack(ok ? 'Access updated.' : 'Could not update access.');
    if (ok) _load();
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    final state = AppStateScope.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Remove staff account?',
      message:
          '${m['name'] ?? ''} (${m['email'] ?? ''}) will no longer be able to sign in.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    final err = await state.supabaseRepository.invokeAdminStaff({
      'action': 'delete',
      'user_id': '${m['user_id']}',
    });
    _snack(err ?? 'Staff account removed.');
    if (err == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const RLoading();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: RSectionHeader(
                title: 'Team',
                subtitle:
                    'Employee admin accounts — each person sees only the sections you tick for them',
              ),
            ),
            RButton(
              label: 'Add staff',
              small: true,
              onPressed: _create,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'You are the super admin: you see and control everything. '
                  'Staff accounts can open ONLY the sections ticked for them — '
                  'the system blocks everything else, even outside this panel.',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_members.isEmpty)
          const REmptyState(
            icon: Icons.group_outlined,
            title: 'No staff accounts yet',
            subtitle:
                'Add your first employee account — a manager, support person, accountant…',
            compact: true,
          )
        else
          ..._members.map((m) {
            final sections =
                (m['sections'] as List).map((e) => '$e').toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          child: Text(
                            ('${m['name']}'.isNotEmpty
                                    ? '${m['name']}'
                                    : '${m['email']}')
                                .characters
                                .first
                                .toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m['name'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${m['email'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if ('${m['status'] ?? 'active'}' ==
                            'suspended')
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Chip(
                              label: Text('Suspended'),
                              labelStyle: TextStyle(fontSize: 11),
                              visualDensity:
                                  VisualDensity.compact,
                            ),
                          ),
                        Switch(
                          value: '${m['status'] ?? 'active'}' !=
                              'suspended',
                          onChanged: (v) => _toggleActive(m, v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.key_outlined),
                          tooltip: 'Edit access',
                          onPressed: () => _editAccess(m),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: RemedooTheme.destructive),
                          tooltip: 'Remove account',
                          onPressed: () => _remove(m),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (sections.isEmpty)
                      Text(
                        'No sections assigned — this account cannot open anything yet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: RemedooTheme.destructive,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final e
                              in staffLevelsDecode(sections).entries)
                            Chip(
                              label: Text(e.value == 'view'
                                  ? '${staffSectionLabel(e.key)} (view)'
                                  : staffSectionLabel(e.key)),
                              labelStyle: const TextStyle(fontSize: 11),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Detailed access picker (owner order 2026-10-23): instead of a
/// plain tick per section, every OPTION gets a level — No access,
/// View only, or Full access — grouped by sidebar section, with
/// per-group quick-set buttons. Speaks the encoded sections list
/// (see utils/staff_access.dart) through [initial]/[onChanged] so
/// the create dialog and the edit-access dialog share it.
class _SectionPicker extends StatefulWidget {
  final Set<String> initial;
  final ValueChanged<Set<String>> onChanged;

  const _SectionPicker({required this.initial, required this.onChanged});

  @override
  State<_SectionPicker> createState() => _SectionPickerState();
}

class _SectionPickerState extends State<_SectionPicker> {
  late final Map<String, String> _levels =
      staffLevelsDecode(widget.initial.toList());

  void _emit() =>
      widget.onChanged(staffSectionsEncode(_levels).toSet());

  void _set(String key, String? level) {
    setState(() {
      if (level == null) {
        _levels.remove(key);
      } else {
        _levels[key] = level;
      }
    });
    _emit();
  }

  void _setGroup(List<(String, String)> options, String? level) {
    setState(() {
      for (final o in options) {
        if (level == null) {
          _levels.remove(o.$1);
        } else {
          _levels[o.$1] = level;
        }
      }
    });
    _emit();
  }

  Widget _levelButton(String key, String label, String? level) {
    final active = _levels[key] == level;
    return InkWell(
      onTap: () => _set(key, level),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active ? RemedooTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? RemedooTheme.primary
                : const Color(0xFFD5D8DE),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'View = can open and see it, but cannot change anything. '
          'Full = can add, edit and delete.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  for (final o in kStaffSectionOptions) {
                    _levels[o.$1] = 'full';
                  }
                });
                _emit();
              },
              child: const Text('All full access'),
            ),
            TextButton(
              onPressed: () {
                setState(_levels.clear);
                _emit();
              },
              child: const Text('Clear all'),
            ),
          ],
        ),
        for (final g in kStaffSectionGroups) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  g.$1,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111318)),
                ),
              ),
              TextButton(
                onPressed: () => _setGroup(g.$2, 'full'),
                child: const Text('All full',
                    style: TextStyle(fontSize: 11.5)),
              ),
              TextButton(
                onPressed: () => _setGroup(g.$2, 'view'),
                child: const Text('All view',
                    style: TextStyle(fontSize: 11.5)),
              ),
              TextButton(
                onPressed: () => _setGroup(g.$2, null),
                child: const Text('None',
                    style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
          const Divider(height: 1),
          for (final o in g.$2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(o.$2,
                        style: const TextStyle(fontSize: 13.5)),
                  ),
                  _levelButton(o.$1, 'None', null),
                  const SizedBox(width: 5),
                  _levelButton(o.$1, 'View', 'view'),
                  const SizedBox(width: 5),
                  _levelButton(o.$1, 'Full', 'full'),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _AccessDialog extends StatefulWidget {
  final String title;
  final Set<String> initial;

  const _AccessDialog({required this.title, required this.initial});

  @override
  State<_AccessDialog> createState() => _AccessDialogState();
}

class _AccessDialogState extends State<_AccessDialog> {
  late Set<String> _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RFormHeaderBand(
                title: widget.title, icon: Icons.lock_outline),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: _SectionPicker(
                  initial: widget.initial,
                  onChanged: (s) => _picked = s,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: RFormActions(
                onCancel: () => Navigator.of(context).pop(),
                onPrimary: () => Navigator.of(context).pop(_picked),
                primaryLabel: 'Save access',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Create-staff dialog (Team screen). Also reused by the Support
/// section's "Add support user" (owner order 2026-10-23) with the
/// Support section preset and locked.
class CreateStaffDialog extends StatefulWidget {
  final String title;
  final Set<String> presetSections;
  final bool lockSections;
  final String? lockedNote;

  const CreateStaffDialog({
    super.key,
    this.title = 'Add staff account',
    this.presetSections = const {},
    this.lockSections = false,
    this.lockedNote,
  });

  @override
  State<CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends State<CreateStaffDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  Set<String> _picked = {};

  @override
  void initState() {
    super.initState();
    _picked = {...widget.presetSections};
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Existing-patient autofill (owner order, 2026-10-21): when the
    // typed email exactly matches a patient account, offer their
    // saved details; Fill puts their name into the form.
    return ExistingUserLookup(
      trigger: _email,
      onFill: (record) {
        if (record.fullName.isNotEmpty) {
          setState(() => _name.text = record.fullName);
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RFormHeaderBand(
                title: widget.title,
                icon: Icons.person_add_outlined,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RKitField(
                          controller: _name,
                          label: 'Full name',
                          icon: Icons.person_outline),
                      const SizedBox(height: 14),
                      RKitField(
                          controller: _email,
                          label: 'Email (login)',
                          icon: Icons.mail_outline),
                      const SizedBox(height: 14),
                      RKitField(
                        controller: _password,
                        label: 'Password (min 8 characters)',
                        icon: Icons.lock_outline,
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      if (widget.lockSections) ...[
                        Text(
                          widget.lockedNote ??
                              'This person will get the sections above only.',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'What can this person open, and what can they change?',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _SectionPicker(
                          initial: widget.presetSections,
                          onChanged: (s) => _picked = s,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: RFormActions(
                  onCancel: () => Navigator.of(context).pop(),
                  primaryLabel: 'Create account',
                  onPrimary: () {
            final name = _name.text.trim();
            final email = _email.text.trim();
            final password = _password.text;
            if (name.isEmpty || !email.contains('@')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Enter a name and a valid email.')),
              );
              return;
            }
            if (password.length < 8) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Password must be at least 8 characters.')),
              );
              return;
            }
            Navigator.of(context).pop({
              'name': name,
              'email': email,
              'password': password,
              'sections': _picked.toList(),
            });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

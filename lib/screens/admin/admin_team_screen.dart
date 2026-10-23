import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/existing_user_lookup.dart';
import '../../widgets/widgets.dart';
import '../../widgets/form_kit.dart';

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
  // Providers
  ('applications', 'Applications'),
  ('provider_payments', 'Payments (UPI)'),
  ('reviews', 'Reviews'),
  // Orders & Care
  ('orders', 'Orders'),
  ('appointments', 'Appointments'),
  ('refunds', 'Refunds'),
  ('emergencies', 'Emergencies'),
  ('ambulance', 'Ambulance'),
  // Support
  ('support', 'Support (Tickets, Chat, Account Deletion)'),
  // Content
  ('announcements', 'Announcements'),
  ('faqs', 'FAQs'),
  ('legal_pages', 'Legal Pages'),
  ('slider_media', 'Home Slider'),
  ('ads', 'Ads'),
  ('broadcasts', 'Broadcasts'),
  // Insights
  ('revenue', 'Revenue'),
  ('analytics', 'Analytics'),
  // Payments
  ('remedoo_pay', 'Remedoo Pay'),
  // Settings
  ('settings', 'App Settings'),
  ('branding', 'Branding'),
  ('commission', 'Commission'),
  ('subscriptions', 'Subscriptions'),
  ('corporate', 'Corporate Plans'),
  ('packages', 'Healthcare Packages'),
  ('service_areas', 'Service Areas'),
  ('featured', 'Featured'),
  ('platform_settings', 'Platform Settings'),
  ('export_data', 'Export Data'),
  ('panel_style', 'Panel Style'),
];

String staffSectionLabel(String key) {
  for (final o in kStaffSectionOptions) {
    if (o.$1 == key) return o.$2;
  }
  return key;
}

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
                          for (final k in sections)
                            Chip(
                              label: Text(staffSectionLabel(k)),
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

class _SectionPicker extends StatefulWidget {
  final Set<String> initial;
  final ValueChanged<Set<String>> onChanged;

  const _SectionPicker({required this.initial, required this.onChanged});

  @override
  State<_SectionPicker> createState() => _SectionPickerState();
}

class _SectionPickerState extends State<_SectionPicker> {
  late final Set<String> _picked = {...widget.initial};

  void _emit() => widget.onChanged({..._picked});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _picked
                      .addAll(kStaffSectionOptions.map((o) => o.$1));
                });
                _emit();
              },
              child: const Text('Select all'),
            ),
            TextButton(
              onPressed: () {
                setState(_picked.clear);
                _emit();
              },
              child: const Text('Clear'),
            ),
          ],
        ),
        for (final o in kStaffSectionOptions)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(o.$2, style: const TextStyle(fontSize: 13.5)),
            value: _picked.contains(o.$1),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _picked.add(o.$1);
                } else {
                  _picked.remove(o.$1);
                }
              });
              _emit();
            },
          ),
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
                          'Which sections can this person open?',
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

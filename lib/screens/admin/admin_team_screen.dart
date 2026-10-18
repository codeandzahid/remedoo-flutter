import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Assignable admin sections for staff accounts (key -> label).
/// 'team' is deliberately absent: only the super admin manages staff.
const kStaffSectionOptions = <(String, String)>[
  ('dashboard', 'Dashboard'),
  ('doctors', 'Doctors'),
  ('hospitals', 'Hospitals'),
  ('labs', 'Labs'),
  ('lab_tests', 'Lab Tests'),
  ('pharmacies', 'Pharmacies'),
  ('medicines', 'Medicines'),
  ('inventory', 'Inventory'),
  ('applications', 'Applications'),
  ('provider_payments', 'Payments (UPI)'),
  ('reviews', 'Reviews'),
  ('orders', 'Orders'),
  ('appointments', 'Appointments'),
  ('refunds', 'Refunds'),
  ('emergencies', 'Emergencies'),
  ('ambulance', 'Ambulance'),
  ('support', 'Support Tickets'),
  ('announcements', 'Announcements'),
  ('settings', 'App Settings'),
  ('branding', 'Branding'),
  ('commission', 'Commission'),
  ('subscriptions', 'Subscriptions'),
  ('corporate', 'Corporate Plans'),
  ('packages', 'Healthcare Packages'),
  ('service_areas', 'Service Areas'),
  ('featured', 'Featured'),
  ('revenue', 'Revenue'),
  ('analytics', 'Analytics'),
  ('users', 'Users'),
  ('remedoo_pay', 'Remedoo Pay'),
  ('export_data', 'Export Data'),
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
      builder: (_) => const _CreateStaffDialog(),
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
            color: RemedooTheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 18, color: RemedooTheme.primary),
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
                              RemedooTheme.primary.withValues(alpha: 0.12),
                          child: Text(
                            ('${m['name']}'.isNotEmpty
                                    ? '${m['name']}'
                                    : '${m['email']}')
                                .characters
                                .first
                                .toUpperCase(),
                            style: TextStyle(
                              color: RemedooTheme.primary,
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
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: _SectionPicker(
            initial: widget.initial,
            onChanged: (s) => _picked = s,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_picked),
          child: const Text('Save access'),
        ),
      ],
    );
  }
}

class _CreateStaffDialog extends StatefulWidget {
  const _CreateStaffDialog();

  @override
  State<_CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends State<_CreateStaffDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  Set<String> _picked = {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add staff account'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RTextField(controller: _name, label: 'Full name'),
              const SizedBox(height: 10),
              RTextField(controller: _email, label: 'Email (login)'),
              const SizedBox(height: 10),
              RTextField(
                controller: _password,
                label: 'Password (min 8 characters)',
                obscureText: true,
              ),
              const SizedBox(height: 14),
              const Text(
                'Which sections can this person open?',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _SectionPicker(
                initial: const {},
                onChanged: (s) => _picked = s,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
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
          child: const Text('Create account'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../widgets/widgets.dart';
import '../../widgets/form_kit.dart';

/// Real user list from Supabase profiles with role management.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await AppStateScope.of(context).loadAllProfiles();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _changeRole(Map<String, dynamic> user, String newRole) async {
    final ok = await SupabaseRepository.instance
        .setUserRole('${user['user_id']}', newRole);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Role updated to $newRole for ${user['email']}'
            : 'Failed to update role'),
      ),
    );
    if (ok) _load();
  }


  /// Profile + status editor (audit Admin gap 6).
  Future<void> _editUser(Map<String, dynamic> u) async {
    final name = TextEditingController(text: '${u['full_name'] ?? ''}');
    final phone = TextEditingController(text: '${u['phone'] ?? ''}');
    final address = TextEditingController(text: '${u['address'] ?? ''}');
    final language =
        TextEditingController(text: '${u['language'] ?? ''}');
    final upi = TextEditingController(text: '${u['upi_id'] ?? ''}');
    final dob = TextEditingController(
        text: '${u['date_of_birth'] ?? ''}'.split('T').first);
    var gender = '${u['gender'] ?? ''}';
    var status = '${u['status'] ?? 'active'}';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Edit ${u['email'] ?? 'user'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RKitField(controller: name, label: 'Full name'),
                RKitField(controller: phone, label: 'Phone'),
                RKitField(controller: address, label: 'Address'),
                RKitField(controller: language, label: 'Language code (en, hi, ur, ks)'),
                RKitField(controller: upi, label: 'UPI ID'),
                RKitField(controller: dob, label: 'Date of birth (YYYY-MM-DD)'),
                RKitDropdown<String>(
                  label: 'Gender',
                  value: const ['male', 'female', 'other']
                          .contains(gender)
                      ? gender
                      : null,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('—')),
                    DropdownMenuItem(value: 'male', child: Text('male')),
                    DropdownMenuItem(
                        value: 'female', child: Text('female')),
                    DropdownMenuItem(
                        value: 'other', child: Text('other')),
                  ],
                  onChanged: (v) => setD(() => gender = v ?? ''),
                ),
                RKitDropdown<String>(
                  label: 'Account status',
                  value: status,
                  items: const [
                    DropdownMenuItem(
                        value: 'active', child: Text('active')),
                    DropdownMenuItem(
                        value: 'suspended',
                        child: Text('suspended')),
                  ],
                  onChanged: (v) =>
                      setD(() => status = v ?? 'active'),
                ),
                if (status == 'suspended')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'A suspended user is flagged in every admin list. '
                      'Their sign-in should be treated as blocked.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final ok = await SupabaseRepository.instance.adminUpdateProfile(
      '${u['user_id']}',
      {
        'full_name': name.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'language':
            language.text.trim().isEmpty ? null : language.text.trim(),
        'upi_id': upi.text.trim().isEmpty ? null : upi.text.trim(),
        'gender': gender.isEmpty ? null : gender,
        'date_of_birth': dob.text.trim().isEmpty ? null : dob.text.trim(),
        'status': status,
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok ? 'User updated.' : 'Update failed.')),
    );
    if (ok) _load();
  }

  void _showRoleDialog(Map<String, dynamic> user) {
    const roles = ['user', 'doctor', 'pharmacy', 'lab', 'hospital', 'driver', 'admin'];
    final current = '${user['role'] ?? 'user'}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Role for ${user['email'] ?? 'user'}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: roles
                .map((r) => ListTile(
                      title: Text(r[0].toUpperCase() + r.substring(1)),
                      trailing: current == r
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (current != r) _changeRole(user, r);
                      },
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const RLoading();
    }
    final q = _query.trim().toLowerCase();
    final users = state.allProfiles.where((u) {
      if (q.isEmpty) return true;
      return '${u['full_name'] ?? ''}'.toLowerCase().contains(q) ||
          '${u['email'] ?? ''}'.toLowerCase().contains(q) ||
          '${u['phone'] ?? ''}'.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: RKitField(
            hint: 'Search name, email or phone…',
            prefixIcon: const Icon(Icons.search),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('${users.length} users',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: users.isEmpty
              ? const REmptyState(
                  icon: Icons.people_outline,
                  title: 'No users found',
                  subtitle: 'Try a different search.',
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final name = '${u['full_name'] ?? 'Unnamed'}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: ListTile(
                          onTap: () => _editUser(u),
                          leading: CircleAvatar(
                            backgroundColor: scheme.primary
                                .withValues(alpha: 0.12),
                            child: Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary),
                            ),
                          ),
                          title: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if ('${u['email'] ?? ''}'.isNotEmpty)
                                Text('${u['email']}',
                                    style: const TextStyle(fontSize: 12)),
                              if ('${u['phone'] ?? ''}'.isNotEmpty)
                                Text('${u['phone']}',
                                    style: const TextStyle(fontSize: 12)),
                              if ('${u['status'] ?? 'active'}' ==
                                  'suspended')
                                const Text('SUSPENDED',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.red)),
                            ],
                          ),
                          trailing: InkWell(
                            onTap: () {
                              // Roles belong to the super admin only;
                              // staff (even with Users access) can't
                              // change them — the database blocks it too.
                              if (state.isStaff) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Only the super admin can change roles.')),
                                );
                                return;
                              }
                              _showRoleDialog(u);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${u['role'] ?? 'user'}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit,
                                      size: 14, color: scheme.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

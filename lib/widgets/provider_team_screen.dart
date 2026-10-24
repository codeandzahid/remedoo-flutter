import 'package:flutter/material.dart';

import '../services/supabase_repository.dart';
import '../utils/provider_team.dart';
import 'widgets.dart';

/// One partner-panel tab: (access key, page, nav item).
typedef PartnerTab = (String, Widget, BottomNavigationBarItem);

/// Filters a partner panel's tabs by the signed-in user's team
/// access and appends the Team tab for the provider owner.
/// Returns the visible tabs, the clamped selected index, and
/// whether the selected tab is view-only for a team member.
({List<PartnerTab> tabs, int index, bool viewOnly}) partnerTabs({
  required List<PartnerTab> entries,
  required bool isOwner,
  required Map<String, String> access,
  required int currentIndex,
  required String providerType,
  required String? providerId,
  required SupabaseRepository repo,
}) {
  final visible = entries
      .where((t) => isOwner || teamAccessLevel(access, t.$1) != 'none')
      .toList();
  if (isOwner && providerId != null) {
    visible.add((
      'team',
      ProviderTeamScreen(
        providerType: providerType,
        providerId: providerId,
        repo: repo,
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.group),
        label: 'Team',
      ),
    ));
  }
  if (visible.isEmpty) {
    return (tabs: visible, index: 0, viewOnly: false);
  }
  final index = currentIndex.clamp(0, visible.length - 1);
  final viewOnly = !isOwner &&
      teamAccessLevel(access, visible[index].$1) == 'view';
  return (tabs: visible, index: index, viewOnly: viewOnly);
}

/// "View only" banner shown above a team member's view-only tab.
Widget viewOnlyBanner() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: Colors.amber.shade100,
    child: const Text(
      'View only — you can see this tab, but changes are off for '
      'your account.',
      style: TextStyle(fontSize: 13),
    ),
  );
}

/// Team tab for provider panels (owner order 2026-10-24).
/// Only the provider OWNER sees this tab. The owner adds team
/// members (own login, same panel, per-tab access) and — for
/// hospitals, labs and pharmacies — drivers (own driver login,
/// tagged with this provider so they join its assignment pool).
/// Account creation runs through the provider-team Edge Function;
/// until that function is deployed (dashboard sitting), adds fail
/// with a plain message and nothing is created.
class ProviderTeamScreen extends StatefulWidget {
  final String providerType; // doctor | hospital | lab | pharmacy
  final String providerId;
  final SupabaseRepository repo;

  const ProviderTeamScreen({
    super.key,
    required this.providerType,
    required this.providerId,
    required this.repo,
  });

  @override
  State<ProviderTeamScreen> createState() => _ProviderTeamScreenState();
}

class _ProviderTeamScreenState extends State<ProviderTeamScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _drivers = [];

  bool get _canAddDrivers => widget.providerType != 'doctor';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final members = await widget.repo
        .fetchTeamMembers(widget.providerType, widget.providerId);
    final drivers = _canAddDrivers
        ? await widget.repo
            .fetchOwnAddedDrivers(widget.providerType, widget.providerId)
        : const <Map<String, dynamic>>[];
    if (!mounted) return;
    setState(() {
      _members = members;
      _drivers = drivers;
      _loading = false;
    });
  }

  String _friendlyError(String err) {
    if (err.contains('404')) {
      return 'Team setup is not live yet — it activates after the next dashboard update. Nothing was created.';
    }
    return err;
  }

  Future<void> _addMember() async {
    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final passC = TextEditingController();
    final tabs = kProviderPanelTabs[widget.providerType] ?? const [];
    final access = {for (final (key, _) in tabs) key: 'none'};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add team member'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: emailC,
                decoration:
                    const InputDecoration(labelText: 'Email (their login)'),
              ),
              TextField(
                controller: passC,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password (8+ characters)'),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('What can they use?',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final (key, label) in tabs)
                _AccessRow(
                  label: label,
                  value: access[key]!,
                  onChanged: (v) => access[key] = v,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add member'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await widget.repo.invokeProviderTeam({
      'action': 'create_team_member',
      'name': nameC.text.trim(),
      'email': emailC.text.trim(),
      'password': passC.text,
      'access': access,
    });
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = _friendlyError(err));
      return;
    }
    _load();
  }

  Future<void> _removeMember(Map<String, dynamic> m) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove ${m['name'] ?? 'this member'}?',
      message: 'Their login stops working right away.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    final err = await widget.repo.invokeProviderTeam({
      'action': 'remove_team_member',
      'user_id': '${m['user_id']}',
    });
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = _friendlyError(err));
      return;
    }
    _load();
  }

  Future<void> _addDriver() async {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final vehicleNoC = TextEditingController();
    final emailC = TextEditingController();
    final passC = TextEditingController();
    var vehicle = 'bike';
    const vehicles = ['bike', 'scooter', 'car', 'van', 'bicycle'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add driver'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneC,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              DropdownButtonFormField<String>(
                initialValue: vehicle,
                items: [
                  for (final v in vehicles)
                    DropdownMenuItem(value: v, child: Text(v)),
                ],
                onChanged: (v) => vehicle = v ?? 'bike',
                decoration: const InputDecoration(labelText: 'Vehicle'),
              ),
              TextField(
                controller: vehicleNoC,
                decoration:
                    const InputDecoration(labelText: 'Vehicle number'),
              ),
              TextField(
                controller: emailC,
                decoration:
                    const InputDecoration(labelText: 'Email (their login)'),
              ),
              TextField(
                controller: passC,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password (8+ characters)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add driver'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await widget.repo.invokeProviderTeam({
      'action': 'create_driver',
      'name': nameC.text.trim(),
      'phone': phoneC.text.trim(),
      'vehicle_type': vehicle,
      'vehicle_number': vehicleNoC.text.trim(),
      'email': emailC.text.trim(),
      'password': passC.text,
    });
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = _friendlyError(err));
      return;
    }
    _load();
  }

  Future<void> _removeDriver(Map<String, dynamic> d) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove ${d['name'] ?? 'this driver'}?',
      message: 'They stop showing as an available driver. Past '
          'deliveries still keep their name.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    final err = await widget.repo.invokeProviderTeam({
      'action': 'remove_driver',
      'user_id': '${d['user_id']}',
    });
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = _friendlyError(err));
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final tabs = kProviderPanelTabs[widget.providerType] ?? const [];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Team members sign in with their own email and password '
            'and open your panel. Give each person only the tabs '
            'they need.',
            style: TextStyle(color: Colors.black54),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!,
                  style: TextStyle(color: Colors.red.shade800)),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text('Team members',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              FilledButton.icon(
                onPressed: _addMember,
                icon: const Icon(Icons.person_add),
                label: const Text('Add member'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_members.isEmpty)
            const Text('No team members yet.',
                style: TextStyle(color: Colors.black54))
          else
            for (final m in _members)
              Card(
                child: ListTile(
                  title: Text('${m['name'] ?? ''}'),
                  subtitle: Text([
                    '${m['email'] ?? ''}',
                    for (final (key, label) in tabs)
                      if (decodeTeamAccess(widget.providerType,
                              (m['access'] as Map?)?.cast<String, dynamic>())[
                          key] !=
                          'none')
                        '$label: ${teamAccessLabel(decodeTeamAccess(widget.providerType, (m['access'] as Map?)?.cast<String, dynamic>())[key]!)}',
                  ].join(' · ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeMember(m),
                  ),
                ),
              ),
          if (_canAddDrivers) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text('Drivers',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                FilledButton.icon(
                  onPressed: _addDriver,
                  icon: const Icon(Icons.delivery_dining),
                  label: const Text('Add driver'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_drivers.isEmpty)
              const Text(
                  'No drivers added yet. Added drivers can be '
                  'assigned to your deliveries.',
                  style: TextStyle(color: Colors.black54))
            else
              for (final d in _drivers)
                Card(
                  child: ListTile(
                    title: Text('${d['name'] ?? ''}'),
                    subtitle: Text([
                      if ('${d['phone'] ?? ''}'.isNotEmpty) '${d['phone']}',
                      '${d['vehicle_type'] ?? ''}',
                      if ('${d['vehicle_number'] ?? ''}'.isNotEmpty)
                        '${d['vehicle_number']}',
                      '${d['status'] ?? ''}',
                      if (d['is_active'] != true) 'removed',
                    ].join(' · ')),
                    trailing: d['is_active'] == true
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeDriver(d),
                          )
                        : null,
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _AccessRow extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _AccessRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_AccessRow> createState() => _AccessRowState();
}

class _AccessRowState extends State<_AccessRow> {
  late String _value = widget.value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(widget.label)),
        DropdownButton<String>(
          value: _value,
          items: [
            for (final level in kTeamAccessLevels)
              DropdownMenuItem(
                  value: level, child: Text(teamAccessLabel(level))),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _value = v);
            widget.onChanged(v);
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/widgets.dart';

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

/// SOS / emergency requests from Supabase with a dispatch workflow.
class AdminEmergenciesScreen extends StatefulWidget {
  const AdminEmergenciesScreen({super.key});

  @override
  State<AdminEmergenciesScreen> createState() =>
      _AdminEmergenciesScreenState();
}

class _AdminEmergenciesScreenState
    extends State<AdminEmergenciesScreen> {
  bool _loading = true;

  static const _flow = [
    'pending',
    'acknowledged',
    'dispatched',
    'resolved',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppStateScope.of(context).loadEmergencyRequests();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator());
    }
    final list = state.emergencyRequests.toList();
    if (list.isEmpty) {
      return const REmptyState(
        icon: Icons.sos,
        title: 'No SOS alerts',
        subtitle: 'Emergency alerts will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) =>
            _card(context, state, list[i]),
      ),
    );
  }

  Widget _card(BuildContext context, AppState state,
      Map<String, dynamic> r) {
    final scheme = Theme.of(context).colorScheme;
    final status = '${r['status'] ?? 'pending'}';
    final lat = r['latitude'];
    final lng = r['longitude'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      'SOS ${(r['id'] as String).length > 8 ? (r['id'] as String).substring(0, 8) : r['id']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
                StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 6),
            if (lat != null && lng != null)
              Text('Location: $lat, $lng',
                  style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant)),
            Text(
              'Raised ${_fmtDate(r['created_at']?.toString())}',
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant),
            ),
            if (r['assigned_ambulance_id'] != null)
              Text(
                'Ambulance: ${r['assigned_ambulance_id']}',
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue:
                  _flow.contains(status) ? status : null,
              decoration: const InputDecoration(
                labelText: 'Status',
                isDense: true,
              ),
              items: _flow
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.replaceAll('_', ' '))))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                final ok = await state.updateEmergencyRequest(
                    '${r['id']}', {'status': v});
                if (context.mounted && !ok) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Update failed. Try again.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

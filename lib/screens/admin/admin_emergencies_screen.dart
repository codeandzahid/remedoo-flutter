import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/widgets.dart';
import '../../widgets/form_kit.dart';

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
    final state = AppStateScope.of(context);
    await state.loadEmergencyRequests();
    await state.loadAmbulances();
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
      if (state.listLoadFailed('emergency_requests')) {
        return REmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load SOS alerts',
          subtitle:
              'The list failed to load — it is not necessarily empty.',
          actionLabel: 'Retry',
          onAction: _load,
        );
      }
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
                'Ambulance: ${state.ambulances.where((a) => '${a['id']}' == '${r['assigned_ambulance_id']}').map((a) => '${a['vehicle_number'] ?? ''}').firstOrNull ?? r['assigned_ambulance_id']}',
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: 12),
            RKitDropdown<String>(
                  label: 'Status',
                  value: _flow.contains(status) ? status : null,
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
            const SizedBox(height: 10),
            // Ambulance assignment (audit Admin gap 22: the
            // assigned vehicle used to be display-only text —
            // dispatch was a status word with no way to choose
            // WHICH ambulance goes).
            RKitDropdown<String>(
                  label: 'Assign ambulance',
                  value: r['assigned_ambulance_id']?.toString(),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Not assigned')),
                // Full-check fix 2026-10-22: every vehicle was
                // offered, including maintenance/closed ones.
                // Only available (or in-use) vehicles can be
                // picked; the currently assigned one always stays
                // listed so the value renders.
                for (final a in state.ambulances)
                  if (a['status'] == 'available' ||
                      a['status'] == 'in_use' ||
                      '${a['id']}' ==
                          r['assigned_ambulance_id']?.toString())
                    DropdownMenuItem(
                      value: '${a['id']}',
                      child: Text(
                          '${a['vehicle_number'] ?? 'Vehicle'} • ${a['status'] ?? ''}'),
                    ),
              ],
              onChanged: (v) async {
                final previousAmbulance =
                    r['assigned_ambulance_id']?.toString();
                final fields = <String, dynamic>{
                  'assigned_ambulance_id': v,
                  // Assigning a vehicle IS the dispatch step —
                  // from pending OR acknowledged (full-check fix
                  // 2026-10-22: acknowledged requests stayed
                  // undispatched, invisible to the dashboard's
                  // dispatched count).
                  if (v != null &&
                      (status == 'pending' || status == 'acknowledged'))
                    'status': 'dispatched',
                  // Clearing the vehicle on a dispatched request
                  // sends it back to the queue — a dispatched
                  // request with no ambulance was an inconsistent
                  // state presented as success.
                  if (v == null && status == 'dispatched')
                    'status': 'pending',
                };
                final ok = await state.updateEmergencyRequest(
                    '${r['id']}', fields);
                if (ok) {
                  // Keep the fleet board truthful: the vehicle is
                  // in use by this patient now; a replaced/cleared
                  // vehicle goes back to available.
                  if (v != null) {
                    await state.updateAmbulance(v, {
                      'status': 'in_use',
                      'assigned_patient_id': r['patient_id'],
                    });
                  }
                  if (previousAmbulance != null &&
                      previousAmbulance != v) {
                    await state.updateAmbulance(previousAmbulance, {
                      'status': 'available',
                      'assigned_patient_id': null,
                    });
                  }
                }
                if (context.mounted && !ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Assignment failed. Try again.')),
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

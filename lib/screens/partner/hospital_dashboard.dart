import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/widgets.dart';

/// Dashboard for logged-in hospitals: appointments and profile.
class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    final hospitals = state.adminTable('hospitals');
    final uid = state.supaUserId;
    Map<String, dynamic>? profile;
    for (final h in hospitals) {
      if ('${h['user_id']}' == uid) {
        profile = h;
        break;
      }
    }
    await state.loadAdminAppointments();
    final all = state.adminAppointments;
    List<Map<String, dynamic>> mine = [];
    if (profile != null) {
      final hid = '${profile['id']}';
      mine = all
          .where((a) => '${a['hospital_id']}' == hid)
          .toList();
    }
    if (mounted) {
      setState(() {
        _profile = profile;
        _appointments = mine;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final state = AppStateScope.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'Leave the partner app?',
      confirmLabel: 'Log Out',
    );
    if (ok && context.mounted) {
      state.switchRole('patient');
      state.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.local_hospital,
                      color: Colors.red, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_profile?['name'] ?? 'Hospital'}',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_profile?['location'] ?? ''}',
                        style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _statCard(context, 'Total Appointments',
              '${_appointments.length}', Icons.calendar_month, Colors.red),
          const SizedBox(height: 24),
          const RSectionHeader(
              title: 'Appointments',
              subtitle: 'Bookings at your hospital'),
          const SizedBox(height: 12),
          if (_appointments.isEmpty)
            const REmptyState(
                icon: Icons.calendar_today,
                title: 'No appointments yet',
                subtitle: 'Bookings will appear here.',
                compact: true)
          else
            ..._appointments.take(20).map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a['patient_name'] ?? 'Patient'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${a['appointment_date'] ?? ''} · ${a['status'] ?? ''}',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return RCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Dashboard for logged-in doctors: their appointments, profile, and stats.
class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
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
    // Find this doctor's catalog entry by user_id.
    final doctors = state.adminTable('doctors');
    final uid = state.supaUserId;
    Map<String, dynamic>? profile;
    for (final d in doctors) {
      if ('${d['user_id']}' == uid) {
        profile = d;
        break;
      }
    }
    // Load appointments for this doctor.
    await state.loadAdminAppointments();
    final all = state.adminAppointments;
    List<Map<String, dynamic>> mine = [];
    if (profile != null) {
      final docId = '${profile['id']}';
      mine = all
          .where((a) => '${a['doctor_id']}' == docId)
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
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todaysAppts = _appointments
        .where((a) => '${a['appointment_date']}'.startsWith(todayStr))
        .toList();
    final upcoming = _appointments
        .where((a) => !'${a['appointment_date']}'.startsWith(todayStr))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
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
          // Profile card
          RCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      RemedooTheme.teal.withValues(alpha: 0.12),
                  child: Text(
                    '${_profile?['name'] ?? 'D'}'
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: RemedooTheme.teal,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_profile?['name'] ?? 'Doctor'}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_profile?['specialty'] ?? ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stats
          Row(
            children: [
              Expanded(
                child: _statCard(context, "Today's", '${todaysAppts.length}',
                    Icons.today, RemedooTheme.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(context, 'Upcoming', '${upcoming.length}',
                    Icons.calendar_month, RemedooTheme.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(context, 'Total', '${_appointments.length}',
                    Icons.groups, scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const RSectionHeader(
            title: "Today's Appointments",
            subtitle: 'Patients visiting today',
          ),
          const SizedBox(height: 12),
          if (todaysAppts.isEmpty)
            const REmptyState(
              icon: Icons.calendar_today,
              title: 'No appointments today',
              subtitle: 'Enjoy your free day!',
              compact: true,
            )
          else
            ...todaysAppts.map((a) => _appointmentCard(context, a)),
          const SizedBox(height: 24),
          const RSectionHeader(
            title: 'Upcoming',
            subtitle: 'Future appointments',
          ),
          const SizedBox(height: 12),
          if (upcoming.isEmpty)
            const REmptyState(
              icon: Icons.upcoming,
              title: 'Nothing scheduled',
              subtitle: 'New bookings will appear here.',
              compact: true,
            )
          else
            ...upcoming.take(10).map((a) => _appointmentCard(context, a)),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return RCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentCard(
      BuildContext context, Map<String, dynamic> a) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: RemedooTheme.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person,
                  color: RemedooTheme.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${a['patient_name'] ?? 'Patient'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${a['appointment_date'] ?? ''} · ${a['status'] ?? ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

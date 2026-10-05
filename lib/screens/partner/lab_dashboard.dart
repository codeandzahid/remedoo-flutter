import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Dashboard for logged-in labs: test bookings and profile.
class LabDashboard extends StatefulWidget {
  const LabDashboard({super.key});

  @override
  State<LabDashboard> createState() => _LabDashboardState();
}

class _LabDashboardState extends State<LabDashboard> {
  bool _loading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    final labs = state.adminTable('labs');
    final uid = state.supaUserId;
    Map<String, dynamic>? profile;
    for (final l in labs) {
      if ('${l['user_id']}' == uid) {
        profile = l;
        break;
      }
    }
    if (mounted) {
      setState(() {
        _profile = profile;
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
        title: const Text('Lab Dashboard'),
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
                    color: RemedooTheme.purple
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.science,
                      color: RemedooTheme.purple, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_profile?['name'] ?? 'Lab'}',
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
          const SizedBox(height: 24),
          const RSectionHeader(
              title: 'Welcome',
              subtitle: 'Your lab is live on Remedoo'),
          const SizedBox(height: 12),
          RCard(
            child: Text(
              'Patients can book tests at your lab through the Remedoo app. '
              'Bookings will appear here once the booking flow is connected.',
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

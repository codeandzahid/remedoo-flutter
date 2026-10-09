import 'package:flutter/material.dart';

import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Dashboard for logged-in labs.
/// Shows test bookings with plain-language actions:
/// confirm the booking, mark the sample collected, mark the report ready.
class LabDashboard extends StatefulWidget {
  const LabDashboard({super.key});

  @override
  State<LabDashboard> createState() => _LabDashboardState();
}

class _LabDashboardState extends State<LabDashboard> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _bookings = [];

  SupabaseRepository get _repo =>
      AppStateScope.of(context).supabaseRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repo.fetchOwnProviderRecord('labs');
      final bookings = await _repo.fetchLabBookings();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _bookings = bookings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your data. Pull down to try again.';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'Leave the partner app?',
      confirmLabel: 'Log Out',
    );
    if (!ok) return;
    if (!mounted) return;
    final state = AppStateScope.of(context);
    state.switchRole('patient');
    state.logout();
  }

  Future<void> _setStatus(Map<String, dynamic> b, String status) async {
    final ok = await _repo.updateAppointmentStatus('${b['id']}', status);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final i = _bookings.indexWhere((x) => '${x['id']}' == '${b['id']}');
        if (i >= 0) _bookings[i] = {..._bookings[i], 'status': status};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking marked as $status.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _loading
          ? const RLoading()
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        REmptyState(
                          icon: Icons.cloud_off,
                          title: 'Something went wrong',
                          subtitle: _error!,
                        ),
                      ],
                    )
                  : _buildBody(context),
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todaysBookings = _bookings
        .where((b) => '${b['appointment_date']}'.startsWith(todayStr))
        .toList();
    final upcoming = _bookings
        .where((b) => !'${b['appointment_date']}'.startsWith(todayStr))
        .toList();
    final pendingCount =
        _bookings.where((b) => '${b['status']}' == 'pending').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RCard(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color:
                      RemedooTheme.purple.withValues(alpha: 0.12),
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
                      'Welcome, ${_profile?['name'] ?? 'Lab'}',
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
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                "Today's tests",
                '${todaysBookings.length}',
                'Samples to collect today',
                Icons.today,
                RemedooTheme.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                context,
                'Needs confirmation',
                '$pendingCount',
                'Tap a booking to confirm it',
                Icons.pending_actions,
                RemedooTheme.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                context,
                'Upcoming',
                '${upcoming.length}',
                'Future bookings',
                Icons.calendar_month,
                scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const RSectionHeader(
          title: "Today's Bookings",
          subtitle:
              'Patients coming for tests today — confirm each booking',
        ),
        const SizedBox(height: 12),
        if (todaysBookings.isEmpty)
          const REmptyState(
            icon: Icons.science_outlined,
            title: 'No tests today',
            subtitle:
                'New test bookings from patients will appear here.',
            compact: true,
          )
        else
          ...todaysBookings.map((b) => _bookingCard(context, b)),
        const SizedBox(height: 24),
        const RSectionHeader(
          title: 'Upcoming Bookings',
          subtitle: 'Future test bookings',
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
          ...upcoming.take(20).map((b) => _bookingCard(context, b)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value,
      String hint, IconData icon, Color color) {
    return RCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
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
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(
      BuildContext context, Map<String, dynamic> b) {
    final scheme = Theme.of(context).colorScheme;
    final status = '${b['status'] ?? 'pending'}';
    final statusColor = status == 'confirmed'
        ? RemedooTheme.purple
        : status == 'completed'
            ? scheme.primary
            : status == 'cancelled'
                ? scheme.error
                : RemedooTheme.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: RemedooTheme.purple
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person,
                      color: RemedooTheme.purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${b['patient_name'] ?? 'Patient'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                      Text(
                        '${b['appointment_date'] ?? ''} at ${b['appointment_time'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if ('${b['notes'] ?? ''}'.isNotEmpty)
                        Text(
                          'Tests: ${b['notes']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:
                        statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (status == 'pending' ||
                status == 'confirmed') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (status == 'pending')
                    Expanded(
                      child: RButton(
                        label: 'Confirm booking',
                        small: true,
                        onPressed: () =>
                            _setStatus(b, 'confirmed'),
                      ),
                    ),
                  if (status == 'pending')
                    const SizedBox(width: 8),
                  if (status == 'confirmed')
                    Expanded(
                      child: RButton(
                        label: 'Report ready',
                        small: true,
                        onPressed: () =>
                            _setStatus(b, 'completed'),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RButton(
                      label: 'Cancel',
                      small: true,
                      variant: RButtonVariant.danger,
                      onPressed: () =>
                          _setStatus(b, 'cancelled'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

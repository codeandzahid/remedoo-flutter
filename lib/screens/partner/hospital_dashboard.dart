import 'package:flutter/material.dart';

import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/provider_payments.dart';
import '../../widgets/provider_profile_form.dart';
import '../../widgets/hospital_units_manager.dart';
import '../../widgets/provider_wallet_card.dart';
import '../../widgets/upi_setup_dialog.dart';
import '../../widgets/widgets.dart';

/// Dashboard for logged-in hospitals.
/// Shows appointments at the hospital with plain-language actions:
/// confirm, mark complete, or cancel each booking.
class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  bool _loading = true;
  bool _upiPromptShown = false;
  String? _error;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _reviews = [];

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
      final profile = await _repo.fetchOwnProviderRecord('hospitals');
      final appointments = await _repo.fetchHospitalAppointments();
      final reviews =
          await _repo.fetchProviderReviews('hospital', 'hospitals');
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _appointments = appointments;
        _reviews = reviews;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your data. Pull down to try again.';
        _loading = false;
      });
    }
 
    if (mounted && !_upiPromptShown) {
      _upiPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybePromptUpiSetup(context, _profile);
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

  Future<void> _setStatus(Map<String, dynamic> a, String status) async {
    // Destructive and completion actions confirm first and carry
    // their context (audit Panelist 17).
    String? reason;
    String? consultNotes;
    String? followUp;
    if (status == 'cancelled') {
      reason = await promptActionReason(
        context,
        title: 'Cancel this appointment?',
        message:
            'The patient will be notified that the appointment was not approved.',
        confirmLabel: 'Cancel appointment',
      );
      if (reason == null || !mounted) return;
    } else if (status == 'completed') {
      final details = await promptCompletionDetails(context);
      if (details == null || !mounted) return;
      consultNotes = details.notes;
      followUp = details.followUpIso;
    }
    final ok = await _repo.updateAppointmentStatus('${a['id']}', status,
        rejectionReason: reason,
        consultationNotes: consultNotes,
        followUpDate: followUp);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final i = _appointments.indexWhere((x) => '${x['id']}' == '${a['id']}');
        if (i >= 0) _appointments[i] = {..._appointments[i], 'status': status};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment marked as $status.')),
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
        title: const Text('Hospital Dashboard'),
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
    final accent = scheme.error;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todaysAppts = _appointments
        .where((a) => '${a['appointment_date']}'.startsWith(todayStr))
        .toList();
    final upcoming = _appointments
        .where((a) => !'${a['appointment_date']}'.startsWith(todayStr))
        .toList();
    final pendingCount =
        _appointments.where((a) => '${a['status']}' == 'pending').length;

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
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.local_hospital,
                    color: accent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${_profile?['name'] ?? 'Hospital'}',
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
        ProviderProfileForm(
          table: 'hospitals',
          profile: _profile,
          repo: _repo,
          onSaved: _load,
        ),
        const SizedBox(height: 16),
        ProviderUpiSettingsCard(
          table: 'hospitals',
          profile: _profile,
          repo: _repo,
          onSaved: _load,
        ),
        const SizedBox(height: 16),
        ProviderOnlinePayments(repo: _repo),
        const SizedBox(height: 16),
        RouteOnboardingTile(
          providerType: 'hospital',
          providerId: '${_profile?['id'] ?? ''}',
          providerName: '${_profile?['name'] ?? ''}',
        ),
        const SizedBox(height: 16),
        HospitalUnitsManager(repo: _repo),
        const SizedBox(height: 16),
        ProviderWalletCard(
          repo: _repo,
          providerType: 'hospital',
          providerId: '${_profile?['id'] ?? ''}',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                "Today's visits",
                '${todaysAppts.length}',
                'Patients coming today',
                Icons.today,
                accent,
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
          title: "Today's Appointments",
          subtitle:
              'Patients visiting your hospital today — confirm or complete each visit',
        ),
        const SizedBox(height: 12),
        if (todaysAppts.isEmpty)
          const REmptyState(
            icon: Icons.calendar_today,
            title: 'No visits today',
            subtitle:
                'New bookings from patients will appear here.',
            compact: true,
          )
        else
          ...todaysAppts.map((a) => _appointmentCard(context, a)),
        const SizedBox(height: 24),
        const RSectionHeader(
          title: 'Upcoming Appointments',
          subtitle: 'Future bookings at your hospital',
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
          ...upcoming.take(20).map((a) => _appointmentCard(context, a)),
        const SizedBox(height: 24),
        ProviderReviewsList(reviews: _reviews),
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

  Widget _appointmentCard(
      BuildContext context, Map<String, dynamic> a) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.error;
    final status = '${a['status'] ?? 'pending'}';
    final statusColor = status == 'confirmed'
        ? RemedooTheme.teal
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
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${a['patient_name'] ?? 'Patient'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                      Text(
                        '${a['appointment_date'] ?? ''} at ${a['appointment_time'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if ('${a['notes'] ?? ''}'.isNotEmpty)
                        Text(
                          'Note: ${a['notes']}',
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
                        label: 'Confirm visit',
                        small: true,
                        onPressed: () =>
                            _setStatus(a, 'confirmed'),
                      ),
                    ),
                  if (status == 'pending')
                    const SizedBox(width: 8),
                  if (status == 'confirmed')
                    Expanded(
                      child: RButton(
                        label: 'Mark visit done',
                        small: true,
                        onPressed: () =>
                            _setStatus(a, 'completed'),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RButton(
                      label: 'Cancel',
                      small: true,
                      variant: RButtonVariant.danger,
                      onPressed: () =>
                          _setStatus(a, 'cancelled'),
                    ),
                  ),
                ],
              ),
            ],
            AppointmentRefundButton(repo: _repo, appointment: a),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/working_hours.dart';
import '../../widgets/prescription_form.dart';
import '../../widgets/provider_payments.dart';
import '../../widgets/provider_wallet_card.dart';
import '../../widgets/upi_setup_dialog.dart';
import '../../widgets/widgets.dart';
import '../../widgets/working_hours_editor.dart';

/// Dashboard for logged-in doctors.
/// Tabs: Appointments, Profile, Payments, Reviews.
/// Plain-language UI: every option says what it does.
class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _tab = 0;
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
      final profile = await _repo.fetchOwnProviderRecord('doctors');
      final appointments = await _repo.fetchDoctorAppointments();
      final reviews = await _repo.fetchProviderReviews('doctor', 'doctors');
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
      // Notify the patient
      final patientId = '${a['patient_id'] ?? a['user_id'] ?? ''}';
      if (patientId.isNotEmpty) {
        if (status == 'confirmed') {
          await _repo.sendNotificationToUser(
            userId: patientId,
            title: 'Appointment Confirmed',
            message:
                'Your appointment was successfully booked for ${a['appointment_date'] ?? ''} at ${a['appointment_time'] ?? ''}. You can now view and print your appointment letter.',
            type: 'appointment',
          );
        } else if (status == 'cancelled') {
          await _repo.sendNotificationToUser(
            userId: patientId,
            title: 'Appointment Not Approved',
            message:
                'Your appointment request for ${a['appointment_date'] ?? ''} was not approved by the doctor. Please try another slot.'
                '${reason != null && reason.isNotEmpty ? ' Reason: $reason' : ''}',
            type: 'appointment',
          );
        }
      }
      if (!mounted) return;
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
        title: const Text('Doctor Dashboard'),
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
          : _error != null
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
              : IndexedStack(
                  index: _tab,
                  children: [
                    _AppointmentsTab(
                      appointments: _appointments,
                      profile: _profile,
                      onRefresh: _load,
                      onSetStatus: _setStatus,
                    ),
                    _ProfileTab(
                      profile: _profile,
                      repo: _repo,
                      onSaved: _load,
                    ),
                    _PaymentsTab(
                      profile: _profile,
                      repo: _repo,
                      onSaved: _load,
                    ),
                    _ReviewsTab(reviews: _reviews),
                  ],
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Visits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payments),
            label: 'Payments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Reviews',
          ),
        ],
      ),
    );
  }
}

// ==================== APPOINTMENTS TAB ====================

class _AppointmentsTab extends StatelessWidget {
  final List<Map<String, dynamic>> appointments;
  final Map<String, dynamic>? profile;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic>, String) onSetStatus;

  const _AppointmentsTab({
    required this.appointments,
    required this.profile,
    required this.onRefresh,
    required this.onSetStatus,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final todaysAppts = appointments
        .where((a) => '${a['appointment_date']}'.startsWith(todayStr))
        .toList();
    final upcoming = appointments
        .where((a) => !'${a['appointment_date']}'.startsWith(todayStr))
        .toList();
    final pendingCount =
        appointments.where((a) => '${a['status']}' == 'pending').length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      RemedooTheme.teal.withValues(alpha: 0.12),
                  child: Text(
                    '${profile?['name'] ?? 'D'}'
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
                        'Welcome, ${profile?['name'] ?? 'Doctor'}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${profile?['specialization'] ?? 'General'} · Fee ₹${profile?['consultation_fee'] ?? '—'}',
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
          Row(
            children: [
              Expanded(
                child: _statCard(
                  context,
                  "Today's visits",
                  '${todaysAppts.length}',
                  'Patients coming today',
                  Icons.today,
                  RemedooTheme.teal,
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
                'Patients visiting you today — confirm or complete each visit',
          ),
          const SizedBox(height: 12),
          if (todaysAppts.isEmpty)
            const REmptyState(
              icon: Icons.calendar_today,
              title: 'No visits today',
              subtitle: 'New bookings from patients will appear here.',
              compact: true,
            )
          else
            ...todaysAppts.map((a) => _appointmentCard(context, a)),
          const SizedBox(height: 24),
          const RSectionHeader(
            title: 'Upcoming Appointments',
            subtitle:
                'Future bookings — confirm them so patients know you accepted',
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
          const SizedBox(height: 16),
        ],
      ),
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
                    color: statusColor.withValues(alpha: 0.12),
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
                        label: 'Approve',
                        icon: Icons.check_circle,
                        small: true,
                        onPressed: () =>
                            onSetStatus(a, 'confirmed'),
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
                            onSetStatus(a, 'completed'),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RButton(
                      label: status == 'pending' ? 'Reject' : 'Cancel',
                      small: true,
                      variant: RButtonVariant.danger,
                      onPressed: () =>
                          onSetStatus(a, 'cancelled'),
                    ),
                  ),
                ],
              ),
              // View uploaded prescription if attached — opens the
              // actual file (audit M3: this used to show the raw
              // URL in a SnackBar).
              if ('${a['prescription_url'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 8),
                RButton(
                  label: 'View Prescription',
                  icon: Icons.description,
                  small: true,
                  variant: RButtonVariant.outline,
                  fullWidth: true,
                  onPressed: () => launchUrl(
                    Uri.parse('${a['prescription_url']}'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ],
            // The doctor's own prescription for a finished visit
            // (prescriptions + prescription_items, audit M3).
            if (status == 'completed') ...[
              const SizedBox(height: 10),
              RButton(
                label: 'Prescription',
                icon: Icons.medication_outlined,
                small: true,
                variant: RButtonVariant.outline,
                fullWidth: true,
                onPressed: () => PrescriptionSheet.show(
                  context,
                  appointmentId: '${a['id']}',
                  patientName: '${a['patient_name'] ?? 'Patient'}',
                ),
              ),
            ],
            AppointmentRefundButton(appointment: a),
          ],
        ),
      ),
    );
  }
}

// ==================== PROFILE TAB ====================

class _ProfileTab extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final SupabaseRepository repo;
  final Future<void> Function() onSaved;

  const _ProfileTab({
    required this.profile,
    required this.repo,
    required this.onSaved,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final TextEditingController _name;
  late final TextEditingController _specialization;
  late final TextEditingController _fee;
  late final TextEditingController _experience;
  late final TextEditingController _phone;
  late final TextEditingController _bio;
  late Map<String, DayHours> _hoursValue;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile ?? {};
    _name = TextEditingController(text: '${p['name'] ?? ''}');
    _specialization =
        TextEditingController(text: '${p['specialization'] ?? ''}');
    _fee = TextEditingController(
        text: p['consultation_fee'] != null
            ? '${p['consultation_fee']}'
            : '');
    _experience = TextEditingController(
        text: p['experience_years'] != null
            ? '${p['experience_years']}'
            : '');
    _phone = TextEditingController(text: '${p['phone'] ?? ''}');
    _bio = TextEditingController(text: '${p['bio'] ?? ''}');
    // Structured hours (audit M4): parsed from the stored JSONB,
    // never flattened into a text note.
    _hoursValue = parseWorkingHours(p['working_hours']);
  }

  @override
  void dispose() {
    _name.dispose();
    _specialization.dispose();
    _fee.dispose();
    _experience.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final values = <String, dynamic>{
      'name': _name.text.trim(),
      'specialization': _specialization.text.trim(),
      'phone': _phone.text.trim(),
      'bio': _bio.text.trim(),
    };
    final fee = double.tryParse(_fee.text.trim());
    if (fee != null) values['consultation_fee'] = fee;
    final exp = int.tryParse(_experience.text.trim());
    if (exp != null) values['experience_years'] = exp;
    // The structured schedule is written back as structured
    // JSONB (audit M4: this used to overwrite the schedule with
    // a free-text note map, destroying what the booking flow
    // reads).
    values['working_hours'] = workingHoursToJson(_hoursValue);
    final ok = await widget.repo.updateOwnProviderRecord('doctors', values);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Profile updated. Patients will see the new details.'
            : 'Could not save. Try again.'),
      ),
    );
    if (ok) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const RSectionHeader(
          title: 'My Profile',
          subtitle:
              'What patients see about you — keep it up to date',
        ),
        const SizedBox(height: 12),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RTextField(controller: _name, label: 'Full name'),
              const SizedBox(height: 12),
              RTextField(
                  controller: _specialization,
                  label: 'Specialty (e.g. Cardiology)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RTextField(
                      controller: _fee,
                      label: 'Consultation fee (₹)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RTextField(
                      controller: _experience,
                      label: 'Experience (years)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RTextField(
                controller: _phone,
                label: 'Phone number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              RTextField(
                controller: _bio,
                label: 'About you',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Working hours',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              WorkingHoursEditor(
                initial: _hoursValue,
                onChanged: (v) => _hoursValue = v,
              ),
              const SizedBox(height: 20),
              RButton(
                label: _saving ? 'Saving…' : 'Save profile',
                fullWidth: true,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AvailabilityCard(
          repo: widget.repo,
          profile: widget.profile,
          onSaved: widget.onSaved,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ==================== PAYMENTS TAB ====================

/// Doctor payments use the SHARED provider payments card
/// (form-pages audit Panelist 15: this tab used to carry a
/// diverged duplicate of the form that lacked the shared card's
/// empty-UPI-ID guard, so UPI could be switched on with no ID).
class _PaymentsTab extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final SupabaseRepository repo;
  final Future<void> Function() onSaved;

  const _PaymentsTab({
    required this.profile,
    required this.repo,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const RSectionHeader(
          title: 'Payments',
          subtitle:
              'How patients pay you — money goes straight to your account',
        ),
        const SizedBox(height: 12),
        ProviderUpiSettingsCard(
          table: 'doctors',
          profile: profile,
          repo: repo,
          onSaved: onSaved,
        ),
        const SizedBox(height: 16),
        ProviderOnlinePayments(repo: repo),
        const SizedBox(height: 16),
        RouteOnboardingTile(
          providerType: 'doctor',
          providerId: '${profile?['id'] ?? ''}',
          providerName: '${profile?['name'] ?? ''}',
        ),
        const SizedBox(height: 16),
        ProviderWalletCard(
          repo: repo,
          providerType: 'doctor',
          providerId: '${profile?['id'] ?? ''}',
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ==================== REVIEWS TAB ====================

class _ReviewsTab extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;

  const _ReviewsTab({required this.reviews});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avg = reviews.isEmpty
        ? 0.0
        : reviews
                .map((r) => (r['rating'] as num?)?.toDouble() ?? 0)
                .reduce((a, b) => a + b) /
            reviews.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RSectionHeader(
          title: 'Patient Reviews',
          subtitle: reviews.isEmpty
              ? 'What patients say about you'
              : '${reviews.length} reviews · ${avg.toStringAsFixed(1)} average',
        ),
        const SizedBox(height: 12),
        if (reviews.isEmpty)
          const REmptyState(
            icon: Icons.star_outline,
            title: 'No reviews yet',
            subtitle:
                'When patients rate their visit, their reviews appear here.',
            compact: true,
          )
        else
          ...reviews.map((r) {
            final rating =
                (r['rating'] as num?)?.toInt() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RStarRating(rating: rating.toDouble()),
                        const SizedBox(width: 8),
                        Text(
                          '$rating/5',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          '${r['created_at'] ?? ''}'
                              .toString()
                              .split('T')
                              .first,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if ('${r['comment'] ?? ''}'
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${r['comment']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ==================== AVAILABILITY ====================

/// Blocked slots + vacation days (form-pages audit Panelist 5 /
/// M14): doctor_blocked_slots and doctors.vacation_dates existed
/// in the schema with zero app references, so a doctor could not
/// stop patients booking a time they could not keep. Blocked
/// slots are filtered out of the booking flow's offered times.
class _AvailabilityCard extends StatefulWidget {
  final SupabaseRepository repo;
  final Map<String, dynamic>? profile;
  final Future<void> Function() onSaved;

  const _AvailabilityCard({
    required this.repo,
    required this.profile,
    required this.onSaved,
  });

  @override
  State<_AvailabilityCard> createState() => _AvailabilityCardState();
}

class _AvailabilityCardState extends State<_AvailabilityCard> {
  List<Map<String, dynamic>> _blocks = [];
  List<String> _vacation = [];
  bool _loading = true;
  bool _savingVacation = false;

  @override
  void initState() {
    super.initState();
    final v = widget.profile?['vacation_dates'];
    if (v is List) _vacation = v.map((e) => '$e').toList()..sort();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.repo.fetchOwnBlockedSlots();
    if (!mounted) return;
    setState(() {
      _blocks = rows;
      _loading = false;
    });
  }

  Future<void> _addBlock() async {
    var date = DateTime.now().add(const Duration(days: 1));
    var fullDay = true;
    var start = const TimeOfDay(hour: 9, minute: 0);
    var end = const TimeOfDay(hour: 13, minute: 0);
    final reason = TextEditingController();
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Block time off'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined,
                      size: 18),
                  label: Text(
                      'Date: ${date.day}/${date.month}/${date.year}'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (picked != null) setD(() => date = picked);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Full day'),
                  value: fullDay,
                  onChanged: (v) => setD(() => fullDay = v),
                ),
                if (!fullDay)
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          final p = await showTimePicker(
                              context: ctx, initialTime: start);
                          if (p != null) setD(() => start = p);
                        },
                        child: Text('From ${fmt(start)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final p = await showTimePicker(
                              context: ctx, initialTime: end);
                          if (p != null) setD(() => end = p);
                        },
                        child: Text('To ${fmt(end)}'),
                      ),
                    ],
                  ),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                      labelText: 'Reason (optional)'),
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
              child: const Text('Block'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final id = await widget.repo.addBlockedSlot(
      dateIso: date.toIso8601String().substring(0, 10),
      startTime: fullDay ? null : '${fmt(start)}:00',
      endTime: fullDay ? null : '${fmt(end)}:00',
      isFullDay: fullDay,
      reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
    );
    reason.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(id != null
            ? 'Time blocked. Patients will not be offered it.'
            : 'Could not block. Try again.'),
      ),
    );
    if (id != null) _load();
  }

  Future<void> _saveVacation() async {
    setState(() => _savingVacation = true);
    final ok = await widget.repo.updateOwnProviderRecord('doctors', {
      'vacation_dates': _vacation,
    });
    if (!mounted) return;
    setState(() => _savingVacation = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Leave days saved.'
            : 'Could not save leave days. Try again.'),
      ),
    );
    if (ok) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Availability — time off',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Blocked times and leave days are removed from the '
            'slots patients can book.',
            style: TextStyle(
                fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_blocks.isEmpty)
            Text('No blocked time.',
                style: TextStyle(color: scheme.onSurfaceVariant))
          else
            for (final b in _blocks)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.block_outlined, size: 20),
                title: Text('${b['blocked_date'] ?? ''}'),
                subtitle: Text(
                  b['is_full_day'] == true
                      ? 'Full day'
                          '${'${b['reason'] ?? ''}'.isNotEmpty ? ' • ${b['reason']}' : ''}'
                      : '${b['start_time'] ?? ''} – ${b['end_time'] ?? ''}'
                          '${'${b['reason'] ?? ''}'.isNotEmpty ? ' • ${b['reason']}' : ''}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    final ok =
                        await widget.repo.deleteBlockedSlot('${b['id']}');
                    if (ok) _load();
                  },
                ),
              ),
          const SizedBox(height: 8),
          RButton(
            label: 'Block time off',
            icon: Icons.add,
            small: true,
            variant: RButtonVariant.outline,
            onPressed: _addBlock,
          ),
          const Divider(height: 28),
          const Text('Leave days (vacation)',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _vacation)
                Chip(
                  label: Text(d),
                  onDeleted: () =>
                      setState(() => _vacation.remove(d)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Add day'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked == null) return;
                  final iso =
                      picked.toIso8601String().substring(0, 10);
                  if (!_vacation.contains(iso)) {
                    setState(() => _vacation = [..._vacation, iso]
                      ..sort());
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          RButton(
            label: _savingVacation ? 'Saving…' : 'Save leave days',
            small: true,
            onPressed: _savingVacation ? null : _saveVacation,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

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
    final ok = await _repo.updateAppointmentStatus('${a['id']}', status);
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
          ? const Center(child: CircularProgressIndicator())
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
                        label: 'Confirm visit',
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
                      label: 'Cancel',
                      small: true,
                      variant: RButtonVariant.danger,
                      onPressed: () =>
                          onSetStatus(a, 'cancelled'),
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
  late final TextEditingController _hours;
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
    final wh = p['working_hours'];
    _hours = TextEditingController(
        text: wh is Map
            ? wh.entries.map((e) => '${e.key}: ${e.value}').join('\n')
            : '${wh ?? ''}');
  }

  @override
  void dispose() {
    _name.dispose();
    _specialization.dispose();
    _fee.dispose();
    _experience.dispose();
    _phone.dispose();
    _bio.dispose();
    _hours.dispose();
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
    if (_hours.text.trim().isNotEmpty) {
      values['working_hours'] = {'note': _hours.text.trim()};
    }
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
              RTextField(
                controller: _hours,
                label: 'Working hours (e.g. Mon–Fri 9am–5pm)',
                maxLines: 2,
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
      ],
    );
  }
}

// ==================== PAYMENTS TAB ====================

class _PaymentsTab extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final SupabaseRepository repo;
  final Future<void> Function() onSaved;

  const _PaymentsTab({
    required this.profile,
    required this.repo,
    required this.onSaved,
  });

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  late final TextEditingController _upiId;
  late bool _upiEnabled;
  late bool _payInClinic;
  bool _saving = false;

  static final _upiRegex = RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$');

  @override
  void initState() {
    super.initState();
    final p = widget.profile ?? {};
    _upiId = TextEditingController(text: '${p['upi_id'] ?? ''}');
    _upiEnabled = p['upi_enabled'] == true;
    _payInClinic = p['pay_in_clinic_enabled'] != false;
  }

  @override
  void dispose() {
    _upiId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _upiId.text.trim();
    if (_upiEnabled && id.isNotEmpty && !_upiRegex.hasMatch(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Enter a valid UPI ID (e.g. yourname@okhdfcbank).')),
      );
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.repo.updateOwnProviderRecord('doctors', {
      'upi_id': id.isEmpty ? null : id,
      'upi_enabled': _upiEnabled,
      'pay_in_clinic_enabled': _payInClinic,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Payment settings saved.'
            : 'Could not save. Try again.'),
      ),
    );
    if (ok) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const RSectionHeader(
          title: 'Payments',
          subtitle:
              'How patients pay you — money goes straight to your account',
        ),
        const SizedBox(height: 12),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your UPI ID',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Open GPay, PhonePe, or Paytm to find your UPI ID (looks like name@okhdfcbank).',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              RTextField(
                controller: _upiId,
                label: 'UPI ID',
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Accept UPI payments'),
                subtitle: const Text(
                    'Patients see a "Pay via UPI" option when booking'),
                value: _upiEnabled,
                onChanged: (v) =>
                    setState(() => _upiEnabled = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pay in clinic'),
                subtitle: const Text(
                    'Patients can choose to pay at your clinic'),
                value: _payInClinic,
                onChanged: (v) =>
                    setState(() => _payInClinic = v),
              ),
              const SizedBox(height: 12),
              RButton(
                label: _saving ? 'Saving…' : 'Save payment settings',
                fullWidth: true,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
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

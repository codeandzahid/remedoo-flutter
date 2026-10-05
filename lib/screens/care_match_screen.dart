import 'package:flutter/material.dart';

import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'lab_detail_screen.dart';
import '../app_navigator.dart';

const _quickSymptoms = [
  'Fever and body ache',
  'Chest discomfort',
  'Persistent cough',
  'Stomach pain',
  'Skin rash',
  'Headache and dizziness',
];

const _careTypes = [
  'Anything suitable',
  'Doctor',
  'Hospital',
  'Lab test',
];

const _urgencies = [
  'Routine',
  'Within a few days',
  'Urgent',
];

/// Smart Care Finder: symptom input + preferences → ranked matches.
class CareMatchScreen extends StatefulWidget {
  final String initialSymptom;

  const CareMatchScreen({super.key, this.initialSymptom = ''});

  @override
  State<CareMatchScreen> createState() => _CareMatchScreenState();
}

class _CareMatchScreenState extends State<CareMatchScreen> {
  late final TextEditingController _symptom;
  late final TextEditingController _budget;
  late final TextEditingController _distance;
  final _notes = TextEditingController();
  String _careType = 'Anything suitable';
  String _urgency = 'Routine';
  bool _searched = false;

  double get _budgetValue =>
      double.tryParse(_budget.text) ?? 1000;
  double get _distanceValue =>
      double.tryParse(_distance.text) ?? 10;

  @override
  void initState() {
    super.initState();
    _symptom = TextEditingController(text: widget.initialSymptom);
    _budget = TextEditingController(text: '1000');
    _distance = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _symptom.dispose();
    _budget.dispose();
    _distance.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // White sticky header.
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).dividerColor),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding:
                  const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back,
                          size: 20),
                      onPressed: () =>
                          goBack(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 16,
                                color: scheme.primary),
                            const SizedBox(width: 6),
                            const Text('Smart Care Finder',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        Text(
                            'Describe your symptoms, get matched care',
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MaxWidthBox(
                maxWidth: 720,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      20, 16, 20, 32),
                  children: [
                    RCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('How are you feeling?',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          RTextField(
                            hint:
                                'e.g. Sharp stomach pain with nausea for two days, worse after meals',
                            controller: _symptom,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickSymptoms
                                .map((s) => RFilterChip(
                                      label: s,
                                      selected: false,
                                      onTap: () => setState(
                                          () =>
                                              _symptom.text = s),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                              'What kind of care do you want?',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _careTypes
                                .map((t) => _segPill(
                                    t,
                                    _careType == t,
                                    () => setState(
                                        () => _careType = t)))
                                .toList(),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                              'How soon do you need it?',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _urgencies
                                .map((u) => _segPill(
                                    u,
                                    _urgency == u,
                                    () => setState(
                                        () => _urgency = u)))
                                .toList(),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: RTextField(
                                  label: 'Budget (₹)',
                                  hint: 'e.g. 500',
                                  controller: _budget,
                                  keyboardType:
                                      TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RTextField(
                                  label: 'Max distance (km)',
                                  hint: 'e.g. 10',
                                  controller: _distance,
                                  keyboardType:
                                      TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          RTextField(
                            label: 'Anything else? (optional)',
                            hint:
                                'e.g. prefer a female doctor, home sample collection',
                            controller: _notes,
                          ),
                          const SizedBox(height: 18),
                          RButton(
                            label: 'Find my care match',
                            icon: Icons.auto_awesome,
                            fullWidth: true,
                            onPressed: () => setState(
                                () => _searched = true),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              '⚕️ Guidance only, not a medical diagnosis. Always consult a qualified doctor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_searched) ...[
                      const SizedBox(height: 20),
                      const Text('Your matches',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      ..._matches(state),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Segmented pill: selected = orange, unselected = bordered.
  Widget _segPill(
      String label, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary
          : Theme.of(context).cardColor,
      shape: StadiumBorder(
        side: selected
            ? BorderSide.none
            : BorderSide(
                color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : scheme.onSurface)),
        ),
      ),
    );
  }

  List<Widget> _matches(AppState state) {
    final out = <Widget>[];
    final urgent = _urgency == 'Urgent';
    final budget = _budgetValue;
    final distance = _distanceValue;
    Widget staggered(Widget card) =>
        StaggerItem(index: out.length % 6, child: card);
    if (_careType == 'Anything suitable' || _careType == 'Doctor') {
      final docs = state.activeDoctors
          .where((d) =>
              d.fee <= budget && d.distanceKm <= distance)
          .take(2)
          .toList();
      for (final d in docs) {
        out.add(staggered(_matchCard(
          kind: 'Doctor',
          icon: Icons.medical_services,
          name: d.name,
          sub:
              '${d.specialty} • ${inr(d.fee)} • ${d.distanceKm.toStringAsFixed(1)} km',
          rating: d.rating,
          pct: urgent ? 96 : 92,
          reason:
              'Matches your symptoms and stays within your budget and distance.',
          onTap: () {
            if (!checkLogin(context, 'Please login to view details')) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DoctorDetailScreen(doctor: d)),
            );
          },
        )));
      }
    }
    if (_careType == 'Anything suitable' || _careType == 'Hospital') {
      final hs = state.activeHospitals
          .where((h) => h.distanceKm <= distance)
          .take(2)
          .toList();
      for (final h in hs) {
        out.add(staggered(_matchCard(
          kind: 'Hospital',
          icon: Icons.local_hospital_outlined,
          name: h.name,
          sub:
              '${h.location} • ${h.distanceKm.toStringAsFixed(1)} km',
          rating: h.rating,
          pct: urgent ? 94 : 88,
          reason:
              'Well-rated hospital close to you with emergency support.',
          onTap: () {
            if (!checkLogin(context, 'Please login to view details')) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      HospitalDetailScreen(hospital: h)),
            );
          },
        )));
      }
    }
    if (_careType == 'Anything suitable' || _careType == 'Lab test') {
      final ls = state.activeLabs
          .where((l) => l.distanceKm <= distance)
          .take(1)
          .toList();
      for (final l in ls) {
        out.add(staggered(_matchCard(
          kind: 'Lab',
          icon: Icons.science_outlined,
          name: l.name,
          sub:
              '${l.testCount} tests • Report in ${l.turnaround}',
          rating: l.rating,
          pct: 85,
          reason:
              'Recommended lab for the tests your symptoms suggest.',
          onTap: () {
            if (!checkLogin(context, 'Please login to view details')) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LabDetailScreen(lab: l)),
            );
          },
        )));
      }
    }
    if (out.isEmpty) {
      out.add(RCard(
        child: Text(
            'No matches for these filters — try widening your budget or distance.',
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant)),
      ));
    }
    return out;
  }

  Widget _matchCard({
    required String kind,
    required IconData icon,
    required String name,
    required String sub,
    required double rating,
    required int pct,
    required String reason,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: RCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      Text(kind,
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$pct% match',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(reason,
                style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                RStat(
                    icon: Icons.star,
                    text: rating.toStringAsFixed(1)),
                const SizedBox(width: 14),
                Expanded(
                  child: RStat(icon: Icons.info_outline, text: sub),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

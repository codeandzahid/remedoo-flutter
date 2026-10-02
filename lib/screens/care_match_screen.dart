import 'package:flutter/material.dart';

import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'lab_detail_screen.dart';

const _symptomChips = [
  'Fever',
  'Headache',
  'Cough',
  'Stomach pain',
  'Chest pain',
  'Skin rash',
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
  final Set<String> _chips = {};
  String _careType = 'Anything suitable';
  String _urgency = 'Routine';
  double _budget = 1000;
  double _distance = 10;
  final _notes = TextEditingController();
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _symptom = TextEditingController(text: widget.initialSymptom);
  }

  @override
  void dispose() {
    _symptom.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Care Finder')),
      body: MaxWidthBox(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StaggerItem(
              index: 0,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Describe your symptoms',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _symptom,
                        decoration: const InputDecoration(
                          hintText:
                              'e.g. fever and headache for 2 days…',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _symptomChips
                            .asMap()
                            .entries
                            .map((e) => _optionChip(e.key, e.value))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            StaggerItem(
              index: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('What kind of care?',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      RadioGroup<String>(
                        groupValue: _careType,
                        onChanged: (v) =>
                            setState(() => _careType = v!),
                        child: Column(
                          children: [
                            for (final t in [
                              'Anything suitable',
                              'Doctor',
                              'Hospital',
                              'Lab test'
                            ])
                              RadioListTile<String>(
                                value: t,
                                title: Text(t),
                                activeColor:
                                    RemedooTheme.primary,
                                contentPadding:
                                    EdgeInsets.zero,
                                dense: true,
                              ),
                          ],
                        ),
                      ),
                      const Divider(),
                      const Text('How urgent?',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      RadioGroup<String>(
                        groupValue: _urgency,
                        onChanged: (v) =>
                            setState(() => _urgency = v!),
                        child: Column(
                          children: [
                            for (final t in [
                              'Routine',
                              'Soon',
                              'Urgent'
                            ])
                              RadioListTile<String>(
                                value: t,
                                title: Text(t),
                                activeColor:
                                    RemedooTheme.primary,
                                contentPadding:
                                    EdgeInsets.zero,
                                dense: true,
                              ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Text(
                          'Budget: up to ${inr(_budget.round())}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      Slider(
                        value: _budget,
                        min: 200,
                        max: 5000,
                        divisions: 24,
                        activeColor: RemedooTheme.primary,
                        onChanged: (v) =>
                            setState(() => _budget = v),
                      ),
                      Text(
                          'Max distance: ${_distance.round()} km',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      Slider(
                        value: _distance,
                        min: 1,
                        max: 30,
                        divisions: 29,
                        activeColor: RemedooTheme.primary,
                        onChanged: (v) =>
                            setState(() => _distance = v),
                      ),
                      TextField(
                        controller: _notes,
                        decoration: const InputDecoration(
                          hintText: 'Notes (optional)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            BigTargetButton(
              onPressed: () => setState(() => _searched = true),
              child: const Text('Find my care match'),
            ),
            if (_searched) ...[
              const SizedBox(height: 16),
              const Text('Your matches',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ..._matches(state),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'This is guidance only, not a diagnosis. '
                  'For urgent symptoms please visit emergency care.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Symptom option chip with a 56px-minimum touch target.
  Widget _optionChip(int index, String c) {
    final sel = _chips.contains(c);
    return StaggerItem(
      index: 2 + (index % 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: Text(c),
            selected: sel,
            onSelected: (_) =>
                setState(() => sel ? _chips.remove(c) : _chips.add(c)),
          ),
        ),
      ),
    );
  }

  List<Widget> _matches(AppState state) {
    final out = <Widget>[];
    final urgent = _urgency == 'Urgent';
    Widget staggered(Widget card) =>
        StaggerItem(index: out.length % 6, child: card);
    if (_careType == 'Anything suitable' || _careType == 'Doctor') {
      final docs = state.activeDoctors
          .where((d) =>
              d.fee <= _budget && d.distanceKm <= _distance)
          .take(2)
          .toList();
      for (final d in docs) {
        out.add(staggered(_matchCard(
          'Doctor',
          d.name,
          '${d.specialty} • ${inr(d.fee)} • ${d.distanceKm.toStringAsFixed(1)} km',
          d.rating,
          urgent ? 96 : 92,
          () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DoctorDetailScreen(doctor: d)),
          ),
        )));
      }
    }
    if (_careType == 'Anything suitable' || _careType == 'Hospital') {
      final hs = state.activeHospitals
          .where((h) => h.distanceKm <= _distance)
          .take(2)
          .toList();
      for (final h in hs) {
        out.add(staggered(_matchCard(
          'Hospital',
          h.name,
          '${h.location} • ${h.distanceKm.toStringAsFixed(1)} km',
          h.rating,
          urgent ? 94 : 88,
          () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    HospitalDetailScreen(hospital: h)),
          ),
        )));
      }
    }
    if (_careType == 'Anything suitable' || _careType == 'Lab test') {
      final ls = state.activeLabs
          .where((l) => l.distanceKm <= _distance)
          .take(1)
          .toList();
      for (final l in ls) {
        out.add(staggered(_matchCard(
          'Lab',
          l.name,
          '${l.testCount} tests • Report in ${l.turnaround}',
          l.rating,
          85,
          () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => LabDetailScreen(lab: l)),
          ),
        )));
      }
    }
    if (out.isEmpty) {
      out.add(const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
              'No matches for these filters — try widening your budget or distance.'),
        ),
      ));
    }
    return out;
  }

  Widget _matchCard(String kind, String name, String sub, double rating,
      int pct, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: RemedooTheme.primary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(kind,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: RemedooTheme.primary)),
                    ),
                    const SizedBox(height: 6),
                    Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    RatingPill(rating: rating),
                  ],
                ),
              ),
              Column(
                children: [
                  Text('$pct%',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: RemedooTheme.ratingGreen)),
                  const Text('match',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

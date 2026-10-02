import 'package:flutter/material.dart';

import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../theme.dart';
import 'care_match_screen.dart';

/// Symptom Checker: chat-style step flow → possible conditions.
class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({super.key});

  @override
  State<SymptomCheckerScreen> createState() =>
      _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  int _step = 0;
  String? _symptom;
  String? _duration;
  double _severity = 5;
  String? _ageGroup;
  final Set<String> _conditions = {};
  bool _done = false;

  static const _symptoms = [
    'Fever',
    'Headache',
    'Cough',
    'Stomach pain',
    'Chest pain',
    'Skin rash',
  ];
  static const _durations = [
    'Less than a day',
    '1–3 days',
    '4–7 days',
    'More than a week',
  ];
  static const _ages = [
    'Under 12',
    '12–30',
    '31–50',
    'Over 50',
  ];
  static const _existing = [
    'Diabetes',
    'Blood pressure',
    'Asthma',
    'None',
  ];

  void _next() {
    if (_step < 4) {
      setState(() => _step++);
    } else {
      setState(() => _done = true);
    }
  }

  bool get _canNext {
    switch (_step) {
      case 0:
        return _symptom != null;
      case 1:
        return _duration != null;
      case 2:
        return true;
      case 3:
        return _ageGroup != null;
      case 4:
        return _conditions.isNotEmpty;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _results();
    return Scaffold(
      appBar: AppBar(title: const Text('Symptom Checker')),
      body: MaxWidthBox(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (_step + 1) / 5,
                backgroundColor: Colors.grey.shade200,
                color: RemedooTheme.primary,
              ),
              const SizedBox(height: 8),
              Text('Step ${_step + 1} of 5',
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              Expanded(child: _stepBody()),
              BigTargetButton(
                onPressed: _canNext ? _next : null,
                child: Text(_step == 4 ? 'See results' : 'Continue'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _chips(
            'What is your main symptom?',
            _symptoms,
            (s) => setState(() => _symptom = s),
            _symptom);
      case 1:
        return _chips(
            'How long have you had it?',
            _durations,
            (s) => setState(() => _duration = s),
            _duration);
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How severe is it?',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Slider(
              value: _severity,
              min: 1,
              max: 10,
              divisions: 9,
              label: _severity.round().toString(),
              activeColor: RemedooTheme.primary,
              onChanged: (v) => setState(() => _severity = v),
            ),
            Center(
              child: Text(
                _severity <= 3
                    ? 'Mild'
                    : _severity <= 7
                        ? 'Moderate'
                        : 'Severe',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      case 3:
        return _chips('Which age group are you in?', _ages,
            (s) => setState(() => _ageGroup = s), _ageGroup);
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Any existing conditions?',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _existing.asMap().entries.map((e) {
                final c = e.value;
                final sel = _conditions.contains(c);
                return StaggerItem(
                  index: e.key % 6,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minHeight: 56),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilterChip(
                        label: Text(c),
                        selected: sel,
                        onSelected: (_) => setState(() => sel
                            ? _conditions.remove(c)
                            : _conditions.add(c)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
    }
  }

  Widget _chips(String title, List<String> options,
      ValueChanged<String> onPick, String? selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.asMap().entries.map((e) {
            final o = e.value;
            final sel = o == selected;
            return StaggerItem(
              index: e.key % 6,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ChoiceChip(
                    label: Text(o),
                    selected: sel,
                    onSelected: (_) => onPick(o),
                    selectedColor: RemedooTheme.primary,
                    labelStyle: TextStyle(
                        color: sel
                            ? Colors.white
                            : Theme.of(context)
                                .colorScheme
                                .onSurface),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _results() {
    final severe = _severity > 7;
    final conditions = [
      (
        'Common viral infection',
        severe ? 62 : 78,
        'Fever, body ache and fatigue that usually settle with rest and fluids within a few days.'
      ),
      (
        'Seasonal allergy',
        54,
        'Sneezing, itchy eyes or throat irritation that tends to flare in dusty or pollen-heavy weather.'
      ),
      (
        'Stress-related headache',
        47,
        'Tension around the head and neck, often linked to screen time, dehydration or poor sleep.'
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Possible Conditions')),
      body: MaxWidthBox(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Based on your answers, here are some possibilities. '
                  'This is not a diagnosis — please consult a doctor for proper evaluation.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...conditions.asMap().entries.map((e) {
              final (name, pct, desc) = e.value;
              return StaggerItem(
                index: e.key % 6,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16)),
                              const SizedBox(height: 6),
                              Text(desc,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            Text('$pct%',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: RemedooTheme.primary)),
                            const Text('match',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Not a diagnosis. If symptoms are severe or worsening, seek care immediately.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            BigTargetButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CareMatchScreen(initialSymptom: _symptom ?? ''),
                ),
              ),
              child: const Text('Find Care'),
            ),
          ],
        ),
      ),
    );
  }
}

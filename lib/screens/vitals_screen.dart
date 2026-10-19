import 'package:flutter/material.dart';

import '../app_navigator.dart';
import '../models.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Health Numbers (2026-10-19): the patient logs BP, sugar and weight
/// readings; stored on-device with the account session (cleared at
/// logout), latest values surface on the dashboard.
class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  String _type = 'bp';
  final _v1 = TextEditingController();
  final _v2 = TextEditingController();

  @override
  void dispose() {
    _v1.dispose();
    _v2.dispose();
    super.dispose();
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _dateLabel(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  IconData _icon(String type) => switch (type) {
        'bp' => Icons.favorite,
        'sugar' => Icons.water_drop,
        _ => Icons.monitor_weight,
      };

  Color _color(String type) => switch (type) {
        'bp' => RemedooTheme.emergency,
        'sugar' => RemedooTheme.warning,
        _ => RemedooTheme.success,
      };

  String _typeName(String type) => switch (type) {
        'bp' => 'Blood Pressure',
        'sugar' => 'Blood Sugar',
        _ => 'Weight',
      };

  void _save(AppState state) {
    final a = double.tryParse(_v1.text.trim());
    if (a == null || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid value.')));
      return;
    }
    double? b;
    if (_type == 'bp') {
      b = double.tryParse(_v2.text.trim());
      if (b == null || b <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enter both BP numbers.')));
        return;
      }
    }
    state.addVital(VitalReading(
      id: 'V${DateTime.now().millisecondsSinceEpoch}',
      type: _type,
      value: a,
      value2: b,
      date: DateTime.now(),
    ));
    _v1.clear();
    _v2.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Reading saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.isSignedIn) {
      return const GuestGate();
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Row(
              children: [
                Material(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => goBack(context),
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.arrow_back,
                          size: 20, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Health Numbers',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Expanded(
            child: MaxWidthBox(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  RCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add a reading',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (final t in const ['bp', 'sugar', 'weight'])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(_typeName(t)),
                                  selected: _type == t,
                                  onSelected: (_) =>
                                      setState(() => _type = t),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_type == 'bp')
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _v1,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Systolic (top)',
                                      hintText: '120'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _v2,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Diastolic (bottom)',
                                      hintText: '80'),
                                ),
                              ),
                            ],
                          )
                        else
                          TextField(
                            controller: _v1,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: _type == 'sugar'
                                  ? 'Sugar (mg/dL)'
                                  : 'Weight (kg)',
                              hintText: _type == 'sugar' ? '98' : '70',
                            ),
                          ),
                        const SizedBox(height: 16),
                        RButton(
                          label: 'Save Reading',
                          icon: Icons.add,
                          onPressed: () => _save(state),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('History',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (state.vitals.isEmpty)
                    Text('No readings yet. Add your first one above.',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant))
                  else
                    for (final v in state.vitals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _color(v.type),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_icon(v.type),
                                    color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${_typeName(v.type)} • ${v.label}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(_dateLabel(v.date),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => state.removeVital(v.id),
                                icon: Icon(Icons.delete_outline,
                                    size: 20,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Medical History: appointments, prescriptions, lab reports.
class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  State<MedicalHistoryScreen> createState() =>
      _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  String _chip = 'All';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Medical History')),
      body: MaxWidthBox(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'All',
                    'Appointments',
                    'Prescriptions',
                    'Lab Reports'
                  ].map((c) {
                    final sel = c == _chip;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: sel,
                        onSelected: (_) => setState(() => _chip = c),
                        selectedColor: RemedooTheme.primary,
                        labelStyle: TextStyle(
                            color: sel
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_chip == 'All' || _chip == 'Appointments') ...[
                    const _GroupTitle('Appointments'),
                    ...state.appointments.asMap().entries.map(
                          (e) => StaggerItem(
                            index: e.key % 6,
                            child: _apptCard(e.value),
                          ),
                        ),
                  ],
                  if (_chip == 'All' || _chip == 'Prescriptions') ...[
                    const _GroupTitle('Prescriptions'),
                    ...state.prescriptions.asMap().entries.map(
                          (e) => StaggerItem(
                            index: e.key % 6,
                            child: _rxCard(e.value),
                          ),
                        ),
                  ],
                  if (_chip == 'All' || _chip == 'Lab Reports') ...[
                    const _GroupTitle('Lab Reports'),
                    ...state.reports.asMap().entries.map(
                          (e) => StaggerItem(
                            index: e.key % 6,
                            child: Card(
                              margin:
                                  const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: const Icon(Icons.science,
                                    color: RemedooTheme.teal),
                                title: Text(e.value.labName,
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w700)),
                                subtitle: Text(
                                    '${e.value.tests.length} tests • ${e.value.date.day}/${e.value.date.month}/${e.value.date.year}'),
                                trailing: StatusChip(
                                    status: e.value.status),
                              ),
                            ),
                          ),
                        ),
                  ],
                  if (state.appointments.isEmpty &&
                      state.prescriptions.isEmpty &&
                      state.reports.isEmpty)
                    const EmptyState(
                      icon: Icons.history,
                      title: 'No medical history yet',
                      subtitle:
                          'Your visits, prescriptions and reports will build your history here.',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _apptCard(Appointment a) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: InitialsAvatar(name: a.doctorName, radius: 22),
        title: Text(a.doctorName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${a.specialty} • ${a.dateLabel}'),
        trailing: StatusChip(status: a.status),
      ),
    );
  }

  Widget _rxCard(String rx) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: RemedooTheme.purple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.description,
              color: RemedooTheme.purple),
        ),
        title: Text(rx,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Prescription • PDF'),
        trailing: TextButton(
          onPressed: () {},
          child: const Text('View'),
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String title;

  const _GroupTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800)),
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Hospital portal: overview cards, doctor list, appointment list.
class HospitalPortalScreen extends StatelessWidget {
  const HospitalPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final me = hospitals[0];
    final docs =
        doctors.where((d) => d.hospital == me.name).toList();
    final appts = state.appointments
        .where((a) => a.kind == 'hospital')
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(me.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _card('${docs.length}', 'Doctors',
                  Icons.person_search),
              const SizedBox(width: 10),
              _card('${me.beds}', 'Beds', Icons.bed),
              const SizedBox(width: 10),
              _card('${appts.length}', 'Appointments',
                  Icons.calendar_month),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Doctors',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (docs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No doctors linked yet.'),
              ),
            )
          else
            ...docs.take(6).map((d) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: InitialsAvatar(
                        name: d.name, radius: 22),
                    title: Text(d.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    subtitle: Text(d.specialty),
                    trailing:
                        RatingPill(rating: d.rating),
                  ),
                )),
          const SizedBox(height: 16),
          const Text('Appointments',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (appts.isEmpty)
            const EmptyState(
              icon: Icons.calendar_month,
              title: 'No appointments',
              subtitle:
                  'Patient bookings will appear here.',
            )
          else
            ...appts.map((a) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(a.doctorName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${a.dateLabel} • ${a.timeLabel}'),
                    trailing:
                        StatusChip(status: a.status),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _card(String value, String label, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: RemedooTheme.primary),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../responsive/animations.dart';
import '../../responsive/responsive.dart';
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
    final stats = [
      _card('${docs.length}', 'Doctors', Icons.person_search),
      _card('${me.beds}', 'Beds', Icons.bed),
      _card('${appts.length}', 'Appointments',
          Icons.calendar_month),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(me.name)),
      body: MaxWidthBox(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ResponsiveGrid(
              compactCols: 2,
              mediumCols: 3,
              expandedCols: 3,
              wideCols: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              itemCount: stats.length,
              itemBuilder: (_, i) =>
                  StaggerItem(index: i % 6, child: stats[i]),
            ),
            const SizedBox(height: 16),
            const Text('Doctors',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (docs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No doctors linked yet.'),
                ),
              )
            else
              ...docs.take(6).map((d) => StaggerItem(
                    index: 0,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: InitialsAvatar(
                            name: d.name, radius: 22),
                        title: Text(d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(d.specialty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing:
                            RatingPill(rating: d.rating),
                      ),
                    ),
                  )),
            const SizedBox(height: 16),
            const Text('Appointments',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (appts.isEmpty)
              const EmptyState(
                icon: Icons.calendar_month,
                title: 'No appointments',
                subtitle:
                    'Patient bookings will appear here.',
              )
            else
              ...appts.map((a) => StaggerItem(
                    index: 0,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(a.doctorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${a.dateLabel} • ${a.timeLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing:
                            StatusChip(status: a.status),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _card(String value, String label, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: RemedooTheme.primary),
            const SizedBox(height: 6),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

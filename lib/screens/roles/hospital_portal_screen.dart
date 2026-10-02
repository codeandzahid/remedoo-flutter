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
    final scheme = Theme.of(context).colorScheme;
    final me = hospitals[0];
    final docs =
        doctors.where((d) => d.hospital == me.name).toList();
    final appts = state.appointments
        .where((a) => a.kind == 'hospital')
        .toList();
    final stats = [
      _card(context, '${docs.length}', 'Doctors',
          Icons.person_search, RemedooTheme.teal),
      _card(context, '${me.beds}', 'Beds', Icons.bed,
          scheme.primary),
      _card(context, '${appts.length}', 'Appointments',
          Icons.calendar_month, RemedooTheme.purple),
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
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              itemCount: stats.length,
              itemBuilder: (_, i) =>
                  StaggerItem(index: i % 6, child: stats[i]),
            ),
            const SizedBox(height: 24),
            const RSectionHeader(
                title: 'Doctors', subtitle: 'Linked doctors'),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              RCard(
                child: Text('No doctors linked yet.',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant)),
              )
            else
              ...docs.take(6).map((d) => StaggerItem(
                    index: 0,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(bottom: 10),
                      child: RCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
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
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      scheme.onSurfaceVariant)),
                          trailing:
                              RRatingPill(rating: d.rating),
                        ),
                      ),
                    ),
                  )),
            const SizedBox(height: 24),
            const RSectionHeader(
                title: 'Appointments',
                subtitle: 'Patient bookings'),
            const SizedBox(height: 12),
            if (appts.isEmpty)
              const REmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'No appointments',
                subtitle:
                    'Patient bookings will appear here.',
              )
            else
              ...appts.map((a) => StaggerItem(
                    index: 0,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(bottom: 10),
                      child: RCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: ListTile(
                          leading: InitialsAvatar(
                              name: a.doctorName,
                              radius: 22),
                          title: Text(a.doctorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '${a.dateLabel} • ${a.timeLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      scheme.onSurfaceVariant)),
                          trailing:
                              StatusChip(status: a.status),
                        ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String value, String label,
      IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: dark
                  ? color.withValues(alpha: 0.18)
                  : Color.lerp(color, Colors.white, 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

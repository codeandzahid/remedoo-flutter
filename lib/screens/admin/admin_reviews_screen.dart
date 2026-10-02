import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Admin reviews with Hide / Show toggle.
class AdminReviewsScreen extends StatelessWidget {
  const AdminReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final entries = state.reviews.entries.toList();
    if (entries.isEmpty) {
      return const REmptyState(
        icon: Icons.star_border,
        title: 'No reviews yet',
        subtitle: 'Patient reviews will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final r = entries[i].value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RRatingPill(
                        rating: r.stars.toDouble()),
                    const Spacer(),
                    if (r.hidden)
                      const StatusChip(status: 'hidden'),
                    Switch(
                      value: !r.hidden,
                      activeThumbColor:
                          RemedooTheme.success,
                      onChanged: (_) =>
                          state.toggleReviewHidden(
                              r.appointmentId),
                    ),
                  ],
                ),
                if (r.comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(r.comment),
                ],
                const SizedBox(height: 6),
                Text('Appointment ${r.appointmentId}',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        );
      },
    );
  }
}

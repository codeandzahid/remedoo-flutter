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
    final entries = state.reviews.entries.toList();
    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.star_border,
        title: 'No reviews yet',
        subtitle: 'Patient reviews will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final r = entries[i].value;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Row(
                      children: List.generate(5, (s) {
                        return Icon(
                          s < r.stars
                              ? Icons.star
                              : Icons.star_border,
                          size: 18,
                          color: Colors.amber.shade700,
                        );
                      }),
                    ),
                    const Spacer(),
                    if (r.hidden)
                      const StatusChip(status: 'hidden'),
                    Switch(
                      value: !r.hidden,
                      activeThumbColor:
                          RemedooTheme.ratingGreen,
                      onChanged: (_) =>
                          state.toggleReviewHidden(
                              r.appointmentId),
                    ),
                  ],
                ),
                if (r.comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(r.comment),
                ],
                Text('Appointment ${r.appointmentId}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}

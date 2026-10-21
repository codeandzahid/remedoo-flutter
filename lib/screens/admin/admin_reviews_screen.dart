import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Admin reviews moderation (form-pages audit Admin 8 / M6).
///
/// Reads the backend `reviews` table — every patient's reviews, not
/// just the ones left on this device — with Hide / Show
/// (reviews.status hidden|approved) and an admin-notes editor
/// (reviews.admin_notes).
class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppStateScope.of(context).loadAdminReviews();
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _editNotes(
      BuildContext context, AppState state, Review review) async {
    final controller = TextEditingController(text: review.adminNotes);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin notes'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Internal note about this review',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved != null) await state.setAdminReviewNotes(review, saved);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final entries = state.adminReviews;
    if (entries.isEmpty) {
      return const REmptyState(
        icon: Icons.star_border,
        title: 'No reviews yet',
        subtitle: 'Patient reviews will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await state.loadAdminReviews();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final r = entries[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RRatingPill(rating: r.stars.toDouble()),
                      const Spacer(),
                      if (r.hidden) const StatusChip(status: 'hidden'),
                      Switch(
                        value: !r.hidden,
                        activeThumbColor: RemedooTheme.success,
                        onChanged: (visible) =>
                            state.setAdminReviewHidden(r, !visible),
                      ),
                    ],
                  ),
                  if (r.comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(r.comment),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    [
                      if ((r.providerType ?? '').isNotEmpty)
                        'Provider: ${r.providerType} ${r.providerId ?? ''}',
                      if (r.appointmentId.isNotEmpty)
                        'Appointment ${r.appointmentId}',
                    ].join(' • '),
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  if (r.adminNotes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Note: ${r.adminNotes}',
                        style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: scheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _editNotes(context, state, r),
                      icon: const Icon(Icons.note_alt_outlined, size: 16),
                      label: const Text('Admin notes'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

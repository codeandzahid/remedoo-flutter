import 'package:flutter/material.dart';

import '../theme.dart';
import '../models.dart';
import '../state/app_state.dart';

// Shared building blocks for the Remedoo app.

class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({super.key, required this.child, this.maxWidth = 760});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Orange rounded-square logo with a white medical cross.
class RemedooLogo extends StatelessWidget {
  final double size;

  const RemedooLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RemedooTheme.headerGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: RemedooTheme.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.medical_services_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

/// Orange gradient header used on top of tab screens.
class GradientHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const GradientHeader({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: RemedooTheme.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 16),
          child: Row(
            children: [
              leading ??
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...?actions,
            ],
          ),
        ),
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const InitialsAvatar({super.key, required this.name, this.radius = 28});

  static const _palette = [
    Color(0xFFE86A1C),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF2E9E6B),
    Color(0xFFD43D3D),
    Color(0xFF0E9F8A),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name.replaceAll(RegExp(r'^(Dr\.\s*)'), '').split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'
        : name.substring(0, 1);
    final color = _palette[name.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.14),
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

class RatingPill extends StatelessWidget {
  final double rating;

  const RatingPill({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: RemedooTheme.ratingGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star,
              size: 14, color: RemedooTheme.ratingGreen),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: RemedooTheme.ratingGreen,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(color: RemedooTheme.primary),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor:
                  RemedooTheme.primary.withValues(alpha: 0.12),
              child: Icon(icon,
                  size: 36, color: RemedooTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    final Color color;
    if (lower.contains('cancel') || lower.contains('reject')) {
      color = RemedooTheme.emergency;
    } else if (lower.contains('deliver') ||
        lower.contains('complet') ||
        lower.contains('approv') ||
        lower.contains('resolv')) {
      color = RemedooTheme.ratingGreen;
    } else if (lower.contains('pack') ||
        lower.contains('pick') ||
        lower.contains('progress') ||
        lower.contains('pend') ||
        lower.contains('request')) {
      color = Colors.orange.shade800;
    } else {
      color = RemedooTheme.primary;
    }
    final label = status.replaceAll('_', ' ');
    final pretty = label.isEmpty
        ? label
        : '${label[0].toUpperCase()}${label.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        pretty,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: RemedooTheme.primary),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minus / qty / plus stepper.
class QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const QtyStepper({
    super.key,
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: RemedooTheme.primary),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            color: RemedooTheme.primary,
            onPressed: onMinus,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
          Text('$qty',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            color: RemedooTheme.primary,
            onPressed: onPlus,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Heart favorite toggle button.
class FavoriteButton extends StatelessWidget {
  final String favKey;

  const FavoriteButton({super.key, required this.favKey});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final fav = state.isFavorite(favKey);
    return IconButton(
      icon: Icon(
        fav ? Icons.favorite : Icons.favorite_border,
        color: fav ? RemedooTheme.emergency : null,
      ),
      onPressed: () => state.toggleFavorite(favKey),
    );
  }
}

/// Medicine detail bottom sheet (own descriptive copy).
class MedicineDetailSheet extends StatelessWidget {
  final Medicine medicine;

  const MedicineDetailSheet({super.key, required this.medicine});

  static void show(BuildContext context, Medicine medicine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MedicineDetailSheet(medicine: medicine),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = medicine;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color:
                      RemedooTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.medication,
                    color: RemedooTheme.primary, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('${m.pack} • ${m.brand}',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(inr(m.price),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: RemedooTheme.primary)),
                        const SizedBox(width: 8),
                        Text(
                          inr(m.mrp),
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        if (m.rxRequired) ...[
                          const SizedBox(width: 8),
                          const StatusChip(status: 'Rx'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('About',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            '${m.name} is a commonly used ${m.category.toLowerCase()} medicine. '
            'It is typically taken as directed on the pack or by your doctor.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          const Text('Dosage',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'Follow the dosage printed on the pack (${m.pack}) or your doctor\'s prescription. '
            'Do not exceed the recommended dose.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          const Text('Note',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            m.rxRequired
                ? 'This medicine requires a valid prescription. You can upload it at checkout.'
                : 'No prescription needed for this product.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Star-rating review dialog after an appointment.
class ReviewDialog extends StatefulWidget {
  final String appointmentId;
  final String title;

  const ReviewDialog({
    super.key,
    required this.appointmentId,
    required this.title,
  });

  static Future<void> show(
      BuildContext context, String appointmentId, String title) {
    return showDialog(
      context: context,
      builder: (_) =>
          ReviewDialog(appointmentId: appointmentId, title: title),
    );
  }

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _stars = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate ${widget.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return IconButton(
                icon: Icon(
                  i < _stars ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade700,
                  size: 32,
                ),
                onPressed: () => setState(() => _stars = i + 1),
              );
            }),
          ),
          TextField(
            controller: _comment,
            decoration: const InputDecoration(
              hintText: 'Share your experience (optional)',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () {
            AppStateScope.of(context).addReview(
              widget.appointmentId,
              _stars,
              _comment.text.trim(),
            );
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thanks for your review!')),
            );
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

/// Side-by-side lab comparison sheet.
class LabCompareSheet extends StatelessWidget {
  final Lab a;
  final Lab b;

  const LabCompareSheet({super.key, required this.a, required this.b});

  static void show(BuildContext context, Lab a, Lab b) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LabCompareSheet(a: a, b: b),
    );
  }

  Widget _row(String label, String va, String vb, {bool highlightA = false, bool highlightB = false}) {
    TextStyle style(bool h) => TextStyle(
        fontWeight: h ? FontWeight.w800 : FontWeight.w500,
        color: h ? RemedooTheme.primary : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(va, style: style(highlightA))),
          Expanded(
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
              child: Text(va == vb ? '' : vb,
                  textAlign: TextAlign.right, style: style(highlightB))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cheaperA = true; // visual only
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Compare Labs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: Text(a.name,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              const Expanded(
                  child: Text('vs',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey))),
              Expanded(
                  child: Text(b.name,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          const Divider(),
          _row('Rating', a.rating.toString(), b.rating.toString(),
              highlightA: a.rating >= b.rating,
              highlightB: b.rating > a.rating),
          _row('Tests', '${a.testCount}', '${b.testCount}',
              highlightA: a.testCount >= b.testCount,
              highlightB: b.testCount > a.testCount),
          _row('Turnaround', a.turnaround, b.turnaround),
          _row('NABL', a.nabl ? 'Yes' : 'No', b.nabl ? 'Yes' : 'No',
              highlightA: a.nabl && !b.nabl, highlightB: b.nabl && !a.nabl),
          _row('Distance', '${a.distanceKm.toStringAsFixed(1)} km',
              '${b.distanceKm.toStringAsFixed(1)} km'),
          if (cheaperA) const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Simple help dialog for the floating "?" button.
void showHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Need help?'),
      content: const Text(
        'Our support team is available 24x7.\n\n'
        '• Call us: 1800-123-4567\n'
        '• Email: care@remedoo.app\n\n'
        'For emergencies, use the Emergency SOS screen.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Confirm dialog returning true when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}

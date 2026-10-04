import 'package:flutter/material.dart';

import '../theme.dart';
import '../models.dart';
import '../data/mock_data.dart';
import '../state/app_state.dart';
import 'theme_backdrop.dart';

// Shared building blocks for the Remedoo app.
//
// Naming: legacy widgets keep their original names (screens depend on them);
// new reskin components use the `R` prefix. Every component below follows the
// design spec in `~/workspace/remedoo-reskin/DESIGN_SPEC.md`.

/// Whether the current theme is dark.
bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

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

/// Orange gradient header used on top of tab screens, with a rounded bottom
/// (~28px) like the React app's dashboard hero.
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
      decoration: BoxDecoration(
        gradient: RemedooTheme.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(RemedooRadius.xxl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 20),
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



  @override
  Widget build(BuildContext context) {
    final parts = name.replaceAll(RegExp(r'^(Dr\.\s*)'), '').split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'
        : name.substring(0, 1);
    final color = RemedooTheme.primary;
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

/// Green rating pill with a white star + number, as in the React listings.
class RatingPill extends StatelessWidget {
  final double rating;

  const RatingPill({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB300)),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// Bold section title with an orange "See all"-style action on the right.
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
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
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
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: RemedooTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    size: 26, color: RemedooTheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 10),
                RButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  small: true,
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: RemedooTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 40, color: RemedooTheme.primary),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              RButton(
                label: actionLabel!,
                onPressed: onAction,
                small: true,
              ),
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
    final Color bg;
    if (lower.contains('cancel') || lower.contains('reject')) {
      color = RemedooTheme.destructive;
      bg = RemedooTheme.destructive.withValues(alpha: 0.12);
    } else if (lower.contains('deliver') ||
        lower.contains('complet') ||
        lower.contains('approv') ||
        lower.contains('resolv')) {
      color = RemedooTheme.success;
      bg = RemedooTheme.success.withValues(alpha: 0.12);
    } else if (lower.contains('pack') ||
        lower.contains('pick') ||
        lower.contains('progress') ||
        lower.contains('pend') ||
        lower.contains('request') ||
        lower.contains('placed')) {
      color = const Color(0xFFB45309);
      bg = const Color(0xFFFEF3C7);
    } else {
      color = Theme.of(context).colorScheme.primary;
      bg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    }
    final label = status.replaceAll('_', ' ');
    final pretty = label.isEmpty
        ? label
        : '${label[0].toUpperCase()}${label.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
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
          Icon(icon,
              size: 18, color: Theme.of(context).colorScheme.primary),
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
    final p = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: p),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            color: p,
            onPressed: onMinus,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
          Text('$qty',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            color: p,
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
    final p = Theme.of(context).colorScheme.primary;
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
                color: Theme.of(context).dividerColor,
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
                  color: p.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.medication, color: p, size: 32),
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
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: p)),
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
          const SizedBox(height: 20),
          _cartAction(context, m),
        ],
      ),
    );
  }

  /// Add-to-cart control for the detail sheet: a full-width button that
  /// morphs into a quantity stepper once the item is in the cart, so
  /// checkout is always reachable from here.
  Widget _cartAction(BuildContext context, Medicine m) {
    final state = AppStateScope.of(context);
    final qty = state.cartQty(m.id);
    if (qty == 0) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => _addToCart(context, state, m),
          child: const Text('Add to Cart'),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            '$qty in cart • ${inr(state.priceOf(m) * qty)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        QtyStepper(
          qty: qty,
          onMinus: () => state.removeFromCart(m.id),
          onPlus: () => _addToCart(context, state, m),
        ),
      ],
    );
  }

  /// Adds [m] to the cart, asking to switch pharmacies when the cart holds
  /// another vendor's items (same behavior as the storefront cards).
  void _addToCart(BuildContext context, AppState state, Medicine m) {
    final match = pharmacies.where((p) => p.id == m.pharmacyId);
    final pharmacyName = match.isEmpty ? 'Pharmacy' : match.first.name;
    if (state.addToCart(
        m, pharmacyId: m.pharmacyId, pharmacyName: pharmacyName)) {
      return;
    }
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Switch pharmacy?'),
        content: const Text(
            'Your cart has items from another pharmacy. Clear it and add this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Keep cart'),
          ),
          FilledButton(
            onPressed: () {
              state.clearCart();
              state.addToCart(m,
                  pharmacyId: m.pharmacyId, pharmacyName: pharmacyName);
              Navigator.pop(c);
            },
            child: const Text('Clear & add'),
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
                  color: RemedooTheme.primary,
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

  Widget _row(BuildContext context, String label, String va, String vb,
      {bool highlightA = false, bool highlightB = false}) {
    final p = Theme.of(context).colorScheme.primary;
    TextStyle style(bool h) => TextStyle(
        fontWeight: h ? FontWeight.w800 : FontWeight.w500,
        color: h ? p : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(va, style: style(highlightA))),
          Expanded(
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13)),
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
                color: Theme.of(context).dividerColor,
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
              Expanded(
                  child: Text('vs',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant))),
              Expanded(
                  child: Text(b.name,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          const Divider(),
          _row(context, 'Rating', a.rating.toString(), b.rating.toString(),
              highlightA: a.rating >= b.rating,
              highlightB: b.rating > a.rating),
          _row(context, 'Tests', '${a.testCount}', '${b.testCount}',
              highlightA: a.testCount >= b.testCount,
              highlightB: b.testCount > a.testCount),
          _row(context, 'Turnaround', a.turnaround, b.turnaround),
          _row(context, 'NABL', a.nabl ? 'Yes' : 'No',
              b.nabl ? 'Yes' : 'No',
              highlightA: a.nabl && !b.nabl, highlightB: b.nabl && !a.nabl),
          _row(context, 'Distance', '${a.distanceKm.toStringAsFixed(1)} km',
              '${b.distanceKm.toStringAsFixed(1)} km'),
        ],
      ),
    );
  }
}

/// Simple help dialog for the floating "?" button.
void showHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Need help?'),
      content: const Text(
        'Our support team is available 24x7.\n\n'
        '• Call us: 1800-123-4567\n'
        '• Email: care@remedoo.app\n\n'
        'For emergencies, use the Emergency SOS screen.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
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
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// Reference-style guest gate (matches remedoo.inboxxahid.workers.dev):
/// no modal dialogs — a toast is shown and the guest is redirected to the
/// login page, which always offers "Skip, continue as guest".
///
/// Returns true when the user is signed in. For guests it shows [message] as
/// a toast, redirects to login after a beat, and returns false so callers
/// can bail out of the tapped action.
bool checkLogin(BuildContext context,
    [String message = 'Please login to access this feature']) {
  final state = AppStateScope.of(context);
  // Only a real signed-in account passes. Guests — and the logged-out
  // state right after a guest is redirected — are blocked, so repeated
  // tapping can never walk through an open gate.
  if (state.isSignedIn) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
  // Let the toast show, then exit guest mode → RootGate → LoginScreen.
  Future.delayed(const Duration(milliseconds: 1200), () {
    if (state.isGuest) state.logout();
  });
  return false;
}

/// Passive full-screen guest gate (backstop for screens that require a
/// signed-in account). Shows the message with a Sign In action that exits
/// guest mode to the login page. Intentionally passive (no auto-redirect):
/// it must be safe to build eagerly inside an IndexedStack. The
/// reference-style toast + redirect happens at navigation time via
/// [checkLogin].
class GuestGate extends StatelessWidget {
  final String message;

  const GuestGate({
    super.key,
    this.message = 'Please login to access this feature',
  });

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              FilledButton(
                // Exit guest mode; RootGate rebuilds straight to LoginScreen.
                onPressed: () => state.logout(),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Reskin component library (R-prefixed). Screen workstreams: build screens
// out of these so every screen inherits the React reference look.
// ============================================================================

/// Button variants matching the React app: solid orange pill, white outline
/// pill, and red danger pill.
enum RButtonVariant { primary, outline, danger }

/// Pill-shaped semibold button.
class RButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool small;
  final RButtonVariant variant;

  const RButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.small = false,
    this.variant = RButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    final BorderSide? side;
    switch (variant) {
      case RButtonVariant.primary:
        bg = scheme.primary;
        fg = Colors.white;
        side = null;
      case RButtonVariant.outline:
        bg = scheme.surface;
        fg = scheme.primary;
        side = BorderSide(color: scheme.primary, width: 1.4);
      case RButtonVariant.danger:
        bg = RemedooTheme.emergency;
        fg = Colors.white;
        side = null;
    }
    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: small ? 16 : 18, color: fg),
          SizedBox(width: small ? 6 : 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: RemedooTheme.fontFamily,
              color: fg,
              fontSize: small ? 14 : 16,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    final button = Material(
      color: bg,
      shape: RemedooTheme.pillButtons
          ? StadiumBorder(side: side ?? BorderSide.none)
          : RoundedRectangleBorder(
              side: side ?? BorderSide.none,
              borderRadius:
                  BorderRadius.circular(RemedooTheme.buttonRadius),
            ),
      child: InkWell(
        onTap: onPressed,
        customBorder: RemedooTheme.pillButtons
            ? const StadiumBorder()
            : RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(RemedooTheme.buttonRadius),
              ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 18 : 24,
            vertical: small ? 10 : 14,
          ),
          child: content,
        ),
      ),
    );
    if (onPressed == null) {
      return Opacity(opacity: 0.5, child: button);
    }
    return fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Mockup-style avatar: theme-tinted circle with initials or icon.
class RAvatarCircle extends StatelessWidget {
  final String name;
  final double size;
  final IconData? icon;

  const RAvatarCircle(
      {super.key, required this.name, this.size = 60, this.icon});

  /// "Dr. Meera Rao" -> "MR".
  static String initialsOf(String name) {
    final parts =
        name.replaceFirst(RegExp(r'^Dr\.\s*'), '').split(' ');
    final keep = parts.where((w) => w.isNotEmpty).take(2).toList();
    if (keep.isEmpty) return '?';
    return keep.map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: RemedooTheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: RemedooTheme.primary.withValues(alpha: 0.30),
          width: 2,
        ),
      ),
      child: Center(
        child: icon != null
            ? Icon(icon,
                size: size * 0.42, color: RemedooTheme.primary)
            : Text(
                initialsOf(name),
                style: TextStyle(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w800,
                  color: RemedooTheme.primary,
                ),
              ),
      ),
    );
  }
}

/// Mockup-style star rating row.
class RStarRating extends StatelessWidget {
  final double rating;
  final double size;

  const RStarRating({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: size, color: RemedooTheme.primary),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }
}

/// Mockup-style doctor card (like the theme mockups): circular avatar,
/// name, specialty, star rating, Visit button. Compact mode is the
/// dashboard rail card.
class RDoctorCard extends StatelessWidget {
  final Doctor doctor;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onVisit;
  final Widget? trailing;

  const RDoctorCard({
    super.key,
    required this.doctor,
    this.compact = false,
    this.onTap,
    this.onVisit,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (compact) return _compact(context, scheme);
    return _row(context, scheme);
  }

  Widget _compact(BuildContext context, ColorScheme scheme) {
    return RCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RAvatarCircle(name: doctor.name, size: 62),
          const SizedBox(height: 8),
          Text(
            doctor.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          Text(
            doctor.specialty,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          RStarRating(rating: doctor.rating),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: RButton(
              label: 'Visit',
              small: true,
              onPressed: onVisit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ColorScheme scheme) {
    return RCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RAvatarCircle(name: doctor.name, size: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doctor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                        ),
                        trailing ?? const SizedBox.shrink(),
                      ],
                    ),
                    Text(
                      doctor.specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: RemedooTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 13,
                            color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            doctor.hospital,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              RStarRating(rating: doctor.rating),
              _dot(scheme),
              Text('${doctor.expYears} yrs exp',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              _dot(scheme),
              Text(inr(doctor.fee),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: RButton(
              label: 'Visit',
              icon: Icons.arrow_forward,
              small: true,
              onPressed: onVisit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('·',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
    );
  }
}

/// Mockup-style hospital card: circular avatar, name, location, rating
/// line, View/Book buttons. Government hospitals never show Book.
class RHospitalCard extends StatelessWidget {
  final Hospital hospital;
  final bool hideBooking;
  final VoidCallback? onTap;
  final VoidCallback? onView;
  final VoidCallback? onBook;
  final Widget? trailing;

  const RHospitalCard({
    super.key,
    required this.hospital,
    this.hideBooking = false,
    this.onTap,
    this.onView,
    this.onBook,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = hospital;
    return RCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RAvatarCircle(
                  name: h.name, size: 58, icon: Icons.local_hospital),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            h.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                        ),
                        trailing ?? const SizedBox.shrink(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 13,
                            color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            h.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              RStarRating(rating: h.rating),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('·',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 16)),
              ),
              Text('${h.beds} beds',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('·',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 16)),
              ),
              Text(h.government ? 'Government' : 'Private',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: RButton(
                  label: 'View',
                  small: true,
                  variant: RButtonVariant.outline,
                  onPressed: onView,
                ),
              ),
              if (!h.government && !hideBooking) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: RButton(
                    label: 'Book',
                    icon: Icons.calendar_month,
                    small: true,
                    onPressed: onBook,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Dense list row for the compact UI: leading avatar, title, subtitle,
/// meta line, optional trailing action. Rows are grouped in [RDenseGroup].
class RDenseRow extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? meta;
  final Widget? trailing;

  const RDenseRow({
    super.key,
    this.onTap,
    required this.leading,
    required this.title,
    this.subtitle,
    this.meta,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: RemedooTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (meta != null) ...[
                    const SizedBox(height: 2),
                    meta!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact "star rating · detail · detail" meta line for dense rows.
class RDenseMeta extends StatelessWidget {
  final double rating;
  final List<String> parts;

  const RDenseMeta(
      {super.key, required this.rating, this.parts = const []});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        RStarRating(rating: rating, size: 12),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            parts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ),
      ],
    );
  }
}

/// One card holding dense rows separated by dividers — the compact UI's
/// replacement for grids of big cards.
class RDenseGroup extends StatelessWidget {
  final List<Widget> rows;

  const RDenseGroup({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return RCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(height: 1, indent: 70),
          ],
        ],
      ),
    );
  }
}

/// White card: 18px radius, thin warm-gray border, soft subtle shadow.
class RCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const RCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = RemedooTheme.cardRadius + 4;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _isDark(context)
            ? null
            : [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

/// Rounded-full search bar with a magnifier icon.
class RSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final TextEditingController? controller;
  final bool readOnly;

  const RSearchBar({
    super.key,
    this.hint = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted?.call(),
      style: const TextStyle(
          fontFamily: RemedooTheme.fontFamily, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search, color: scheme.primary),
        filled: true,
        fillColor: scheme.primary.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }
}

/// Title with a vertical theme-accent bar (+ optional subtitle) and "See all".
class RSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  const RSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 22,
          margin: const EdgeInsets.only(right: 10, top: 1),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'See all',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

/// Tinted rounded chip; selected = theme-primary filled, white text.
class RFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const RFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color bg = selected
        ? scheme.primary
        : scheme.primary.withValues(alpha: 0.10);
    final Color fg = selected ? Colors.white : scheme.primary;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: RemedooTheme.fontFamily,
                  color: fg,
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green pill with a white star + rating number (listings).
class RRatingPill extends StatelessWidget {
  final double rating;

  const RRatingPill({super.key, required this.rating});

  @override
  Widget build(BuildContext context) => RatingPill(rating: rating);
}

/// Gradient promo banner: white bold title, lighter subtitle, trailing
/// illustration widget, optional dot indicators ([pageCount] pages,
/// [pageIndex] active).
class RPromoBanner extends StatelessWidget {
  final Gradient gradient;
  final String title;
  final String subtitle;
  final Widget? illustration;
  final int? pageCount;
  final int pageIndex;

  const RPromoBanner({
    super.key,
    this.gradient = RemedooTheme.promoTealGradient,
    required this.title,
    required this.subtitle,
    this.illustration,
    this.pageCount,
    this.pageIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -28,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 52,
            bottom: -40,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (illustration != null)
                      SizedBox(
                          width: 64, height: 64, child: illustration),
                  ],
                ),
                if (pageCount != null && pageCount! > 1) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pageCount!, (i) {
                      final active = i == pageIndex;
                      return Container(
                        width: active ? 18 : 6,
                        height: 6,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Theme-tinted ribbon badge overlaid at the bottom of a listing image
/// header (e.g. "ICU Available 24/7", "Government Hospital").
class RRibbon extends StatelessWidget {
  final String label;
  final IconData icon;

  const RRibbon({
    super.key,
    required this.label,
    this.icon = Icons.shield_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [RemedooTheme.primary, RemedooTheme.primaryDark],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny icon + gray text stat (e.g. "500 beds", "ICU", "20–30 min").
class RStat extends StatelessWidget {
  final IconData icon;
  final String text;

  const RStat({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Centered empty state: icon illustration, title, subtitle, orange pill CTA.
class REmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const REmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: icon,
        title: title,
        subtitle: subtitle,
        actionLabel: actionLabel,
        onAction: onAction,
        compact: compact,
      );
}

/// Floating white rounded-2xl bottom bar with soft shadow.
/// 5 items: Home, Hospitals, Labs, Pharmacy, Orders — active = orange.
class RBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const RBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    ('Home', Icons.home_outlined, Icons.home),
    ('Hospitals', Icons.business_outlined, Icons.business),
    ('Labs', Icons.science_outlined, Icons.science),
    ('Pharmacy', Icons.storefront_outlined, Icons.storefront),
    ('Orders', Icons.shopping_cart_outlined, Icons.shopping_cart),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary.withValues(alpha: 0.08);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(
                color: scheme.primary.withValues(alpha: 0.18)),
          ),
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final active = i == currentIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? scheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: scheme.primary
                                  .withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(active ? _items[i].$3 : _items[i].$2,
                          size: 22,
                          color: active
                              ? Colors.white
                              : scheme.onSurfaceVariant),
                      const SizedBox(height: 2),
                      Text(
                        _items[i].$1,
                        style: TextStyle(
                          fontFamily: RemedooTheme.fontFamily,
                          fontSize: 10.5,
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: active
                              ? Colors.white
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Labeled form field: small orange icon + label above a rounded filled input.
class RTextField extends StatelessWidget {
  final String? label;
  final IconData? labelIcon;
  final String? hint;
  final TextEditingController? controller;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final Widget? prefixIcon;

  const RTextField({
    super.key,
    this.label,
    this.labelIcon,
    this.hint,
    this.controller,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.suffixIcon,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              if (labelIcon != null) ...[
                Icon(labelIcon, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
              ],
              Text(
                label!,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(
              fontFamily: RemedooTheme.fontFamily, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
          ),
        ),
      ],
    );
  }
}

/// Orange gradient header container with a rounded bottom (~28px) for
/// dashboard-style headers; content goes in [child].
class RGradientHeader extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;

  RGradientHeader({
    super.key,
    required this.child,
    Gradient? gradient,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
  }) : gradient = gradient ?? RemedooTheme.headerGradient;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(RemedooRadius.xxl),
        ),
      ),
      child: Stack(
        children: [
          // Per-theme decorative artwork (clouds, waves, petals...).
          const HeaderArtwork(),
          // Soft diagonal sheen for depth (solid, not a gradient wash).
          Positioned(
            left: -40,
            top: -60,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                width: 220,
                height: 160,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

/// Pastel rounded tile + icon + label, for the dashboard service grid.
class RServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tileColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const RServiceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.tileColor,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RemedooRadius.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(RemedooRadius.lg),
            ),
            child: Icon(icon, size: 28, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Sidebar primitives — rebuilt 1:1 from the React AppSidebar
/// (`remedoo-react-ref/src/components/AppSidebar.tsx`).
/// ---------------------------------------------------------------------------

/// Tiny uppercase group label: "⚡ QUICK ACTIONS" / "🧭 NAVIGATE".
/// 10px, extrabold, letter-spaced, muted gray.
class RSidebarGroupLabel extends StatelessWidget {
  final String label;

  const RSidebarGroupLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// Full-width orange gradient Close button (rounded-2xl, white bold text +
/// chevron-left), as at the top of the React sidebar.
class RSidebarCloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const RSidebarCloseButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Ink(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [p, p.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chevron_left, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient quick-action tile: big emoji + tiny (10px) bold white label,
/// rounded-2xl, min height 44 — the React sidebar's action grid.
class RSidebarQuickTile extends StatelessWidget {
  final String emoji;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const RSidebarQuickTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sidebar nav row (rounded-2xl, icon + semibold label, min height 44).
/// Active: orange-tint gradient background + vertical orange indicator bar on
/// the left edge + subtle shadow + orange text. Inactive: muted gray text;
/// press shows a light orange tint.
class RSidebarNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// Optional count pill (e.g. cart items) shown at the row's trailing edge.
  final String? badgeLabel;

  const RSidebarNavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? RemedooTheme.darkAccent : RemedooTheme.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: scheme.primary.withValues(alpha: 0.12),
          highlightColor: scheme.primary.withValues(alpha: 0.08),
          child: Ink(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: active
                  ? LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.6)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(16),
              border: active
                  ? Border.all(
                      color: scheme.primary.withValues(alpha: 0.2))
                  : null,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (active)
                  Positioned(
                    left: -16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: active
                          ? scheme.primary
                          : scheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? scheme.primary
                              : scheme.onSurfaceVariant
                                  .withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    if (badgeLabel != null &&
                        badgeLabel!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius:
                              BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

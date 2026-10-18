import 'dart:ui';

import 'package:flutter/material.dart';

/// Glassmorphism kit for the Admin panel (owner order 2026-10-18).
///
/// Light frosted glass over a soft aurora backdrop: translucent
/// white surfaces, hairline white borders, soft violet shadows.
/// Everything inside the admin shell (and the admin login) lives
/// under a [GlassScope] so the shared widgets (RCard, fields,
/// chips…) render their glass variant there and stay untouched
/// everywhere else in the app.
class GlassScope extends InheritedWidget {
  final bool enabled;

  const GlassScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  static bool of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<GlassScope>();
    return scope?.enabled ?? false;
  }

  @override
  bool updateShouldNotify(GlassScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// The standard frosted-glass surface decoration: white gradient
/// translucency + hairline border + soft shadow.
BoxDecoration glassDecoration({
  double radius = 20,
  double topAlpha = 0.62,
  double bottomAlpha = 0.38,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: topAlpha),
        Colors.white.withValues(alpha: bottomAlpha),
      ],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.65),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF4C1D95).withValues(alpha: 0.10),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

/// A frosted glass panel. With [blur] it also backdrop-blurs what
/// is behind it (used by the drawer, which slides over content);
/// over the static aurora backdrop the translucent fill alone
/// already reads as glass, so fixed chrome skips the filter cost.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final bool blur;
  final EdgeInsetsGeometry? padding;

  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 20,
    this.blur = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: padding,
      decoration: glassDecoration(radius: radius),
      child: child,
    );
    if (!blur) return panel;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: panel,
      ),
    );
  }
}

/// The aurora backdrop behind the glass: a soft pastel gradient
/// with large blurred color blobs in the brand hues. Static, so
/// the blur is a one-time layer cost.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE9E3FF),
                Color(0xFFDCEBFF),
                Color(0xFFDFF7EE),
                Color(0xFFFFEAF3),
              ],
            ),
          ),
        ),
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
          child: Stack(
            children: [
              Positioned(
                top: -120,
                left: -80,
                child: _blob(const Color(0xFF7C3AED), 380, 0.35),
              ),
              Positioned(
                top: -60,
                right: -100,
                child: _blob(const Color(0xFF38BDF8), 340, 0.32),
              ),
              Positioned(
                bottom: -140,
                left: 120,
                child: _blob(const Color(0xFF2DD4BF), 360, 0.28),
              ),
              Positioned(
                bottom: -80,
                right: 60,
                child: _blob(const Color(0xFFF472B6), 300, 0.24),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _blob(Color color, double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: alpha),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Spatial UI kit for the Admin panel (owner order 2026-10-18,
/// superseding glassmorphism, then maximalism): a calm, deep
/// "environment" backdrop with content floating in front of it as
/// light slabs at different depths — visionOS-style. Depth comes
/// from layered soft shadows and detachment (gaps around the
/// sidebar / top bar / workspace), never from heavy blur, so text
/// stays crisp.
///
/// Everything inside the admin shell (and the admin login) lives
/// under a [SpatialScope] so shared widgets (RCard…) render their
/// floating variant there and stay untouched elsewhere.
class SpatialScope extends InheritedWidget {
  final bool enabled;

  const SpatialScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  static bool of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SpatialScope>();
    return scope?.enabled ?? false;
  }

  @override
  bool updateShouldNotify(SpatialScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// A floating slab surface. [depth] is the float level:
/// 0 = card resting inside the workspace, 1 = the workspace slab
/// itself, 2 = top bar / sidebar / drawer hovering highest.
BoxDecoration spatialDecoration({
  double radius = 24,
  int depth = 0,
}) {
  final shadows = switch (depth) {
    2 => const [
        BoxShadow(
          color: Color(0x4D000000),
          blurRadius: 48,
          offset: Offset(0, 24),
        ),
        BoxShadow(
          color: Color(0x26000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    1 => const [
        BoxShadow(
          color: Color(0x38000000),
          blurRadius: 36,
          offset: Offset(0, 18),
        ),
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    _ => const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
  };
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.98),
        Colors.white.withValues(alpha: 0.93),
      ],
    ),
    borderRadius: BorderRadius.circular(radius),
    border:
        Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1),
    boxShadow: shadows,
  );
}

/// A floating panel (sidebar, drawer, workspace slab).
class SpatialPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final int depth;
  final EdgeInsetsGeometry? padding;

  const SpatialPanel({
    super.key,
    required this.child,
    this.radius = 24,
    this.depth = 1,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: spatialDecoration(radius: radius, depth: depth),
      child: child,
    );
  }
}

/// The environment: deep indigo space with soft ambient color
/// glows — violet upper-left, teal lower-right, a whisper of
/// amber — and fine "dust" dots, so the light slabs floating in
/// front read as nearer to the viewer.
class SpatialBackdrop extends StatelessWidget {
  const SpatialBackdrop({super.key});

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
                Color(0xFF0B1026),
                Color(0xFF17203A),
                Color(0xFF1E293B),
              ],
            ),
          ),
        ),
        Positioned(
          top: -160,
          left: -120,
          child: _glow(460, const Color(0xFF7C3AED), 0.40),
        ),
        Positioned(
          bottom: -180,
          right: -100,
          child: _glow(520, const Color(0xFF0D9488), 0.32),
        ),
        Positioned(
          top: 120,
          right: 180,
          child: _glow(220, const Color(0xFFF59E0B), 0.14),
        ),
        CustomPaint(painter: _DustPainter()),
      ],
    );
  }

  Widget _glow(double size, Color color, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _DustPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    const gap = 34.0;
    for (double x = gap / 2; x < size.width; x += gap) {
      for (double y = gap / 2; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

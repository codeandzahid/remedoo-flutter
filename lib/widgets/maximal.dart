import 'package:flutter/material.dart';

/// Maximalism kit for the Admin panel (owner order 2026-10-18,
/// superseding the glassmorphism pass): MORE is more — a loud
/// saturated backdrop (violet → magenta → tangerine with a dot
/// pattern and bold shapes), warm-paper surfaces with chunky
/// near-black outlines, hard offset shadows, and pop accents.
///
/// Everything inside the admin shell (and the admin login) lives
/// under a [MaxScope] so shared widgets (RCard, fields, chips…)
/// render their maximal variant there and stay untouched in the
/// rest of the app.
class MaxScope extends InheritedWidget {
  final bool enabled;

  const MaxScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  static bool of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<MaxScope>();
    return scope?.enabled ?? false;
  }

  @override
  bool updateShouldNotify(MaxScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// The ink color used for the chunky outlines and hard shadows.
const Color maxInk = Color(0xFF232038);

/// Pop accent palette.
const Color maxPink = Color(0xFFDB2777);
const Color maxViolet = Color(0xFF7C3AED);
const Color maxOrange = Color(0xFFF97316);
const Color maxAmber = Color(0xFFFDE68A);
const Color maxPaper = Color(0xFFFFFBEB);

/// The maximal surface: warm paper, 2px ink outline, hard offset
/// shadow (no blur — it should look printed, bold, deliberate).
BoxDecoration maxDecoration({
  double radius = 20,
  Color fill = maxPaper,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [fill, const Color(0xFFFFF1C9)],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: maxInk, width: 2),
    boxShadow: const [
      BoxShadow(
        color: Color(0xE6232038),
        blurRadius: 0,
        offset: Offset(6, 6),
      ),
      BoxShadow(
        color: Color(0x407C3AED),
        blurRadius: 28,
        offset: Offset(0, 14),
      ),
    ],
  );
}

/// A maximal panel (sidebar, drawer, hero surfaces).
class MaxPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  const MaxPanel({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: maxDecoration(radius: radius),
      child: child,
    );
  }
}

/// The loud backdrop: saturated gradient + dot pattern + bold
/// outlined shapes + glowing color blobs.
class MaxBackdrop extends StatelessWidget {
  const MaxBackdrop({super.key});

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
                Color(0xFF2E1065),
                Color(0xFF7C3AED),
                Color(0xFFDB2777),
                Color(0xFFF97316),
              ],
              stops: [0.0, 0.38, 0.72, 1.0],
            ),
          ),
        ),
        CustomPaint(painter: _DotsPainter()),
        Positioned(
          top: -70,
          right: -50,
          child: _ring(190, Colors.white.withValues(alpha: 0.20)),
        ),
        Positioned(
          bottom: 40,
          left: -60,
          child: _ring(150, const Color(0xFFFDE68A).withValues(alpha: 0.35)),
        ),
        Positioned(
          top: 130,
          left: 60,
          child: Transform.rotate(
            angle: 0.5,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          right: 140,
          child: Icon(
            Icons.star,
            size: 120,
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
      ],
    );
  }

  Widget _ring(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 10),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    const gap = 26.0;
    const r = 2.2;
    for (double x = gap / 2; x < size.width; x += gap) {
      for (double y = gap / 2; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

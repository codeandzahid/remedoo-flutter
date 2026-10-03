import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Decorative artwork painted behind gradient headers, unique to each theme.
/// Subtle white motifs at low opacity so header text stays readable.
class HeaderArtwork extends StatelessWidget {
  const HeaderArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _BackdropPainter(RemedooTheme.backdrop)),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final ThemeBackdrop backdrop;
  _BackdropPainter(this.backdrop);

  @override
  void paint(Canvas canvas, Size size) {
    switch (backdrop) {
      case ThemeBackdrop.clouds:
        _clouds(canvas, size);
        break;
      case ThemeBackdrop.wash:
        _wash(canvas, size);
        break;
      case ThemeBackdrop.mist:
        _mist(canvas, size);
        break;
      case ThemeBackdrop.petals:
        _petals(canvas, size);
        break;
      case ThemeBackdrop.glow:
        _glow(canvas, size);
        break;
      case ThemeBackdrop.leaves:
        _leaves(canvas, size);
        break;
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.backdrop != backdrop;

  Paint _paint(double opacity) =>
      Paint()..color = Colors.white.withValues(alpha: opacity);

  /// Sky Pulse: puffy clouds along the bottom, small ones top-right.
  void _clouds(Canvas canvas, Size size) {
    final p = _paint(0.16);
    void cloud(double cx, double cy, double r) {
      canvas.drawCircle(Offset(cx - r * 1.1, cy + r * 0.25), r * 0.75, p);
      canvas.drawCircle(Offset(cx, cy), r, p);
      canvas.drawCircle(Offset(cx + r * 1.1, cy + r * 0.25), r * 0.75, p);
      canvas.drawCircle(Offset(cx + r * 0.4, cy - r * 0.45), r * 0.7, p);
      canvas.drawCircle(Offset(cx - r * 0.5, cy - r * 0.35), r * 0.6, p);
    }

    cloud(size.width * 0.18, size.height * 0.92, 26);
    cloud(size.width * 0.62, size.height * 1.02, 34);
    cloud(size.width * 0.97, size.height * 0.85, 22);
    cloud(size.width * 0.86, size.height * 0.18, 14);
    cloud(size.width * 0.38, size.height * 0.12, 10);
  }

  /// Ocean Sand: soft wavy bands drifting across.
  void _wash(Canvas canvas, Size size) {
    final p = _paint(0.12);
    for (var i = 0; i < 3; i++) {
      final baseY = size.height * (0.35 + i * 0.28);
      final path = Path()..moveTo(0, baseY);
      for (var x = 0.0; x <= size.width; x += 8) {
        path.lineTo(
          x,
          baseY + math.sin(x / size.width * math.pi * 2 + i * 1.4) * 14,
        );
      }
      path.lineTo(size.width, baseY + 26);
      path.lineTo(0, baseY + 26);
      path.close();
      canvas.drawPath(path, p);
    }
  }

  /// Lavender Mist: large soft radial blobs.
  void _mist(Canvas canvas, Size size) {
    void blob(double cx, double cy, double r) {
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.20),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );
    }

    blob(size.width * 0.15, size.height * 0.25, 90);
    blob(size.width * 0.85, size.height * 0.75, 110);
    blob(size.width * 0.55, size.height * 0.45, 70);
  }

  /// Blush Rose: scattered petals (rotated ellipses).
  void _petals(Canvas canvas, Size size) {
    final p = _paint(0.14);
    final rnd = math.Random(7);
    for (var i = 0; i < 12; i++) {
      final cx = rnd.nextDouble() * size.width;
      final cy = rnd.nextDouble() * size.height;
      final w = 10 + rnd.nextDouble() * 14;
      final h = w * 0.55;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rnd.nextDouble() * math.pi);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: h), p);
      canvas.restore();
    }
  }

  /// Honey Glow: warm sun glow top-right with soft rays.
  void _glow(Canvas canvas, Size size) {
    final cx = size.width * 0.88;
    final cy = size.height * 0.12;
    canvas.drawCircle(
      Offset(cx, cy),
      110,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: 110)),
    );
    final p = _paint(0.10);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.8), 18, p);
    canvas.drawCircle(Offset(size.width * 0.30, size.height * 0.92), 12, p);
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.18), 10, p);
  }

  /// Emerald Heal: simple leaf sprigs in the corners.
  void _leaves(Canvas canvas, Size size) {
    final p = _paint(0.13);
    void leaf(double cx, double cy, double len, double angle) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.5, -len * 0.45, len, 0)
        ..quadraticBezierTo(len * 0.5, len * 0.45, 0, 0)
        ..close();
      canvas.drawPath(path, p);
      canvas.restore();
    }

    leaf(size.width * 0.06, size.height * 0.75, 44, -0.5);
    leaf(size.width * 0.10, size.height * 0.88, 34, -0.9);
    leaf(size.width * 0.94, size.height * 0.30, 44, 2.4);
    leaf(size.width * 0.90, size.height * 0.16, 34, 2.8);
    leaf(size.width * 0.50, size.height * 0.95, 40, 0.2);
  }
}

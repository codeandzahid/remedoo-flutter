import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Admin analytics: user growth chart, top specialties, top medicines.
class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
  static const _users = [120.0, 210.0, 340.0, 520.0, 780.0, 1050.0];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final specCount = <String, int>{};
    for (final d in doctors) {
      specCount[d.specialty] = (specCount[d.specialty] ?? 0) + 1;
    }
    final topSpecs = specCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topMeds = medicines.take(6).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const RSectionHeader(
            title: 'User Growth',
            subtitle: 'New signups per month'),
        const SizedBox(height: 12),
        RCard(
          child: SizedBox(
            height: 200,
            child: CustomPaint(
              painter: _GrowthPainter(
                  _months, _users, RemedooTheme.purple),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const RSectionHeader(
            title: 'Top Specialties',
            subtitle: 'Doctor count per specialty'),
        const SizedBox(height: 12),
        ...topSpecs.take(6).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: ListTile(
                  leading: _tile(context, Icons.medical_services,
                      scheme.primary),
                  title: Text(e.key,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  trailing: Text('${e.value} doctors',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                ),
              ),
            )),
        const SizedBox(height: 24),
        const RSectionHeader(
            title: 'Top Medicines',
            subtitle: 'Best-selling catalog items'),
        const SizedBox(height: 12),
        ...topMeds.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: ListTile(
                  leading: _tile(context, Icons.medication,
                      RemedooTheme.teal),
                  title: Text(m.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(m.category),
                  trailing: Text(inr(m.price),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                ),
              ),
            )),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: dark
            ? color.withValues(alpha: 0.18)
            : Color.lerp(color, Colors.white, 0.85),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _GrowthPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final Color color;

  _GrowthPainter(this.labels, this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y =
          size.height - 24 - (size.height - 40) * values[i] / maxV;
      pts.add(Offset(x, y));
    }
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = color;
    for (final p in pts) {
      canvas.drawCircle(p, 4, dot);
    }
    for (var i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: const TextStyle(
                fontSize: 11, color: Colors.grey)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset(pts[i].dx - tp.width / 2,
              size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}

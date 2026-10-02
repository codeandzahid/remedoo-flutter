import 'package:flutter/material.dart';

import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// My Analytics: stat cards, monthly activity bar chart, top categories.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static const _months = [
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct'
  ];
  static const _values = [3.0, 5.0, 4.0, 7.0, 6.0, 8.0];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final spent = state.orders.fold<double>(
        0, (s, o) => s + o.total);
    final stats = [
      (
        '${state.appointments.length}',
        'Appointments',
        Icons.calendar_month_outlined,
        scheme.primary
      ),
      (
        '${state.upcoming.length}',
        'Upcoming',
        Icons.upcoming_outlined,
        RemedooTheme.success
      ),
      (
        '${state.orders.length}',
        'Orders',
        Icons.shopping_bag_outlined,
        RemedooTheme.warning
      ),
      ('0', 'Emergencies', Icons.sos_outlined,
          RemedooTheme.emergency),
      (
        '${state.favorites.length}',
        'Favorites',
        Icons.favorite_outline,
        RemedooTheme.emergency
      ),
      (
        inr(spent),
        'Total Spent',
        Icons.currency_rupee,
        scheme.primary
      ),
    ];
    final categories = [
      ('Doctor Visits', state.appointments.length,
          Icons.person_search),
      ('Medicines', state.orders.length, Icons.medication),
      ('Lab Tests', state.reports.length, Icons.science),
      ('Emergency', 0, Icons.sos),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding:
                const EdgeInsets.fromLTRB(12, 8, 20, 20),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white),
                  onPressed: () =>
                      Navigator.maybePop(context),
                ),
                const SizedBox(width: 4),
                const Text('Analytics',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Expanded(
            child: MaxWidthBox(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    20, 16, 20, 24),
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: stats.length,
                    itemBuilder: (_, i) {
                      final (value, label, icon, color) =
                          stats[i];
                      return StaggerItem(
                        index: i % 6,
                        child: RCard(
                          padding:
                              const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color.withValues(
                                      alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(
                                          11),
                                ),
                                child: Icon(icon,
                                    color: color, size: 19),
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(value,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.w800)),
                              ),
                              Text(label,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme
                                          .onSurfaceVariant)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Appointments by Month',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  RCard(
                    child: SizedBox(
                      height: 200,
                      child: CustomPaint(
                        painter: _BarChartPainter(
                            _months, _values, scheme),
                        child: Container(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Top Categories',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...categories.asMap().entries.map((e) {
                    final (label, count, icon) = e.value;
                    return StaggerItem(
                      index: e.key % 6,
                      child: Container(
                        margin: const EdgeInsets.only(
                            bottom: 8),
                        child: RCard(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: RemedooTheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                ),
                                child: Icon(icon,
                                    color:
                                        RemedooTheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(label,
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w700)),
                              ),
                              Text('$count',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight:
                                          FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final ColorScheme scheme;

  _BarChartPainter(this.labels, this.values, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final n = values.length;
    final slot = size.width / n;
    final barW = slot * 0.5;
    final paint = Paint()
      ..color = RemedooTheme.primary
      ..style = PaintingStyle.fill;
    final grid = Paint()
      ..color = scheme.surfaceContainerHighest
      ..strokeWidth = 1;
    final textColor = scheme.onSurfaceVariant;
    for (var g = 0; g <= 4; g++) {
      final y = size.height - 24 - (size.height - 40) * g / 4;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 0; i < n; i++) {
      final h = (size.height - 40) * values[i] / maxV;
      final x = slot * i + (slot - barW) / 2;
      final y = size.height - 24 - h;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, h),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, paint);
      final tp = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: TextStyle(
                fontSize: 11, color: textColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset(slot * i + (slot - tp.width) / 2,
              size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}

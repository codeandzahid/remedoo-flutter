import 'package:flutter/material.dart';

import '../../responsive/animations.dart';
import '../../responsive/responsive.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Admin overview with real data: stats, order pipeline, recent activity.
///
/// Layout redesigned 2026-10-18 to the owner's Dribbble pick
/// (Cognify): header with a black "+ New" pill, stat cards with
/// solid candy-colored circle icons + arrow chips, a charts row
/// (donut / bars / progress), and an activity row (week line
/// chart / recent activity). All numbers are live Remedoo data.
class AdminDashboardScreen extends StatefulWidget {
  /// Called with the nav index when a management card is tapped.
  final void Function(int index)? onNavigate;

  const AdminDashboardScreen({super.key, this.onNavigate});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

// Cognify palette (the owner's Dribbble pick).
const _cBlue = Color(0xFF0E3EFE);
const _cPink = Color(0xFFFD1A54);
const _cGreen = Color(0xFF5D8E5E);
const _cLav = Color(0xFF8A7CA8);
const _cBlack = Color(0xFF141414);
const _cGreyBg = Color(0xFFEEF0F2);

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    await Future.wait([
      state.loadAllProfiles(),
      state.loadAdminTable('doctors'),
      state.loadAdminAppointments(),
      state.loadAdminOrders(),
      state.loadAdminProviderApplications(),
      state.loadEmergencyRequests(),
      state.loadSupportTickets(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (_loading) {
      return const RLoading();
    }

    final revenue = state.adminOrders.fold<double>(
        0, (s, o) => s + ((o['total'] as num?)?.toDouble() ?? 0));
    final byStatus = <String, int>{};
    for (final o in state.adminOrders) {
      final st = '${o['status'] ?? 'placed'}';
      byStatus[st] = (byStatus[st] ?? 0) + 1;
    }
    final pendingApprovals = state.adminProviderApplications
        .where((a) => '${a['status']}' == 'pending')
        .length;
    final activeEmergencies = state.emergencyRequests
        .where((a) =>
            '${a['status']}' != 'resolved' &&
            '${a['status']}' != 'dispatched')
        .length;
    final pendingQueries = state.supportTickets
        .where((t) =>
            '${t['status'] ?? 'open'}' == 'open' ||
            '${t['status'] ?? 'open'}' == 'opened')
        .length;

    // Appointment status buckets for the donut (Cognify colors).
    final appts = state.adminAppointments;
    int apptCount(bool Function(String) test) => appts
        .where((a) => test('${a['status'] ?? ''}'.toLowerCase()))
        .length;
    final apptCompleted = apptCount((s) => s == 'completed');
    final apptConfirmed =
        apptCount((s) => s == 'confirmed' || s == 'approved');
    final apptPending =
        apptCount((s) => s == 'pending' || s == 'requested' || s.isEmpty);
    final apptOther = appts.length -
        apptCompleted -
        apptConfirmed -
        apptPending;
    final donutData = <String, int>{
      'Completed': apptCompleted,
      'Confirmed': apptConfirmed,
      'Pending': apptPending,
      if (apptOther > 0) 'Other': apptOther,
    };

    // Completion rates for the progress card.
    final delivered = byStatus['delivered'] ?? 0;
    final resolvedTickets = state.supportTickets
        .where((t) =>
            '${t['status']}' == 'resolved' ||
            '${t['status']}' == 'closed')
        .length;

    // This week's Mon–Fri series for the line chart.
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    bool sameDay(dynamic v, DateTime d) {
      final parsed = DateTime.tryParse('$v');
      if (parsed == null) return false;
      return parsed.year == d.year &&
          parsed.month == d.month &&
          parsed.day == d.day;
    }

    final apptSeries = <double>[];
    final orderSeries = <double>[];
    for (var i = 0; i < 5; i++) {
      final day = monday.add(Duration(days: i));
      apptSeries.add(appts
          .where((a) => sameDay(a['appointment_date'], day))
          .length
          .toDouble());
      orderSeries.add(state.adminOrders
          .where((o) => sameDay(o['created_at'], day))
          .length
          .toDouble());
    }

    // Stat cards arranged section-wise (owner order 2026-10-22),
    // in the same sections as the sidebar: Users, Orders & Care,
    // Providers, Support, Insights.
    final statGroups = <(String, List<Widget>)>[
      (
        'Users',
        [
          _stat(context, 'Total Users', '${state.allProfiles.length}',
              Icons.people, _cBlue),
          _stat(context, 'Doctors',
              '${state.adminTable('doctors').length}',
              Icons.person_search, _cGreen),
        ]
      ),
      (
        'Orders & Care',
        [
          _stat(context, 'Appointments', '${appts.length}',
              Icons.calendar_month, _cPink),
          _stat(context, 'Total Orders', '${state.adminOrders.length}',
              Icons.shopping_bag, _cLav),
          _stat(context, 'Active Emergencies', '$activeEmergencies',
              Icons.sos, _cPink),
        ]
      ),
      (
        'Providers',
        [
          _stat(context, 'Pending Approvals', '$pendingApprovals',
              Icons.approval, _cBlue),
        ]
      ),
      (
        'Support',
        [
          _stat(
              context,
              'Pending Queries',
              '$pendingQueries',
              Icons.mark_chat_unread_outlined,
              _cPink,
              onTap: () => widget.onNavigate?.call(18)),
        ]
      ),
      (
        'Insights',
        [
          _stat(context, 'Revenue', inr(revenue), Icons.currency_rupee,
              _cGreen),
        ]
      ),
    ];

    // Recent activity from real orders + appointments.
    final recent = [
      for (final o in state.adminOrders.take(3))
        _Activity(
          icon: Icons.shopping_bag,
          color: _cBlue,
          title:
              'Order ${('${o['id'] ?? ''}').length > 8 ? ('${o['id']}').substring(0, 8) : o['id']}',
          body:
              '${inr((o['total'] as num?)?.toDouble() ?? 0)} · ${o['status'] ?? 'placed'}',
        ),
      for (final a in appts.take(3))
        _Activity(
          icon: Icons.calendar_month,
          color: _cPink,
          title: 'Appointment ${a['service_type'] ?? ''}',
          body: '${a['appointment_date'] ?? ''} · ${a['status'] ?? ''}',
        ),
    ];

    final donutCard = _chartCard(
      'Appointments by Status',
      'Where bookings stand right now',
      appts.isEmpty
          ? _emptyNote('No appointments yet.')
          : Row(
              children: [
                SizedBox(
                  width: 148,
                  height: 148,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(148, 148),
                        painter: _RingPainter(donutData),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${appts.length}',
                              style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  color: _cBlack)),
                          const Text('appointments',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF8A8F98))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: donutData.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: _RingPainter.colorFor(e.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(e.key,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF3C4048))),
                            ),
                            Text('${e.value}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );

    final barsCard = _chartCard(
      'Platform Overview',
      'Live catalog and activity totals',
      _BarsChart(
        bars: [
          _Bar('Doctors',
              state.adminTable('doctors').length.toDouble(), _cGreen),
          _Bar('Appointments', appts.length.toDouble(), _cPink),
          _Bar('Orders', state.adminOrders.length.toDouble(), _cBlue),
        ],
      ),
    );

    final progressCard = _chartCard(
      'Completion Rates',
      'How much work is getting finished',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _progressRow('Appointments completed', apptCompleted,
              appts.length, _cGreen),
          const SizedBox(height: 20),
          _progressRow('Orders delivered', delivered,
              state.adminOrders.length, _cPink),
          const SizedBox(height: 20),
          _progressRow('Support resolved', resolvedTickets,
              state.supportTickets.length, _cBlue),
        ],
      ),
    );

    final lineCard = _chartCard(
      'Bookings This Week',
      'Appointments vs orders, Monday to Friday',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legendDot(_cBlue, 'Appointments'),
              const SizedBox(width: 16),
              _legendDot(_cPink, 'Orders'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: const Size(double.infinity, 150),
              painter: _LinePainter(apptSeries, orderSeries),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 5; i++)
                _dayPill(
                  const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'][i],
                  now.weekday - 1 == i,
                ),
            ],
          ),
        ],
      ),
    );

    final recentCard = _chartCard(
      'Recent Activity',
      'Latest platform events',
      recent.isEmpty
          ? _emptyNote('Orders and appointments will appear here.')
          : Column(
              children: [
                for (final n in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: n.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(n.icon, color: n.color, size: 19),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(n.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5)),
                              Text(n.body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF8A8F98))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );

    final chartsRow = LayoutBuilder(
      builder: (ctx, c) {
        if (c.maxWidth >= 1150) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: donutCard),
                const SizedBox(width: 16),
                Expanded(child: barsCard),
                const SizedBox(width: 16),
                Expanded(child: progressCard),
              ],
            ),
          );
        }
        if (c.maxWidth >= 720) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: donutCard),
                    const SizedBox(width: 16),
                    Expanded(child: barsCard),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              progressCard,
            ],
          );
        }
        return Column(
          children: [
            donutCard,
            const SizedBox(height: 16),
            barsCard,
            const SizedBox(height: 16),
            progressCard,
          ],
        );
      },
    );

    final activityRow = LayoutBuilder(
      builder: (ctx, c) {
        if (c.maxWidth >= 1150) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: lineCard),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: recentCard),
              ],
            ),
          );
        }
        return Column(
          children: [lineCard, const SizedBox(height: 16), recentCard],
        );
      },
    );

    return MaxWidthBox(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(context, now),
          const SizedBox(height: 18),
          // Section-wise stat groups (same sections as the sidebar),
          // each with its heading and its own card grid.
          for (final (title, cards) in statGroups) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF8A8F98)),
              ),
            ),
            ResponsiveGrid(
              compactCols: 2,
              mediumCols: 3,
              expandedCols: 4,
              wideCols: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              itemCount: cards.length,
              itemBuilder: (_, i) =>
                  StaggerItem(index: i % 6, child: cards[i]),
            ),
            const SizedBox(height: 16),
          ],
          chartsRow,
          const SizedBox(height: 16),
          activityRow,
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Cognify header: big bold title + grey date line on the left,
  /// black "+ New" pill (with a quick-actions menu) on the right.
  Widget _header(BuildContext context, DateTime now) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    final dateLine =
        '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dashboard',
                  style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: _cBlack)),
              const SizedBox(height: 3),
              Text(dateLine,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF8A8F98))),
            ],
          ),
        ),
        if (widget.onNavigate != null)
          PopupMenuButton<int>(
            tooltip: 'Quick add',
            onSelected: (i) => widget.onNavigate?.call(i),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 1, child: Text('Add Doctor')),
              PopupMenuItem(value: 7, child: Text('Add Medicine')),
              PopupMenuItem(
                  value: 20, child: Text('Send Announcement')),
            ],
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: _cBlack,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 17),
                  SizedBox(width: 5),
                  Text('New',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// A Cognify chart card: small bold title + grey subtitle, then
  /// the chart content. Rendered on an RCard (white in Remidy).
  Widget _chartCard(String title, String subtitle, Widget content) {
    return RCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: _cBlack)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF8A8F98))),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _emptyNote(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(text,
          style:
              const TextStyle(color: Color(0xFF8A8F98), fontSize: 13)),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3C4048))),
      ],
    );
  }

  Widget _dayPill(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: active ? _cBlack : _cGreyBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFF3C4048))),
    );
  }

  Widget _progressRow(String label, int done, int total, Color color) {
    final value = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C4048))),
            ),
            Text('${(value * 100).round()}%',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            backgroundColor: _cGreyBg,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 5),
        Text('$done of $total',
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF8A8F98))),
      ],
    );
  }

  /// Cognify stat card: solid colored circle icon + ↗ chip on
  /// top, big bold number, grey label.
  Widget _stat(BuildContext context, String label, String value,
      IconData icon, Color color,
      {VoidCallback? onTap}) {
    final card = RCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: _cGreyBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.north_east,
                    size: 15, color: _cBlack),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: _cBlack)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF8A8F98), fontSize: 12.5)),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

class _Activity {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  _Activity({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

class _Bar {
  final String label;
  final double value;
  final Color color;
  const _Bar(this.label, this.value, this.color);
}

/// Cognify-style bar chart: three chunky rounded columns, solid
/// top with a lighter base segment, value on top, label below.
class _BarsChart extends StatelessWidget {
  final List<_Bar> bars;
  const _BarsChart({required this.bars});

  @override
  Widget build(BuildContext context) {
    final maxV =
        bars.fold<double>(0, (m, b) => b.value > m ? b.value : m);
    return SizedBox(
      height: 196,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in bars)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${b.value.round()}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  Container(
                    width: 56,
                    height: maxV == 0
                        ? 26
                        : 26 + (b.value / maxV) * 104,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Container(
                            decoration: BoxDecoration(
                              color: b.color,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15)),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: b.color.withValues(alpha: 0.30),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(15)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(b.label,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8A8F98))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ring (donut) painter for appointment statuses, Cognify colors.
class _RingPainter extends CustomPainter {
  final Map<String, int> data;

  _RingPainter(this.data);

  static Color colorFor(String key) {
    switch (key) {
      case 'Completed':
        return _cGreen;
      case 'Confirmed':
        return _cBlue;
      case 'Pending':
        return _cPink;
      default:
        return const Color(0xFFC3B9D0);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold<int>(0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 11;
    final bgPaint = Paint()
      ..color = _cGreyBg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 21;
    canvas.drawCircle(center, radius, bgPaint);
    if (total == 0) return;
    var start = -3.14159 / 2;
    for (final e in data.entries) {
      if (e.value == 0) continue;
      final sweep = 2 * 3.14159 * e.value / total;
      final paint = Paint()
        ..color = colorFor(e.key)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 21
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + 0.03,
        sweep - 0.06,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Smooth two-series line painter (appointments blue, orders pink).
class _LinePainter extends CustomPainter {
  final List<double> a;
  final List<double> b;

  _LinePainter(this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = [
      ...a,
      ...b,
      1.0,
    ].fold<double>(0, (m, v) => v > m ? v : m);
    final gridPaint = Paint()
      ..color = const Color(0xFFE8EAED)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    _drawSeries(canvas, size, a, _cBlue, maxV, true);
    _drawSeries(canvas, size, b, _cPink, maxV, false);
  }

  void _drawSeries(Canvas canvas, Size size, List<double> series,
      Color color, double maxV, bool fill) {
    if (series.isEmpty) return;
    final dx = size.width / (series.length - 1);
    final points = <Offset>[
      for (var i = 0; i < series.length; i++)
        Offset(
          i * dx,
          size.height - 8 - (series[i] / maxV) * (size.height - 24),
        ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
          fillPath, Paint()..color = color.withValues(alpha: 0.07));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final p in points) {
      canvas.drawCircle(p, 3.4, Paint()..color = color);
      canvas.drawCircle(p, 3.4,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

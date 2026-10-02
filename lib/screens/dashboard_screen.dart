import 'dart:async';

import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../widgets/patient_sidebar.dart';
import 'doctors_screen.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'hospitals_screen.dart';
import 'labs_screen.dart';
import 'pharmacies_screen.dart';
import 'orders_screen.dart';
import 'appointments_screen.dart';
import 'emergency_screen.dart';
import 'favorites_screen.dart';
import 'lab_reports_screen.dart';
import 'medical_history_screen.dart';
import 'notifications_screen.dart';
import 'care_match_screen.dart';

/// Home tab: orange hero header (menu / Remedoo / bell, greeting, translucent
/// search, Smart Care Finder), service grid, promo carousel, feature trio,
/// stats, and listing rails — matching the React dashboard.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _promoCtrl = PageController();
  Timer? _promoTimer;
  int _promoPage = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _loading = false);
    });
    // Auto-advance the promo carousel like the React app (every 3.5s).
    _promoTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (!mounted || !_promoCtrl.hasClients || _promos.length < 2) return;
      final next = (_promoPage + 1) % _promos.length;
      _promoCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _promoCtrl.dispose();
    super.dispose();
  }

  void _go(Widget page) {
    pushPage(context, page);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final upcoming =
        state.appointments.where((a) => a.status == 'upcoming').take(2).toList();
    final popularDoctors = state.activeDoctors.take(8).toList();
    final popularHospitals = state.activeHospitals.take(6).toList();
    final popularMeds = state.activeMedicines.take(8).toList();

    return Scaffold(
      drawer: _drawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _heroHeader(state)),
              if (_loading)
                SliverToBoxAdapter(child: _skeletonBody())
              else
                SliverToBoxAdapter(
                  child: MaxWidthBox(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StaggerItem(index: 0, child: _categories()),
                          const SizedBox(height: 20),
                          StaggerItem(index: 1, child: _promoCarousel()),
                          const SizedBox(height: 20),
                          StaggerItem(index: 2, child: _featureTrio()),
                          const SizedBox(height: 20),
                          StaggerItem(index: 3, child: _statsRow(state)),
                          const SizedBox(height: 22),
                          StaggerItem(
                            index: 4,
                            child: RSectionHeader(
                              title: 'Upcoming Appointments',
                              onSeeAll: upcoming.isNotEmpty
                                  ? () => _go(const AppointmentsScreen())
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          StaggerItem(
                            index: 5,
                            child: upcoming.isEmpty
                                ? _emptyAppointments()
                                : Column(
                                    children:
                                        upcoming.map(_appointmentCard).toList(),
                                  ),
                          ),
                          const SizedBox(height: 22),
                          StaggerItem(
                            index: 6,
                            child: RSectionHeader(
                              title: 'Popular Doctors',
                              onSeeAll: () => _go(const DoctorsScreen()),
                            ),
                          ),
                          const SizedBox(height: 10),
                          StaggerItem(
                              index: 7, child: _doctorRail(popularDoctors)),
                          const SizedBox(height: 22),
                          StaggerItem(
                            index: 8,
                            child: RSectionHeader(
                              title: 'Popular Hospitals',
                              onSeeAll: () => _go(const HospitalsScreen()),
                            ),
                          ),
                          const SizedBox(height: 10),
                          StaggerItem(
                              index: 9, child: _hospitalRail(popularHospitals)),
                          const SizedBox(height: 22),
                          StaggerItem(
                            index: 10,
                            child: RSectionHeader(
                              title: 'Popular Medicines',
                              onSeeAll: () => _go(const PharmaciesScreen()),
                            ),
                          ),
                          const SizedBox(height: 10),
                          StaggerItem(
                              index: 11,
                              child: _medicineGrid(popularMeds, state)),
                          const SizedBox(height: 22),
                          StaggerItem(
                            index: 12,
                            child: RSectionHeader(
                              title: 'Pharmacy Benefits',
                              onSeeAll: () => _go(const PharmaciesScreen()),
                            ),
                          ),
                          const SizedBox(height: 10),
                          StaggerItem(index: 13, child: _pharmacyBenefits()),
                          const SizedBox(height: 22),
                          const StaggerItem(
                              index: 14,
                              child: RSectionHeader(title: 'Explore More')),
                          const SizedBox(height: 10),
                          StaggerItem(index: 15, child: _exploreMore()),
                          const SizedBox(height: 22),
                          const StaggerItem(
                              index: 16,
                              child: RSectionHeader(title: 'Browse Services')),
                          const SizedBox(height: 10),
                          StaggerItem(index: 17, child: _browseServices()),
                          const SizedBox(height: 22),
                          const StaggerItem(
                              index: 18,
                              child: RSectionHeader(title: 'Health Tips')),
                          const SizedBox(height: 10),
                          StaggerItem(index: 19, child: _healthTips()),
                          const SizedBox(height: 22),
                          const StaggerItem(
                              index: 20, child: RSectionHeader(title: 'Sponsored')),
                          const SizedBox(height: 10),
                          StaggerItem(index: 21, child: _sponsored()),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Orange hero header: menu / Remedoo / bell, greeting, translucent search,
  /// Smart Care Finder. Rounded bottom via RGradientHeader.
  Widget _heroHeader(AppState state) {
    return RGradientHeader(
      child: MaxWidthBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Builder(
                  builder: (drawerContext) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    tooltip: 'Menu',
                    // NOTE: must use the Builder's context (inside this
                    // screen's own Scaffold) — the State's context resolves
                    // to the outer ResponsiveScaffold, which has no drawer.
                    onPressed: () =>
                        Scaffold.of(drawerContext).openDrawer(),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Remedoo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: Badge(
                    isLabelVisible: state.unreadNotifications > 0,
                    label: Text('${state.unreadNotifications}'),
                    child: const Icon(Icons.notifications_outlined,
                        color: Colors.white),
                  ),
                  tooltip: 'Notifications',
                  onPressed: () => _go(const NotificationsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Hello,',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${state.displayName} 👋',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _translucentSearch(),
            const SizedBox(height: 12),
            _careFinderCard(),
          ],
        ),
      ),
    );
  }

  /// Translucent white rounded-full search bar (read-only, opens search).
  Widget _translucentSearch() {
    return GestureDetector(
      onTap: () => _go(const DoctorsScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(Icons.search,
                color: Colors.white.withValues(alpha: 0.9), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search doctors, hospitals, labs, medicines...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Translucent Smart Care Finder card.
  Widget _careFinderCard() {
    return InkWell(
      onTap: () => _go(const CareMatchScreen()),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Smart Care Finder',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Describe symptoms, get matched doctors, hospitals & labs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Phone drawer: the React AppSidebar — gradient Close button, Quick Actions
  /// gradient tile grid, and the Navigate section. Tapping any item closes
  /// the drawer first, then navigates (matching the React behavior).
  Widget _drawer() {
    return Drawer(
      child: RPatientSidebar(
        activeRoute: 'home',
        onClose: () => Navigator.pop(context),
        onPush: (page) => pushPage(context, page),
      ),
    );
  }

  /// Skeleton placeholders shown while the dashboard "loads".
  Widget _skeletonBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              SkeletonBox(width: 58, height: 58, radius: 18),
              SkeletonBox(width: 58, height: 58, radius: 18),
              SkeletonBox(width: 58, height: 58, radius: 18),
              SkeletonBox(width: 58, height: 58, radius: 18),
            ],
          ),
          const SizedBox(height: 18),
          const SkeletonBox(height: 148, radius: 20),
          const SizedBox(height: 18),
          const SkeletonCard(),
          const SizedBox(height: 12),
          const SkeletonCard(),
          const SizedBox(height: 12),
          const SkeletonCard(),
        ],
      ),
    );
  }

  /// 8 pastel service tiles (4 columns on phones).
  Widget _categories() {
    final tiles = RemedooTheme.serviceTileColors;
    final items = [
      ('Doctors', Icons.medical_services, 0, () => _go(const DoctorsScreen())),
      ('Hospitals', Icons.local_hospital, 1, () => _go(const HospitalsScreen())),
      ('Labs', Icons.science, 2, () => _go(const LabsScreen())),
      ('Pharmacy', Icons.storefront, 3, () => _go(const PharmaciesScreen())),
      ('Emergency', Icons.sos, 4, () => _go(const EmergencyScreen())),
      ('Favorites', Icons.favorite, 5, () => _go(const FavoritesScreen())),
      ('Orders', Icons.shopping_bag, 6, () => _go(const OrdersScreen())),
      ('Reports', Icons.description, 7, () => _go(const LabReportsScreen())),
    ];
    return ResponsiveGrid(
      compactCols: 4,
      mediumCols: 6,
      expandedCols: 8,
      wideCols: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 8,
      childAspectRatio: 0.80,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (label, icon, c, onTap) = items[i];
        return RServiceTile(
          icon: icon,
          label: label,
          tileColor: tiles[c][0],
          iconColor: tiles[c][1],
          onTap: onTap,
        );
      },
    );
  }

  List<({String title, String subtitle, Gradient gradient, String emoji})>
      get _promos => [
            (
              title: 'Flat 30% OFF',
              subtitle: 'on first doctor consultation',
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF7E57E8), Color(0xFF8B45B8)],
              ),
              emoji: '🩺',
            ),
            (
              title: 'Free Delivery',
              subtitle: 'on medicine orders above ₹199',
              gradient: RemedooTheme.promoTealGradient,
              emoji: '💊',
            ),
            (
              title: 'Health Packages',
              subtitle: 'starting at ₹299 only',
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF28A0DC), Color(0xFF267FEB)],
              ),
              emoji: '🧪',
            ),
            (
              title: 'Emergency SOS',
              subtitle: 'ambulance in under 10 mins',
              gradient: RemedooTheme.promoEmergencyGradient,
              emoji: '🚑',
            ),
          ];

  /// Auto-advancing promo carousel with dot indicators.
  Widget _promoCarousel() {
    return SizedBox(
      height: 148,
      child: PageView.builder(
        controller: _promoCtrl,
        itemCount: _promos.length,
        onPageChanged: (i) => setState(() => _promoPage = i),
        itemBuilder: (_, i) {
          final p = _promos[i];
          return RPromoBanner(
            gradient: p.gradient,
            title: p.title,
            subtitle: p.subtitle,
            illustration:
                Text(p.emoji, style: const TextStyle(fontSize: 54)),
            pageCount: _promos.length,
            pageIndex: _promoPage,
          );
        },
      ),
    );
  }

  /// Three gradient "image" promo cards (Find Expert Doctors / Nearby
  /// Hospitals / Lab Tests at Home) — horizontal scroll on phones.
  Widget _featureTrio() {
    final cards = [
      (
        'Find Expert Doctors',
        'Book appointments with top specialists',
        '👨‍⚕️',
        const [Color(0xFF06B6D4), Color(0xFF0284C7)],
        () => _go(const DoctorsScreen()),
      ),
      (
        'Nearby Hospitals',
        'Find the best healthcare facilities',
        '🏥',
        const [Color(0xFF10B981), Color(0xFF059669)],
        () => _go(const HospitalsScreen()),
      ),
      (
        'Lab Tests at Home',
        'Convenient diagnostic testing',
        '🔬',
        const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        () => _go(const LabsScreen()),
      ),
    ];

    Widget card(
        (String, String, String, List<Color>, VoidCallback) c, double? width) {
      return InkWell(
        onTap: c.$5,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: width,
          height: 132,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: c.$4,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: Text(c.$3, style: const TextStyle(fontSize: 50)),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                right: 56,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (context.isCompact) {
      return SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => card(cards[i], 208),
        ),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: card(cards[i], null)),
        ],
      ],
    );
  }

  /// Live status strip: 4 mini tiles with pastel icon, bold count, gray label.
  Widget _statsRow(AppState state) {
    final scheme = Theme.of(context).colorScheme;
    final tiles = RemedooTheme.serviceTileColors;
    final items = [
      ('Appointments', '${state.appointments.length}', Icons.calendar_month,
          tiles[3], () => _go(const AppointmentsScreen())),
      ('Active Orders', '${state.activeOrders.length}', Icons.shopping_bag,
          tiles[1], () => _go(const OrdersScreen())),
      ('Prescriptions', '${state.prescriptions.length}', Icons.description,
          tiles[2], () => _go(const MedicalHistoryScreen())),
      ('Reports', '${state.reports.length}', Icons.science, tiles[0],
          () => _go(const LabReportsScreen())),
    ];
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (label, value, icon, colors, onTap) = items[i];
          return SizedBox(
            width: 152,
            child: RCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: onTap,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors[0],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: colors[1]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

  Widget _emptyAppointments() {
    return REmptyState(
      icon: Icons.calendar_month,
      title: 'No upcoming appointments',
      subtitle: 'Book your visit today!',
      actionLabel: 'Book Now',
      onAction: () => _go(const DoctorsScreen()),
    );
  }

  Widget _appointmentCard(Appointment a) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _go(const AppointmentsScreen()),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: RemedooTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.medical_services,
                  color: RemedooTheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.doctorName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(a.specialty,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 12, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${a.dateLabel} • ${a.timeLabel}',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _doctorRail(List<Doctor> list) {
    if (!context.isCompact) {
      // Tablets and larger: adaptive grid with visible TV focus.
      return ResponsiveGrid(
        compactCols: 2,
        mediumCols: 3,
        expandedCols: 4,
        wideCols: 5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.78,
        itemCount: list.length,
        itemBuilder: (_, i) => FocusableScale(
          autofocus: i == 0,
          onTap: () => _go(DoctorDetailScreen(doctor: list[i])),
          child: _doctorCard(list[i]),
        ),
      );
    }
    return SizedBox(
      height: 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 150,
          child: _doctorCard(list[i]),
        ),
      ),
    );
  }

  Widget _doctorCard(Doctor d) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      padding: EdgeInsets.zero,
      onTap: () => _go(DoctorDetailScreen(doctor: d)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 88,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(RemedooRadius.card)),
            ),
            child: Center(child: InitialsAvatar(name: d.name, radius: 26)),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Text(d.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    RRatingPill(rating: d.rating),
                    const Spacer(),
                    Flexible(
                      child: Text(inr(d.fee),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: RemedooTheme.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hospitalRail(List<Hospital> list) {
    if (!context.isCompact) {
      return ResponsiveGrid(
        compactCols: 1,
        mediumCols: 2,
        expandedCols: 3,
        wideCols: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.9,
        itemCount: list.length,
        itemBuilder: (_, i) => _hospitalCard(list[i]),
      );
    }
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 250,
          child: _hospitalCard(list[i]),
        ),
      ),
    );
  }

  Widget _hospitalCard(Hospital h) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      padding: EdgeInsets.zero,
      onTap: () => _go(HospitalDetailScreen(hospital: h)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 104,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  RemedooTheme.primary.withValues(alpha: 0.14),
                  RemedooTheme.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(RemedooRadius.card)),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(Icons.local_hospital,
                      size: 44, color: RemedooTheme.primary),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: RRatingPill(rating: h.rating),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 12, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(h.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: scheme.onSurfaceVariant)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${h.beds} beds',
                    style: TextStyle(
                        fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicineGrid(List<Medicine> list, AppState state) {
    return ResponsiveGrid(
      compactCols: 2,
      mediumCols: 3,
      expandedCols: 4,
      wideCols: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      itemCount: list.length,
      itemBuilder: (_, i) {
        final m = list[i];
        final qty = state.cartQty(m.id);
        final discount =
            m.mrp > m.price ? ((m.mrp - m.price) / m.mrp * 100).round() : 0;
        return Stack(
          children: [
            RCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(m.pack,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                  const Spacer(),
                  Row(
                    children: [
                      Text(inr(state.priceOf(m)),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: RemedooTheme.primary)),
                      const Spacer(),
                      if (qty == 0)
                        OutlinedButton(
                          onPressed: () => _addMed(state, m),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(64, 32),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('ADD'),
                        )
                      else
                        QtyStepper(
                          qty: qty,
                          onMinus: () => state.removeFromCart(m.id),
                          onPlus: () => _addMed(state, m),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (discount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: RemedooTheme.success,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$discount% OFF',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _addMed(AppState state, Medicine m) {
    final pharmName = pharmacyById(m.pharmacyId).name;
    if (state.addToCart(m, pharmacyId: m.pharmacyId, pharmacyName: pharmName)) {
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Switch pharmacy?'),
        content: const Text(
            'Your cart has items from another pharmacy. Clear it and add this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep cart'),
          ),
          FilledButton(
            onPressed: () {
              state.clearCart();
              state.addToCart(m,
                  pharmacyId: m.pharmacyId,
                  pharmacyName: pharmacyById(m.pharmacyId).name);
              Navigator.pop(context);
            },
            child: const Text('Clear & add'),
          ),
        ],
      ),
    );
  }

  Widget _pharmacyBenefits() {
    const steps = [
      ('Upload prescription', Icons.upload_file, 'Snap & upload in seconds'),
      ('Pharmacist verifies', Icons.verified, 'Licensed review, always'),
      ('Doorstep delivery', Icons.delivery_dining, 'In under 45 minutes'),
    ];
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order in 3 Easy Steps',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...steps.map((s) {
            final (t, icon, sub) = s;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: RemedooTheme.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(icon, color: RemedooTheme.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _exploreMore() {
    final items = [
      ('Find Doctors', Icons.person_search, () => _go(const DoctorsScreen())),
      ('Ambulance Service', Icons.emergency, () => _go(const EmergencyScreen())),
      ('Medicine Delivery', Icons.delivery_dining,
          () => _go(const PharmaciesScreen())),
      ('Health Packages', Icons.health_and_safety, () => _go(const LabsScreen())),
    ];
    return ResponsiveGrid(
      compactCols: 2,
      mediumCols: 3,
      expandedCols: 4,
      wideCols: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.6,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (label, icon, onTap) = items[i];
        return RCard(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: RemedooTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: RemedooTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _browseServices() {
    final items = [
      ('Doctors', Icons.person_search, RemedooTheme.primary,
          () => _go(const DoctorsScreen())),
      ('Hospitals', Icons.local_hospital, RemedooTheme.teal,
          () => _go(const HospitalsScreen())),
      ('Labs', Icons.science, RemedooTheme.purple,
          () => _go(const LabsScreen())),
      ('Pharmacy', Icons.medication, Colors.blue,
          () => _go(const PharmaciesScreen())),
    ];
    return ResponsiveGrid(
      compactCols: 2,
      mediumCols: 3,
      expandedCols: 4,
      wideCols: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (label, icon, color, onTap) = items[i];
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 36),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _healthTips() {
    final tips = healthTips.take(4).toList();
    return Column(
      children: tips
          .map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: RemedooTheme.ratingGreen
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lightbulb_outline,
                            color: RemedooTheme.ratingGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['title']!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(t['text']!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _sponsored() {
    final sponsors = [
      ('CityCare Diagnostics', 'Flat 25% off on all lab tests', Icons.science),
      ('MediPlus Pharmacy', 'Extra 10% off on first order', Icons.medication),
      ('Smile Dental Studio', 'Free dental checkup this month', Icons.mood),
      (
        'FitLife Gym',
        '1 month free trial for Remedoo users',
        Icons.fitness_center
      ),
    ];
    return Column(
      children: sponsors
          .map((s) {
            final (name, offer, icon) = s;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(icon, color: RemedooTheme.purple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text(offer,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Text('Ad',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
            );
          })
          .toList(),
    );
  }
}

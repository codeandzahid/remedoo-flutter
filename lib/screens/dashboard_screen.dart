import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../widgets/patient_sidebar.dart';
import 'doctors_screen.dart';
import 'doctor_detail_screen.dart';
import 'hospitals_screen.dart';
import 'labs_screen.dart';
import 'pharmacies_screen.dart';
import 'orders_screen.dart';
import 'appointments_screen.dart';
import 'emergency_screen.dart';
import 'favorites_screen.dart';
import 'lab_reports_screen.dart';
import 'family_screen.dart';
import 'notifications_screen.dart';
import 'care_match_screen.dart';

/// Home tab: orange hero header (menu / Remedoo / bell, greeting, translucent
/// search), service grid, promo carousel, feature trio,
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

  /// Reference-style navigation for guests: toast + redirect to login.
  void _goGated(Widget page,
      [String message = 'Please login to access this feature']) {
    if (!checkLogin(context, message)) return;
    _go(page);
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
                          StaggerItem(index: 0, child: _illustratedBanner()),
                          const SizedBox(height: 22),
                          StaggerItem(
                            index: 1,
                            child: RSectionHeader(
                              title: 'Doctors near you',
                              onSeeAll: () => _go(const DoctorsScreen()),
                            ),
                          ),
                          const SizedBox(height: 10),
                          StaggerItem(
                              index: 2, child: _doctorCards(popularDoctors)),
                          if (state.isSignedIn) ...[
                            const SizedBox(height: 22),
                            StaggerItem(
                              index: 3,
                              child: RSectionHeader(
                                title: 'Family Health',
                                onSeeAll: () =>
                                    _goGated(const FamilyScreen()),
                              ),
                            ),
                            const SizedBox(height: 10),
                            StaggerItem(index: 4, child: _familyRow(state)),
                          ],
                          const SizedBox(height: 22),
                          const StaggerItem(
                              index: 5,
                              child: RSectionHeader(title: 'Services')),
                          const SizedBox(height: 10),
                          StaggerItem(index: 6, child: _categories()),
                          const SizedBox(height: 22),
                          StaggerItem(
                            index: 7,
                            child: RSectionHeader(
                              title: 'Upcoming Appointments',
                              onSeeAll: upcoming.isNotEmpty
                                  ? () => _go(const AppointmentsScreen())
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          StaggerItem(
                            index: 8,
                            child: upcoming.isEmpty
                                ? _emptyAppointments()
                                : Column(
                                    children:
                                        upcoming.map(_appointmentCard).toList(),
                                  ),
                          ),
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
              _greeting(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${state.displayName} 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _upcomingPill(state),
              ],
            ),
            const SizedBox(height: 12),
            _translucentSearch(),
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
      ('Favorites', Icons.favorite, 5, () => _goGated(const FavoritesScreen())),
      ('Orders', Icons.shopping_bag, 6, () => _goGated(const OrdersScreen())),
      ('Reports', Icons.description, 7, () => _goGated(const LabReportsScreen())),
      ('Smart Care', Icons.auto_awesome, 8, () => _go(const CareMatchScreen())),
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

  /// Promo banners tinted by the active theme (like the mockup artwork).
  List<({String title, String subtitle, Gradient gradient, String emoji})>
      get _promos {
    Gradient g(List<Color> c, AlignmentGeometry b, AlignmentGeometry e) =>
        LinearGradient(begin: b, end: e, colors: c);
    final p = RemedooTheme.primary;
    final pd = RemedooTheme.primaryDark;
    return [
      (
        title: 'Flat 30% OFF',
        subtitle: 'on first doctor consultation',
        gradient: g([p, pd], Alignment.centerLeft, Alignment.centerRight),
        emoji: '🩺',
      ),
      (
        title: 'Free Delivery',
        subtitle: 'on medicine orders above ₹199',
        gradient: g([pd, p], Alignment.topLeft, Alignment.bottomRight),
        emoji: '💊',
      ),
      (
        title: 'Health Packages',
        subtitle: 'starting at ₹299 only',
        gradient: g([p, pd], Alignment.topCenter, Alignment.bottomCenter),
        emoji: '🧪',
      ),
      (
        title: 'Emergency SOS',
        subtitle: 'ambulance in under 10 mins',
        gradient: g([pd, p], Alignment.centerRight, Alignment.centerLeft),
        emoji: '🚑',
      ),
    ];
  }

  /// Illustrated promo banner carousel (mockup style): theme-tinted
  /// gradient, soft decorative circles, big emoji artwork, dot indicators.
  Widget _illustratedBanner() {
    return SizedBox(
      height: 168,
      child: PageView.builder(
        controller: _promoCtrl,
        itemCount: _promos.length,
        onPageChanged: (i) => setState(() => _promoPage = i),
        itemBuilder: (_, i) {
          final p = _promos[i];
          return Container(
            decoration: BoxDecoration(
              gradient: p.gradient,
              borderRadius:
                  BorderRadius.circular(RemedooTheme.cardRadius),
              boxShadow: RemedooTheme.softShadow,
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -34,
                  top: -34,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 70,
                  bottom: -44,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              p.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.subtitle,
                              style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(p.emoji,
                          style: const TextStyle(fontSize: 64)),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 12,
                  child: Row(
                    children: List.generate(
                      _promos.length,
                      (d) => Container(
                        width: d == _promoPage ? 18 : 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                              alpha: d == _promoPage ? 0.95 : 0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Time-based greeting, mockup style ("Good evening,").
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  /// Pill showing the upcoming-appointments count (taps through to
  /// appointments, login-gated like the mockup's streak pill).
  Widget _upcomingPill(AppState state) {
    final n =
        state.appointments.where((a) => a.status == 'upcoming').length;
    return GestureDetector(
      onTap: () => _goGated(const AppointmentsScreen()),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month,
                color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              '$n Upcoming',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Initials for avatar circles ("Dr. Meera Rao" -> "MR").
  String _initials(String name) {
    final parts =
        name.replaceFirst(RegExp(r'^Dr.\s*'), '').split(' ');
    final keep = parts.where((w) => w.isNotEmpty).take(2).toList();
    if (keep.isEmpty) return '?';
    return keep.map((w) => w[0].toUpperCase()).join();
  }

  /// Three gradient "image" promo cards (Find Expert Doctors / Nearby
  /// Hospitals / Lab Tests at Home) — horizontal scroll on phones.
  Widget _emptyAppointments() {
    return REmptyState(
      icon: Icons.calendar_month,
      title: 'No upcoming appointments',
      subtitle: 'Book your visit today!',
      actionLabel: 'Book Now',
      onAction: () => _goGated(const DoctorsScreen()),
    );
  }

  Widget _appointmentCard(Appointment a) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _goGated(const AppointmentsScreen()),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: RemedooTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.medical_services,
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

  /// "Doctors near you" — mockup-style horizontal cards: circular
  /// initial avatar, name, specialty, star rating, Visit pill button.
  Widget _doctorCards(List<Doctor> list) {
    return SizedBox(
      height: 212,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 158,
          child: RDoctorCard(
            compact: true,
            doctor: list[i],
            onTap: () => _goGated(DoctorDetailScreen(doctor: list[i])),
            onVisit: () => _goGated(DoctorDetailScreen(doctor: list[i])),
          ),
        ),
      ),
    );
  }

  /// "Family Health" avatar row (mockup style). Logged-in users only.
  Widget _familyRow(AppState state) {
    final members = state.family;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: members.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemBuilder: (_, i) {
          if (i == members.length) {
            return _familyAvatar(
              '+',
              'Add',
              true,
              () => _goGated(const FamilyScreen()),
            );
          }
          final m = members[i];
          return _familyAvatar(
            _initials(m.name),
            m.name.split(' ').first,
            false,
            () => _goGated(const FamilyScreen()),
          );
        },
      ),
    );
  }

  Widget _familyAvatar(
      String label, String name, bool isAdd, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isAdd
                  ? scheme.surfaceContainerHighest
                  : RemedooTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: isAdd
                    ? scheme.outlineVariant
                    : RemedooTheme.primary.withValues(alpha: 0.30),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isAdd ? 26 : 20,
                  fontWeight: FontWeight.w800,
                  color: isAdd
                      ? scheme.onSurfaceVariant
                      : RemedooTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

}

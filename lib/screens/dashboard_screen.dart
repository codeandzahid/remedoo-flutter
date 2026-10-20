import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../widgets/upi_setup_dialog.dart';
import '../widgets/patient_sidebar.dart';
import 'doctors_screen.dart';
import 'doctor_detail_screen.dart';
import 'hospitals_screen.dart';
import 'labs_screen.dart';
import 'orders_screen.dart';
import 'appointments_screen.dart';
import 'cart_screen.dart';
import 'emergency_screen.dart';
import 'favorites_screen.dart';
import 'lab_reports_screen.dart';
import 'family_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'care_match_screen.dart';
import 'remedoo_checkout_screen.dart';
import 'remedoo_pharmacy_screen.dart';
import 'medical_history_screen.dart';
import 'reminders_screen.dart';
import 'search_screen.dart';
import 'vitals_screen.dart';

/// Home tab: orange hero header (menu / Remedoo / bell, greeting, translucent
/// search), dense service grid, compact promo carousel,
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
    // Show UPI setup popup for verified providers who haven't set it up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppStateScope.of(context);
      if (state.shouldShowUpiSetup) {
        showUpiSetupDialog(context);
      }
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
    final upcoming = state.appointments
        .where((a) => a.status == 'upcoming')
        .take(3)
        .toList();
    final nextAppt = upcoming.firstOrNull;
    final popularDoctors = state.activeDoctors.take(8).toList();

    return Scaffold(
      drawer: _drawer(),
      onDrawerChanged: (open) => state.drawerOpen = open,
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
                          // Admin announcements (Content > Announcements).
                          if (state.latestAnnouncements.isNotEmpty)
                            StaggerItem(
                              index: 0,
                              child:
                                  _announcementBanner(state),
                            ),
                          if (state.latestAnnouncements.isNotEmpty)
                            const SizedBox(height: 14),
                          if (nextAppt != null) ...[
                            StaggerItem(
                                index: 1,
                                child: _nextAppointmentCard(nextAppt)),
                            const SizedBox(height: 14),
                          ],
                          StaggerItem(index: 1, child: _statRow(state)),
                          const SizedBox(height: 14),
                          StaggerItem(index: 2, child: _categories()),
                          const SizedBox(height: 14),
                          StaggerItem(index: 3, child: _illustratedBanner()),
                          _profileCompletion(state),
                          const SizedBox(height: 14),
                          StaggerItem(index: 4, child: _weekStrip(state)),
                          _alertsStack(state),
                          const SizedBox(height: 14),
                          if (state.isSignedIn) ...[
                            _healthNumbersCard(state),
                            const SizedBox(height: 14),
                          ],
                          StaggerItem(
                            index: 5,
                            child: RSectionHeader(
                              title: 'Doctors near you',
                              onSeeAll: () => _go(const DoctorsScreen()),
                            ),
                          ),
                          const SizedBox(height: 8),
                          StaggerItem(
                              index: 6, child: _doctorRows(popularDoctors)),
                          if (state.isSignedIn) ...[
                            const SizedBox(height: 14),
                            StaggerItem(
                              index: 7,
                              child: RSectionHeader(
                                title: 'Family Health',
                                onSeeAll: () =>
                                    _goGated(const FamilyScreen()),
                              ),
                            ),
                            const SizedBox(height: 8),
                            StaggerItem(index: 8, child: _familyRow(state)),
                          ],
                          // The next appointment already has its own
                          // card at the top; this section lists the rest,
                          // or the empty state when there are none.
                          if (upcoming.length > 1) ...[
                            const SizedBox(height: 14),
                            StaggerItem(
                              index: 9,
                              child: RSectionHeader(
                                title: 'Upcoming Appointments',
                                onSeeAll: () =>
                                    _go(const AppointmentsScreen()),
                              ),
                            ),
                            const SizedBox(height: 8),
                            StaggerItem(
                              index: 10,
                              child: Column(
                                children: upcoming
                                    .skip(1)
                                    .map(_appointmentCard)
                                    .toList(),
                              ),
                            ),
                          ] else if (upcoming.isEmpty) ...[
                            const SizedBox(height: 14),
                            StaggerItem(
                              index: 9,
                              child: const RSectionHeader(
                                title: 'Upcoming Appointments',
                              ),
                            ),
                            const SizedBox(height: 8),
                            StaggerItem(
                                index: 10, child: _emptyAppointments()),
                          ],
                          _recentUpdates(state),
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

  /// Light Remidy header: (phone) white-circle menu button, greeting +
  /// name in dark ink, upcoming pill, white-circle bell, then a white
  /// pill search bar — no colour slab.
  Widget _heroHeader(AppState state) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: MaxWidthBox(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
          child: Column(
            children: [
              Row(
                children: [
                  // Menu button at EVERY width: the drawer holds Settings
                  // and Log Out, which must stay reachable on desktop too
                  // (live QA 2026-10-19: desktop patients could not log
                  // out at all when this was compact-only).
                  Builder(
                    builder: (drawerContext) => Container(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: RemedooTheme.softShadow,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.menu, color: scheme.onSurface),
                        tooltip: 'Menu',
                        // NOTE: must use the Builder's context (inside
                        // this screen's own Scaffold) — the outer
                        // context resolves to a shell with no drawer.
                        onPressed: () =>
                            Scaffold.of(drawerContext).openDrawer(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${state.displayName} 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _dateLine(),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Primary header action (Cognify's black pill).
                  GestureDetector(
                    onTap: () => _goGated(const DoctorsScreen()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Book',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: RemedooTheme.softShadow,
                    ),
                    child: IconButton(
                      icon: Badge(
                        isLabelVisible: state.unreadNotifications > 0,
                        label: Text('${state.unreadNotifications}'),
                        child: Icon(Icons.notifications_outlined,
                            color: scheme.onSurface),
                      ),
                      tooltip: 'Notifications',
                      onPressed: () => _go(const NotificationsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _searchPill(),
            ],
          ),
        ),
      ),
    );
  }

  /// White pill search bar (read-only, opens search).
  Widget _searchPill() {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _go(const SearchScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: RemedooTheme.softShadow,
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: scheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search doctors, medicines, tests...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
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
          const SizedBox(height: 14),
          const SkeletonBox(height: 148, radius: 20),
          const SizedBox(height: 14),
          const SkeletonCard(),
          const SizedBox(height: 12),
          const SkeletonCard(),
          const SizedBox(height: 12),
          const SkeletonCard(),
        ],
      ),
    );
  }

  /// Dense service grid: 9 tiles — only what isn't already covered
  /// by the nav bars, the stat cards, or the sections on this page
  /// (owner cleanup 2026-10-19: Doctors/Orders/Appointments/Family/
  /// Pharmacy/Support tiles removed as duplicates).
  Widget _categories() {
    final tiles = RemedooTheme.serviceTileColors;
    final items = [
      ('Hospitals', Icons.local_hospital, 1,
          () => _go(const HospitalsScreen())),
      ('Labs', Icons.science, 2, () => _go(const LabsScreen())),
      ('Medicines', Icons.medication, 4,
          () => _go(const RemedooPharmacyScreen())),
      ('Emergency', Icons.sos, 5, () => _go(const EmergencyScreen())),
      ('Smart Care', Icons.auto_awesome, 6,
          () => _go(const CareMatchScreen())),
      ('Reminders', Icons.notifications, 10,
          () => _goGated(const RemindersScreen())),
      ('Favorites', Icons.favorite, 11,
          () => _goGated(const FavoritesScreen())),
      ('Reports', Icons.description, 12,
          () => _goGated(const LabReportsScreen())),
      ('History', Icons.history, 13,
          () => _goGated(const MedicalHistoryScreen())),
    ];
    // Responsive column count + fixed row height (mainAxisExtent): the
    // tile content is 50px icon + label (~71px total), so rows stay tight
    // on every screen width instead of stretching into giant tap targets.
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w < 480 ? 5 : (w < 900 ? 7 : 8);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 4,
            mainAxisExtent: 78,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final (label, icon, c, onTap) = items[i];
            return _denseTile(
              icon: icon,
              label: label,
              tileColor: tiles[c][0],
              iconColor: tiles[c][1],
              onTap: onTap,
            );
          },
        );
      },
    );
  }

  /// Compact service tile for the dense grid. Remidy style: the
  /// icon sits in a SOLID candy-coloured circle with a white glyph
  /// (the tile's strong colour becomes the circle).
  Widget _denseTile({
    required IconData icon,
    required String label,
    required Color tileColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Promo banners tinted by the active theme (like the mockup artwork).
  List<({String title, String subtitle, Gradient gradient, IconData icon})>
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
        icon: Icons.medical_services,
      ),
      (
        title: 'Free Delivery',
        subtitle: 'on medicine orders above ₹199',
        gradient: g([pd, p], Alignment.topLeft, Alignment.bottomRight),
        icon: Icons.medication,
      ),
      (
        title: 'Health Packages',
        subtitle: 'starting at ₹299 only',
        gradient: g([p, pd], Alignment.topCenter, Alignment.bottomCenter),
        icon: Icons.science,
      ),
      (
        title: 'Emergency SOS',
        subtitle: 'ambulance in under 10 mins',
        gradient: g([pd, p], Alignment.centerRight, Alignment.centerLeft),
        icon: Icons.sos,
      ),
    ];
  }

  /// Compact illustrated promo banner carousel: theme-tinted gradient,
  /// soft decorative circles, emoji artwork, dot indicators.
  /// Dismissible banner showing the latest admin announcement.
  Widget _announcementBanner(AppState state) {
    final a = state.latestAnnouncements.first;
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${a['title'] ?? 'Announcement'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                if ('${a['message'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${a['message']}',
                    style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => state.dismissAnnouncement(0),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }

  Widget _illustratedBanner() {
    return SizedBox(
      height: 112,
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
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.subtitle,
                              style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(p.icon,
                            color: Colors.white, size: 32),
                      ),
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

  /// Full date line for the header ("Monday, October 19, 2026").
  String _dateLine() {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${months[n.month - 1]} ${n.day}, ${n.year}';
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
      compact: true,
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
                color: RemedooTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medical_services,
                  color: Colors.white, size: 24),
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
  /// Dense "Doctors near you": one card with compact divided rows so
  /// more doctors fit on screen.
  Widget _doctorRows(List<Doctor> list) {
    final scheme = Theme.of(context).colorScheme;
    return RDenseGroup(
      rows: [
        for (final d in list.take(4))
          RDenseRow(
            leading: RAvatarCircle(name: d.name, size: 46),
            title: d.name,
            subtitle: d.specialty,
            meta: RDenseMeta(
              rating: d.rating,
              parts: ['${d.expYears} yrs exp', inr(d.fee)],
            ),
            trailing: Icon(Icons.chevron_right,
                color: scheme.onSurfaceVariant),
            onTap: () => _goGated(DoctorDetailScreen(doctor: d),
                'Please login to view details'),
          ),
      ],
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

  // ------------------------------------------------------------------
  // Patient dashboard additions (Cognify pieces, real account data)
  // ------------------------------------------------------------------

  static const _cBlue = Color(0xFF0E3EFE);
  static const _cGreen = Color(0xFF5D8E5E);
  static const _cPink = Color(0xFFFD1A54);
  static const _cLav = Color(0xFF8A7CA8);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Next appointment, front and centre.
  Widget _nextAppointmentCard(Appointment a) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _goGated(const AppointmentsScreen()),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NEXT APPOINTMENT',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Color(0xFF8A8F98))),
                const SizedBox(height: 6),
                Text(a.doctorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w800)),
                Text(a.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_month,
                        size: 14, color: scheme.primary),
                    const SizedBox(width: 5),
                    Text('${a.dateLabel} • ${a.timeLabel}',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('View',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// Your numbers at a glance: visits, orders, reports, cart.
  Widget _statRow(AppState state) {
    final reportsReady =
        state.reports.where((r) => r.status == 'Completed').length;
    final items = <(IconData, Color, String, String, VoidCallback)>[
      (
        Icons.calendar_month,
        _cBlue,
        '${state.upcoming.length}',
        'Visits',
        () => _goGated(const AppointmentsScreen()),
      ),
      (
        Icons.shopping_bag,
        _cPink,
        '${state.activeOrders.length}',
        'Orders',
        () => _goGated(const OrdersScreen()),
      ),
      (
        Icons.description,
        _cGreen,
        '$reportsReady',
        'Reports',
        () => _goGated(const LabReportsScreen()),
      ),
      (
        Icons.shopping_cart,
        _cLav,
        '${state.cartCount}',
        'Cart',
        () => _go(const CartScreen()),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth < 560 ? 2 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 60,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final (icon, color, value, label, onTap) = items[i];
            final scheme = Theme.of(context).colorScheme;
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: RemedooTheme.softShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                      child:
                          Icon(icon, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Mon–Sun strip of the current week; days with appointments fill
  /// black, today gets a ring.
  Widget _weekStrip(AppState state) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return RCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Your Week',
                  style: TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('appointments',
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(7, (i) {
              final day = monday.add(Duration(days: i));
              final has = state.appointments.any((a) =>
                  a.status != 'cancelled' && _sameDay(a.date, day));
              final today = _sameDay(day, now);
              return Expanded(
                child: Column(
                  children: [
                    Text(letters[i],
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: has
                            ? scheme.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: today && !has
                            ? Border.all(
                                color: scheme.primary, width: 1.6)
                            : null,
                      ),
                      child: Center(
                        child: Text('${day.day}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: has
                                    ? Colors.white
                                    : scheme.onSurface)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Stack of live alert cards: reminders due today, active order,
  /// reports ready, cart waiting. Each appears only when it applies.
  Widget _alertsStack(AppState state) {
    final scheme = Theme.of(context).colorScheme;
    final cards = <Widget>[];

    final now = DateTime.now();
    final due = state.reminders
        .where((r) =>
            !r.done &&
            (r.repeat == 'Daily' || _sameDay(r.date, now)))
        .toList();
    if (due.isNotEmpty) {
      cards.add(RCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _goGated(const RemindersScreen()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                      color: _cPink, shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_active,
                      size: 17, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text('Due today',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${due.length}',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            for (final r in due.take(2)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 44),
                  Expanded(
                    child: Text(r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  Text(r.timeLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ));
    }

    if (state.activeOrders.isNotEmpty) {
      final o = [...state.activeOrders]
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
      final latest = o.first;
      final statusText = switch (latest.status) {
        'placed' => 'Order placed',
        'confirmed' => 'Being prepared',
        'out_for_delivery' => 'Out for delivery',
        _ => latest.status,
      };
      cards.add(RCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _goGated(const OrdersScreen()),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                  color: _cBlue, shape: BoxShape.circle),
              child: const Icon(Icons.shopping_bag,
                  size: 19, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order • ${inr(latest.total)}',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800)),
                  Text('${latest.pharmacyName} — $statusText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ));
    }

    final reportsReady =
        state.reports.where((r) => r.status == 'Completed').length;
    if (reportsReady > 0) {
      cards.add(RCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _goGated(const LabReportsScreen()),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                  color: _cGreen, shape: BoxShape.circle),
              child: const Icon(Icons.description,
                  size: 19, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                  reportsReady == 1
                      ? '1 lab report is ready'
                      : '$reportsReady lab reports are ready',
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ));
    }

    if (state.cartCount > 0) {
      cards.add(RCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _go(const CartScreen()),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                  color: _cLav, shape: BoxShape.circle),
              child: const Icon(Icons.shopping_cart,
                  size: 19, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                  '${state.cartCount} item${state.cartCount == 1 ? '' : 's'} in your cart • ${inr(state.cartTotal)}',
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
            // The Checkout pill is its own tap target into the
            // real checkout flow (audit fix 2026-10-19 — it was a
            // decorative container before): Remedoo's own store
            // carts go straight to their checkout; pharmacy carts
            // go to the cart screen where their checkout lives.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (state.cartPharmacyId == 'remedoo') {
                  _go(const RemedooCheckoutScreen());
                } else {
                  _go(const CartScreen());
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Checkout',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ));
    }

    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            cards[i],
          ],
        ],
      ),
    );
  }

  /// Profile completion progress (signed-in users, until 100%).
  /// Health Numbers card (2026-10-19): latest BP / sugar / weight
  /// with a small trend arrow vs the previous reading; opens the
  /// full log where readings are added.
  Widget _healthNumbersCard(AppState state) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String type, String label, IconData icon, Color color) {
      final latest = state.latestVital(type);
      final prev = state.previousVital(type);
      IconData? trend;
      if (latest != null && prev != null) {
        trend = latest.value > prev.value
            ? Icons.arrow_upward
            : latest.value < prev.value
                ? Icons.arrow_downward
                : Icons.remove;
      }
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(latest?.label ?? '—',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5)),
                if (trend != null) ...[
                  const SizedBox(width: 2),
                  Icon(trend, size: 13, color: scheme.onSurfaceVariant),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RSectionHeader(
          title: 'Your Health Numbers',
          onSeeAll: () => _go(const VitalsScreen()),
        ),
        const SizedBox(height: 8),
        RCard(
          onTap: () => _go(const VitalsScreen()),
          child: state.vitals.isEmpty
              ? Row(
                  children: [
                    Icon(Icons.monitor_heart,
                        color: scheme.primary, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                          'Track your BP, sugar and weight here',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.add_circle,
                        color: scheme.primary, size: 22),
                  ],
                )
              : Row(
                  children: [
                    cell('bp', 'BP', Icons.favorite,
                        RemedooTheme.emergency),
                    cell('sugar', 'Sugar', Icons.water_drop,
                        RemedooTheme.warning),
                    cell('weight', 'Weight', Icons.monitor_weight,
                        RemedooTheme.success),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _profileCompletion(AppState state) {
    if (!state.isSignedIn) return const SizedBox.shrink();
    final checks = <(bool, String)>[
      (state.userName.trim().isNotEmpty, 'Add your name'),
      (state.phone.trim().isNotEmpty, 'Add your phone number'),
      (state.email.trim().isNotEmpty, 'Add your email'),
      (state.family.isNotEmpty, 'Add a family member'),
    ];
    final done = checks.where((c) => c.$1).length;
    final pct = (done * 100 / checks.length).round();
    if (pct >= 100) return const SizedBox.shrink();
    final hint = checks.firstWhere((c) => !c.$1).$2;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: RCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _go(const ProfileScreen()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Complete your profile',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                Text('$pct%',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 4),
            Text(hint,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor:
                    AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  /// Recent updates feed (latest notifications, no bell-hunting).
  Widget _recentUpdates(AppState state) {
    if (state.notifications.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final items = [...state.notifications]
      ..sort((a, b) => b.time.compareTo(a.time));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RSectionHeader(
            title: 'Recent Updates',
            onSeeAll: () => _go(const NotificationsScreen()),
          ),
          const SizedBox(height: 8),
          RCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            onTap: () => _go(const NotificationsScreen()),
            child: Column(
              children: [
                for (final n in items.take(4))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(n.icon,
                              size: 17, color: scheme.onSurface),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(n.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              Text(n.message,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_ago(n.time),
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
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

import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
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
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Home tab: header, search, care finder, categories, promos, lists.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _promoCtrl = PageController();
  int _promoPage = 0;

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  void _go(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final upcoming = state.appointments
        .where((a) => a.status == 'upcoming')
        .take(2)
        .toList();
    final popularDoctors = state.activeDoctors.take(8).toList();
    final popularHospitals = state.activeHospitals.take(6).toList();
    final popularMeds = state.activeMedicines.take(8).toList();

    return Scaffold(
      drawer: _drawer(state),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.white,
        foregroundColor: RemedooTheme.primary,
        onPressed: () => showHelpDialog(context),
        child: const Text('?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(state)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _greeting(state),
                  const SizedBox(height: 14),
                  _searchBox(),
                  const SizedBox(height: 14),
                  _careFinderCard(),
                  const SizedBox(height: 18),
                  _categories(state),
                  const SizedBox(height: 18),
                  _promoCarousel(),
                  const SizedBox(height: 18),
                  _featureTrio(),
                  const SizedBox(height: 18),
                  _statsRow(state),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: 'Upcoming Appointments',
                    actionLabel: 'See all',
                    onAction: () => _go(const AppointmentsScreen()),
                  ),
                  const SizedBox(height: 8),
                  if (upcoming.isEmpty)
                    _emptyAppointments()
                  else
                    ...upcoming.map(_appointmentCard),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: 'Popular Doctors',
                    actionLabel: 'See all',
                    onAction: () => _go(const DoctorsScreen()),
                  ),
                  const SizedBox(height: 8),
                  _doctorRail(popularDoctors),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: 'Popular Hospitals',
                    actionLabel: 'See all',
                    onAction: () => _go(const HospitalsScreen()),
                  ),
                  const SizedBox(height: 8),
                  _hospitalRail(popularHospitals),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Popular Medicines'),
                  const SizedBox(height: 8),
                  _medicineGrid(popularMeds, state),
                  const SizedBox(height: 20),
                  _pharmacyBenefits(),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Explore More'),
                  const SizedBox(height: 8),
                  _exploreMore(),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Browse Services'),
                  const SizedBox(height: 8),
                  _browseServices(),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Health Tips'),
                  const SizedBox(height: 8),
                  _healthTips(),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Sponsored'),
                  const SizedBox(height: 8),
                  _sponsored(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AppState state) {
    return Container(
      decoration:
          const BoxDecoration(gradient: RemedooTheme.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
              const Text(
                'Remedoo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Badge(
                  isLabelVisible: state.unreadNotifications > 0,
                  label: Text('${state.unreadNotifications}'),
                  child: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                ),
                onPressed: () => _go(const NotificationsScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawer(AppState state) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
                gradient: RemedooTheme.headerGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const RemedooLogo(size: 48),
                const SizedBox(height: 8),
                Text(state.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
                Text(state.userEmail ?? 'Guest',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          _drawerItem(Icons.person_outline, 'My Profile',
              () => _go(const ProfileScreen())),
          _drawerItem(Icons.settings_outlined, 'Settings',
              () => _go(const SettingsScreen())),
          _drawerItem(Icons.favorite_outline, 'Favorites',
              () => _go(const FavoritesScreen())),
          _drawerItem(Icons.science_outlined, 'Lab Reports',
              () => _go(const LabReportsScreen())),
          _drawerItem(Icons.history, 'Medical History',
              () => _go(const MedicalHistoryScreen())),
          _drawerItem(Icons.sos, 'Emergency SOS',
              () => _go(const EmergencyScreen())),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: RemedooTheme.primary),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _greeting(AppState state) {
    return Text(
      'Hello, ${state.displayName} 👋',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
    );
  }

  Widget _searchBox() {
    return TextField(
      readOnly: true,
      onTap: () => _go(const DoctorsScreen()),
      decoration: const InputDecoration(
        hintText: 'Search doctors, hospitals, medicines…',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }

  Widget _careFinderCard() {
    return InkWell(
      onTap: () => _go(const CareMatchScreen()),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [RemedooTheme.purple, Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: RemedooTheme.purple.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.psychology,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Smart Care Finder',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                  Text(
                    'Tell us your symptoms, we will match the right care.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _categories(AppState state) {
    final items = [
      ('Doctors', Icons.person_search, () => _go(const DoctorsScreen())),
      ('Hospitals', Icons.local_hospital, () => _go(const HospitalsScreen())),
      ('Labs', Icons.science, () => _go(const LabsScreen())),
      ('Pharmacy', Icons.medication, () => _go(const PharmaciesScreen())),
      ('Emergency', Icons.sos, () => _go(const EmergencyScreen())),
      ('Favorites', Icons.favorite, () => _go(const FavoritesScreen())),
      ('Orders', Icons.receipt_long, () => _go(const OrdersScreen())),
      ('Reports', Icons.description, () => _go(const LabReportsScreen())),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (label, icon, onTap) = items[i];
        final danger = label == 'Emergency';
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: danger
                      ? RemedooTheme.emergency.withValues(alpha: 0.12)
                      : RemedooTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon,
                    color: danger
                        ? RemedooTheme.emergency
                        : RemedooTheme.primary,
                    size: 28),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }

  Widget _promoCarousel() {
    final promos = [
      (
        'Flat 30% OFF',
        'On your first doctor consultation',
        RemedooTheme.primary,
        Icons.local_offer
      ),
      (
        'Free Health Checkup',
        'With every hospital booking this week',
        RemedooTheme.purple,
        Icons.health_and_safety
      ),
      (
        'Medicines at your door',
        'Extra 20% off on all orders above ₹499',
        RemedooTheme.teal,
        Icons.delivery_dining
      ),
    ];
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _promoCtrl,
            itemCount: promos.length,
            onPageChanged: (i) => setState(() => _promoPage = i),
            itemBuilder: (_, i) {
              final (t, s, c, icon) = promos[i];
              return Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [c, c.withValues(alpha: 0.75)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(s,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(icon, color: Colors.white54, size: 64),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(promos.length, (i) {
            return Container(
              width: _promoPage == i ? 20 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _promoPage == i
                    ? RemedooTheme.primary
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _featureTrio() {
    final items = [
      ('Find Expert\nDoctors', Icons.person_search,
          () => _go(const DoctorsScreen())),
      ('Nearby\nHospitals', Icons.local_hospital,
          () => _go(const HospitalsScreen())),
      ('Lab Tests\nat Home', Icons.home, () => _go(const LabsScreen())),
    ];
    return Row(
      children: items.map((e) {
        final (label, icon, onTap) = e;
        return Expanded(
          child: InkWell(
            onTap: onTap,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Icon(icon,
                        color: RemedooTheme.primary, size: 32),
                    const SizedBox(height: 8),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statsRow(AppState state) {
    final stats = [
      ('Appointments', '${state.appointments.length}', Icons.calendar_month,
          () => _go(const AppointmentsScreen())),
      ('Active Orders', '${state.activeOrders.length}', Icons.shopping_bag,
          () => _go(const OrdersScreen())),
      ('Prescriptions', '${state.prescriptions.length}', Icons.description,
          () => _go(const MedicalHistoryScreen())),
      ('Reports', '${state.reports.length}', Icons.science,
          () => _go(const LabReportsScreen())),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: stats.map((s) {
            final (label, value, icon, onTap) = s;
            return Expanded(
              child: InkWell(
                onTap: onTap,
                child: Column(
                  children: [
                    Icon(icon,
                        color: RemedooTheme.primary, size: 24),
                    const SizedBox(height: 4),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _emptyAppointments() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.calendar_month,
                color: RemedooTheme.primary, size: 36),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('No upcoming appointments.\nBook your visit today!'),
            ),
            FilledButton(
              onPressed: () => _go(const DoctorsScreen()),
              child: const Text('Book Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentCard(Appointment a) {
    return Card(
      child: ListTile(
        leading: InitialsAvatar(name: a.doctorName, radius: 24),
        title: Text(a.doctorName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${a.specialty}\n${a.dateLabel} • ${a.timeLabel}'),
        isThreeLine: true,
        trailing: const StatusChip(status: 'upcoming'),
        onTap: () => _go(const AppointmentsScreen()),
      ),
    );
  }

  Widget _doctorRail(List<Doctor> list) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final d = list[i];
          return SizedBox(
            width: 170,
            child: InkWell(
              onTap: () => _go(DoctorDetailScreen(doctor: d)),
              borderRadius: BorderRadius.circular(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: InitialsAvatar(name: d.name)),
                      const SizedBox(height: 8),
                      Text(d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(d.specialty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          RatingPill(rating: d.rating),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(inr(d.fee),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color:
                                        RemedooTheme.primary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hospitalRail(List<Hospital> list) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final h = list[i];
          return SizedBox(
            width: 240,
            child: InkWell(
              onTap: () => _go(HospitalDetailScreen(hospital: h)),
              borderRadius: BorderRadius.circular(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: RemedooTheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                                Icons.local_hospital,
                                color: RemedooTheme.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(h.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          RatingPill(rating: h.rating),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(h.location,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _medicineGrid(List<Medicine> list, AppState state) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final m = list[i];
        final qty = state.cartQty(m.id);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontWeight: FontWeight.w700)),
                Text(m.pack,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
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
                        onMinus: () =>
                            state.removeFromCart(m.id),
                        onPlus: () => _addMed(state, m),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addMed(AppState state, Medicine m) {
    final pharmName = pharmacyById(m.pharmacyId).name;
    if (state.addToCart(m, pharmacyId: m.pharmacyId, pharmacyName: pharmName)) return;
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
              state.addToCart(m, pharmacyId: m.pharmacyId, pharmacyName: pharmacyById(m.pharmacyId).name);
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order in 3 Easy Steps',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                      child: Icon(icon, color: RemedooTheme.teal),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        Text(sub,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _exploreMore() {
    final items = [
      ('Find Doctors', Icons.person_search,
          () => _go(const DoctorsScreen())),
      ('Ambulance Service', Icons.emergency,
          () => _go(const EmergencyScreen())),
      ('Medicine Delivery', Icons.delivery_dining,
          () => _go(const PharmaciesScreen())),
      ('Health Packages', Icons.health_and_safety,
          () => _go(const LabsScreen())),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (label, icon, onTap) = items[i];
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, color: RemedooTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
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
      children: tips.map((t) {
        return Card(
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: RemedooTheme.ratingGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lightbulb_outline,
                  color: RemedooTheme.ratingGreen),
            ),
            title: Text(t['title']!,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(t['text']!,
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        );
      }).toList(),
    );
  }

  Widget _sponsored() {
    final sponsors = [
      ('CityCare Diagnostics', 'Flat 25% off on all lab tests', Icons.science),
      ('MediPlus Pharmacy', 'Extra 10% off on first order', Icons.medication),
      ('Smile Dental Studio', 'Free dental checkup this month', Icons.mood),
      ('FitLife Gym', '1 month free trial for Remedoo users', Icons.fitness_center),
    ];
    return Column(
      children: sponsors.map((s) {
        final (name, offer, icon) = s;
        return Card(
          color: RemedooTheme.purple.withValues(alpha: 0.06),
          child: ListTile(
            leading: Icon(icon, color: RemedooTheme.purple),
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(offer),
            trailing: const Text('Ad',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        );
      }).toList(),
    );
  }
}

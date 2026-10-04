import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'doctor_detail_screen.dart';

const _specialties = [
  'All',
  'General Physician',
  'Cardiologist',
  'Dermatologist',
  'Pediatrician',
  'Orthopedic',
  'Gynecologist',
  'Neurologist',
  'ENT Specialist',
  'Ophthalmologist',
  'Psychiatrist',
  'Dentist',
  'Pulmonologist',
];

const _sortOptions = [
  'Relevance',
  'Rating High→Low',
  'Distance Nearest',
  'Fee Low→High',
  'Fee High→Low',
  'Experience',
];

/// Rotating offer banners, mirroring the React Doctors page carousel.
class _BannerData {
  final String emoji;
  final String title;
  final String subtitle;
  final Gradient gradient;

  const _BannerData(this.emoji, this.title, this.subtitle, this.gradient);
}

/// Promo banners tinted by the active theme.
List<_BannerData> get _banners => [
      _BannerData('🩺', 'Flat 30% OFF', 'On first doctor consultation',
          RemedooTheme.bannerGradientA),
      _BannerData('⚡', 'Instant Booking', 'No waiting, confirm in seconds',
          RemedooTheme.bannerGradientB),
      _BannerData('📞', 'Free Follow-up', 'Within 7 days of consultation',
          RemedooTheme.bannerGradientC),
    ];

/// Doctor directory with search, filters and sorting.
class DoctorsScreen extends StatefulWidget {
  final String initialQuery;

  const DoctorsScreen({super.key, this.initialQuery = ''});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  late final TextEditingController _search;
  String _specialty = 'All';
  String _sort = _sortOptions.first;
  bool _rating4 = false;
  bool _lowFee = false;
  bool _nearest = false;
  bool _loading = true;
  int _bannerIdx = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _loading = false);
    });
    _bannerTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (mounted) setState(() => _bannerIdx = (_bannerIdx + 1) % _banners.length);
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  List<Doctor> _filtered(AppState state) {
    var list = state.activeDoctors.toList();
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((d) =>
              d.name.toLowerCase().contains(q) ||
              d.specialty.toLowerCase().contains(q) ||
              d.hospital.toLowerCase().contains(q))
          .toList();
    }
    if (_specialty != 'All') {
      list = list.where((d) => d.specialty == _specialty).toList();
    }
    if (_rating4) list = list.where((d) => d.rating >= 4.0).toList();
    switch (_sort) {
      case 'Rating High→Low':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Distance Nearest':
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case 'Fee Low→High':
        list.sort((a, b) => a.fee.compareTo(b.fee));
        break;
      case 'Fee High→Low':
        list.sort((a, b) => b.fee.compareTo(a.fee));
        break;
      case 'Experience':
        list.sort((a, b) => b.expYears.compareTo(a.expYears));
        break;
    }
    if (_lowFee) list.sort((a, b) => a.fee.compareTo(b.fee));
    if (_nearest) list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = _filtered(state);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: MaxWidthBox(
          child: Column(
            children: [
              _header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _promoBanner(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: RSectionHeader(
                  title: '${list.length} doctors available',
                  subtitle: 'Book consultation with best doctors',
                ),
              ),
              Expanded(
                child: _loading
                    ? ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: 4,
                        itemBuilder: (_, _) => const SkeletonCard(),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: list.isEmpty
                            ? ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 60),
                                  EmptyState(
                                    icon: Icons.person_search,
                                    title: 'No doctors found',
                                    subtitle:
                                        'Try a different search or filter.',
                                  ),
                                ],
                              )
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 16),
                                children: [
                                  StaggerItem(
                                    index: 0,
                                    child: RDenseGroup(
                                      rows: [
                                        for (int i = 0;
                                            i < list.length;
                                            i++)
                                          _doctorRow(list[i], state),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// White sticky-style header: back button + title, search, chip rows —
  /// mirrors the React Doctors page header.
  Widget _header() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.maybePop(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back,
                        size: 20, color: scheme.onSurface),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Doctors',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 12, color: scheme.primary),
                          const SizedBox(width: 4),
                          Text('Doctors near your location',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: RSearchBar(
              hint: 'Search by name or specialization',
              controller: _search,
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _specialties.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _specialties[i];
                return Center(
                  child: RFilterChip(
                    label: s,
                    selected: s == _specialty,
                    onTap: () => setState(() => _specialty = s),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                Center(
                  // Decorative in the React app too (no action attached).
                  child: RFilterChip(
                    label: 'Filter',
                    icon: Icons.tune,
                    selected: false,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 8),
                for (final o in _sortOptions) ...[
                  Center(
                    child: RFilterChip(
                      label: o,
                      selected: _sort == o,
                      onTap: () => setState(() => _sort = o),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Center(
                  child: RFilterChip(
                    label: 'Rating 4.0+',
                    selected: _rating4,
                    onTap: () => setState(() => _rating4 = !_rating4),
                  ),
                ),
                const SizedBox(width: 8),
                Center(
                  child: RFilterChip(
                    label: 'Fee: Low-High',
                    selected: _lowFee,
                    onTap: () => setState(() => _lowFee = !_lowFee),
                  ),
                ),
                const SizedBox(width: 8),
                Center(
                  child: RFilterChip(
                    label: 'Nearest First',
                    selected: _nearest,
                    onTap: () => setState(() => _nearest = !_nearest),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _promoBanner() {
    final b = _banners[_bannerIdx];
    return Container(
      height: 96,
      decoration: BoxDecoration(
        gradient: b.gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(b.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.subtitle,
                        style: TextStyle(
                            color:
                                Colors.white.withValues(alpha: 0.85),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 10,
            child: Row(
              children: List.generate(_banners.length, (i) {
                final active = i == _bannerIdx;
                return Container(
                  width: active ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _doctorRow(Doctor d, AppState state) {
    final scheme = Theme.of(context).colorScheme;
    return RDenseRow(
      leading: RAvatarCircle(name: d.name, size: 46),
      title: d.name,
      subtitle: d.specialty,
      meta: RDenseMeta(
        rating: d.rating,
        parts: ['${d.expYears} yrs exp', inr(d.fee)],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _favButton(state, d),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: () {
        if (!checkLogin(context, 'Please login to view details')) return;
        pushPage(context, DoctorDetailScreen(doctor: d));
      },
    );
  }

  Widget _favButton(AppState state, Doctor d) {
    final fav = state.isFavorite('doctor:${d.id}');
    return Material(
      color: Theme.of(context).cardColor,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (!checkLogin(context, 'Please sign in to add favorites')) return;
          state.toggleFavorite('doctor:${d.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            fav ? Icons.favorite : Icons.favorite_border,
            size: 18,
            color: fav ? RemedooTheme.emergency : RemedooTheme.mutedText,
          ),
        ),
      ),
    );
  }
}

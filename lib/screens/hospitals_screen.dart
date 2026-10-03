import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'hospital_detail_screen.dart';
import 'booking_screen.dart';

const _filters = [
  'Relevance',
  'Rating 4.0+',
  'Has ICU',
  'Government',
  'Nearest First',
];

const _sortOptions = [
  'Relevance',
  'Rating High→Low',
  'Distance Nearest',
  'Beds Most',
  'Name A→Z',
];

const _banners = [
  ('🏥', 'Free Health Checkup', 'On first hospital visit',
      RemedooTheme.promoTealGradient),
  ('🛏️', 'ICU Available 24/7', 'Critical care at your service',
      LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)])),
  ('🚑', 'Free Ambulance', 'For emergency admissions',
      LinearGradient(colors: [Color(0xFFF2790F), Color(0xFFF5A623)])),
];

/// Hospital directory with search, filters and sorting — reskinned to match
/// the React "Swiggy-style" listing (09-hospitals.png).
class HospitalsScreen extends StatefulWidget {
  const HospitalsScreen({super.key});

  @override
  State<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends State<HospitalsScreen> {
  final _search = TextEditingController();
  String _sort = _sortOptions.first;
  String _filter = _filters.first;
  bool _loading = true;
  int _bannerIdx = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _loading = false);
    });
    _bannerTimer = Timer.periodic(
      const Duration(milliseconds: 3500),
      (_) {
        if (mounted) {
          setState(() => _bannerIdx = (_bannerIdx + 1) % _banners.length);
        }
      },
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  List<Hospital> _filtered(AppState state) {
    var list = state.activeHospitals.toList();
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((h) =>
              h.name.toLowerCase().contains(q) ||
              h.location.toLowerCase().contains(q))
          .toList();
    }
    if (_filter == 'Rating 4.0+') {
      list = list.where((h) => h.rating >= 4.0).toList();
    }
    if (_filter == 'Has ICU') list = list.where((h) => h.hasIcu).toList();
    if (_filter == 'Government') {
      list = list.where((h) => h.government).toList();
    }
    if (_filter == 'Nearest First' || _sort == 'Distance Nearest') {
      list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    switch (_sort) {
      case 'Rating High→Low':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Beds Most':
        list.sort((a, b) => b.beds.compareTo(a.beds));
        break;
      case 'Name A→Z':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Relevance':
        if (_filter != 'Nearest First') {
          list.sort((a, b) => b.rating.compareTo(a.rating));
        }
        break;
    }
    return list;
  }

  double _aspectFor(double maxWidth, BuildContext context) {
    final cols = const ResponsiveValue<int>(
      compact: 1,
      medium: 2,
      expanded: 3,
      wide: 4,
    ).of(context);
    final cellW = (maxWidth - 32 - 12 * (cols - 1)) / cols;
    // Card: 130px image header + ~152px content.
    return (cellW / 282).clamp(0.6, 3.0);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = _filtered(state);
    final banner = _banners[_bannerIdx];
    return Scaffold(
      body: SafeArea(
        top: true,
        child: MaxWidthBox(
          child: Column(
            children: [
              _header(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: RSearchBar(
                  hint: 'Search for hospitals',
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 10),
              _filterRow(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: RPromoBanner(
                  gradient: banner.$4,
                  title: banner.$2,
                  subtitle: banner.$3,
                  illustration: Center(
                    child: Text(banner.$1,
                        style: const TextStyle(fontSize: 52)),
                  ),
                  pageCount: _banners.length,
                  pageIndex: _bannerIdx,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: RSectionHeader(
                  title: '${list.length} hospitals near you',
                  subtitle: 'Find the right hospital for your needs',
                ),
              ),
              Expanded(child: _resultsBody(list)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _BackCircle(onTap: () => Navigator.maybePop(context)),
          const SizedBox(width: 12),
          const Text('Hospitals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _filterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _sortPill(),
          const SizedBox(width: 8),
          ..._filters.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: RFilterChip(
                  label: f,
                  selected: _filter == f,
                  onTap: () => setState(() => _filter = f),
                ),
              )),
        ],
      ),
    );
  }

  Widget _sortPill() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort, size: 14, color: scheme.primary),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sort,
              icon: Icon(Icons.keyboard_arrow_down,
                  size: 16, color: scheme.onSurfaceVariant),
              style: TextStyle(
                fontFamily: RemedooTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
              items: _sortOptions
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _sort = v ?? _sortOptions.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsBody(List<Hospital> list) {
    Widget grid({
      required int itemCount,
      required Widget Function(BuildContext, int) itemBuilder,
    }) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return ResponsiveGrid(
            compactCols: 1,
            mediumCols: 2,
            expandedCols: 3,
            wideCols: 4,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            childAspectRatio: _aspectFor(constraints.maxWidth, context),
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );
        },
      );
    }

    if (_loading) {
      return grid(
        itemCount: 6,
        itemBuilder: (_, _) => const SkeletonCard(height: 150),
      );
    }
    if (list.isEmpty) {
      return const REmptyState(
        icon: Icons.local_hospital_outlined,
        title: 'No hospitals found',
        subtitle: 'Try a different search term',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) setState(() {});
      },
      child: grid(
        itemCount: list.length,
        itemBuilder: (_, i) =>
            StaggerItem(index: i % 6, child: _card(list[i])),
      ),
    );
  }

  Widget _card(Hospital h) {
    void openDetail() {
      if (!checkLogin(context, 'Please login to view details')) return;
      pushPage(context, HospitalDetailScreen(hospital: h));
    }

    return RHospitalCard(
      hospital: h,
      isGuest: AppStateScope.of(context).isGuest,
      trailing: FavoriteButton(favKey: 'hospital:${h.id}'),
      onTap: openDetail,
      onView: openDetail,
      onBook: () {
        if (!checkLogin(context, 'Please login to book appointments')) return;
        pushPage(
          context,
          BookingScreen(
            kind: 'hospital',
            refId: h.id,
            title: h.name,
            subtitle: 'General Consultation',
            place: h.location,
            fee: 300,
          ),
        );
      },
    );
  }

}

/// Circular back button on a muted circle, like the React listing headers.
class _BackCircle extends StatelessWidget {
  final VoidCallback onTap;

  const _BackCircle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark
          ? RemedooTheme.darkSecondary
          : RemedooTheme.mutedSurface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.arrow_back, size: 20),
        ),
      ),
    );
  }
}

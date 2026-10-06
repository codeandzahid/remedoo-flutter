import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'pharmacy_detail_screen.dart';
import '../app_navigator.dart';

const _filters = [
  'Relevance',
  'Rating 4.0+',
  'Delivery Time',
  'Has Offers',
  'Nearest First',
];

const _sortOptions = [
  'Relevance',
  'Rating High→Low',
  'Delivery Time',
  'Distance Nearest',
];

/// Promo banners tinted by the active theme.
List<(String, String, String, Gradient)> get _banners => [
      ('💊', 'Flat 20% OFF', 'On first medicine order',
          RemedooTheme.bannerGradientA),
      ('🚚', 'Free Delivery', 'On orders above ₹199',
          RemedooTheme.bannerGradientB),
      ('⚡', 'Express 15 min', 'Get meds super fast',
          RemedooTheme.bannerGradientC),
    ];

/// Medicines & More: pharmacy directory — reskinned to match the React
/// "Swiggy-style" listing (11-pharmacies.png).
class PharmaciesScreen extends StatefulWidget {
  const PharmaciesScreen({super.key});

  @override
  State<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends State<PharmaciesScreen> {
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

  List<Pharmacy> _filtered(AppState state) {
    var list = state.activePharmacies.toList();
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.location.toLowerCase().contains(q))
          .toList();
    }
    if (_filter == 'Rating 4.0+') {
      list = list.where((p) => p.rating >= 4.0).toList();
    }
    if (_filter == 'Has Offers') {
      list = list.where((p) => p.offers > 0).toList();
    }
    if (_filter == 'Delivery Time' || _sort == 'Delivery Time') {
      list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    if (_filter == 'Nearest First' || _sort == 'Distance Nearest') {
      list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    if (_sort == 'Rating High→Low') {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    if (_sort == 'Relevance' &&
        _filter != 'Nearest First' &&
        _filter != 'Delivery Time') {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
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
                  hint: 'Search for pharmacies or medicines',
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 10),
              _filterRow(),
              Expanded(child: _resultsBody(list, banner)),
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
          _BackCircle(onTap: () => goBack(context)),
          const SizedBox(width: 12),
          const Text('Medicines & More',
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

  Widget _resultsBody(List<Pharmacy> list,
      (String, String, String, Gradient) banner) {
    Widget denseList({
      required int itemCount,
      required Widget Function(BuildContext, int) itemBuilder,
    }) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RPromoBanner(
              gradient: banner.$4,
              title: banner.$2,
              subtitle: banner.$3,
              illustration: Center(
                child: Text(banner.$1,
                    style: const TextStyle(fontSize: 44)),
              ),
              pageCount: _banners.length,
              pageIndex: _bannerIdx,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
            child: RSectionHeader(
              title: '${list.length} pharmacies near you',
            ),
          ),
          RDenseGroup(
            rows: [
              for (int i = 0; i < itemCount; i++) itemBuilder(context, i),
            ],
          ),
        ],
      );
    }

    if (_loading) {
      return denseList(
        itemCount: 6,
        itemBuilder: (_, _) => const SkeletonCard(height: 64),
      );
    }
    if (list.isEmpty) {
      return const REmptyState(
        icon: Icons.medication_outlined,
        title: 'No pharmacies found',
        subtitle: 'Try a different search term',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) setState(() {});
      },
      child: denseList(
        itemCount: list.length,
        itemBuilder: (_, i) =>
            StaggerItem(index: i % 6, child: _card(list[i])),
      ),
    );
  }

  Widget _card(Pharmacy p) {
    final scheme = Theme.of(context).colorScheme;
    final itemCount = AppStateScope.of(context).medicineCountFor(p.id);
    return RDenseRow(
      leading: RAvatarCircle(
          name: p.name, size: 46, icon: Icons.storefront_outlined),
      title: p.name,
      subtitle: p.location,
      meta: RDenseMeta(
        rating: p.rating,
        parts: [
          '$itemCount items',
          p.deliveryTime,
          if (p.offers > 0) '${p.offers} offers',
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FavoriteButton(favKey: 'pharmacy:${p.id}'),
          Icon(Icons.chevron_right,
              color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: () {
        if (!checkLogin(context, 'Please login to view details')) return;
        pushPage(context, PharmacyDetailScreen(pharmacy: p));
      },
    );
  }
}

class _BackCircle extends StatelessWidget {
  final VoidCallback onTap;

  const _BackCircle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color:
          dark ? RemedooTheme.darkSecondary : RemedooTheme.mutedSurface,
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

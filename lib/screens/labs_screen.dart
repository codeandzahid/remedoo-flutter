import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'lab_detail_screen.dart';
import '../app_navigator.dart';

const _filters = [
  'Relevance',
  'Rating 4.0+',
  'Most Tests',
  'Has Offers',
  'Nearest First',
];

const _sortOptions = [
  'Relevance',
  'Rating High→Low',
  'Distance Nearest',
  'Most Tests',
];

/// Promo banners tinted by the active theme.
List<(String, String, String, Gradient)> get _banners => [
      ('🔬', 'Flat 30% OFF', 'On first lab test booking',
          RemedooTheme.bannerGradientA),
      ('🏠', 'Free Home Collection', 'On orders above ₹499',
          RemedooTheme.bannerGradientB),
      ('⚡', 'Reports in 6 hrs', 'Express test results',
          RemedooTheme.bannerGradientC),
    ];

/// Labs & diagnostics directory — reskinned to match the React
/// "Swiggy-style" listing (10-labs.png).
class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> {
  final _search = TextEditingController();
  String _sort = _sortOptions.first;
  String _filter = _filters.first;
  bool _loading = true;
  int _bannerIdx = 0;
  Timer? _bannerTimer;
  Lab? _compareA;

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

  List<Lab> _filtered(AppState state) {
    var list = state.activeLabs.toList();
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((l) =>
              l.name.toLowerCase().contains(q) ||
              l.location.toLowerCase().contains(q))
          .toList();
    }
    if (_filter == 'Rating 4.0+') {
      list = list.where((l) => l.rating >= 4.0).toList();
    }
    if (_filter == 'Has Offers') {
      list = list.where((l) => l.offers > 0).toList();
    }
    if (_filter == 'Most Tests' || _sort == 'Most Tests') {
      list.sort((a, b) => b.testCount.compareTo(a.testCount));
    }
    if (_filter == 'Nearest First' || _sort == 'Distance Nearest') {
      list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    switch (_sort) {
      case 'Rating High→Low':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Relevance':
        if (_filter != 'Nearest First' && _filter != 'Most Tests') {
          list.sort((a, b) => b.rating.compareTo(a.rating));
        }
        break;
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
                  hint: 'Search for labs or tests',
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
          const Text('Labs & Diagnostics',
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

  Widget _resultsBody(List<Lab> list,
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
              title: '${list.length} labs near you',
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
        icon: Icons.science_outlined,
        title: 'No labs found',
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

  Widget _card(Lab l) {
    final scheme = Theme.of(context).colorScheme;
    final comparing = _compareA != null;
    final selected = _compareA?.id == l.id;
    return RDenseRow(
      leading: RAvatarCircle(
          name: l.name, size: 46, icon: Icons.science_outlined),
      title: l.name,
      subtitle: l.location,
      meta: RDenseMeta(
        rating: l.rating,
        parts: [
          '${l.testCount} tests',
          'Report in ${l.turnaround}',
          if (l.offers > 0) '${l.offers} offers',
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FavoriteButton(favKey: 'lab:${l.id}'),
          IconButton(
            tooltip: selected ? 'Cancel compare' : 'Compare',
            icon: Icon(
              Icons.compare_arrows,
              color: selected
                  ? RemedooTheme.primary
                  : scheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: () => setState(
                () => _compareA = selected ? null : l),
          ),
          Icon(Icons.chevron_right,
              color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: () {
        if (comparing && !selected) {
          LabCompareSheet.show(context, _compareA!, l);
          setState(() => _compareA = null);
        } else {
          if (!checkLogin(context, 'Please login to view details')) {
            return;
          }
          pushPage(context, LabDetailScreen(lab: l));
        }
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

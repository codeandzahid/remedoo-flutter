import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'lab_detail_screen.dart';

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

const _banners = [
  ('🔬', 'Flat 30% OFF', 'On first lab test booking',
      RemedooTheme.promoTealGradient),
  ('🏠', 'Free Home Collection', 'On orders above ₹499',
      LinearGradient(colors: [Color(0xFFF2790F), Color(0xFFF5A623)])),
  ('⚡', 'Reports in 6 hrs', 'Express test results',
      LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)])),
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

  double _aspectFor(double maxWidth, BuildContext context) {
    final cols = const ResponsiveValue<int>(
      compact: 1,
      medium: 2,
      expanded: 3,
      wide: 4,
    ).of(context);
    final cellW = (maxWidth - 32 - 12 * (cols - 1)) / cols;
    // Card: 130px image header + ~104px content.
    return (cellW / 234).clamp(0.6, 3.0);
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
                  title: '${list.length} labs near you',
                  subtitle: 'Book tests with best prices & offers',
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

  Widget _resultsBody(List<Lab> list) {
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
      child: grid(
        itemCount: list.length,
        itemBuilder: (_, i) =>
            StaggerItem(index: i % 6, child: _card(list[i])),
      ),
    );
  }

  Widget _card(Lab l) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final comparing = _compareA != null;
    return RCard(
      padding: EdgeInsets.zero,
      onTap: () {
        if (comparing && _compareA!.id != l.id) {
          LabCompareSheet.show(context, _compareA!, l);
          setState(() => _compareA = null);
        } else {
          pushPage(context, LabDetailScreen(lab: l));
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 130,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: dark
                        ? RemedooTheme.darkSecondary
                        : const Color(0xFFEAF6F4),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(RemedooRadius.card)),
                  ),
                  child: const Center(
                    child: Text('🔬', style: TextStyle(fontSize: 60)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: FavoriteButton(favKey: 'lab:${l.id}'),
                    ),
                  ),
                ),
                if (l.offers > 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: RRibbon(
                        label: '${l.offers} offers on tests',
                        icon: Icons.percent),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(l.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ),
                          if (l.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified,
                                size: 16, color: RemedooTheme.primary),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    RRatingPill(rating: l.rating),
                  ],
                ),
                const SizedBox(height: 3),
                Text(l.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      RStat(
                          icon: Icons.access_time,
                          text: 'Report in ${l.turnaround}'),
                      _dot(),
                      RStat(
                          icon: Icons.science_outlined,
                          text: '${l.testCount} tests'),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _compareA =
                            _compareA?.id == l.id ? null : l),
                        child: Text(
                          _compareA?.id == l.id
                              ? 'Cancel'
                              : 'Compare',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary),
                        ),
                      ),
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

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('•',
          style: TextStyle(
              color:
                  Theme.of(context).colorScheme.onSurfaceVariant)),
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

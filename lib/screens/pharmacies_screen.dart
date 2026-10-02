import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'pharmacy_detail_screen.dart';
import 'remedoo_pharmacy_screen.dart';

const _sortOptions = [
  'Relevance',
  'Rating High→Low',
  'Delivery Time',
  'Distance Nearest',
];

/// Medicines & More: pharmacy directory.
class PharmaciesScreen extends StatefulWidget {
  const PharmaciesScreen({super.key});

  @override
  State<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends State<PharmaciesScreen> {
  final _search = TextEditingController();
  String _sort = _sortOptions.first;
  bool _rating4 = false;
  bool _fast = false;
  bool _offers = false;
  bool _nearest = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _search.dispose();
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
    if (_rating4) list = list.where((p) => p.rating >= 4.0).toList();
    if (_fast) list = list.where((p) => p.deliveryTime.contains('25')).toList();
    if (_offers) list = list.where((p) => p.offers > 0).toList();
    switch (_sort) {
      case 'Rating High→Low':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Delivery Time':
        list.sort((a, b) => a.deliveryTime.compareTo(b.deliveryTime));
        break;
      case 'Distance Nearest':
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
    }
    if (_nearest) list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
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
    // Card content height is width-independent; 215 leaves slack for
    // larger text scales.
    return (cellW / 215).clamp(0.6, 3.0);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = _filtered(state);
    return Scaffold(
      appBar: AppBar(title: const Text('Medicines & More')),
      body: MaxWidthBox(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search pharmacies…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: InkWell(
                onTap: () =>
                    pushPage(context, const RemedooPharmacyScreen()),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: RemedooTheme.headerGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.storefront, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Remedoo Pharmacy',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            Text(
                                'Our own store — genuine medicines, best prices',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _sort,
                decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12)),
                items: _sortOptions
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _sort = v ?? _sortOptions.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Rating 4.0+'),
                    selected: _rating4,
                    onSelected: (v) => setState(() => _rating4 = v),
                  ),
                  FilterChip(
                    label: const Text('Delivery Time'),
                    selected: _fast,
                    onSelected: (v) => setState(() => _fast = v),
                  ),
                  FilterChip(
                    label: const Text('Has Offers'),
                    selected: _offers,
                    onSelected: (v) => setState(() => _offers = v),
                  ),
                  FilterChip(
                    label: const Text('Nearest First'),
                    selected: _nearest,
                    onSelected: (v) => setState(() => _nearest = v),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [RemedooTheme.teal, Color(0xFF3BB98A)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.delivery_dining, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Free delivery on orders above ₹499!',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${list.length} pharmacies near you',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Expanded(child: _resultsBody(list)),
          ],
        ),
      ),
    );
  }

  Widget _resultsBody(List<Pharmacy> list) {
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            childAspectRatio:
                _aspectFor(constraints.maxWidth, context),
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );
        },
      );
    }

    if (_loading) {
      return grid(
        itemCount: 6,
        itemBuilder: (_, _) => const SkeletonCard(height: 140),
      );
    }
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.medication,
        title: 'No pharmacies found',
        subtitle: 'Try a different search or filter.',
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

  Widget _card(Pharmacy p) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            pushPage(context, PharmacyDetailScreen(pharmacy: p)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: RemedooTheme.purple,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  '${p.offers} offers available',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'pharmacy-image-${p.id}',
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: RemedooTheme.purple
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.storefront,
                                color: RemedooTheme.purple, size: 30),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(p.name,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w700,
                                            fontSize: 16)),
                                  ),
                                  if (p.verified)
                                    const Icon(Icons.verified,
                                        size: 18,
                                        color: RemedooTheme.primary),
                                  FavoriteButton(
                                      favKey: 'pharmacy:${p.id}'),
                                ],
                              ),
                              Text(p.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          RatingPill(rating: p.rating),
                          const SizedBox(width: 8),
                          _miniChip(p.deliveryTime),
                          const SizedBox(width: 8),
                          _miniChip('${p.itemCount} items'),
                          const SizedBox(width: 8),
                          _miniChip(
                              '${p.distanceKm.toStringAsFixed(1)} km'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.arrow_forward,
                            size: 16,
                            color: RemedooTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'View store',
                          style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

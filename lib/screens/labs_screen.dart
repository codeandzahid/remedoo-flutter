import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'lab_detail_screen.dart';

const _sortOptions = [
  'Relevance',
  'Rating High→Low',
  'Distance Nearest',
  'Most Tests',
];

/// Labs & diagnostics directory.
class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> {
  final _search = TextEditingController();
  String _sort = _sortOptions.first;
  bool _rating4 = false;
  bool _mostTests = false;
  bool _offers = false;
  bool _nearest = false;
  bool _loading = true;
  Lab? _compareA;

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
    if (_rating4) list = list.where((l) => l.rating >= 4.0).toList();
    if (_mostTests) list = list.where((l) => l.testCount >= 200).toList();
    if (_offers) list = list.where((l) => l.offers > 0).toList();
    switch (_sort) {
      case 'Rating High→Low':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Distance Nearest':
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case 'Most Tests':
        list.sort((a, b) => b.testCount.compareTo(a.testCount));
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
    // Card content height is width-independent; 235 leaves slack for
    // larger text scales.
    return (cellW / 235).clamp(0.6, 3.0);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = _filtered(state);
    return Scaffold(
      appBar: AppBar(title: const Text('Labs & Diagnostics')),
      body: MaxWidthBox(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search labs…',
                  prefixIcon: Icon(Icons.search),
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
                    label: const Text('Most Tests'),
                    selected: _mostTests,
                    onSelected: (v) => setState(() => _mostTests = v),
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
                    colors: [RemedooTheme.purple, Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.science, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Home sample collection — free above ₹299!',
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
                  '${list.length} labs near you',
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
        itemBuilder: (_, _) => const SkeletonCard(height: 150),
      );
    }
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.science,
        title: 'No labs found',
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

  Widget _card(Lab l) {
    final comparing = _compareA != null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
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
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: RemedooTheme.teal,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  '${l.offers} offers on tests',
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
                          tag: 'lab-image-${l.id}',
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: RemedooTheme.teal
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.science,
                                color: RemedooTheme.teal, size: 30),
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
                                    child: Text(l.name,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w700,
                                            fontSize: 16)),
                                  ),
                                  if (l.verified)
                                    const Icon(Icons.verified,
                                        size: 18,
                                        color: RemedooTheme.primary),
                                  FavoriteButton(
                                      favKey: 'lab:${l.id}'),
                                ],
                              ),
                              Text(l.location,
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
                          RatingPill(rating: l.rating),
                          const SizedBox(width: 8),
                          _miniChip(
                              '${l.distanceKm.toStringAsFixed(1)} km'),
                          const SizedBox(width: 8),
                          _miniChip('Report in ${l.turnaround}'),
                          const SizedBox(width: 8),
                          _miniChip('${l.testCount} tests'),
                          if (l.nabl) ...[
                            const SizedBox(width: 8),
                            _miniChip('NABL'),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _compareA =
                            _compareA?.id == l.id ? null : l),
                        child: Text(_compareA?.id == l.id
                            ? 'Cancel compare'
                            : 'Compare'),
                      ),
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

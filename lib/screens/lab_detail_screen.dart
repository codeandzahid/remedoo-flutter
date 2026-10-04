import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../responsive/animations.dart';
import '../theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'booking_screen.dart';

const _testSortOptions = [
  'Relevance',
  'Price: Low to High',
  'Price: High to Low',
  'Name: A to Z',
];

/// Lab detail: hero header, overlapping info card, category chips, expandable
/// test catalogue with ADD selection, sticky book button — matches LabDetail.tsx.
class LabDetailScreen extends StatefulWidget {
  final Lab lab;

  const LabDetailScreen({super.key, required this.lab});

  @override
  State<LabDetailScreen> createState() => _LabDetailScreenState();
}

class _LabDetailScreenState extends State<LabDetailScreen> {
  final Set<String> _selected = {};
  final _search = TextEditingController();
  String _category = 'All';
  String _sort = _testSortOptions.first;
  String? _expanded;
  bool _showSearch = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _book(List<LabTest> selectedTests, double total) {
    final l = widget.lab;
    pushPage(
      context,
      BookingScreen(
        kind: 'lab',
        refId: l.id,
        title: l.name,
        subtitle: '${selectedTests.length} tests • Home collection',
        place: l.location,
        fee: total,
        tests: selectedTests,
      ),
    );
  }

  List<LabTest> _tests() {
    var tests = labTests.take(12).toList();
    if (_category != 'All') {
      tests = tests.where((t) => t.category == _category).toList();
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      tests = tests
          .where((t) =>
              t.name.toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q))
          .toList();
    }
    switch (_sort) {
      case 'Price: Low to High':
        tests.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        tests.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Name: A to Z':
        tests.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return tests;
  }

  @override
  Widget build(BuildContext context) {
    if (!AppStateScope.of(context).isSignedIn) {
      return const GuestGate(message: 'Please login to view details');
    }
    final l = widget.lab;
    final tests = _tests();
    final selectedTests =
        tests.where((t) => _selected.contains(t.id)).toList();
    final total = selectedTests.fold<double>(0, (s, t) => s + t.price);
    final categories = [
      'All',
      ...{for (final t in labTests.take(12)) t.category}
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _hero(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _infoCard(l),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showSearch) ...[
                      RSearchBar(
                        hint: 'Search tests in this lab…',
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _categoryChips(categories),
                    const SizedBox(height: 10),
                    _sortRow(tests.length),
                    const SizedBox(height: 8),
                    if (tests.isEmpty)
                      const REmptyState(
                        icon: Icons.science_outlined,
                        title: 'No tests found',
                        subtitle: 'Try a different search or category',
                      )
                    else
                      for (var i = 0; i < tests.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: StaggerItem(
                            index: i % 6,
                            child: _testCard(tests[i]),
                          ),
                        ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: RButton(
            label: selectedTests.isEmpty
                ? 'Select tests to book'
                : 'Book ${selectedTests.length} Tests • ${inr(total)}',
            icon: Icons.calendar_month_outlined,
            fullWidth: true,
            onPressed: selectedTests.isEmpty
                ? null
                : () => _book(selectedTests, total),
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 150,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [RemedooTheme.darkSecondary, RemedooTheme.darkCard]
                    : [
                        const Color(0xFFD9EFE9),
                        const Color(0xFFEFF8F4),
                      ],
              ),
            ),
            child: const Center(
              child: Text('🔬',
                  style: TextStyle(fontSize: 48)),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _CircleBtn(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const Spacer(),
                  _CircleBtn(
                    icon: _showSearch ? Icons.close : Icons.search,
                    onTap: () =>
                        setState(() => _showSearch = !_showSearch),
                  ),
                  const SizedBox(width: 8),
                  _CircleBtn(
                    child: FavoriteButton(favKey: 'lab:${widget.lab.id}'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(Lab l) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(l.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                        ),
                        if (l.verified) ...[
                          const SizedBox(width: 5),
                          Icon(Icons.verified,
                              size: 18,
                              color: RemedooTheme.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13, color: scheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(l.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        RStat(
                            icon: Icons.access_time,
                            text: 'Report in ${l.turnaround}'),
                        RStat(
                            icon: Icons.science_outlined,
                            text: '${l.testCount} tests'),
                        if (l.offers > 0)
                          Text('${l.offers} offers',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              RRatingPill(rating: l.rating),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      style: BorderStyle.solid)),
            ),
            child: Row(
              children: [
                Icon(Icons.navigation_outlined,
                    size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Text('Get Directions',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary)),
                const Spacer(),
                if (l.nabl) const StatusChip(status: 'NABL Accredited'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChips(List<String> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: RFilterChip(
                    label: c,
                    selected: _category == c,
                    onTap: () => setState(() => _category = c),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _sortRow(int count) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text('$count tests',
            style: TextStyle(
                fontSize: 12, color: scheme.onSurfaceVariant)),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sort,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down,
                  size: 15, color: scheme.onSurfaceVariant),
              style: TextStyle(
                fontFamily: RemedooTheme.fontFamily,
                fontSize: 12,
                color: scheme.onSurface,
              ),
              items: _testSortOptions
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _sort = v ?? _testSortOptions.first),
            ),
          ),
        ),
      ],
    );
  }

  Widget _testCard(LabTest t) {
    final scheme = Theme.of(context).colorScheme;
    final sel = _selected.contains(t.id);
    final expanded = _expanded == t.id;
    return RCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(RemedooRadius.card),
            onTap: () =>
                setState(() => _expanded = expanded ? null : t.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: RemedooTheme.accent.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(_categoryEmoji(t.category),
                          style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(t.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5)),
                                  Text(t.category,
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          color:
                                              scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(inr(t.price),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 30,
                              child: sel
                                  ? RButton(
                                      label: 'ADDED',
                                      small: true,
                                      onPressed: () => setState(() =>
                                          _selected.remove(t.id)),
                                    )
                                  : RButton(
                                      label: 'ADD',
                                      small: true,
                                      variant: RButtonVariant.outline,
                                      onPressed: () => setState(() =>
                                          _selected.add(t.id)),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            RStat(
                                icon: Icons.access_time,
                                text: 'Report in ${t.turnaround}'),
                            const SizedBox(width: 10),
                            RStat(
                                icon: Icons.home_outlined,
                                text: 'Home collection'),
                            const Spacer(),
                            Icon(
                                expanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 18,
                                color: scheme.onSurfaceVariant),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _detailBlock(
                      context,
                      Icons.info_outline,
                      'About This Test',
                      'The ${t.name} is a ${t.category.toLowerCase()} test. '
                      'Reports are typically available within ${t.turnaround}.'),
                  _detailBlock(
                      context,
                      Icons.warning_amber_outlined,
                      'Before the Test',
                      'Carry a valid ID and your prescription (if any). '
                      'Inform the lab about any medications you are taking.'),
                  _detailBlock(
                      context,
                      Icons.check_circle_outline,
                      'After the Test',
                      'You can resume normal activities immediately. '
                      'Consult your doctor to interpret the results — do not self-diagnose.'),
                ],
              ),
            )

        ],
      ),
    );
  }

  Widget _detailBlock(
      BuildContext context, IconData icon, String title, String body) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text(body,
              style: TextStyle(
                  fontSize: 12.5, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _categoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'blood test':
        return '🩸';
      case 'diabetes':
        return '💉';
      case 'cardiac':
        return '❤️';
      case 'thyroid':
        return '🦋';
      case 'vitamin':
        return '🌿';
      case 'imaging':
        return '📷';
      default:
        return '🧬';
    }
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;

  const _CircleBtn({this.icon, this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      width: 38,
      height: 38,
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
        child: child ?? Icon(icon, size: 19, color: Colors.black87),
      ),
    );
    if (onTap == null) return btn;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: btn,
      ),
    );
  }
}

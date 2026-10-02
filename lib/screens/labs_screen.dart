import 'package:flutter/material.dart';

import '../models.dart';
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
  Lab? _compareA;

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

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = _filtered(state);
    return Scaffold(
      appBar: AppBar(title: const Text('Labs & Diagnostics')),
      body: Column(
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
                        color: Colors.white, fontWeight: FontWeight.w700),
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
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.science,
                    title: 'No labs found',
                    subtitle: 'Try a different search or filter.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _card(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(Lab l) {
    final comparing = _compareA != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (comparing && _compareA!.id != l.id) {
            LabCompareSheet.show(context, _compareA!, l);
            setState(() => _compareA = null);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LabDetailScreen(lab: l)),
            );
          }
        },
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: RemedooTheme.teal,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
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
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: RemedooTheme.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.science,
                        color: RemedooTheme.teal, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(l.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ),
                            if (l.verified)
                              const Icon(Icons.verified,
                                  size: 18,
                                  color: RemedooTheme.primary),
                            FavoriteButton(favKey: 'lab:${l.id}'),
                          ],
                        ),
                        Text(l.location,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            RatingPill(rating: l.rating),
                            _miniChip(
                                '${l.distanceKm.toStringAsFixed(1)} km'),
                            _miniChip('Report in ${l.turnaround}'),
                            _miniChip('${l.testCount} tests'),
                            if (l.nabl) _miniChip('NABL'),
                          ],
                        ),
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
                ],
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

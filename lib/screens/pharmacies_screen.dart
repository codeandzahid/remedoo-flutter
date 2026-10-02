import 'package:flutter/material.dart';

import '../models.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = _filtered(state);
    return Scaffold(
      appBar: AppBar(title: const Text('Medicines & More')),
      body: Column(
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RemedooPharmacyScreen()),
              ),
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
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.medication,
                    title: 'No pharmacies found',
                    subtitle: 'Try a different search or filter.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _card(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(Pharmacy p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PharmacyDetailScreen(pharmacy: p)),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: RemedooTheme.purple,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
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
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
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
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            RatingPill(rating: p.rating),
                            _miniChip(p.deliveryTime),
                            _miniChip('${p.itemCount} items'),
                            _miniChip(
                                '${p.distanceKm.toStringAsFixed(1)} km'),
                          ],
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

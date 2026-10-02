import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'hospital_detail_screen.dart';
import 'booking_screen.dart';

const _sortOptions = [
  'Relevance',
  'Rating High→Low',
  'Distance Nearest',
  'Beds Most',
];

/// Hospital directory with search, filters and sorting.
class HospitalsScreen extends StatefulWidget {
  const HospitalsScreen({super.key});

  @override
  State<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends State<HospitalsScreen> {
  final _search = TextEditingController();
  String _sort = _sortOptions.first;
  bool _rating4 = false;
  bool _icu = false;
  bool _govt = false;
  bool _nearest = false;

  @override
  void dispose() {
    _search.dispose();
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
    if (_rating4) list = list.where((h) => h.rating >= 4.0).toList();
    if (_icu) list = list.where((h) => h.hasIcu).toList();
    if (_govt) list = list.where((h) => h.government).toList();
    switch (_sort) {
      case 'Rating High→Low':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Distance Nearest':
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case 'Beds Most':
        list.sort((a, b) => b.beds.compareTo(a.beds));
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
      appBar: AppBar(title: const Text('Hospitals')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search hospitals…',
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
                  label: const Text('Has ICU'),
                  selected: _icu,
                  onSelected: (v) => setState(() => _icu = v),
                ),
                FilterChip(
                  label: const Text('Government'),
                  selected: _govt,
                  onSelected: (v) => setState(() => _govt = v),
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
                Icon(Icons.health_and_safety, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Free health checkup on your first hospital visit!',
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
                '${list.length} hospitals near you',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.local_hospital,
                    title: 'No hospitals found',
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

  Widget _card(Hospital h) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => HospitalDetailScreen(hospital: h)),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: RemedooTheme.headerGradient,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  h.government
                      ? 'Government Hospital'
                      : 'ICU Available 24/7',
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
                      color: RemedooTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.local_hospital,
                        color: RemedooTheme.primary, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(h.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ),
                            if (h.verified)
                              const Icon(Icons.verified,
                                  size: 18,
                                  color: RemedooTheme.primary),
                            FavoriteButton(
                                favKey: 'hospital:${h.id}'),
                          ],
                        ),
                        Text(h.location,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            RatingPill(rating: h.rating),
                            _miniChip('${h.beds} beds'),
                            if (h.hasIcu) _miniChip('ICU'),
                            _miniChip(
                                '${h.distanceKm.toStringAsFixed(1)} km'),
                            _miniChip('${h.waitMin} min wait'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookingScreen(
                                  kind: 'hospital',
                                  refId: h.id,
                                  title: h.name,
                                  subtitle: 'General Consultation',
                                  place: h.location,
                                  fee: 300,
                                ),
                              ),
                            ),
                            child: const Text('Book Appointment'),
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

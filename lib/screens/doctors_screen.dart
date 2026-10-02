import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'doctor_detail_screen.dart';

const _specialties = [
  'All',
  'General Physician',
  'Cardiologist',
  'Dermatologist',
  'Pediatrician',
  'Orthopedic',
  'Gynecologist',
  'Neurologist',
  'ENT Specialist',
  'Ophthalmologist',
  'Psychiatrist',
  'Dentist',
  'Pulmonologist',
];

const _sortOptions = [
  'Relevance',
  'Rating High→Low',
  'Distance Nearest',
  'Fee Low→High',
  'Fee High→Low',
  'Experience',
];

/// Doctor directory with search, filters and sorting.
class DoctorsScreen extends StatefulWidget {
  final String initialQuery;

  const DoctorsScreen({super.key, this.initialQuery = ''});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  late final TextEditingController _search;
  String _specialty = 'All';
  String _sort = _sortOptions.first;
  bool _rating4 = false;
  bool _lowFee = false;
  bool _nearest = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Doctor> _filtered(AppState state) {
    var list = state.activeDoctors.toList();
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((d) =>
              d.name.toLowerCase().contains(q) ||
              d.specialty.toLowerCase().contains(q) ||
              d.hospital.toLowerCase().contains(q))
          .toList();
    }
    if (_specialty != 'All') {
      list = list.where((d) => d.specialty == _specialty).toList();
    }
    if (_rating4) list = list.where((d) => d.rating >= 4.0).toList();
    switch (_sort) {
      case 'Rating High→Low':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Distance Nearest':
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case 'Fee Low→High':
        list.sort((a, b) => a.fee.compareTo(b.fee));
        break;
      case 'Fee High→Low':
        list.sort((a, b) => b.fee.compareTo(a.fee));
        break;
      case 'Experience':
        list.sort((a, b) => b.expYears.compareTo(a.expYears));
        break;
    }
    if (_lowFee) list.sort((a, b) => a.fee.compareTo(b.fee));
    if (_nearest) list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = _filtered(state);
    return Scaffold(
      appBar: AppBar(title: const Text('Find Doctors')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search doctors, specialties…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _specialties.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _specialties[i];
                final sel = s == _specialty;
                return Center(
                  child: ChoiceChip(
                    label: Text(s),
                    selected: sel,
                    onSelected: (_) => setState(() => _specialty = s),
                    selectedColor: RemedooTheme.primary,
                    labelStyle: TextStyle(
                        color: sel
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sort,
                    decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12)),
                    items: _sortOptions
                        .map((o) =>
                            DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _sort = v ?? _sortOptions.first),
                  ),
                ),
              ],
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
                  label: const Text('Fee Low-High'),
                  selected: _lowFee,
                  onSelected: (v) => setState(() => _lowFee = v),
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
                Icon(Icons.local_offer, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Flat 30% OFF on your first consultation!',
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
                '${list.length} doctors available',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.person_search,
                    title: 'No doctors found',
                    subtitle: 'Try a different search or filter.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) =>
                        _doctorCard(list[i], state),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _doctorCard(Doctor d, AppState state) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DoctorDetailScreen(doctor: d)),
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
                  'Consultation fee ${inr(d.fee)}',
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
                  InitialsAvatar(name: d.name, radius: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(d.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ),
                            if (d.verified)
                              const Icon(Icons.verified,
                                  size: 18,
                                  color: RemedooTheme.primary),
                            FavoriteButton(
                                favKey: 'doctor:${d.id}'),
                          ],
                        ),
                        Text(d.specialty,
                            style: const TextStyle(
                                color: RemedooTheme.primary,
                                fontWeight: FontWeight.w600)),
                        Text(d.hospital,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            RatingPill(rating: d.rating),
                            _miniChip('${d.expYears} yrs exp'),
                            _miniChip('${d.waitMin} min wait'),
                            _miniChip(
                                '${d.distanceKm.toStringAsFixed(1)} km'),
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

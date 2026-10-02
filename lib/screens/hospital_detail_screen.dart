import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'booking_screen.dart';
import 'doctor_detail_screen.dart';

const _departments = [
  'Emergency',
  'Cardiology',
  'Orthopedics',
  'Pediatrics',
  'Gynecology',
  'Neurology',
  'Radiology',
];

const _facilities = [
  '24x7 Emergency',
  'ICU & Ventilators',
  'Pharmacy',
  'Pathology Lab',
  'Ambulance',
  'Cafeteria',
  'Parking',
  'Blood Bank',
];

/// Hospital detail: departments, facilities, doctors, sticky booking.
class HospitalDetailScreen extends StatelessWidget {
  final Hospital hospital;

  const HospitalDetailScreen({super.key, required this.hospital});

  void _book(BuildContext context, Hospital h) {
    pushPage(
      context,
      BookingScreen(
        kind: 'hospital',
        refId: h.id,
        title: h.name,
        subtitle: 'General Consultation',
        place: h.location,
        fee: 300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = hospital;
    final docs = doctors.where((d) => d.hospital == h.name).take(6).toList();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 170,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'hospital-image-${h.id}',
                child: Container(
                  decoration: const BoxDecoration(
                      gradient: RemedooTheme.headerGradient),
                  child: const Center(
                    child: Icon(Icons.local_hospital,
                        color: Colors.white54, size: 80),
                  ),
                ),
              ),
              title: Text(h.name),
            ),
            actions: [FavoriteButton(favKey: 'hospital:${h.id}')],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: context.isCompact
                  ? _mainInfo(context, h, docs)
                  : DetailSplit(
                      main: _mainInfo(context, h, docs),
                      side: _bookPanel(context, h),
                    ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: FilledButton(
            onPressed: () => _book(context, h),
            child: const Text('Book Appointment'),
          ),
        ),
      ),
    );
  }

  Widget _mainInfo(BuildContext context, Hospital h, List<Doctor> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RatingPill(rating: h.rating),
            const SizedBox(width: 8),
            if (h.verified)
              const Row(
                children: [
                  Icon(Icons.verified,
                      size: 16, color: RemedooTheme.primary),
                  SizedBox(width: 4),
                  Text('Verified',
                      style: TextStyle(
                          color: RemedooTheme.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            const Spacer(),
            Text('${h.distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on,
                size: 18, color: RemedooTheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(h.location,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _fact('${h.beds}', 'Beds'),
                _fact(h.hasIcu ? 'Yes' : 'No', 'ICU'),
                _fact('${h.waitMin} min', 'Avg. wait'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Departments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _departments.map((d) => Chip(label: Text(d))).toList(),
        ),
        const SizedBox(height: 16),
        const Text('Facilities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ..._facilities.map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 18, color: RemedooTheme.ratingGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(f,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 16),
        if (docs.isNotEmpty) ...[
          SectionHeader(
            title: 'Doctors here',
            actionLabel: '${docs.length} doctors',
          ),
          const SizedBox(height: 8),
          ...docs.map((d) => Card(
                child: ListTile(
                  leading: InitialsAvatar(name: d.name, radius: 22),
                  title: Text(d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(d.specialty,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: RatingPill(rating: d.rating),
                  onTap: () =>
                      pushPage(context, DoctorDetailScreen(doctor: d)),
                ),
              )),
        ],
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _bookPanel(BuildContext context, Hospital h) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Book a visit',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('General Consultation')),
                Text(inr(300),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: RemedooTheme.primary)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Free health checkup on your first visit.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            BigTargetButton(
              onPressed: () => _book(context, h),
              child: const Text('Book Appointment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fact(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

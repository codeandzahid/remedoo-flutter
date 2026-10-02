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

/// Hospital detail: hero card, stats, departments, doctors, hours —
/// reskinned to match HospitalDetail.tsx.
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        top: true,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _topBar(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
      ),
      bottomNavigationBar: h.government
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              color: scheme.surface,
              child: SafeArea(
                child: RButton(
                  label: 'Book Appointment',
                  icon: Icons.calendar_month_outlined,
                  fullWidth: true,
                  onPressed: () => _book(context, h),
                ),
              ),
            ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _BackCircle(onTap: () => Navigator.maybePop(context)),
          const SizedBox(width: 12),
          const Text('Hospital Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          _FavCircle(favKey: 'hospital:${hospital.id}'),
        ],
      ),
    );
  }

  Widget _mainInfo(BuildContext context, Hospital h, List<Doctor> docs) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RCard(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child:
                          Text('🏥', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(h.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800)),
                            ),
                            if (h.verified) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified,
                                  size: 18,
                                  color: RemedooTheme.primary),
                            ],
                          ],
                        ),
                        if (h.government)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_outlined,
                                    size: 11, color: scheme.primary),
                                const SizedBox(width: 4),
                                Text('GOVT',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 13,
                                color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(h.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 15, color: RemedooTheme.warning),
                            const SizedBox(width: 4),
                            Text(h.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  children: [
                    _stat(context, Icons.bed_outlined, '${h.beds}',
                        'Beds Available'),
                    _stat(context, Icons.shield_outlined,
                        h.hasIcu ? '${h.beds ~/ 10}' : '0', 'ICU Beds'),
                    _stat(context, Icons.people_outline,
                        '${docs.length}', 'Doctors'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 15, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text('1800-123-4567',
                      style: TextStyle(
                          fontSize: 13,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 18),
                  const Icon(Icons.phone_outlined,
                      size: 15, color: RemedooTheme.emergency),
                  const SizedBox(width: 6),
                  const Text('Emergency',
                      style: TextStyle(
                          fontSize: 13,
                          color: RemedooTheme.emergency,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.business_outlined,
                      size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('Departments (${_departments.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _departments
                    .map((d) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: RemedooTheme.accent
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people_outline,
                      size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('Doctors (${docs.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                Text('No doctors listed yet.',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 13))
              else
                ...docs.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: scheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: Theme.of(context).dividerColor),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => pushPage(
                              context, DoctorDetailScreen(doctor: d)),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                InitialsAvatar(
                                    name: d.name, radius: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(d.name,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w700,
                                              fontSize: 14)),
                                      Text(d.specialty,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.primary,
                                              fontWeight:
                                                  FontWeight.w600)),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(Icons.star,
                                              size: 12,
                                              color:
                                                  RemedooTheme.warning),
                                          const SizedBox(width: 3),
                                          Text(
                                              d.rating.toStringAsFixed(1),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: scheme
                                                      .onSurfaceVariant)),
                                          const SizedBox(width: 8),
                                          Text(inr(d.fee),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w700)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Text('Working Hours',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 10),
              ...[
                ('Monday – Friday', '9:00 AM – 8:00 PM'),
                ('Saturday', '9:00 AM – 2:00 PM'),
                ('Sunday', 'Emergency only'),
              ].map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(e.$1,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant)),
                        ),
                        Text(e.$2,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.navigation_outlined,
                      size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Text('Location',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              Text(h.location,
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              RButton(
                label: 'Get Directions',
                icon: Icons.navigation_outlined,
                variant: RButtonVariant.outline,
                small: true,
                fullWidth: true,
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Directions'),
                    content: const Text('Opening maps… (demo)'),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Text('Facilities',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 10),
              ..._facilities.map((f) => Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 17, color: RemedooTheme.success),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(f,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontSize: 13.5)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _stat(
      BuildContext context, IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _bookPanel(BuildContext context, Hospital h) {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Book a visit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
          Text('Free health checkup on your first visit.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          RButton(
            label: 'Book Appointment',
            fullWidth: true,
            onPressed: () => _book(context, h),
          ),
        ],
      ),
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

class _FavCircle extends StatelessWidget {
  final String favKey;

  const _FavCircle({required this.favKey});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: dark
            ? RemedooTheme.darkSecondary
            : RemedooTheme.mutedSurface,
        shape: BoxShape.circle,
      ),
      child: Center(child: FavoriteButton(favKey: favKey)),
    );
  }
}

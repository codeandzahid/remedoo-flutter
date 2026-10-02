import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'booking_screen.dart';

/// Doctor profile: single column on phones, info + booking panel on larger.
class DoctorDetailScreen extends StatelessWidget {
  final Doctor doctor;

  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    final compact = context.isCompact;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        actions: [FavoriteButton(favKey: 'doctor:${d.id}')],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DetailSplit(
            main: Column(
              children: [
                _profileCard(d),
                const SizedBox(height: 12),
                _aboutCard(d),
                const SizedBox(height: 12),
                _hospitalCard(context, d),
                const SizedBox(height: 12),
                _hoursCard(),
              ],
            ),
            side: _bookingPanel(context, d),
          ),
          if (compact) const SizedBox(height: 80),
        ],
      ),
      bottomSheet: compact ? _bookBar(context, d) : null,
    );
  }

  Widget _profileCard(Doctor d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Hero(
              tag: 'doctor-avatar-${d.id}',
              child: InitialsAvatar(name: d.name, radius: 44),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(d.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                if (d.verified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified,
                      color: RemedooTheme.primary),
                ],
              ],
            ),
            Text(d.specialty,
                style: const TextStyle(
                    color: RemedooTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat(RatingPill(rating: d.rating), 'Rating'),
                _stat(
                    Text('${d.expYears} yrs',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800)),
                    'Experience'),
                _stat(
                    Text(inr(d.fee),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: RemedooTheme.primary)),
                    'Fee'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutCard(Doctor d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('About',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(d.about),
          ],
        ),
      ),
    );
  }

  Widget _hospitalCard(BuildContext context, Doctor d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hospital',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            InfoRow(
                icon: Icons.local_hospital,
                label: 'Name',
                value: d.hospital),
            InfoRow(
                icon: Icons.location_on,
                label: 'Address',
                value: 'Main Road, Srinagar'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  showResponsiveDialog(
                    context,
                    (_) => AlertDialog(
                      title: const Text('Directions'),
                      content: const Text(
                          'Opening maps to the hospital… (demo)'),
                      actions: [
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hoursCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Working Hours',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            InfoRow(
                icon: Icons.schedule,
                label: 'Mon – Sat',
                value: '09:00 AM – 05:00 PM'),
            InfoRow(
                icon: Icons.schedule,
                label: 'Sunday',
                value: 'Closed'),
          ],
        ),
      ),
    );
  }

  /// Booking panel: sticky bottom bar on phones, side panel on larger screens.
  Widget _bookingPanel(BuildContext context, Doctor d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Book Appointment',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                RatingPill(rating: d.rating),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${d.expYears} yrs experience',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Consultation fee',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            Text(inr(d.fee),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: RemedooTheme.primary)),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.schedule,
                    size: 16, color: Colors.grey),
                SizedBox(width: 6),
                Expanded(
                    child: Text('Available Mon–Sat, 9 AM – 5 PM',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey))),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => pushPage(
                context,
                BookingScreen(
                  kind: 'doctor',
                  refId: d.id,
                  title: d.name,
                  subtitle: d.specialty,
                  place: d.hospital,
                  fee: d.fee,
                ),
              ),
              child: const Text('Book Appointment'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                showResponsiveDialog(
                  context,
                  (_) => AlertDialog(
                    title: const Text('Call clinic'),
                    content: Text(
                        'Calling ${d.hospital} reception… (demo)'),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.call),
              label: const Text('Call Clinic'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookBar(BuildContext context, Doctor d) {
    return Container(
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
          onPressed: () => pushPage(
            context,
            BookingScreen(
              kind: 'doctor',
              refId: d.id,
              title: d.name,
              subtitle: d.specialty,
              place: d.hospital,
              fee: d.fee,
            ),
          ),
          child: const Text('Book Appointment'),
        ),
      ),
    );
  }

  Widget _stat(Widget value, String label) {
    return Column(
      children: [
        value,
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

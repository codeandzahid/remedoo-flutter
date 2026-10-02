import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'booking_screen.dart';

/// Doctor profile with sticky Book Appointment button.
class DoctorDetailScreen extends StatelessWidget {
  final Doctor doctor;

  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        actions: [FavoriteButton(favKey: 'doctor:${d.id}')],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  InitialsAvatar(name: d.name, radius: 44),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(d.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
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
                      _stat(Text('${d.expYears} yrs',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800)),
                          'Experience'),
                      _stat(Text(inr(d.fee),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: RemedooTheme.primary)),
                          'Fee'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
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
                    label: const Text('Call'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
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
          ),
          const SizedBox(height: 12),
          Card(
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
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Directions'),
                            content: const Text(
                                'Opening maps to the hospital… (demo)'),
                            actions: [
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(context),
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
          ),
          const SizedBox(height: 12),
          Card(
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
          ),
          const SizedBox(height: 80),
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingScreen(
                  kind: 'doctor',
                  refId: d.id,
                  title: d.name,
                  subtitle: d.specialty,
                  place: d.hospital,
                  fee: d.fee,
                ),
              ),
            ),
            child: const Text('Book Appointment'),
          ),
        ),
      ),
    );
  }

  Widget _stat(Widget value, String label) {
    return Column(
      children: [
        value,
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

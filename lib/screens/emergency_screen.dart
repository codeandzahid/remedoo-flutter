import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'booking_screen.dart';

const _contacts = [
  ('Ambulance', '108', Icons.emergency),
  ('Women Helpline', '1091', Icons.woman),
  ('Police', '100', Icons.local_police),
  ('Fire', '101', Icons.local_fire_department),
  ('Child Helpline', '1098', Icons.child_care),
  ('Disaster Mgmt', '1078', Icons.warning),
];

/// Emergency SOS: big red button + quick contacts + nearby hospitals.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nearby = hospitals.take(4).toList();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                    gradient: RemedooTheme.emergencyGradient),
                child: const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Emergency SOS',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                        Text('Help is one tap away',
                            style: TextStyle(
                                color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () => _sosConfirm(context),
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              RemedooTheme.emergencyGradient,
                          boxShadow: [
                            BoxShadow(
                              color: RemedooTheme.emergency
                                  .withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sos,
                                color: Colors.white, size: 52),
                            Text('SOS',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800)),
                            Text('Tap to call 112',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Quick Contacts',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _contacts.length,
                    itemBuilder: (_, i) {
                      final (name, number, icon) = _contacts[i];
                      return InkWell(
                        onTap: () => _callDialog(context, name, number),
                        borderRadius: BorderRadius.circular(16),
                        child: Card(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(icon,
                                  color: RemedooTheme.emergency,
                                  size: 28),
                              const SizedBox(height: 6),
                              Text(name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              Text(number,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: RemedooTheme
                                          .emergency)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Nearby Hospitals',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...nearby.map((h) => Card(
                        margin:
                            const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                      Icons.local_hospital,
                                      color:
                                          RemedooTheme.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(h.name,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight
                                                        .w700)),
                                        Text(
                                            '${h.location} • ${h.distanceKm.toStringAsFixed(1)} km',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  RatingPill(rating: h.rating),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _callDialog(
                                          context,
                                          h.name,
                                          '0194-000000'),
                                      icon: const Icon(
                                          Icons.call,
                                          size: 16),
                                      label:
                                          const Text('Call'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text(
                                              'Directions'),
                                          content: Text(
                                              'Opening maps to ${h.name}… (demo)'),
                                          actions: [
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context),
                                              child:
                                                  const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      icon: const Icon(
                                          Icons.directions,
                                          size: 16),
                                      label: const Text(
                                          'Directions'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () =>
                                          Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              BookingScreen(
                                            kind: 'hospital',
                                            refId: h.id,
                                            title: h.name,
                                            subtitle:
                                                'Emergency Consultation',
                                            place: h.location,
                                            fee: 300,
                                          ),
                                        ),
                                      ),
                                      child:
                                          const Text('Book'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sosConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Call emergency services?'),
        content: const Text(
            'This will dial 112 and share your location with responders. (demo — no actual call is made)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: RemedooTheme.emergency),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'SOS alert sent to nearby responders! (demo)')),
              );
            },
            child: const Text('Call 112'),
          ),
        ],
      ),
    );
  }

  void _callDialog(
      BuildContext context, String name, String number) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Call $name?'),
        content: Text('Dialing $number… (demo)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling $number… (demo)')),
              );
            },
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }
}

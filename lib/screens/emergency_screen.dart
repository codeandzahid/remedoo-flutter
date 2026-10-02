import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'booking_screen.dart';

const _quickContacts = [
  ('Ambulance', '108', Icons.emergency),
  ('Women Helpline', '1091', Icons.woman),
  ('Police', '100', Icons.local_police),
  ('Fire', '101', Icons.local_fire_department),
  ('Child Helpline', '1098', Icons.child_care),
  ('Disaster Mgmt', '1078', Icons.warning),
];

const _emergencyGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFE5484D), Color(0xFFF76B1C)],
);

/// Emergency SOS: gradient banner, big SOS dial, quick contacts,
/// nearby hospitals. React Emergency.tsx replica.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nearby = hospitals.take(4).toList();
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            gradient: _emergencyGradient,
            padding:
                const EdgeInsets.fromLTRB(12, 8, 20, 20),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white),
                  onPressed: () =>
                      Navigator.maybePop(context),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text('Emergency SOS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      Text(
                          'Get help fast when every second counts',
                          style: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: 0.8),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: MaxWidthBox(
              maxWidth: 760,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // Big SOS dial.
                  Center(
                    child: FocusableScale(
                      onTap: () => _sosConfirm(context),
                      child: Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: RemedooTheme.emergency,
                          boxShadow: [
                            BoxShadow(
                              color: RemedooTheme.emergency
                                  .withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber,
                                color: Colors.white, size: 40),
                            SizedBox(height: 6),
                            Text('SOS',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900)),
                            Text('Tap to Call',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Calls 112 · Your location will be shared if available',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RSectionHeader(
                      title: 'Quick Contacts',
                      subtitle: 'Call your emergency contacts'),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: _quickContacts.length,
                    itemBuilder: (_, i) {
                      final name = _quickContacts[i].$1;
                      final number = _quickContacts[i].$2;
                      final icon = _quickContacts[i].$3;
                      return StaggerItem(
                        index: i % 6,
                        child: RCard(
                          onTap: () => _callDialog(
                              context, name, number),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: RemedooTheme.emergency
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(11),
                                ),
                                child: Icon(icon,
                                    color:
                                        RemedooTheme.emergency,
                                    size: 19),
                              ),
                              const SizedBox(height: 6),
                              Text(name,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w700,
                                      fontSize: 13)),
                              Text(number,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  RSectionHeader(
                      title: 'Nearby Hospitals',
                      subtitle: 'Emergency-ready facilities'),
                  const SizedBox(height: 8),
                  ...nearby.asMap().entries.map((e) =>
                      StaggerItem(
                        index: e.key % 6,
                        child: _hospitalCard(context, e.value),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hospitalCard(BuildContext context, Hospital h) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(h.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
                if (h.hasIcu) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: RemedooTheme.success
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ICU',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: RemedooTheme.success)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
                '${h.location} • ${h.distanceKm.toStringAsFixed(1)} km',
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              children: [
                RStat(
                    icon: Icons.star,
                    text: h.rating.toStringAsFixed(1)),
                const SizedBox(width: 14),
                RStat(icon: Icons.hotel, text: '${h.beds} beds'),
                const SizedBox(width: 14),
                RStat(
                    icon: Icons.schedule,
                    text: '${h.waitMin} min wait'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RButton(
                    label: 'Call',
                    icon: Icons.call,
                    variant: RButtonVariant.danger,
                    small: true,
                    onPressed: () =>
                        _callDialog(context, h.name, '0194-000000'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RButton(
                    label: 'Directions',
                    icon: Icons.navigation,
                    small: true,
                    onPressed: () => showResponsiveDialog(
                      context,
                      (_) => AlertDialog(
                        title: const Text('Directions'),
                        content: Text(
                            'Opening maps to ${h.name}… (demo)'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RButton(
                    label: 'Book',
                    icon: Icons.calendar_month,
                    variant: RButtonVariant.outline,
                    small: true,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingScreen(
                          kind: 'hospital',
                          refId: h.id,
                          title: h.name,
                          subtitle: 'Emergency Consultation',
                          place: h.location,
                          fee: 300,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sosConfirm(BuildContext context) {
    showResponsiveDialog(
      context,
      (_) => AlertDialog(
        title: const Text('Call emergency services?'),
        content: const Text(
            'This will dial 112 and share your location with responders. (demo — no actual call is made)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          RButton(
            label: 'Call 112',
            variant: RButtonVariant.danger,
            small: true,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'SOS sent to responders (demo).')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _callDialog(
      BuildContext context, String name, String number) {
    showResponsiveDialog(
      context,
      (_) => AlertDialog(
        title: Text('Call $name?'),
        content: Text(number),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          RButton(
            label: 'Call',
            small: true,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Calling $number… (demo)')),
              );
            },
          ),
        ],
      ),
    );
  }
}

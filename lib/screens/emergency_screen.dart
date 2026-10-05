import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/device_actions.dart';
import '../widgets/widgets.dart';
import 'booking_screen.dart';
import '../app_navigator.dart';

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
  colors: [Color(0xFFE5484D), Color(0xFFC81E1E)],
);

/// Emergency SOS: gradient banner, big SOS dial, quick contacts,
/// nearby hospitals. React Emergency.tsx replica.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('ambulance')) return Icons.emergency;
    if (l.contains('women')) return Icons.woman;
    if (l.contains('police')) return Icons.local_police;
    if (l.contains('fire')) return Icons.local_fire_department;
    if (l.contains('child')) return Icons.child_care;
    if (l.contains('disaster')) return Icons.warning;
    return Icons.phone;
  }

  @override
  Widget build(BuildContext context) {
    final nearby = hospitals.take(4).toList();
    // Quick contacts are admin-controlled (Settings > App Settings >
    // Emergency Numbers); fall back to the built-in list.
    final state = AppStateScope.of(context);
    final contacts = state.emergencyNumbers.isNotEmpty
        ? state.emergencyNumbers
        : _quickContacts.map((c) => (c.$1, c.$2)).toList();
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
                      goBack(context),
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
                      'Calls ${contacts.isNotEmpty ? contacts.first.$2 : '112'} · Your location will be shared if available',
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
                    itemCount: contacts.length,
                    itemBuilder: (_, i) {
                      final name = contacts[i].$1;
                      final number = contacts[i].$2;
                      final icon = _iconFor(name);
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
      margin: const EdgeInsets.only(bottom: 8),
      child: RCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(h.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ),
                      if (h.hasIcu) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
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
                  const SizedBox(height: 3),
                  Text(
                      '${h.location} \u2022 ${h.distanceKm.toStringAsFixed(1)} km \u2022 '
                      '\u2605 ${h.rating.toStringAsFixed(1)} \u2022 ${h.beds} beds \u2022 '
                      '${h.waitMin} min wait',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RButton(
                  label: 'Call',
                  icon: Icons.call,
                  variant: RButtonVariant.danger,
                  small: true,
                  onPressed: () =>
                      _callDialog(context, h.name, '0194-000000'),
                ),
                if (AppStateScope.of(context).isSignedIn) ...[
                  const SizedBox(height: 6),
                  RButton(
                    label: 'Book',
                    icon: Icons.calendar_month,
                    variant: RButtonVariant.outline,
                    small: true,
                    onPressed: () {
                      if (!checkLogin(
                          context, 'Please login to book appointments')) {
                        return;
                      }
                      Navigator.push(
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
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _sosConfirm(BuildContext context) {
    final state = AppStateScope.of(context);
    final numbers = state.emergencyNumbers;
    final primary = numbers.isNotEmpty ? numbers.first.$2 : '112';
    showResponsiveDialog(
      context,
      (_) => AlertDialog(
        title: const Text('Call emergency services?'),
        content: Text(
            'This will dial $primary now. ${state.sosMessage}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          RButton(
            label: 'Call $primary',
            variant: RButtonVariant.danger,
            small: true,
            onPressed: () {
              Navigator.pop(context);
              dialNumber(context, primary);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Dialing $primary…')),
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
              dialNumber(context, number);
            },
          ),
        ],
      ),
    );
  }
}

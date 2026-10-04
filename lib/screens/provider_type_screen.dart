import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../theme.dart';
import 'provider_register_screen.dart';

/// First step of provider onboarding: choose which type of provider
/// to register as. Tapping a card opens the registration form.
class ProviderTypeScreen extends StatelessWidget {
  const ProviderTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final types = [
      _ProviderType(
        title: 'Doctor',
        subtitle: 'Individual medical practitioner',
        icon: Icons.medical_services_outlined,
        color: scheme.primary,
        route: 'doctor',
      ),
      _ProviderType(
        title: 'Hospital',
        subtitle: 'Hospital or clinic facility',
        icon: Icons.local_hospital_outlined,
        color: RemedooTheme.emergency,
        route: 'hospital',
      ),
      _ProviderType(
        title: 'Lab',
        subtitle: 'Diagnostic laboratory',
        icon: Icons.science_outlined,
        color: RemedooTheme.success,
        route: 'lab',
      ),
      _ProviderType(
        title: 'Pharmacy',
        subtitle: 'Medicine store or pharmacy',
        icon: Icons.medication_outlined,
        color: RemedooTheme.warning,
        route: 'pharmacy',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: const Text(
          'Join as Provider',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primary.withValues(alpha: 0.08),
              scheme.surface,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: MaxWidthBox(
            maxWidth: 520,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'What best describes you?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose your provider type to start registration.',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                for (final t in types) ...[
                  _TypeCard(type: t),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                Text(
                  'After registration, our team verifies your details. Once approved, you can set up UPI payments to receive money directly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderType {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _ProviderType({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _TypeCard extends StatelessWidget {
  final _ProviderType type;

  const _TypeCard({required this.type});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderRegisterScreen(providerType: type.route),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: type.color.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: type.color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: type.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(type.icon,
                  color: type.color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    type.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

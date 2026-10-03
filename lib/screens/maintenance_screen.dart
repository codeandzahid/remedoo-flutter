import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// "Under Maintenance" with Refresh Page.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: MaxWidthBox(
          maxWidth: 480,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: RemedooTheme.primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Icon(Icons.handyman_outlined,
                      size: 56, color: RemedooTheme.primary),
                ),
                const SizedBox(height: 24),
                const Text("We'll Be Right Back",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(
                  'Remedoo is undergoing scheduled maintenance to serve you better. '
                  'We should be back shortly — please check back in a few minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                RButton(
                  label: 'Refresh Page',
                  icon: Icons.refresh,
                  onPressed: () {
                    AppStateScope.of(context)
                        .setMaintenanceMode(false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

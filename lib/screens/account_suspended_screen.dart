import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Shown instead of any shell when the signed-in account's profile
/// is marked 'suspended' (Admin > Users). Full-check fix 2026-10-22:
/// the status used to be written but never read, so "suspended"
/// accounts signed in and used the app normally.
class AccountSuspendedScreen extends StatelessWidget {
  const AccountSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: RemedooTheme.emergency.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.block_rounded,
                        size: 44, color: RemedooTheme.emergency),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Account Suspended',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your account has been suspended by the Remedoo '
                    'team, so you cannot use the app right now.\n\n'
                    'If you think this is a mistake, please contact '
                    'support and we will review it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  RButton(
                    label: 'Log Out',
                    icon: Icons.logout_rounded,
                    variant: RButtonVariant.danger,
                    onPressed: () =>
                        AppStateScope.of(context).logout(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/account_deletion.dart';
import '../widgets/provider_payments.dart';
import '../widgets/widgets.dart';

/// Shown instead of the app when a signed-in account is scheduled
/// for deletion (owner order 2026-10-22). The account is closed:
/// nothing of the app opens. The user sees when everything will be
/// erased forever and can ask support to reactivate the account —
/// the request goes out only after an email OTP, so only the real
/// account owner can send it.
class AccountDeletionPendingScreen extends StatefulWidget {
  const AccountDeletionPendingScreen({super.key});

  @override
  State<AccountDeletionPendingScreen> createState() =>
      _AccountDeletionPendingScreenState();
}

class _AccountDeletionPendingScreenState
    extends State<AccountDeletionPendingScreen> {
  bool _requestSent = false;
  bool _busy = false;

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $h:$mm $ampm';
  }

  Future<void> _askReactivation(AppState state) async {
    final verified = await requireEmailOtp(
      context,
      title: 'Verify it is you',
      message:
          'Enter the code to send your reactivation request to support.',
    );
    if (!verified || !mounted) return;
    setState(() => _busy = true);
    state.addTicket(
      subject: 'Account reactivation request',
      category: 'reactivation',
      description:
          'I want to reactivate my account. It is scheduled for deletion. '
          'My identity was verified with an email OTP from this page.',
      priority: 'high',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _requestSent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final requestedAt = state.deletionRequestedAt;
    final eraseAt = requestedAt == null
        ? null
        : deletionEraseTime(requestedAt.toLocal());
    final hoursLeft = requestedAt == null
        ? 0
        : deletionHoursLeft(requestedAt.toLocal(), DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: MaxWidthBox(
              maxWidth: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.schedule_outlined,
                      size: 56, color: RemedooTheme.destructive),
                  const SizedBox(height: 16),
                  const Text(
                    'Your account is scheduled for deletion',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    eraseAt == null
                        ? 'Everything in your account will be erased from the server forever after 72 hours.'
                        : 'Everything in your account will be erased from the server forever on ${_fmt(eraseAt)} (about $hoursLeft hours left). After that, no one can bring it back.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  if (_requestSent)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:
                            RemedooTheme.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              RemedooTheme.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'Your request was sent to support. When support reactivates your account, you will get an email: your account is back, you can now login again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5),
                      ),
                    )
                  else
                    RButton(
                      label: 'Reactivate my account',
                      icon: Icons.restore,
                      onPressed:
                          _busy ? null : () => _askReactivation(state),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => state.logout(),
                    child: const Text('Log out'),
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

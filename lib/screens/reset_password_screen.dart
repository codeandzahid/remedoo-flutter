import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Set a new password after opening a password-recovery link
/// (React ResetPassword.tsx). The recovery link creates a Supabase session;
/// this screen then updates the password for real.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    if (_p1.text.length < 8) {
      setState(
          () => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (_p1.text != _p2.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await AppStateScope.of(context).updatePassword(_p1.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      setState(() => _error = result.error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Password updated! Please sign in again.')),
    );
    // Drop the recovery session and return to the login screen.
    AppStateScope.of(context).logout();
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: MaxWidthBox(
        maxWidth: 480,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Orange header with rounded bottom.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 60),
              decoration: BoxDecoration(
                gradient: RemedooTheme.headerGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'New Password',
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Set your new password',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Card overlapping the header.
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RTextField(
                        label: 'New Password',
                        hint: 'Min. 8 characters',
                        controller: _p1,
                        obscureText: _obscure,
                        onChanged: (_) => setState(() {}),
                        prefixIcon:
                            const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: 12),
                      RTextField(
                        label: 'Confirm Password',
                        hint: 'Repeat your password',
                        controller: _p2,
                        obscureText: _obscure,
                        prefixIcon:
                            const Icon(Icons.lock_outline, size: 18),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: RemedooTheme.emergency
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: RemedooTheme.emergency
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 18,
                                  color: RemedooTheme.emergency),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: RemedooTheme.emergency,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      RButton(
                        label: _busy ? 'Please wait…' : 'Update Password',
                        fullWidth: true,
                        onPressed: _busy ? null : _update,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

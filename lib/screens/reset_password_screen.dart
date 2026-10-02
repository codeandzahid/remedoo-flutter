import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Set a new password (React ResetPassword.tsx). Demo behavior kept.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
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
              decoration: const BoxDecoration(
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
                        hint: 'Min. 6 characters',
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
                      RButton(
                        label: 'Update Password',
                        fullWidth: true,
                        onPressed: () {
                          if (_p1.text.length < 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Password must be at least 8 characters')),
                            );
                            return;
                          }
                          if (_p1.text != _p2.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Passwords do not match')),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Password reset! Please sign in again.')),
                          );
                          Navigator.popUntil(context, (r) => r.isFirst);
                        },
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

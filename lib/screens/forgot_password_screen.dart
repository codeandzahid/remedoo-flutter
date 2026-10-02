import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'reset_password_screen.dart';

/// "Forgot Password": request a reset link (React ForgotPassword.tsx).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: MaxWidthBox(
        maxWidth: 480,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Curved orange header.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 72),
              decoration: const BoxDecoration(
                gradient: RemedooTheme.headerGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: -70,
                    right: -70,
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.vpn_key_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Forgot Password',
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'We\'ll send you a reset link',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Card overlapping the header.
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RTextField(
                        label: 'Email',
                        hint: 'your@email.com',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon:
                            const Icon(Icons.mail_outline, size: 18),
                      ),
                      const SizedBox(height: 20),
                      RButton(
                        label: 'Send Reset Link',
                        fullWidth: true,
                        onPressed: () {
                          if (_email.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please enter your email')),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Reset link sent! Check your inbox.')),
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ResetPasswordScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Back to login.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back,
                      size: 16, color: scheme.primary),
                  label: Text(
                    'Back to Login',
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

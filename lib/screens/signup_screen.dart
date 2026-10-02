import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// "Create Account" with password strength meter (React Signup.tsx).
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signUp() {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill name and email')),
      );
      return;
    }
    AppStateScope.of(context)
        .login(name: _name.text.trim(), email: _email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pwLen = _password.text.length;
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
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Create Account',
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Join Remedoo today',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Form card overlapping the header.
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
                        label: 'Full Name',
                        hint: 'John Doe',
                        controller: _name,
                        prefixIcon:
                            const Icon(Icons.person_outline, size: 18),
                      ),
                      const SizedBox(height: 12),
                      RTextField(
                        label: 'Email',
                        hint: 'your@email.com',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon:
                            const Icon(Icons.mail_outline, size: 18),
                      ),
                      const SizedBox(height: 12),
                      RTextField(
                        label: 'Password',
                        hint: 'Min. 6 characters',
                        controller: _password,
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
                      // Password strength indicator (React logic).
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(4, (i) {
                          final on = pwLen >= (i + 1) * 3;
                          final color = pwLen >= 12
                              ? RemedooTheme.success
                              : pwLen >= 8
                                  ? RemedooTheme.warning
                                  : RemedooTheme.emergency;
                          return Expanded(
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 200),
                              height: 4,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 3),
                              decoration: BoxDecoration(
                                color: on ? color : scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      RButton(
                        label: 'Sign Up',
                        fullWidth: true,
                        onPressed: _signUp,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            child: Text(
                              'or',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      RButton(
                        label: 'Continue with Google',
                        icon: Icons.g_mobiledata,
                        variant: RButtonVariant.outline,
                        fullWidth: true,
                        onPressed: _signUp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Link back to sign-in.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Sign In',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

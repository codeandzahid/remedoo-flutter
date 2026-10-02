import 'package:flutter/material.dart';

import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'provider_register_screen.dart';
import 'admin/admin_login_screen.dart';

/// "Welcome Back" sign-in with Password / Magic Link tabs (React Login.tsx).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    final state = AppStateScope.of(context);
    final email = _email.text.trim();
    final name = email.contains('@') ? email.split('@')[0] : 'Patient';
    state.login(name: name, email: email);
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
            // Orange curved header with decorative circles.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 48),
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
                  Positioned(
                    bottom: -50,
                    left: -60,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Welcome Back',
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sign in to continue to Remedoo',
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
                child: AnimatedBuilder(
                  animation: _tabs,
                  builder: (_, _) {
                    final magic = _tabs.index == 1;
                    return RCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Segmented mode tabs.
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _modeTab('Password', 0, !magic, scheme),
                                _modeTab('Magic Link', 1, magic, scheme),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          RTextField(
                            label: 'Email',
                            hint: 'your@email.com',
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(
                                Icons.mail_outline, size: 18),
                          ),
                          if (!magic) ...[
                            const SizedBox(height: 12),
                            RTextField(
                              label: 'Password',
                              hint: '••••••••',
                              controller: _password,
                              obscureText: _obscure,
                              prefixIcon: const Icon(
                                  Icons.lock_outline, size: 18),
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
                          ] else ...[
                            const SizedBox(height: 8),
                            Text(
                              'We\'ll send you a magic link — no password needed.',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (!magic)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => pushPage(
                                    context,
                                    const ForgotPasswordScreen()),
                                child: Text(
                                  'Forgot Password?',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 16),
                          RButton(
                            label: magic ? 'Send Magic Link' : 'Sign In',
                            icon: magic ? Icons.auto_awesome : null,
                            fullWidth: true,
                            onPressed: _signIn,
                          ),
                          const SizedBox(height: 12),
                          // "or" divider.
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
                          const SizedBox(height: 12),
                          RButton(
                            label: 'Continue with Google',
                            icon: Icons.g_mobiledata,
                            variant: RButtonVariant.outline,
                            fullWidth: true,
                            onPressed: _signIn,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Bottom actions.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  RButton(
                    label: "Don't have an account? Sign Up",
                    icon: Icons.person_add_outlined,
                    variant: RButtonVariant.outline,
                    fullWidth: true,
                    onPressed: () =>
                        pushPage(context, const SignupScreen()),
                  ),
                  const SizedBox(height: 8),
                  RButton(
                    label: 'Are you a provider? Register',
                    icon: Icons.medical_services_outlined,
                    variant: RButtonVariant.outline,
                    fullWidth: true,
                    onPressed: () =>
                        pushPage(context, const ProviderRegisterScreen()),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () =>
                        AppStateScope.of(context).loginAsGuest(),
                    icon: Icon(Icons.arrow_forward,
                        size: 16, color: scheme.onSurfaceVariant),
                    label: Text(
                      'Skip, continue as guest',
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        pushPage(context, const AdminLoginScreen()),
                    child: Text(
                      'Admin',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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

  Widget _modeTab(
      String label, int index, bool selected, ColorScheme scheme) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabs.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

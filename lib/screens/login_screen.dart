import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'signup_screen.dart';
import 'admin/admin_login_screen.dart';
import 'forgot_password_screen.dart';
import 'provider_type_screen.dart';

/// Modern login screen: branded header with gradient artwork,
/// clean card form, social proof footer.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}


void _push(BuildContext context, Widget page) {
  Navigator.push(
      context, MaterialPageRoute(builder: (_) => page));
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await AppStateScope.of(context).signInWithPassword(
      email: email,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              scheme.surface,
              scheme.surface,
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: MaxWidthBox(
                maxWidth: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    // Brand mark
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.primary,
                              RemedooTheme.primaryDark
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary
                                  .withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.health_and_safety,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to manage your health',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Form card
                    RCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RTextField(
                            label: 'Email',
                            hint: 'you@example.com',
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(
                                Icons.email_outlined,
                                size: 18),
                          ),
                          const SizedBox(height: 14),
                          RTextField(
                            label: 'Password',
                            hint: 'Enter your password',
                            controller: _password,
                            obscureText: _obscure,
                            prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              onPressed: () => setState(
                                  () => _obscure = !_obscure),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: RemedooTheme.emergency
                                    .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      RemedooTheme.emergency,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _push(
                                  context,
                                  const ForgotPasswordScreen()),
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          RButton(
                            label: _busy
                                ? 'Signing in…'
                                : 'Sign In',
                            fullWidth: true,
                            onPressed:
                                _busy ? null : _signIn,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Divider
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: Theme.of(context)
                                    .dividerColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          child: Text(
                            'New here?',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: Theme.of(context)
                                    .dividerColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RButton(
                      label: 'Create Account',
                      fullWidth: true,
                      variant: RButtonVariant.outline,
                      onPressed: () => _push(
                          context, const SignupScreen()),
                    ),
                    const SizedBox(height: 12),
                    // Provider + guest links
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment:
                          WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => _push(
                              context,
                              const ProviderTypeScreen()),
                          child: Text(
                            'Join as Provider',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '·',
                          style: TextStyle(
                              color:
                                  scheme.onSurfaceVariant),
                        ),
                        TextButton(
                          onPressed: () =>
                              AppStateScope.of(context)
                                  .loginAsGuest(),
                          child: Text(
                            'Continue as Guest',
                            style: TextStyle(
                              color:
                                  scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Discreet admin access
                    Center(
                      child: TextButton(
                        onPressed: () => _push(context,
                            const AdminLoginScreen()),
                        child: Text(
                          'Admin Login',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

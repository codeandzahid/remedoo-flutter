import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Modern signup screen matching the login redesign.
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
  bool _busy = false;
  String? _error;
  bool _confirmationSent = false;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  double get _strength {
    final p = _password.text;
    if (p.isEmpty) return 0;
    var s = 0.0;
    if (p.length >= 8) s += 0.35;
    if (p.length >= 12) s += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(p)) s += 0.2;
    if (RegExp(r'[0-9]').hasMatch(p)) s += 0.15;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s += 0.15;
    return s.clamp(0.0, 1.0);
  }

  Future<void> _signUp() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name.');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      setState(
          () => _error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await AppStateScope.of(context).signUpWithPassword(
      name: name,
      email: email,
      password: password,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      setState(() => _error = result.error);
    } else {
      setState(() => _confirmationSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
      ),
      extendBodyBehindAppBar: true,
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
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.primary,
                              RemedooTheme.primaryDark
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary
                                  .withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_add_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Create account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join Remedoo for better healthcare',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_confirmationSent)
                      RCard(
                        child: Column(
                          children: [
                            Icon(
                              Icons.mark_email_read_outlined,
                              size: 48,
                              color: scheme.primary,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Check your email',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'We sent a confirmation link to ${_email.text.trim()}. Tap it to activate your account.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            RButton(
                              label: 'Back to Sign In',
                              fullWidth: true,
                              variant:
                                  RButtonVariant.outline,
                              onPressed: () =>
                                  Navigator.pop(context),
                            ),
                          ],
                        ),
                      )
                    else
                      RCard(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            RTextField(
                              label: 'Full Name',
                              hint: 'Your full name',
                              controller: _name,
                              prefixIcon: const Icon(
                                  Icons.person_outline,
                                  size: 18),
                            ),
                            const SizedBox(height: 14),
                            RTextField(
                              label: 'Email',
                              hint: 'you@example.com',
                              controller: _email,
                              keyboardType:
                                  TextInputType.emailAddress,
                              prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  size: 18),
                            ),
                            const SizedBox(height: 14),
                            RTextField(
                              label: 'Password',
                              hint: 'At least 8 characters',
                              controller: _password,
                              obscureText: _obscure,
                              onChanged: (_) =>
                                  setState(() {}),
                              prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons
                                          .visibility_outlined
                                      : Icons
                                          .visibility_off_outlined,
                                  size: 18,
                                ),
                                onPressed: () => setState(() =>
                                    _obscure = !_obscure),
                              ),
                            ),
                            if (_password
                                .text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(
                                        4),
                                child:
                                    LinearProgressIndicator(
                                  value: _strength,
                                  minHeight: 6,
                                  backgroundColor: scheme
                                      .surfaceContainerHighest,
                                  valueColor:
                                      AlwaysStoppedAnimation(
                                    _strength < 0.4
                                        ? RemedooTheme
                                            .emergency
                                        : _strength < 0.7
                                            ? RemedooTheme
                                                .warning
                                            : RemedooTheme
                                                .success,
                                  ),
                                ),
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding:
                                    const EdgeInsets.all(
                                        10),
                                decoration: BoxDecoration(
                                  color: RemedooTheme
                                      .emergency
                                      .withValues(
                                          alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(
                                          10),
                                ),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: RemedooTheme
                                        .emergency,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            RButton(
                              label: _busy
                                  ? 'Creating…'
                                  : 'Create Account',
                              fullWidth: true,
                              onPressed:
                                  _busy ? null : _signUp,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                scheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context),
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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

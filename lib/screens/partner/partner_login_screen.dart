import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../forgot_password_screen.dart';
import '../provider_type_screen.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Provider sign-in for the Remedoo Partner app.
/// Backed by Supabase Auth + the `user_roles` table.
/// Accepts doctor, pharmacy, lab, or hospital roles.
class PartnerLoginScreen extends StatefulWidget {
  const PartnerLoginScreen({super.key});

  @override
  State<PartnerLoginScreen> createState() => _PartnerLoginScreenState();
}

class _PartnerLoginScreenState extends State<PartnerLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  static const _providerRoles = {'doctor', 'pharmacy', 'lab', 'hospital'};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    AuthResult result;
    try {
      result = await AuthService.instance
          .signIn(email: email, password: _password.text)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Connection timed out. Check your internet and try again.';
      });
      return;
    }
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.error ?? 'Sign-in failed.';
      });
      return;
    }
    // Signed in — check for a provider role. Logins are separate
    // (owner's rule): a non-provider email is signed back out and
    // told exactly what it IS registered as.
    final accountRole = await AuthService.instance.currentAccountRole();
    if (!mounted) return;
    if (accountRole == null || !_providerRoles.contains(accountRole)) {
      await AuthService.instance.signOut();
      setState(() {
        _busy = false;
        _error = accountRole != null
            ? wrongEntranceMessage(accountRole)
            : 'This account is not registered as a provider. Contact Remedoo to get provider access.';
      });
      return;
    }
    final role = accountRole;
    final state = AppStateScope.of(context);
    await state.checkProviderRole();
    state.switchRole(role);
    if (!mounted) return;
    setState(() => _busy = false);
    // PartnerRootGate rebuilds into the right dashboard on role change.
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
              RemedooTheme.teal.withValues(alpha: 0.12),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: RemedooTheme.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.handshake,
                        size: 36,
                        color: RemedooTheme.teal,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Remedoo Partner',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'For doctors, pharmacies, labs & hospitals',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    RCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RTextField(
                            controller: _email,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          RTextField(
                            controller: _password,
                            label: 'Password',
                            obscureText: _obscure,
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _obscure = !_obscure),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: RemedooTheme.destructive
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color:
                                          RemedooTheme.destructive,
                                      fontSize: 13)),
                            ),
                          ],
                          const SizedBox(height: 20),
                          RButton(
                            label: _busy
                                ? 'Signing in…'
                                : 'Sign In',
                            fullWidth: true,
                            onPressed: _busy ? null : _signIn,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ForgotPasswordScreen()),
                                      ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const ProviderTypeScreen()),
                      ),
                      child: const Text(
                        'New provider? Register here',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Only approved providers can sign in here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
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

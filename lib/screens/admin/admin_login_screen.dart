import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Admin sign-in backed by Supabase Auth + the `user_roles` table.
/// Only accounts with the `admin` role can enter the admin panel.
class AdminLoginScreen extends StatefulWidget {
  /// When true, this screen is the app root (admin APK entry): on success
  /// the parent gate rebuilds into the shell instead of popping.
  final bool isRoot;

  const AdminLoginScreen({super.key, this.isRoot = false});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

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
    final result = await AuthService.instance.signIn(
      email: email,
      password: _password.text,
    );
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.error ?? 'Sign-in failed.';
      });
      return;
    }
    // Signed in — now verify the admin role.
    final state = AppStateScope.of(context);
    final isAdmin =
        await AuthService.instance.isCurrentUserAdmin();
    if (!mounted) return;
    if (!isAdmin) {
      await AuthService.instance.signOut();
      state.checkAdminRole();
      setState(() {
        _busy = false;
        _error =
            'This account does not have admin access. Contact the app owner to grant the admin role.';
      });
      return;
    }
    await state.checkAdminRole();
    state.switchRole('admin');
    if (!mounted) return;
    setState(() => _busy = false);
    if (widget.isRoot) {
      // Admin APK entry: AdminRootGate rebuilds into the shell on the
      // role change — nothing to pop.
      return;
    }
    // Pop back to RootGate (through any intermediate login screens),
    // which shows the AdminShell for role=admin.
    Navigator.of(context).popUntil((r) => r.isFirst);
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
              scheme.primary.withValues(alpha: 0.08),
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
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: RemedooTheme.softShadow,
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text('Admin Panel',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface)),
                    const SizedBox(height: 6),
                    Text('Sign in with your admin account',
                        style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    RCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RTextField(
                            label: 'Email',
                            hint: 'admin@remedoo.app',
                            controller: _email,
                            keyboardType:
                                TextInputType.emailAddress,
                            prefixIcon: Icon(Icons.email_outlined,
                                size: 20,
                                color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          RTextField(
                            label: 'Password',
                            hint: '••••••••',
                            controller: _password,
                            obscureText: _obscure,
                            prefixIcon: Icon(Icons.lock_outline,
                                size: 20,
                                color: scheme.onSurfaceVariant),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 20),
                              onPressed: () => setState(
                                  () => _obscure = !_obscure),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding:
                                  const EdgeInsets.all(10),
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
                                : 'Sign In as Admin',
                            fullWidth: true,
                            onPressed:
                                _busy ? null : _signIn,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                        'Only accounts with the admin role can sign in here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant)),
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

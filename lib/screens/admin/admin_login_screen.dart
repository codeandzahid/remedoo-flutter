import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/supabase_config.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/maximal.dart';
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
  String? _diag;

  /// Tests basic connectivity to the Supabase backend and reports details.
  Future<void> _testConnection() async {
    setState(() {
      _diag = 'Testing…';
      _error = null;
    });
    final sb = StringBuffer();
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.headUrl(
          Uri.parse('${SupabaseConfig.url}/rest/v1/'));
      req.headers.set('apikey', 'test');
      final resp =
          await req.close().timeout(const Duration(seconds: 10));
      sb.writeln('Internet: OK (server replied ${resp.statusCode})');
      client.close();
    } catch (e) {
      sb.writeln('Internet: FAILED');
      sb.writeln('$e'.split('\n').first);
    }
    try {
      final inited = AuthService.instance.isInitialized;
      sb.writeln(
          'App backend: ${inited ? 'ready' : 'NOT ready — restart app'}');
    } catch (e) {
      sb.writeln('App backend: error');
    }
    if (mounted) setState(() => _diag = sb.toString().trim());
  }

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
          .signIn(
            email: email,
            password: _password.text,
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            'Connection timed out. Check your internet and tap Test Connection below.';
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
    // Signed in — now verify the admin-side role. This entrance is
    // for the super admin AND staff (employee admin) accounts.
    final state = AppStateScope.of(context);
    final isAdmin =
        await AuthService.instance.isCurrentUserAdmin();
    if (!mounted) return;
    if (!isAdmin) {
      // Staff account? They belong to this entrance too and land in
      // the filtered admin panel.
      final staffSections =
          await state.supabaseRepository.fetchOwnStaffAccess();
      if (!mounted) return;
      if (staffSections != null) {
        await state.checkStaffRole();
        state.switchRole('staff');
        if (!mounted) return;
        setState(() => _busy = false);
        if (widget.isRoot) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
        return;
      }
      // Wrong entrance (owner's rule: logins are separate) — sign
      // back out and name what the email IS registered as.
      final accountRole =
          await AuthService.instance.currentAccountRole();
      await AuthService.instance.signOut();
      state.checkAdminRole();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = accountRole != null
            ? wrongEntranceMessage(accountRole)
            : 'This account does not have admin access. Contact the app owner to grant the admin role.';
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
    // Maximalism (same kit as the admin console): loud saturated
    // backdrop + bold paper form card with ink outlines.
    final base = Theme.of(context);
    OutlineInputBorder fieldBorder(Color c, double w) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    final maxTheme = base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: maxPaper,
        border: fieldBorder(maxInk, 2),
        enabledBorder: fieldBorder(maxInk, 2),
        focusedBorder: fieldBorder(maxPink, 2.5),
      ),
    );
    return MaxScope(
      enabled: true,
      child: Theme(
        data: maxTheme,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              const Positioned.fill(child: MaxBackdrop()),
              SafeArea(
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
                        gradient: const LinearGradient(
                          colors: [maxPink, maxViolet, Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: maxInk, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xE6232038),
                            blurRadius: 0,
                            offset: Offset(4, 4),
                          ),
                        ],
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
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _busy ? null : _testConnection,
                            child: const Text(
                              'Test Connection',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          if (_diag != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: scheme.primary
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Text(_diag!,
                                  style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 12)),
                            ),
                          ],
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
            ],
          ),
        ),
      ),
    );
  }
}

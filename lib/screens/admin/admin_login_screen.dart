import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Admin sign-in (demo credentials).
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController(text: 'admin@remedoo.app');
  final _password = TextEditingController(text: 'admin123');
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    if (_email.text.trim() == 'admin@remedoo.app' &&
        _password.text == 'admin123') {
      final state = AppStateScope.of(context);
      state.login(name: 'Admin', email: 'admin@remedoo.app');
      state.switchRole('admin');
      // Pop back to RootGate, which shows the AdminShell for role=admin.
      Navigator.of(context).pop();
    } else {
      setState(() => _error =
          'Invalid credentials. Try admin@remedoo.app / admin123');
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
                            label: 'Sign In as Admin',
                            fullWidth: true,
                            onPressed: _signIn,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Demo: admin@remedoo.app / admin123',
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

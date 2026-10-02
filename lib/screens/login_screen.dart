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

/// "Welcome Back" sign-in with Password / Magic Link tabs.
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
    return Scaffold(
      body: SafeArea(
        child: MaxWidthBox(
          maxWidth: 480,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              const Center(child: RemedooLogo(size: 72)),
              const SizedBox(height: 16),
              const Center(
                child: Text('Welcome Back',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('Sign in to continue to Remedoo',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              ),
              const SizedBox(height: 24),
              TabBar(
                controller: _tabs,
                labelColor: RemedooTheme.primary,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: RemedooTheme.primary,
                tabs: const [Tab(text: 'Password'), Tab(text: 'Magic Link')],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'EMAIL',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _tabs,
                builder: (_, _) {
                  if (_tabs.index == 1) {
                    return const SizedBox.shrink();
                  }
                  return TextField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'PASSWORD',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => pushPage(
                      context, const ForgotPasswordScreen()),
                  child: const Text('Forgot Password?',
                      style: TextStyle(color: RemedooTheme.primary)),
                ),
              ),
              FilledButton(
                onPressed: _signIn,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 48),
                ),
                child: Text(_tabs.index == 1 ? 'Send Magic Link' : 'Sign In'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _signIn,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  TextButton(
                    onPressed: () =>
                        pushPage(context, const SignupScreen()),
                    child: const Text('Sign Up',
                        style: TextStyle(color: RemedooTheme.primary)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () =>
                    pushPage(context, const ProviderRegisterScreen()),
                child: const Text('Are you a provider? Register',
                    style: TextStyle(color: RemedooTheme.primary)),
              ),
              TextButton(
                onPressed: () =>
                    AppStateScope.of(context).loginAsGuest(),
                child: const Text('Skip, continue as guest →',
                    style: TextStyle(color: RemedooTheme.primary)),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () =>
                      pushPage(context, const AdminLoginScreen()),
                  child: Text('Admin',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

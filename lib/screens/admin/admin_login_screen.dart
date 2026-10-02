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
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Center(child: RemedooLogo(size: 64)),
            const SizedBox(height: 16),
            const Center(
              child: Text('Admin Console',
                  style:
                      TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            const Center(
                child: Text('Manage the Remedoo platform',
                    style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'EMAIL',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
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
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: RemedooTheme.emergency)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _signIn,
              child: const Text('Sign In as Admin'),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text('Demo: admin@remedoo.app / admin123',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

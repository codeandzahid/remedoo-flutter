import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'pending_approval_screen.dart';

const _roles = ['Doctor', 'Hospital', 'Lab', 'Pharmacy', 'Driver'];

/// "Become a Provider" application form.
class ProviderRegisterScreen extends StatefulWidget {
  const ProviderRegisterScreen({super.key});

  @override
  State<ProviderRegisterScreen> createState() =>
      _ProviderRegisterScreenState();
}

class _ProviderRegisterScreenState extends State<ProviderRegisterScreen> {
  String _role = _roles.first;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _license = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _license.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Provider')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Center(child: RemedooLogo(size: 56)),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Join the Remedoo network and reach thousands of patients.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            const Text('I am a',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _roles.map((r) {
                final sel = r == _role;
                return ChoiceChip(
                  label: Text(r),
                  selected: sel,
                  onSelected: (_) => setState(() => _role = r),
                  selectedColor: RemedooTheme.primary,
                  labelStyle: TextStyle(
                      color: sel
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'FULL NAME',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
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
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'PHONE',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _license,
              decoration: const InputDecoration(
                labelText: 'LICENSE / REGISTRATION NUMBER',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (_name.text.trim().isEmpty ||
                    _email.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill name and email')),
                  );
                  return;
                }
                AppStateScope.of(context).submitProviderApplication(
                  name: _name.text.trim(),
                  email: _email.text.trim(),
                  phone: _phone.text.trim(),
                  role: _role,
                  license: _license.text.trim(),
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PendingApprovalScreen()),
                );
              },
              child: const Text('Submit Application'),
            ),
          ],
        ),
      ),
    );
  }
}

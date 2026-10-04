import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'pending_approval_screen.dart';

const _roles = ['Doctor', 'Hospital', 'Lab', 'Pharmacy', 'Driver'];

IconData _roleIcon(String role) {
  switch (role) {
    case 'Doctor':
      return Icons.medical_services_outlined;
    case 'Hospital':
      return Icons.local_hospital_outlined;
    case 'Lab':
      return Icons.science_outlined;
    case 'Pharmacy':
      return Icons.local_pharmacy_outlined;
    case 'Driver':
      return Icons.directions_car_outlined;
    default:
      return Icons.business_outlined;
  }
}

/// "Provider Registration" application form (React ProviderRegister.tsx styling).
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
  final _upiId = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _license.dispose();
    _upiId.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill name and email')),
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
      MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: MaxWidthBox(
        maxWidth: 720,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Orange header with rounded bottom.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 52),
              decoration: BoxDecoration(
                gradient: RemedooTheme.headerGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Provider Registration',
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Join the Remedoo network and reach thousands of patients.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Form card overlapping the header.
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'I want to register as a:',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Provider-type tiles (2-column grid).
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: _roles.length,
                        itemBuilder: (_, i) {
                          final r = _roles[i];
                          final sel = r == _role;
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _role = r),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: sel
                                    ? scheme.primary.withValues(alpha: 0.08)
                                    : scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: sel
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                  width: sel ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _roleIcon(r),
                                    color: scheme.primary,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      r,
                                      style: textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Account Information',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RTextField(
                        label: 'Full Name',
                        hint: 'Your full name',
                        controller: _name,
                        prefixIcon:
                            const Icon(Icons.person_outline, size: 18),
                      ),
                      const SizedBox(height: 12),
                      RTextField(
                        label: 'Email',
                        hint: 'your@email.com',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon:
                            const Icon(Icons.mail_outline, size: 18),
                      ),
                      const SizedBox(height: 12),
                      RTextField(
                        label: 'Phone',
                        hint: '+91 9876543210',
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        prefixIcon:
                            const Icon(Icons.phone_outlined, size: 18),
                      ),
                      const SizedBox(height: 12),
                      RTextField(
                        label: 'License / Registration Number',
                        hint: 'Enter your license number',
                        controller: _license,
                        prefixIcon:
                            const Icon(Icons.badge_outlined, size: 18),
                      ),
                      const SizedBox(height: 12),
                      RTextField(
                        label: 'UPI ID (for receiving payments)',
                        hint: 'yourname@upi',
                        controller: _upiId,
                        prefixIcon:
                            const Icon(Icons.qr_code_2, size: 18),
                      ),
                      const SizedBox(height: 20),
                      RButton(
                        label: 'Submit Registration',
                        fullWidth: true,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Back to sign-in.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Sign In',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
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
}

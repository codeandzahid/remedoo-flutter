import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

/// My Profile: avatar, name/email, phone, gender, address, password section.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String _gender = 'Male';
  bool _loaded = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (state.isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: MaxWidthBox(
          child: REmptyState(
            icon: Icons.person_outline,
            title: 'You are browsing as a guest',
            subtitle: 'Sign in to manage your profile.',
            actionLabel: 'Sign In',
            // Log out of guest mode; RootGate rebuilds straight to LoginScreen.
            onAction: () => state.logout(),
          ),
        ),
      );
    }
    if (!_loaded) {
      _name.text = state.userName;
      _email.text = state.userEmail ?? '';
      _phone.text = state.userPhone ?? '';
      _address.text = state.userAddress ?? '';
      _gender = state.gender.isNotEmpty ? state.gender : 'Male';
      _loaded = true;
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header: back arrow + title, white with bottom border.
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const Text('My Profile',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: MaxWidthBox(
                maxWidth: 720,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    // Avatar + name + email.
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.surfaceContainerHighest,
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                  width: 3,
                                ),
                              ),
                              child: Icon(Icons.person,
                                  size: 52,
                                  color: scheme.onSurfaceVariant),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.surface,
                                  border: Border.all(
                                    color:
                                        Theme.of(context).dividerColor,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.08),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.camera_alt,
                                    size: 15,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _name.text.isEmpty
                              ? state.displayName
                              : _name.text,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.userEmail ?? '',
                          style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                    // Basic info card.
                    RCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RTextField(
                            label: 'Full Name',
                            labelIcon: Icons.person_outline,
                            hint: 'Your full name',
                            controller: _name,
                          ),
                          const SizedBox(height: 18),
                          RTextField(
                            label: 'Email',
                            labelIcon: Icons.mail_outline,
                            controller: _email,
                            enabled: false,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Email cannot be changed',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(height: 18),
                          RTextField(
                            label: 'Phone',
                            labelIcon: Icons.phone_outlined,
                            hint: '+91 98765 43210',
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 14, color: scheme.primary),
                              const SizedBox(width: 6),
                              const Text('Gender',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 18,
                            runSpacing: 12,
                            children: [
                              _genderOption('Male', Icons.man),
                              _genderOption('Female', Icons.woman),
                              _genderOption('Other', Icons.person_outline),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Saved address card.
                    RCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: scheme.primary),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text('Saved Address',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              RButton(
                                label: 'Use GPS',
                                icon: Icons.my_location,
                                small: true,
                                variant: RButtonVariant.outline,
                                onPressed: () {
                                  _address.text =
                                      'Bakura, Srinagar (North), Srinagar, Jammu and Kashmir, 190006, India';
                                  setState(() {});
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Location detected!')),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          RTextField(
                            hint:
                                'Enter your address or use GPS to auto-detect...',
                            controller: _address,
                            maxLines: 3,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'This address will be auto-filled in your orders',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    RButton(
                      label: 'Save Changes',
                      icon: Icons.save_outlined,
                      fullWidth: true,
                      onPressed: () {
                        state.updateProfile(
                          name: _name.text.trim(),
                          phone: _phone.text.trim(),
                          address: _address.text.trim(),
                        );
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Profile saved!')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Change password (expandable).
                    RCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(
                                () => _showPassword = !_showPassword),
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                Icon(Icons.key_outlined,
                                    size: 14, color: scheme.primary),
                                const SizedBox(width: 6),
                                const Text('Change Password',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Icon(
                                  _showPassword
                                      ? Icons.expand_less
                                      : Icons.lock_outline,
                                  size: 18,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                          if (_showPassword) ...[
                            const SizedBox(height: 12),
                            Divider(
                                color:
                                    Theme.of(context).dividerColor,
                                height: 1),
                            const SizedBox(height: 12),
                            Text(
                              "We'll send a password reset link to ${state.userEmail ?? 'your email'}. Click the link in your email to set a new password.",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            RButton(
                              label: 'Send Password Reset Email',
                              icon: Icons.mail_outline,
                              fullWidth: true,
                              variant: RButtonVariant.outline,
                              onPressed: () => showResponsiveDialog(
                                context,
                                (_) => AlertDialog(
                                  title:
                                      const Text('Change Password'),
                                  content: const Text(
                                      'A reset link will be sent to your email. (demo)'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    RButton(
                                      label: 'Send Link',
                                      small: true,
                                      onPressed: () {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Reset link sent! (demo)')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Radio circle + small avatar + label, like the React gender picker.
  Widget _genderOption(String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _gender == value;
    return InkWell(
      onTap: () => setState(() => _gender = value),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : Theme.of(context).dividerColor,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

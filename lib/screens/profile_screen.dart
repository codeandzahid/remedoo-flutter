import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// My Profile: avatar, name/email, phone, gender, address.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String _gender = 'Male';
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
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
          child: EmptyState(
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
      _phone.text = state.userPhone ?? '';
      _address.text = state.userAddress ?? '';
      _loaded = true;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: MaxWidthBox(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    InitialsAvatar(
                        name: state.displayName, radius: 40),
                    const SizedBox(height: 10),
                    Text(state.displayName,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text(state.userEmail ?? '',
                        style: const TextStyle(
                            color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'FULL NAME',
                        prefixIcon:
                            Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: TextEditingController(
                          text: state.userEmail ?? ''),
                      enabled: false,
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
                        prefixIcon:
                            Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Gender',
                        style: TextStyle(
                            fontWeight: FontWeight.w700)),
                    RadioGroup<String>(
                      groupValue: _gender,
                      onChanged: (v) =>
                          setState(() => _gender = v!),
                      child: Row(
                        children: ['Male', 'Female', 'Other']
                            .map((g) => Expanded(
                                  child: RadioListTile<String>(
                                    value: g,
                                    title: Text(g,
                                        style:
                                            const TextStyle(
                                                fontSize:
                                                    13)),
                                    activeColor:
                                        RemedooTheme.primary,
                                    contentPadding:
                                        EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    TextField(
                      controller: _address,
                      decoration: InputDecoration(
                        labelText: 'SAVED ADDRESS',
                        prefixIcon: const Icon(
                            Icons.location_on_outlined),
                        suffixIcon: TextButton(
                          onPressed: () {
                            _address.text =
                                '12, Residency Road, Srinagar';
                            setState(() {});
                          },
                          child: const Text('Use GPS'),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                state.updateProfile(
                  name: _name.text.trim(),
                  phone: _phone.text.trim(),
                  address: _address.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Profile saved!')),
                );
              },
              child: const Text('Save Changes'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => showResponsiveDialog(
                context,
                (_) => AlertDialog(
                  title: const Text('Change Password'),
                  content: const Text(
                      'A reset link will be sent to your email. (demo)'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Reset link sent! (demo)')),
                        );
                      },
                      child: const Text('Send Link'),
                    ),
                  ],
                ),
              ),
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }
}

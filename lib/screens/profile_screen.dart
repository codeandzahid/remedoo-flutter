import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../responsive/responsive.dart';
import '../theme.dart';
import '../state/app_state.dart';
import '../app_navigator.dart';
import '../utils/device_actions.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';

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
  final _upi = TextEditingController();
  String _gender = 'Male';
  DateTime? _dob;
  String _languageSel = 'English';
  bool _loaded = false;
  bool _showPassword = false;
  bool _locating = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _upi.dispose();
    super.dispose();
  }

  /// Picks and uploads a profile photo (2026-10-19): stored in the
  /// public avatars bucket; URL saved to profiles.avatar_url.
  Future<void> _pickAvatar(AppState state) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (files.isEmpty || !mounted) return;
    final file = files.single;
    Uint8List? bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {}
    if (bytes == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading photo...')));
    final url =
        await state.supabaseRepository.uploadAvatar(bytes, file.name);
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Photo upload failed. Try again.')));
      return;
    }
    await state.setAvatarUrl(url);
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')));
  }

  /// Adds an address to the address book, or edits [existing]
  /// when one is passed (2026-10-19; edit support added by the
  /// patient-panel audit fix the same day).
  Future<void> _addAddress(AppState state, {SavedAddress? existing}) async {
    final labelCtrl =
        TextEditingController(text: existing?.label ?? 'Home');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Address' : 'Edit Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                  labelText: 'Label', hintText: 'Home, Office…'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addrCtrl,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Full address'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final addr = addrCtrl.text.trim();
    if (addr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter the address.')));
      return;
    }
    final label =
        labelCtrl.text.trim().isEmpty ? 'Home' : labelCtrl.text.trim();
    if (existing != null) {
      state.updateSavedAddress(SavedAddress(
        id: existing.id,
        label: label,
        address: addr,
      ));
    } else {
      state.addSavedAddress(SavedAddress(
        id: 'A${DateTime.now().millisecondsSinceEpoch}',
        label: label,
        address: addr,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: MaxWidthBox(
          child: REmptyState(
            icon: Icons.person_outline,
            title: 'You are browsing as a guest',
            subtitle: 'Sign in to manage your profile.',
            actionLabel: 'Sign In',
            // Open the login page; back returns to guest browsing.
            onAction: () => appNavigatorKey.currentState?.push(
              MaterialPageRoute(
                  builder: (_) => const LoginScreen()),
            ),
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
      _dob = state.dateOfBirth;
      _languageSel = state.language;
      _upi.text = state.patientUpiId;
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
                    onPressed: () => goBack(context),
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
                        GestureDetector(
                          onTap: () => _pickAvatar(state),
                          child: Stack(
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
                              child: state.avatarUrl != null
                                  ? ClipOval(
                                      child: Image.network(
                                        state.avatarUrl!,
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                            Icons.person,
                                            size: 52,
                                            color:
                                                scheme.onSurfaceVariant),
                                      ),
                                    )
                                  : Icon(Icons.person,
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
                          const SizedBox(height: 18),
                          // Date of birth, language and UPI ID —
                          // all three live on profiles but had no
                          // editor after signup (audit Patient 20).
                          Row(
                            children: [
                              Icon(Icons.cake_outlined,
                                  size: 14, color: scheme.primary),
                              const SizedBox(width: 6),
                              const Text('Date of Birth',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month_outlined,
                                  size: 18),
                              label: Text(_dob == null
                                  ? 'Select date of birth'
                                  : '${_dob!.day}/${_dob!.month}/${_dob!.year}'),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dob ??
                                      DateTime.now().subtract(
                                          const Duration(days: 365 * 25)),
                                  firstDate: DateTime(1920),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => _dob = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          DropdownButtonFormField<String>(
                            initialValue:
                                AppState.languageCodes
                                        .containsKey(_languageSel)
                                    ? _languageSel
                                    : 'English',
                            decoration: const InputDecoration(
                              labelText: 'Preferred Language',
                              isDense: true,
                            ),
                            items: AppState.languageCodes.keys
                                .map((l) => DropdownMenuItem(
                                    value: l, child: Text(l)))
                                .toList(),
                            onChanged: (v) => setState(
                                () => _languageSel = v ?? 'English'),
                          ),
                          const SizedBox(height: 18),
                          RTextField(
                            label: 'UPI ID (for refunds)',
                            labelIcon: Icons.account_balance_wallet_outlined,
                            hint: 'yourname@upi',
                            controller: _upi,
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
                                label: _locating
                                    ? 'Locating…'
                                    : 'Use GPS',
                                icon: Icons.my_location,
                                small: true,
                                variant: RButtonVariant.outline,
                                onPressed: _locating
                                    ? null
                                    : () async {
                                        final messenger =
                                            ScaffoldMessenger.of(
                                                context);
                                        setState(
                                            () => _locating = true);
                                        final address =
                                            await fetchCurrentAddress();
                                        if (!context.mounted) return;
                                        setState(
                                            () => _locating = false);
                                        if (address == null) {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Could not detect location. Please allow location access or enter your address manually.')),
                                          );
                                          return;
                                        }
                                        _address.text = address;
                                        setState(() {});
                                        messenger.showSnackBar(
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
                            label: 'Address',
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
                    const SizedBox(height: 16),
                    // Address book (2026-10-19): more than one saved
                    // address, pickable at checkout.
                    RCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.book_outlined,
                                  size: 14, color: scheme.primary),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text('My Addresses',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                              RButton(
                                label: 'Add',
                                icon: Icons.add,
                                small: true,
                                variant: RButtonVariant.outline,
                                onPressed: () => _addAddress(state),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (state.savedAddresses.isEmpty)
                            Text(
                              'No saved addresses yet. Add Home, Office or any place you get medicines delivered.',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurfaceVariant),
                            )
                          else
                            for (final a in state.savedAddresses)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: scheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(a.label,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: scheme.primary)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          _address.text = a.address;
                                          setState(() {});
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      '"${a.label}" set as your main address. Tap Save Changes to keep it.')));
                                        },
                                        child: Text(a.address,
                                            style: const TextStyle(
                                                fontSize: 13)),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Edit address',
                                      onPressed: () => _addAddress(state,
                                          existing: a),
                                      icon: Icon(Icons.edit_outlined,
                                          size: 18,
                                          color:
                                              scheme.onSurfaceVariant),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete address',
                                      onPressed: () =>
                                          state.removeSavedAddress(a.id),
                                      icon: Icon(Icons.delete_outline,
                                          size: 18,
                                          color:
                                              scheme.onSurfaceVariant),
                                    ),
                                  ],
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
                      onPressed: () async {
                        final messenger =
                            ScaffoldMessenger.of(context);
                        final ok = await state.updateProfile(
                          name: _name.text.trim(),
                          phone: _phone.text.trim(),
                          address: _address.text.trim(),
                          gender: _gender,
                          dateOfBirth: _dob,
                          language: _languageSel,
                          upiId: _upi.text.trim(),
                        );
                        if (!context.mounted) return;
                        setState(() {});
                        messenger.showSnackBar(
                          SnackBar(
                              content: Text(ok
                                  ? 'Profile saved!'
                                  : 'Saved locally; cloud sync failed.')),
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
                                  content: Text(
                                      'A reset link will be sent to ${state.email}.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    RButton(
                                      label: 'Send Link',
                                      small: true,
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        final result =
                                            await AppStateScope.of(
                                                    context)
                                                .sendPasswordReset(
                                                    state.email);
                                        if (!context.mounted) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(
                                                context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                            result.ok
                                                ? 'Reset link sent! Check your email.'
                                                : result.error ??
                                                    'Could not send the reset link.',
                                          )),
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
                    const SizedBox(height: 24),
                    // Log out — reachable at every width (2026-10-19):
                    // the Settings screen's logout sits behind the
                    // compact-only drawer, so desktop users had no
                    // sign-out at all. Same pill as Settings.
                    Material(
                      color: RemedooTheme.destructive.withValues(alpha: 0.06),
                      shape: StadiumBorder(
                        side: BorderSide(
                            color: RemedooTheme.destructive
                                .withValues(alpha: 0.35)),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final ok = await confirmDialog(
                            context,
                            title: 'Log out?',
                            message: 'You will be signed out of Remedoo.',
                            confirmLabel: 'Log Out',
                          );
                          if (ok) state.logout();
                        },
                        customBorder: const StadiumBorder(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.logout,
                                  size: 18,
                                  color: RemedooTheme.destructive),
                              SizedBox(width: 8),
                              Text('Log Out',
                                  style: TextStyle(
                                      color: RemedooTheme.destructive,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Danger zone: delete account (2026-10-19).
                    RCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_outlined,
                                  size: 14,
                                  color: RemedooTheme.destructive),
                              const SizedBox(width: 6),
                              Text('Danger Zone',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: RemedooTheme.destructive)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Deleting your account permanently removes your profile and personal data from Remedoo. This cannot be undone.',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          RButton(
                            label: 'Delete My Account',
                            icon: Icons.delete_forever_outlined,
                            variant: RButtonVariant.danger,
                            fullWidth: true,
                            onPressed: () => _deleteAccount(state),
                          ),
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

  /// Delete account flow (2026-10-19): two confirmations, then the
  /// backend removes the user and the app returns to guest browsing.
  Future<void> _deleteAccount(AppState state) async {
    final first = await confirmDialog(
      context,
      title: 'Delete your account?',
      message:
          'Your profile and personal data will be permanently removed. Past bookings and orders stay in the providers\' records without your name.',
      confirmLabel: 'Continue',
    );
    if (first != true || !mounted) return;
    final second = await confirmDialog(
      context,
      title: 'Are you fully sure?',
      message: 'This is permanent and cannot be undone.',
      confirmLabel: 'Delete my account',
    );
    if (second != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await state.deleteMyAccount();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
        content: Text(ok
            ? 'Your account has been deleted.'
            : 'Could not delete the account. Please try again or contact support.')));
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

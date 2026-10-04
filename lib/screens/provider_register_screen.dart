import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'pending_approval_screen.dart';

IconData _roleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'doctor':
      return Icons.medical_services_outlined;
    case 'hospital':
      return Icons.local_hospital_outlined;
    case 'lab':
      return Icons.science_outlined;
    case 'pharmacy':
      return Icons.local_pharmacy_outlined;
    default:
      return Icons.business_outlined;
  }
}

String _roleTitle(String role) {
  switch (role.toLowerCase()) {
    case 'doctor':
      return 'Doctor';
    case 'hospital':
      return 'Hospital';
    case 'lab':
      return 'Lab';
    case 'pharmacy':
      return 'Pharmacy';
    default:
      return role;
  }
}

/// Maximum document size: 500 KB.
const _maxDocBytes = 500 * 1024;

/// A required document upload slot.
class _DocSlot {
  final String label;
  final String hint;
  PlatformFile? file;

  _DocSlot({required this.label, required this.hint});
}

/// Provider registration form. Opened from [ProviderTypeScreen] after
/// the user picks their provider type. All fields are compulsory.
/// UPI setup happens separately after verification via the UPI popup.
class ProviderRegisterScreen extends StatefulWidget {
  final String providerType;

  const ProviderRegisterScreen({
    super.key,
    this.providerType = 'doctor',
  });

  @override
  State<ProviderRegisterScreen> createState() =>
      _ProviderRegisterScreenState();
}

class _ProviderRegisterScreenState
    extends State<ProviderRegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _license = TextEditingController();
  final _address = TextEditingController();
  bool _busy = false;
  String? _error;

  late final List<_DocSlot> _docs;

  @override
  void initState() {
    super.initState();
    final role = widget.providerType.toLowerCase();
    _docs = [
      _DocSlot(
        label: 'License / Registration Certificate *',
        hint: 'Upload your medical license or registration certificate',
      ),
      _DocSlot(
        label: 'Government ID Proof *',
        hint: 'Aadhaar, PAN, or Passport (front side)',
      ),
      if (role == 'hospital' || role == 'lab')
        _DocSlot(
          label: 'Facility Accreditation *',
          hint: 'NABH, NABL, or equivalent accreditation certificate',
        ),
      if (role == 'pharmacy')
        _DocSlot(
          label: 'Drug License *',
          hint: 'Valid drug retail license',
        ),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _license.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickDoc(_DocSlot slot) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if ((file.size) > _maxDocBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${file.name} is ${(_fileSize(file.size))}. Documents must be under 500 KB.',
          ),
        ),
      );
      return;
    }
    setState(() => slot.file = file);
  }

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  void _submit() {
    // Validate all compulsory fields.
    if (_name.text.trim().isEmpty) {
      setState(
          () => _error = 'Full name is required.');
      return;
    }
    if (_email.text.trim().isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
            .hasMatch(_email.text.trim())) {
      setState(
          () => _error = 'A valid email is required.');
      return;
    }
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Phone number is required.');
      return;
    }
    if (_license.text.trim().isEmpty) {
      setState(() =>
          _error = 'License / registration number is required.');
      return;
    }
    if (_address.text.trim().isEmpty) {
      setState(() => _error = 'Address is required.');
      return;
    }
    // Validate all documents uploaded.
    for (final d in _docs) {
      if (d.file == null) {
        setState(() =>
            _error = 'Please upload: ${d.label.replaceAll(' *', '')}');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    AppStateScope.of(context).submitProviderApplication(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      role: _roleTitle(widget.providerType),
      license: _license.text.trim(),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) =>
              const PendingApprovalScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roleTitle = _roleTitle(widget.providerType);
    final roleIcon = _roleIcon(widget.providerType);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          '$roleTitle Registration',
          style:
              const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primary.withValues(alpha: 0.08),
              scheme.surface,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24),
              child: MaxWidthBox(
                maxWidth: 520,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10),
                        decoration: BoxDecoration(
                          color: scheme.primary
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(999),
                          border: Border.all(
                            color: scheme.primary
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(roleIcon,
                                size: 18,
                                color: scheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Registering as $roleTitle',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All fields marked * are compulsory',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Personal details
                    _SectionCard(
                      title: 'Personal Details',
                      icon: Icons.person_outline,
                      children: [
                        _RequiredField(
                          label: 'Full Name / Business Name',
                          hint: 'Enter name',
                          controller: _name,
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        _RequiredField(
                          label: 'Email',
                          hint: 'you@example.com',
                          controller: _email,
                          keyboardType:
                              TextInputType.emailAddress,
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 12),
                        _RequiredField(
                          label: 'Phone',
                          hint: '+91 XXXXX XXXXX',
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          icon: Icons.phone_outlined,
                        ),
                        const SizedBox(height: 12),
                        _RequiredField(
                          label:
                              'License / Registration Number',
                          hint: 'Enter license number',
                          controller: _license,
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 12),
                        _RequiredField(
                          label: 'Address',
                          hint:
                              'Clinic / facility address',
                          controller: _address,
                          icon:
                              Icons.location_on_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Documents
                    _SectionCard(
                      title: 'Required Documents',
                      icon: Icons.upload_file_outlined,
                      subtitle:
                          'PDF, JPG, or PNG — each under 500 KB',
                      children: [
                        for (var i = 0;
                            i < _docs.length;
                            i++) ...[
                          _DocUploadTile(
                            slot: _docs[i],
                            onPick: () =>
                                _pickDoc(_docs[i]),
                          ),
                          if (i < _docs.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding:
                            const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: RemedooTheme.emergency
                              .withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 18,
                              color:
                                  RemedooTheme.emergency,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: RemedooTheme
                                      .emergency,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    RButton(
                      label: _busy
                          ? 'Submitting…'
                          : 'Submit for Verification',
                      fullWidth: true,
                      onPressed: _busy ? null : _submit,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Our team verifies your details and documents within 24–48 hours. Once approved, you\'ll be guided to set up UPI payments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _RequiredField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;

  const _RequiredField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface,
            ),
            children: [
              TextSpan(text: label),
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        RTextField(
          hint: hint,
          controller: controller,
          keyboardType: keyboardType,
          prefixIcon: Icon(icon, size: 18),
        ),
      ],
    );
  }
}

class _DocUploadTile extends StatelessWidget {
  final _DocSlot slot;
  final VoidCallback onPick;

  const _DocUploadTile({
    required this.slot,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasFile = slot.file != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasFile
              ? RemedooTheme.success
                  .withValues(alpha: 0.08)
              : scheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile
                ? RemedooTheme.success
                    .withValues(alpha: 0.4)
                : scheme.outline
                    .withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasFile
                    ? RemedooTheme.success
                        .withValues(alpha: 0.15)
                    : scheme.primary
                        .withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Icon(
                hasFile
                    ? Icons.check_circle
                    : Icons.upload_file_outlined,
                color: hasFile
                    ? RemedooTheme.success
                    : scheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasFile
                        ? '${slot.file!.name} (${(slot.file!.size / 1024).toStringAsFixed(1)} KB)'
                        : slot.hint,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasFile
                          ? RemedooTheme.success
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              hasFile ? 'Change' : 'Upload',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

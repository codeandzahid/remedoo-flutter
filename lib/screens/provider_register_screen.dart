import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/mock_data.dart' show specialties;
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/email_otp_field.dart';
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

/// A required document upload slot. The picked file's BYTES are
/// kept (audit M5: registration used to record only name/size
/// and throw the file away, so nothing could ever be reviewed
/// or linked to the approved provider record).
class _DocSlot {
  final String label;
  final String hint;
  PlatformFile? file;
  int fileSize = 0;
  Uint8List? bytes;

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
  // Role-specific practice details (audit Panelist 18: approval
  // used to create a bare record because registration never
  // collected these).
  final _fee = TextEditingController();
  final _experience = TextEditingController();
  final _beds = TextEditingController();
  final _services = TextEditingController();
  String _specialization = specialties.first;
  bool _icu = false;
  bool _busy = false;
  String? _error;
  bool _emailVerified = false;

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
    _fee.dispose();
    _experience.dispose();
    _beds.dispose();
    _services.dispose();
    super.dispose();
  }

  Future<void> _pickDoc(_DocSlot slot) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (files.isEmpty) return;
    final file = files.first;
    final size = await file.xFile.length();
    if (size > _maxDocBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${file.name} is ${(_fileSize(size))}. Documents must be under 500 KB.',
          ),
        ),
      );
      return;
    }
    // Keep the bytes: they are uploaded to storage at submit
    // time (audit M5).
    final bytes = await file.xFile.readAsBytes();
    setState(() {
      slot.file = file;
      slot.fileSize = size;
      slot.bytes = bytes;
    });
  }

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  void _submit() async {
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
    if (!_emailVerified) {
      setState(() => _error =
          'Please verify your email with the OTP first.');
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
    // Role-specific practice details are compulsory too
    // (Panelist 18).
    final roleCheck = widget.providerType.toLowerCase();
    if (roleCheck == 'doctor' &&
        double.tryParse(_fee.text.trim()) == null) {
      setState(() =>
          _error = 'Your consultation fee is required.');
      return;
    }
    if (roleCheck == 'hospital' &&
        int.tryParse(_beds.text.trim()) == null) {
      setState(() => _error = 'Your total bed count is required.');
      return;
    }
    if (roleCheck == 'lab' && _services.text.trim().isEmpty) {
      setState(() =>
          _error = 'List the services / tests you offer.');
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
    final state = AppStateScope.of(context);
    final repo = state.supabaseRepository;
    // Upload the documents for real (audit M5): the bytes go to
    // the private certificates bucket and the application keeps
    // the storage paths, so admin can review them and approval
    // can link them onto the provider record.
    final docRows = <Map<String, dynamic>>[];
    for (final d in _docs) {
      final bytes = d.bytes;
      if (bytes == null) {
        setState(() {
          _busy = false;
          _error =
              'Please re-pick: ${d.label.replaceAll(' *', '')}';
        });
        return;
      }
      final path = await repo.uploadProviderDocument(
          fileName: d.file?.name ?? 'document', bytes: bytes);
      if (path == null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Could not upload '
              '${d.label.replaceAll(' *', '')}. Check your '
              'connection and try again.';
        });
        return;
      }
      docRows.add({
        'kind': d.label.replaceAll(' *', ''),
        'name': d.file?.name ?? '',
        'size': d.fileSize,
        'path': path,
      });
    }
    // Role-specific details ride in provider_applications.details
    // and are mapped onto the provider record at approval.
    final role = widget.providerType.toLowerCase();
    final details = <String, dynamic>{
      if (role == 'doctor') ...{
        'specialization': _specialization,
        'consultation_fee': double.tryParse(_fee.text.trim()),
        'experience_years': int.tryParse(_experience.text.trim()),
      },
      if (role == 'hospital') ...{
        'beds': int.tryParse(_beds.text.trim()),
        'icu_available': _icu,
      },
      if (role == 'lab')
        'services': _services.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
    };
    // Submit to the real backend so the admin panel can review it.
    final ok = await state.submitProviderApplicationDb({
      'provider_type': widget.providerType,
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'license_no': _license.text.trim(),
      'address': _address.text.trim(),
      'documents': docRows,
      'details': details,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _error =
          'Could not submit your application. Please try again.');
      return;
    }
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
                    if (!_emailVerified)
                      _SectionCard(
                        title: 'Step 1 of 2: Verify Your Email',
                        icon: Icons.email_outlined,
                        children: [
                          EmailOtpField(
                            controller: _email,
                            label: null,
                            hint: 'you@example.com',
                            blockExistingEmail: true,
                            onVerifiedChanged: (v) =>
                                setState(() {
                              _emailVerified = v;
                              if (v) _error = null;
                            }),
                          ),
                        ],
                      )
                    else ...[
                      VerifiedEmailCard(
                          email: _email.text.trim()),
                      const SizedBox(height: 14),
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
                    // Practice details (Panelist 18): collected
                    // now so approval creates a complete record.
                    if (widget.providerType.toLowerCase() ==
                            'doctor' ||
                        widget.providerType.toLowerCase() ==
                            'hospital' ||
                        widget.providerType.toLowerCase() ==
                            'lab')
                      _SectionCard(
                        title: 'Practice Details',
                        icon: Icons.work_outline,
                        children: [
                          if (widget.providerType.toLowerCase() ==
                              'doctor') ...[
                            DropdownButtonFormField<String>(
                              initialValue: _specialization,
                              decoration: const InputDecoration(
                                labelText: 'Specialization *',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final s in specialties)
                                  DropdownMenuItem(
                                      value: s, child: Text(s)),
                              ],
                              onChanged: (v) => setState(() =>
                                  _specialization =
                                      v ?? _specialization),
                            ),
                            const SizedBox(height: 12),
                            _RequiredField(
                              label: 'Consultation fee (₹)',
                              hint: 'e.g. 500',
                              controller: _fee,
                              keyboardType: TextInputType.number,
                              icon: Icons.payments_outlined,
                            ),
                            const SizedBox(height: 12),
                            _RequiredField(
                              label: 'Years of experience',
                              hint: 'e.g. 8',
                              controller: _experience,
                              keyboardType: TextInputType.number,
                              icon: Icons.timeline_outlined,
                            ),
                          ],
                          if (widget.providerType.toLowerCase() ==
                              'hospital') ...[
                            _RequiredField(
                              label: 'Total beds',
                              hint: 'e.g. 120',
                              controller: _beds,
                              keyboardType: TextInputType.number,
                              icon: Icons.bed_outlined,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  'ICU available'),
                              value: _icu,
                              onChanged: (v) =>
                                  setState(() => _icu = v),
                            ),
                          ],
                          if (widget.providerType.toLowerCase() ==
                              'lab')
                            _RequiredField(
                              label: 'Services / tests offered',
                              hint:
                                  'Blood Test, X-Ray, MRI — comma separated',
                              controller: _services,
                              icon: Icons.science_outlined,
                            ),
                        ],
                      ),
                    if (widget.providerType.toLowerCase() ==
                            'doctor' ||
                        widget.providerType.toLowerCase() ==
                            'hospital' ||
                        widget.providerType.toLowerCase() ==
                            'lab')
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
                    ],
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
                        ? '${slot.file!.name} (${(slot.fileSize / 1024).toStringAsFixed(1)} KB)'
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

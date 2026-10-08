import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// App Settings: maintenance mode, delivery fees, emergency numbers and
/// support contact. All values live in the Supabase `app_config` table and
/// apply across the website and app.
class AdminAppSettingsScreen extends StatefulWidget {
  const AdminAppSettingsScreen({super.key});

  @override
  State<AdminAppSettingsScreen> createState() =>
      _AdminAppSettingsScreenState();
}

class _AdminAppSettingsScreenState
    extends State<AdminAppSettingsScreen> {
  bool _loading = true;
  bool _saving = false;

  // Maintenance
  bool _maintEnabled = false;
  late final TextEditingController _maintMsg;

  // Pharmacy mode
  bool _pharmacyMultiVendor = true;
  String? _singleVendorPharmacyId;

  // Razorpay
  bool _razorpayEnabled = false;
  late final TextEditingController _razorpayKeyId;
  late final TextEditingController _razorpayKeySecret;
  late final TextEditingController _razorpayWebhookSecret;

  // Fees
  late final TextEditingController _deliveryFee;
  late final TextEditingController _freeThreshold;

  // Emergency
  List<Map<String, String>> _numbers = [];
  late final TextEditingController _sosMsg;

  // Support
  late final TextEditingController _supportPhone;
  late final TextEditingController _supportEmail;
  late final TextEditingController _supportHours;

  @override
  void initState() {
    super.initState();
    _maintMsg = TextEditingController();
    _deliveryFee = TextEditingController();
    _freeThreshold = TextEditingController();
    _sosMsg = TextEditingController();
    _supportPhone = TextEditingController();
    _supportEmail = TextEditingController();
    _supportHours = TextEditingController();
    _razorpayKeyId = TextEditingController();
    _razorpayKeySecret = TextEditingController();
    _razorpayWebhookSecret = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _maintMsg.dispose();
    _deliveryFee.dispose();
    _freeThreshold.dispose();
    _sosMsg.dispose();
    _supportPhone.dispose();
    _supportEmail.dispose();
    _supportHours.dispose();
    _razorpayKeyId.dispose();
    _razorpayKeySecret.dispose();
    _razorpayWebhookSecret.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    await state.loadAppConfig();
    if (!mounted) return;
    final maint = state.appConfigValue('maintenance');
    final fees = state.appConfigValue('fees');
    final emg = state.appConfigValue('emergency');
    final support = state.appConfigValue('support');
    final pharmMode = state.appConfigValue('pharmacy_mode');
    final rzp = state.appConfigValue('razorpay');
    setState(() {
      _maintEnabled = maint['enabled'] == true;
      _maintMsg.text = '${maint['message'] ?? ''}';
      _pharmacyMultiVendor = pharmMode['mode'] != 'single';
      _singleVendorPharmacyId = pharmMode['pharmacy_id'] as String?;
      _razorpayEnabled = rzp['enabled'] == true;
      _razorpayKeyId.text = '${rzp['key_id'] ?? ''}';
    });
    // Load secrets from secure_settings (admin-only)
    final secrets = await state.supabaseRepository.fetchSecureSettings([
      'razorpay_key_secret',
      'razorpay_webhook_secret',
    ]);
    if (mounted) {
      setState(() {
        _razorpayKeySecret.text = secrets['razorpay_key_secret'] ?? '';
        _razorpayWebhookSecret.text =
            secrets['razorpay_webhook_secret'] ?? '';
        _deliveryFee.text = '${fees['delivery_fee'] ?? 30}';
        _freeThreshold.text =
            '${fees['free_delivery_threshold'] ?? 499}';
        _numbers = [
          for (final n in (emg['numbers'] as List? ?? []))
            {
              'label': '${(n as Map)['label'] ?? ''}',
              'number': '${n['number'] ?? ''}',
            }
        ];
        _sosMsg.text = '${emg['sos_message'] ?? ''}';
        _supportPhone.text = '${support['phone'] ?? ''}';
        _supportEmail.text = '${support['email'] ?? ''}';
        _supportHours.text = '${support['hours'] ?? ''}';
        _loading = false;
      });
    }
  }

  Future<void> _save(String key, Map<String, dynamic> patch) async {
    setState(() => _saving = true);
    final state = AppStateScope.of(context);
    final merged = Map<String, dynamic>.from(state.appConfigValue(key))
      ..addAll(patch);
    final ok = await state.saveAppConfigValue(key, merged);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Saved — live across website and app'
              : 'Could not save (admin only)')),
    );
  }

  /// Save Razorpay config: public settings to app_config,
  /// secrets to secure_settings (admin-only).
  Future<void> _saveRazorpay() async {
    setState(() => _saving = true);
    final state = AppStateScope.of(context);
    final repo = state.supabaseRepository;

    // Public config (key_id is safe to expose to clients)
    final okPublic = await state.saveAppConfigValue('razorpay', {
      'enabled': _razorpayEnabled,
      'key_id': _razorpayKeyId.text.trim(),
    });

    // Secrets go to admin-only table
    bool okSecrets = true;
    final secret = _razorpayKeySecret.text.trim();
    final webhook = _razorpayWebhookSecret.text.trim();
    if (secret.isNotEmpty) {
      okSecrets = await repo.saveSecureSetting(
              'razorpay_key_secret', secret) &&
          okSecrets;
    }
    if (webhook.isNotEmpty) {
      okSecrets = await repo.saveSecureSetting(
              'razorpay_webhook_secret', webhook) &&
          okSecrets;
    }
    // Also store key_id in secure settings for Edge Functions
    final keyId = _razorpayKeyId.text.trim();
    if (keyId.isNotEmpty) {
      okSecrets =
          await repo.saveSecureSetting('razorpay_key_id', keyId) &&
              okSecrets;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(okPublic && okSecrets
              ? 'Razorpay saved securely — Route payments ready'
              : 'Could not save (admin only)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ResponsiveBody(
      maxWidth: 640,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Maintenance ----
          const RSectionHeader(
              title: 'Maintenance Mode',
              subtitle: 'Show a maintenance page to all users'),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: _maintEnabled,
                  activeThumbColor: RemedooTheme.emergency,
                  onChanged: (v) =>
                      setState(() => _maintEnabled = v),
                  title: const Text('Maintenance mode',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      _maintEnabled
                          ? 'Users see the maintenance message'
                          : 'App is live',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                RTextField(
                    label: 'Maintenance message',
                    controller: _maintMsg),
                const SizedBox(height: 12),
                RButton(
                  label: 'Save',
                  small: true,
                  onPressed: _saving
                      ? null
                      : () => _save('maintenance', {
                            'enabled': _maintEnabled,
                            'message': _maintMsg.text.trim(),
                          }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ---- Fees ----
          const RSectionHeader(
              title: 'Delivery Fees',
              subtitle: 'Pharmacy checkout charges'),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RTextField(
                        label: 'Delivery fee (₹)',
                        controller: _deliveryFee,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RTextField(
                        label: 'Free above (₹)',
                        controller: _freeThreshold,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RButton(
                  label: 'Save',
                  small: true,
                  onPressed: _saving
                      ? null
                      : () => _save('fees', {
                            'delivery_fee':
                                num.tryParse(_deliveryFee.text) ?? 30,
                            'free_delivery_threshold':
                                num.tryParse(_freeThreshold.text) ??
                                    499,
                          }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ---- Pharmacy Mode ----
          const RSectionHeader(
              title: 'Pharmacy Mode',
              subtitle: 'Single vendor or multi-vendor marketplace'),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: _pharmacyMultiVendor,
                  onChanged: (v) =>
                      setState(() => _pharmacyMultiVendor = v),
                  title: const Text('Multi-vendor mode',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      _pharmacyMultiVendor
                          ? 'Users can browse all pharmacies'
                          : 'Single pharmacy store only',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                if (!_pharmacyMultiVendor) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (ctx) {
                      final state = AppStateScope.of(ctx);
                      final pharmacies = state.activePharmacies;
                      return DropdownButtonFormField<String>(
                        value: _singleVendorPharmacyId,
                        decoration: const InputDecoration(
                          labelText: 'Single vendor pharmacy',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final p in pharmacies)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            ),
                        ],
                        onChanged: (v) => setState(
                            () => _singleVendorPharmacyId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: RButton(
                    label: 'Save',
                    small: true,
                    onPressed: _saving
                        ? null
                        : () => _save('pharmacy_mode', {
                              'mode': _pharmacyMultiVendor
                                  ? 'multi'
                                  : 'single',
                              if (!_pharmacyMultiVendor &&
                                  _singleVendorPharmacyId != null)
                                'pharmacy_id':
                                    _singleVendorPharmacyId,
                            }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ---- Emergency ----
          const RSectionHeader(
              title: 'Emergency Numbers',
              subtitle: 'Shown on the Emergency / SOS screen'),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: [
                for (var i = 0; i < _numbers.length; i++)
                  _NumberRow(
                    key: ValueKey('emg_$i'),
                    initialLabel: _numbers[i]['label'] ?? '',
                    initialNumber: _numbers[i]['number'] ?? '',
                    onChanged: (label, number) =>
                        _numbers[i] = {
                      'label': label,
                      'number': number
                    },
                    onRemove: () =>
                        setState(() => _numbers.removeAt(i)),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _numbers.add(
                        {'label': '', 'number': ''})),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add number'),
                  ),
                ),
                const SizedBox(height: 8),
                RTextField(
                    label: 'SOS alert message',
                    controller: _sosMsg),
                const SizedBox(height: 12),
                RButton(
                  label: 'Save',
                  small: true,
                  onPressed: _saving
                      ? null
                      : () => _save('emergency', {
                            'numbers': _numbers
                                .where((n) =>
                                    n['number']!
                                        .trim()
                                        .isNotEmpty)
                                .map((n) => {
                                      'label': n['label']!.trim(),
                                      'number': n['number']!.trim(),
                                    })
                                .toList(),
                            'sos_message': _sosMsg.text.trim(),
                          }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ---- Support ----
          const RSectionHeader(
              title: 'Support Contact',
              subtitle: 'Shown in Help & Support'),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: [
                RTextField(
                    label: 'Support phone',
                    controller: _supportPhone,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                RTextField(
                    label: 'Support email',
                    controller: _supportEmail,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                RTextField(
                    label: 'Support hours',
                    controller: _supportHours),
                const SizedBox(height: 12),
                RButton(
                  label: 'Save',
                  small: true,
                  onPressed: _saving
                      ? null
                      : () => _save('support', {
                            'phone': _supportPhone.text.trim(),
                            'email': _supportEmail.text.trim(),
                            'hours': _supportHours.text.trim(),
                          }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ---- Payment Gateway ----
          const RSectionHeader(
              title: 'Payment Gateway (Razorpay)',
              subtitle: 'In-app UPI, cards, netbanking payments'),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: _razorpayEnabled,
                  onChanged: (v) =>
                      setState(() => _razorpayEnabled = v),
                  title: const Text('Enable online payments',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      _razorpayEnabled
                          ? 'Users can pay via UPI/cards in-app'
                          : 'Online payments disabled',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                RTextField(
                    label: 'Razorpay Key ID (public)',
                    hint: 'rzp_test_... or rzp_live_...',
                    controller: _razorpayKeyId),
                const SizedBox(height: 8),
                RTextField(
                    label: 'Razorpay Key Secret',
                    hint: 'Stored securely, never shown to users',
                    controller: _razorpayKeySecret,
                    obscureText: true),
                const SizedBox(height: 8),
                RTextField(
                    label: 'Razorpay Webhook Secret',
                    hint: 'From Razorpay dashboard > Webhooks',
                    controller: _razorpayWebhookSecret,
                    obscureText: true),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'All keys are stored in a secure admin-only table. '
                    'The Key Secret is never sent to user devices. '
                    'Route split payments (95% provider / 5% platform) use these keys.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: RButton(
                    label: 'Save',
                    small: true,
                    onPressed: _saving
                        ? null
                        : () => _saveRazorpay(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// One editable emergency-number row with its own controllers so focus
/// survives parent rebuilds.
class _NumberRow extends StatefulWidget {
  final String initialLabel;
  final String initialNumber;
  final void Function(String label, String number) onChanged;
  final VoidCallback onRemove;

  const _NumberRow({
    super.key,
    required this.initialLabel,
    required this.initialNumber,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_NumberRow> createState() => _NumberRowState();
}

class _NumberRowState extends State<_NumberRow> {
  late final TextEditingController _label;
  late final TextEditingController _number;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.initialLabel);
    _number = TextEditingController(text: widget.initialNumber);
    _label.addListener(_push);
    _number.addListener(_push);
  }

  void _push() => widget.onChanged(_label.text, _number.text);

  @override
  void dispose() {
    _label.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: RTextField(label: 'Label', controller: _label)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: RTextField(
                label: 'Number',
                controller: _number,
                keyboardType: TextInputType.phone),
          ),
          IconButton(
            icon:
                Icon(Icons.delete_outline, color: RemedooTheme.emergency),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}

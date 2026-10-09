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

  // Support chat media
  bool _supportMediaEnabled = false;
  late final TextEditingController _supportMediaLimit;

  // Pharmacy mode
  bool _pharmacyMultiVendor = true;
  String? _singleVendorPharmacyId;

  // Razorpay
  bool _razorpayEnabled = false;
  bool _razorpayTest = true;
  late final TextEditingController _razorpayKeyId;
  late final TextEditingController _razorpayKeySecret;
  late final TextEditingController _razorpayWebhookSecret;

  // Multi-gateway
  String _activeGateway = 'razorpay';
  // Cashfree
  bool _cashfreeEnabled = false;
  bool _cashfreeTest = true;
  late final TextEditingController _cashfreeKeyId;
  late final TextEditingController _cashfreeSecret;
  // Instamojo
  bool _instamojoEnabled = false;
  bool _instamojoTest = true;
  late final TextEditingController _instamojoKeyId;
  late final TextEditingController _instamojoSecret;
  // PayU
  bool _payuEnabled = false;
  bool _payuTest = true;
  late final TextEditingController _payuKeyId;
  late final TextEditingController _payuSecret;

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
    _supportMediaLimit = TextEditingController(text: '5');
    _deliveryFee = TextEditingController();
    _freeThreshold = TextEditingController();
    _sosMsg = TextEditingController();
    _supportPhone = TextEditingController();
    _supportEmail = TextEditingController();
    _supportHours = TextEditingController();
    _razorpayKeyId = TextEditingController();
    _razorpayKeySecret = TextEditingController();
    _razorpayWebhookSecret = TextEditingController();
    _cashfreeKeyId = TextEditingController();
    _cashfreeSecret = TextEditingController();
    _instamojoKeyId = TextEditingController();
    _instamojoSecret = TextEditingController();
    _payuKeyId = TextEditingController();
    _payuSecret = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _maintMsg.dispose();
    _supportMediaLimit.dispose();
    _deliveryFee.dispose();
    _freeThreshold.dispose();
    _sosMsg.dispose();
    _supportPhone.dispose();
    _supportEmail.dispose();
    _supportHours.dispose();
    _razorpayKeyId.dispose();
    _razorpayKeySecret.dispose();
    _razorpayWebhookSecret.dispose();
    _cashfreeKeyId.dispose();
    _cashfreeSecret.dispose();
    _instamojoKeyId.dispose();
    _instamojoSecret.dispose();
    _payuKeyId.dispose();
    _payuSecret.dispose();
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
    final supportChat = state.appConfigValue('support_chat');
    final pharmMode = state.appConfigValue('pharmacy_mode');
    final rzp = state.appConfigValue('razorpay');
    final pg = state.appConfigValue('payment_gateways');
    final pgGateways = (pg['gateways'] as Map?) ?? {};
    Map<String, dynamic> gwOf(String name) {
      final g = pgGateways[name];
      return g is Map ? Map<String, dynamic>.from(g) : {};
    }
    setState(() {
      _maintEnabled = maint['enabled'] == true;
      _maintMsg.text = '${maint['message'] ?? ''}';
      _supportMediaEnabled = supportChat['media_enabled'] == true;
      _supportMediaLimit.text =
          '${(supportChat['media_per_ticket'] as num?)?.toInt() ?? 5}';
      _pharmacyMultiVendor = pharmMode['mode'] != 'single';
      _singleVendorPharmacyId = pharmMode['pharmacy_id'] as String?;
      // Multi-gateway config, with fallback to legacy 'razorpay' config
      _activeGateway = '${pg['active'] ?? 'razorpay'}';
      final rzpGw = gwOf('razorpay');
      _razorpayEnabled = rzpGw.isNotEmpty
          ? rzpGw['enabled'] == true
          : rzp['enabled'] == true;
      _razorpayTest = rzpGw['test_mode'] != false;
      _razorpayKeyId.text =
          '${rzpGw['key_id'] ?? rzp['key_id'] ?? ''}';
      final cfGw = gwOf('cashfree');
      _cashfreeEnabled = cfGw['enabled'] == true;
      _cashfreeTest = cfGw['test_mode'] != false;
      _cashfreeKeyId.text = '${cfGw['key_id'] ?? ''}';
      final imGw = gwOf('instamojo');
      _instamojoEnabled = imGw['enabled'] == true;
      _instamojoTest = imGw['test_mode'] != false;
      _instamojoKeyId.text = '${imGw['key_id'] ?? ''}';
      final puGw = gwOf('payu');
      _payuEnabled = puGw['enabled'] == true;
      _payuTest = puGw['test_mode'] != false;
      _payuKeyId.text = '${puGw['key_id'] ?? ''}';
    });
    // Load secrets from secure_settings (admin-only)
    final secrets = await state.supabaseRepository.fetchSecureSettings([
      'razorpay_key_secret',
      'razorpay_webhook_secret',
      'cashfree_secret_key',
      'instamojo_auth_token',
      'payu_salt',
    ]);
    if (mounted) {
      setState(() {
        _razorpayKeySecret.text = secrets['razorpay_key_secret'] ?? '';
        _razorpayWebhookSecret.text =
            secrets['razorpay_webhook_secret'] ?? '';
        _cashfreeSecret.text = secrets['cashfree_secret_key'] ?? '';
        _instamojoSecret.text = secrets['instamojo_auth_token'] ?? '';
        _payuSecret.text = secrets['payu_salt'] ?? '';
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

  /// Save multi-gateway config: gateway list + active choice to
  /// app_config ('payment_gateways'), secrets to secure_settings.
  ///
  /// Double-check: if the save would leave customers with NO working
  /// online gateway, warn the admin first — saving then means
  /// customers only get Cash on Delivery / Pay at Clinic.
  Future<void> _saveGateways() async {
    final activeName = _gwName(_activeGateway);
    final activeEnabled = _gwEnabled(_activeGateway);
    final activeHasKey = _gwHasKey(_activeGateway);
    if (!activeEnabled || !activeHasKey) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded,
              size: 36, color: RemedooTheme.emergency),
          title: Text(!activeEnabled
              ? 'No payment gateway is active'
              : '$activeName key is missing'),
          content: Text(!activeEnabled
              ? 'You are saving with no active payment gateway.\n\n'
                  'Customers will NOT see "Pay Online" — they will only '
                  'get Cash on Delivery / Pay at Clinic.\n\nSave anyway?'
              : 'The active gateway ($activeName) has no key saved, so '
                  'online payments will fail.\n\nCustomers will only be '
                  'able to use Cash on Delivery / Pay at Clinic.\n\n'
                  'Save anyway?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    setState(() => _saving = true);
    final state = AppStateScope.of(context);
    final repo = state.supabaseRepository;

    final config = {
      'active': _activeGateway,
      'gateways': {
        'razorpay': {
          'enabled': _razorpayEnabled,
          'key_id': _razorpayKeyId.text.trim(),
          'test_mode': _razorpayTest,
        },
        'cashfree': {
          'enabled': _cashfreeEnabled,
          'key_id': _cashfreeKeyId.text.trim(),
          'test_mode': _cashfreeTest,
        },
        'instamojo': {
          'enabled': _instamojoEnabled,
          'key_id': _instamojoKeyId.text.trim(),
          'test_mode': _instamojoTest,
        },
        'payu': {
          'enabled': _payuEnabled,
          'key_id': _payuKeyId.text.trim(),
          'test_mode': _payuTest,
        },
      },
    };
    bool ok = await state.saveAppConfigValue('payment_gateways', config);
    // Keep legacy 'razorpay' config in sync (older builds read it)
    await state.saveAppConfigValue('razorpay', {
      'enabled': _razorpayEnabled,
      'key_id': _razorpayKeyId.text.trim(),
    });

    Future<void> saveSecret(String key, String value) async {
      final v = value.trim();
      if (v.isNotEmpty) {
        ok = await repo.saveSecureSetting(key, v) && ok;
      }
    }

    await saveSecret('razorpay_key_id', _razorpayKeyId.text);
    await saveSecret('razorpay_key_secret', _razorpayKeySecret.text);
    await saveSecret('razorpay_webhook_secret', _razorpayWebhookSecret.text);
    await saveSecret('cashfree_secret_key', _cashfreeSecret.text);
    await saveSecret('instamojo_auth_token', _instamojoSecret.text);
    await saveSecret('payu_salt', _payuSecret.text);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(!ok
              ? 'Could not save (admin only)'
              : (activeEnabled && activeHasKey)
                  ? 'Saved — customers will pay online via $activeName'
                  : 'Saved — online payments are OFF. Customers get Cash on Delivery / Pay at Clinic only.')),
    );
  }

  // ---- Gateway state helpers (used by the status banner + checks) ----
  static const _gatewayIds = ['razorpay', 'cashfree', 'instamojo', 'payu'];

  String _gwName(String id) => switch (id) {
        'cashfree' => 'Cashfree',
        'instamojo' => 'Instamojo',
        'payu' => 'PayU',
        _ => 'Razorpay',
      };

  bool _gwEnabled(String id) => switch (id) {
        'cashfree' => _cashfreeEnabled,
        'instamojo' => _instamojoEnabled,
        'payu' => _payuEnabled,
        _ => _razorpayEnabled,
      };

  bool _gwTest(String id) => switch (id) {
        'cashfree' => _cashfreeTest,
        'instamojo' => _instamojoTest,
        'payu' => _payuTest,
        _ => _razorpayTest,
      };

  bool _gwHasKey(String id) => switch (id) {
        'cashfree' => _cashfreeKeyId.text.trim().isNotEmpty,
        'instamojo' => _instamojoKeyId.text.trim().isNotEmpty,
        'payu' => _payuKeyId.text.trim().isNotEmpty,
        _ => _razorpayKeyId.text.trim().isNotEmpty,
      };

  /// Make [id] the active gateway AND enable it, so one tap is enough
  /// to switch what customers pay with.
  void _setActiveGateway(String id) {
    setState(() {
      _activeGateway = id;
      switch (id) {
        case 'cashfree':
          _cashfreeEnabled = true;
        case 'instamojo':
          _instamojoEnabled = true;
        case 'payu':
          _payuEnabled = true;
        default:
          _razorpayEnabled = true;
      }
    });
  }

  /// Live status banner for the Payment Gateways section: tells the
  /// admin at a glance whether customers can pay online right now.
  Widget _gatewayStatusBanner() {
    final name = _gwName(_activeGateway);
    final activeEnabled = _gwEnabled(_activeGateway);
    final activeHasKey = _gwHasKey(_activeGateway);
    final anyEnabled = _gatewayIds.any(_gwEnabled);

    late final Color color;
    late final IconData icon;
    late final String title;
    late final String body;
    if (activeEnabled && activeHasKey) {
      color = RemedooTheme.success;
      icon = Icons.check_circle;
      title = '$name is ACTIVE for customers';
      body = _gwTest(_activeGateway)
          ? 'Test mode — no real money moves. Customers see Pay Online via $name, plus offline options.'
          : 'LIVE mode — real payments. Customers see Pay Online via $name, plus offline options.';
    } else if (activeEnabled) {
      color = RemedooTheme.warning;
      icon = Icons.warning_amber_rounded;
      title = '$name is active but its key is missing';
      body =
          'Add the $name key in its card below and Save. Until then online payments fail and customers only get Cash on Delivery / Pay at Clinic.';
    } else {
      color = RemedooTheme.emergency;
      icon = Icons.error_outline;
      title = 'No payment gateway is active';
      body = anyEnabled
          ? 'A gateway below is enabled but not set as Active. Tap "Set as Active" on it — until then customers only see Cash on Delivery / Pay at Clinic.'
          : 'Every gateway is disabled. Customers will only see Cash on Delivery / Pay at Clinic — there will be no Pay Online option.';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: color)),
                const SizedBox(height: 3),
                Text(body,
                    style: const TextStyle(fontSize: 12.5, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One gateway settings card (enable switch, keys, test mode).
  Widget _gatewayCard({
    required String id,
    required String name,
    required String tagline,
    required Color brandColor,
    required bool isActive,
    required VoidCallback onSetActive,
    required String keyLabel,
    required String keyHint,
    required String secretLabel,
    required String secretHint,
    required bool enabled,
    required bool testMode,
    required TextEditingController keyController,
    required TextEditingController secretController,
    required ValueChanged<bool> onEnabled,
    required ValueChanged<bool> onTestMode,
    bool showWebhook = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.05),
          border: Border.all(
            color: isActive
                ? scheme.primary
                : Theme.of(context).dividerColor,
            width: isActive ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              // Branded header: monogram, name, tagline, status chips.
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name[0],
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            if (isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('ACTIVE',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(tagline,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: testMode
                          ? RemedooTheme.warning.withValues(alpha: 0.14)
                          : RemedooTheme.success.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(testMode ? 'TEST' : 'LIVE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: testMode
                                ? RemedooTheme.warning
                                : RemedooTheme.success)),
                  ),
                ],
              ),
              SwitchListTile(
                value: enabled,
                onChanged: onEnabled,
                title: const Text('Enabled',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    enabled ? 'Turned on' : 'Turned off',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 4),
              RTextField(
                  label: keyLabel, hint: keyHint, controller: keyController),
              const SizedBox(height: 8),
              RTextField(
                  label: secretLabel,
                  hint: secretHint,
                  controller: secretController,
                  obscureText: true),
              if (showWebhook) ...[
                const SizedBox(height: 8),
                RTextField(
                    label: 'Webhook Secret (optional)',
                    hint: 'From Razorpay dashboard > Webhooks',
                    controller: _razorpayWebhookSecret,
                    obscureText: true),
              ],
              SwitchListTile(
                value: testMode,
                onChanged: onTestMode,
                title: const Text('Test mode',
                    style: TextStyle(fontSize: 14)),
                subtitle: Text(
                    testMode
                        ? 'Test keys — no real money moves'
                        : 'LIVE mode — real money',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                contentPadding: EdgeInsets.zero,
              ),
              if (!isActive)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onSetActive,
                    icon: const Icon(Icons.bolt, size: 16),
                    label: Text('Set as Active — customers will pay via $name'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const RLoading();
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
          // ---- Support Chat ----
          const RSectionHeader(
              title: 'Support Chat',
              subtitle: 'Media attachments in user support chats'),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: _supportMediaEnabled,
                  onChanged: (v) =>
                      setState(() => _supportMediaEnabled = v),
                  title: const Text('Allow media uploads',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      _supportMediaEnabled
                          ? 'Users can attach photos & files in support chat'
                          : 'Users can only send text in support chat',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                RTextField(
                  label: 'Max files per chat',
                  hint: '5',
                  controller: _supportMediaLimit,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'How many photos/files one user can attach inside a single support query. Images & PDF, max 10 MB each.',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 12),
                RButton(
                  label: 'Save',
                  small: true,
                  onPressed: _saving
                      ? null
                      : () => _save('support_chat', {
                            'media_enabled': _supportMediaEnabled,
                            'media_per_ticket': (int.tryParse(
                                        _supportMediaLimit.text
                                            .trim()) ??
                                    5)
                                .clamp(1, 50),
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
          // ---- Payment Gateways (multi-gateway, switchable) ----
          const RSectionHeader(
              title: 'Payment Gateways',
              subtitle:
                  'Add keys for any gateway, pick the active one — '
                  'switch anytime. Payments open as a secure hosted page.'),
          const SizedBox(height: 12),
          _gatewayStatusBanner(),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active gateway',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in const [
                      ('razorpay', 'Razorpay'),
                      ('cashfree', 'Cashfree'),
                      ('instamojo', 'Instamojo'),
                      ('payu', 'PayU'),
                    ])
                      ChoiceChip(
                        label: Text(g.$2),
                        selected: _activeGateway == g.$1,
                        onSelected: (_) => _setActiveGateway(g.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    'Users will pay via the active gateway. Make sure it is enabled below with keys saved.',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _gatewayCard(
            id: 'razorpay',
            name: 'Razorpay',
            tagline: 'UPI · Cards · Netbanking · Wallets',
            brandColor: const Color(0xFF0F52BA),
            isActive: _activeGateway == 'razorpay',
            onSetActive: () => _setActiveGateway('razorpay'),
            keyLabel: 'Key ID',
            keyHint: 'rzp_test_... or rzp_live_...',
            secretLabel: 'Key Secret',
            secretHint: 'Stored securely, never shown to users',
            enabled: _razorpayEnabled,
            testMode: _razorpayTest,
            keyController: _razorpayKeyId,
            secretController: _razorpayKeySecret,
            onEnabled: (v) => setState(() => _razorpayEnabled = v),
            onTestMode: (v) => setState(() => _razorpayTest = v),
            showWebhook: true,
          ),
          _gatewayCard(
            id: 'cashfree',
            name: 'Cashfree',
            tagline: 'UPI · Cards · Netbanking · Pay Later',
            brandColor: const Color(0xFF00A86B),
            isActive: _activeGateway == 'cashfree',
            onSetActive: () => _setActiveGateway('cashfree'),
            keyLabel: 'App ID (Client ID)',
            keyHint: 'From Cashfree dashboard > Developers',
            secretLabel: 'Secret Key (Client Secret)',
            secretHint: 'Stored securely',
            enabled: _cashfreeEnabled,
            testMode: _cashfreeTest,
            keyController: _cashfreeKeyId,
            secretController: _cashfreeSecret,
            onEnabled: (v) => setState(() => _cashfreeEnabled = v),
            onTestMode: (v) => setState(() => _cashfreeTest = v),
          ),
          _gatewayCard(
            id: 'instamojo',
            name: 'Instamojo',
            tagline: 'UPI · Cards · Payment Links — easy for individuals',
            brandColor: const Color(0xFF5B4BC4),
            isActive: _activeGateway == 'instamojo',
            onSetActive: () => _setActiveGateway('instamojo'),
            keyLabel: 'API Key',
            keyHint: 'From Instamojo dashboard > API',
            secretLabel: 'Auth Token',
            secretHint: 'Stored securely',
            enabled: _instamojoEnabled,
            testMode: _instamojoTest,
            keyController: _instamojoKeyId,
            secretController: _instamojoSecret,
            onEnabled: (v) => setState(() => _instamojoEnabled = v),
            onTestMode: (v) => setState(() => _instamojoTest = v),
          ),
          _gatewayCard(
            id: 'payu',
            name: 'PayU',
            tagline: 'UPI · Cards · Netbanking · EMI',
            brandColor: const Color(0xFF6CBE45),
            isActive: _activeGateway == 'payu',
            onSetActive: () => _setActiveGateway('payu'),
            keyLabel: 'Merchant Key',
            keyHint: 'From PayU dashboard',
            secretLabel: 'Merchant Salt',
            secretHint: 'Stored securely',
            enabled: _payuEnabled,
            testMode: _payuTest,
            keyController: _payuKeyId,
            secretController: _payuSecret,
            onEnabled: (v) => setState(() => _payuEnabled = v),
            onTestMode: (v) => setState(() => _payuTest = v),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RemedooTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'All secrets are stored in a secure admin-only table and '
              'never sent to user devices. Only the active gateway is '
              'used for new payments.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: RButton(
              label: 'Save Gateways',
              small: true,
              onPressed: _saving ? null : () => _saveGateways(),
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

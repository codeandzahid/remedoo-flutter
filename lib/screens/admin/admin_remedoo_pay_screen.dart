import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/refunds.dart';
import '../../widgets/widgets.dart';

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}

/// Remedoo Pay — manage the whole payment system in one place:
/// live payments list with totals, plus the gateway settings
/// (UPI ID, payee name, server URL, SMS-observer token) and the
/// Gmail automation card (bank credit-alert emails confirm payments
/// automatically via the Worker's Gmail poller).
///
/// Sessions live in `remedoo_pay_sessions` (written by the Remedoo
/// Pay Cloudflare Worker); settings live in app_config
/// `payment_gateways.youpi` + secure_settings, same as the App
/// Settings card — both screens edit the same values.
class AdminRemedooPayScreen extends StatefulWidget {
  const AdminRemedooPayScreen({super.key});

  @override
  State<AdminRemedooPayScreen> createState() =>
      _AdminRemedooPayScreenState();
}

class _AdminRemedooPayScreenState extends State<AdminRemedooPayScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _sessions = [];

  Map<String, dynamic> _fullConfig = {};
  String _activeGateway = '';
  bool _enabled = false;
  final _serverUrl = TextEditingController();
  final _vpa = TextEditingController();
  final _payeeName = TextEditingController();
  String _observerToken = '';
  Timer? _refreshTimer;

  // Gmail automation (bank credit-alert emails confirm payments).
  final _gmailClientId = TextEditingController();
  final _gmailClientSecret = TextEditingController();
  String _gmailConnectedEmail = '';
  String _gmailLastPollAt = '';
  String _gmailLastResult = '';
  bool _gmailBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _loadSessions());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _serverUrl.dispose();
    _vpa.dispose();
    _payeeName.dispose();
    _gmailClientId.dispose();
    _gmailClientSecret.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    final repo = state.supabaseRepository;
    final all = await repo.fetchAppConfig();
    final cfg = all['payment_gateways'] ?? {};
    final gateways = cfg['gateways'] is Map
        ? Map<String, dynamic>.from(cfg['gateways'])
        : <String, dynamic>{};
    final yp = gateways['youpi'] is Map
        ? Map<String, dynamic>.from(gateways['youpi'])
        : <String, dynamic>{};
    final secrets = await repo.fetchSecureSettings([
      'remedoo_pay_observer_token',
      'gmail_client_id',
      'gmail_client_secret',
      'gmail_connected_email',
      'gmail_last_poll_at',
      'gmail_last_result',
    ]);
    final sessions = await repo.fetchRemedooPaySessions();
    if (!mounted) return;
    setState(() {
      _fullConfig = Map<String, dynamic>.from(cfg);
      _activeGateway = '${cfg['active'] ?? ''}';
      _enabled = yp['enabled'] == true;
      _serverUrl.text = '${yp['base_url'] ?? ''}';
      _vpa.text = '${yp['vpa'] ?? ''}';
      _payeeName.text = '${yp['payee_name'] ?? ''}';
      _observerToken = secrets['remedoo_pay_observer_token'] ?? '';
      _gmailClientId.text = secrets['gmail_client_id'] ?? '';
      _gmailClientSecret.text = secrets['gmail_client_secret'] ?? '';
      _gmailConnectedEmail = secrets['gmail_connected_email'] ?? '';
      _gmailLastPollAt = secrets['gmail_last_poll_at'] ?? '';
      _gmailLastResult = secrets['gmail_last_result'] ?? '';
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _loadSessions() async {
    if (!mounted || _saving) return;
    final state = AppStateScope.of(context);
    final sessions =
        await state.supabaseRepository.fetchRemedooPaySessions();
    if (!mounted) return;
    setState(() => _sessions = sessions);
  }

  Future<void> _save({bool makeActive = false}) async {
    final state = AppStateScope.of(context);
    final repo = state.supabaseRepository;
    setState(() => _saving = true);
    final config = Map<String, dynamic>.from(_fullConfig);
    final gateways = config['gateways'] is Map
        ? Map<String, dynamic>.from(config['gateways'])
        : <String, dynamic>{};
    final yp = gateways['youpi'] is Map
        ? Map<String, dynamic>.from(gateways['youpi'])
        : <String, dynamic>{};
    yp['enabled'] = makeActive ? true : _enabled;
    yp['base_url'] = _serverUrl.text.trim();
    yp['vpa'] = _vpa.text.trim();
    yp['payee_name'] = _payeeName.text.trim();
    gateways['youpi'] = yp;
    config['gateways'] = gateways;
    if (makeActive) config['active'] = 'youpi';
    var ok = await state.saveAppConfigValue('payment_gateways', config);
    // Observer token: create once, then keep (SMS forwarder app uses it).
    if (_observerToken.isEmpty) {
      final r = Random.secure();
      _observerToken =
          List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
    }
    ok = await repo.saveSecureSetting(
            'remedoo_pay_observer_token', _observerToken) &&
        ok;
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (makeActive) {
        _activeGateway = 'youpi';
        _enabled = true;
      }
      _fullConfig = config;
    });
    _snack(
        context,
        ok
            ? (makeActive
                ? 'Remedoo Pay is now the ACTIVE payment system'
                : 'Remedoo Pay settings saved')
            : 'Save failed — please try again');
  }

  // ----- Gmail automation -----

  String get _workerBase =>
      _serverUrl.text.trim().replaceAll(RegExp(r'/+$'), '');

  bool get _gmailConnected => _gmailConnectedEmail.isNotEmpty;

  /// Refresh only the Gmail status lines (never the text fields, so
  /// an admin mid-typing is not disturbed).
  Future<void> _loadGmailStatus() async {
    final state = AppStateScope.of(context);
    final secrets =
        await state.supabaseRepository.fetchSecureSettings(const [
      'gmail_connected_email',
      'gmail_last_poll_at',
      'gmail_last_result',
    ]);
    if (!mounted) return;
    setState(() {
      _gmailConnectedEmail = secrets['gmail_connected_email'] ?? '';
      _gmailLastPollAt = secrets['gmail_last_poll_at'] ?? '';
      _gmailLastResult = secrets['gmail_last_result'] ?? '';
    });
  }

  Future<void> _saveGmailCredentials() async {
    final state = AppStateScope.of(context);
    final repo = state.supabaseRepository;
    setState(() => _gmailBusy = true);
    var ok = await repo.saveSecureSetting(
        'gmail_client_id', _gmailClientId.text.trim());
    ok = await repo.saveSecureSetting(
            'gmail_client_secret', _gmailClientSecret.text.trim()) &&
        ok;
    if (!mounted) return;
    setState(() => _gmailBusy = false);
    _snack(
        context,
        ok
            ? 'Gmail settings saved — now tap Connect Gmail'
            : 'Save failed — please try again');
  }

  Future<void> _connectGmail() async {
    final base = _workerBase;
    if (base.isEmpty) {
      _snack(context, 'Set the Server URL above and Save first');
      return;
    }
    final ok = await launchUrl(Uri.parse('$base/api/v1/gmail/connect'),
        mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) _snack(context, 'Could not open the Google sign-in page');
  }

  /// POST to a token-protected Gmail endpoint on the Worker (the
  /// observer token is the shared credential, same as the SMS
  /// forwarder). Returns the decoded JSON body, or null after
  /// showing why it failed.
  Future<Map<String, dynamic>?> _gmailCall(String path) async {
    final base = _workerBase;
    if (base.isEmpty) {
      _snack(context, 'Set the Server URL above and Save first');
      return null;
    }
    if (_observerToken.isEmpty) {
      _snack(context,
          'Save the Remedoo Pay settings first — that creates the security token');
      return null;
    }
    try {
      final res = await http.post(
        Uri.parse('$base$path'),
        headers: {'x-observer-token': _observerToken},
      ).timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (mounted) _snack(context, 'Unexpected reply from the server');
      return null;
    } catch (_) {
      if (mounted) _snack(context, 'Could not reach the Remedoo Pay server');
      return null;
    }
  }

  Future<void> _testGmail() async {
    setState(() => _gmailBusy = true);
    final r = await _gmailCall('/api/v1/gmail/test');
    if (!mounted) return;
    setState(() => _gmailBusy = false);
    if (r == null) return;
    if (r['ok'] == true) {
      _snack(context,
          'Gmail connected: ${r['email']} · ${r['messagesTotal']} emails in the inbox');
    } else {
      _snack(context, '${r['error'] ?? 'Gmail test failed'}');
    }
    _loadGmailStatus();
  }

  Future<void> _pollGmail() async {
    setState(() => _gmailBusy = true);
    final r = await _gmailCall('/api/v1/gmail/poll');
    if (!mounted) return;
    setState(() => _gmailBusy = false);
    if (r == null) return;
    if (r['ok'] == true) {
      _snack(context, 'Gmail check done — ${r['result']}');
    } else if (r['reason'] == 'not_connected') {
      _snack(context, 'Gmail is not connected yet — tap Connect Gmail');
    } else {
      _snack(context,
          'Gmail check failed: ${r['error'] ?? r['reason'] ?? 'unknown error'}');
    }
    _loadGmailStatus();
    _loadSessions();
  }

  Future<void> _disconnectGmail() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Disconnect Gmail?',
      message: 'Automatic email confirmation stops. Payments then '
          'need the SMS app or a manual Confirm Paid tap until Gmail '
          'is reconnected.',
      confirmLabel: 'Disconnect',
    );
    if (!confirmed || !mounted) return;
    setState(() => _gmailBusy = true);
    final r = await _gmailCall('/api/v1/gmail/disconnect');
    if (!mounted) return;
    setState(() => _gmailBusy = false);
    if (r != null && r['ok'] == true) {
      setState(() {
        _gmailConnectedEmail = '';
        _gmailLastPollAt = '';
        _gmailLastResult = '';
      });
      _snack(context, 'Gmail disconnected');
    } else if (r != null) {
      _snack(context, 'Disconnect failed — please try again');
    }
  }

  // ----- derived stats -----
  int get _collectedPaise => _sessions
      .where((s) => s['status'] == 'SUCCESS')
      .fold(0, (sum, s) => sum + ((s['amount_paise'] as num?)?.toInt() ?? 0));
  int get _paidCount => _sessions.where((s) => s['status'] == 'SUCCESS').length;
  int get _waitingCount => _sessions
      .where((s) => s['status'] == 'ACTIVE' || s['status'] == 'QUEUED')
      .length;

  static String _rupees(int paise) =>
      '₹${(paise / 100).toStringAsFixed(2)}';

  static String _when(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    var h = dt.hour % 12;
    if (h == 0) h = 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $h:$mm $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const RLoading();
    final isActive = _activeGateway == 'youpi';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---------- status banner ----------
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (isActive && _enabled)
                ? RemedooTheme.success.withValues(alpha: 0.12)
                : RemedooTheme.warning.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                  (isActive && _enabled)
                      ? Icons.check_circle
                      : Icons.info_outline,
                  color: (isActive && _enabled)
                      ? RemedooTheme.success
                      : RemedooTheme.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (isActive && _enabled)
                      ? 'Remedoo Pay is ACTIVE — customers pay online straight to your UPI ID.'
                      : 'Remedoo Pay is not live yet. Fill your UPI ID below, Save, then tap "Set as Active".',
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ---------- stats ----------
        Row(
          children: [
            _statCard('Collected', _rupees(_collectedPaise),
                Icons.payments, RemedooTheme.success),
            const SizedBox(width: 10),
            _statCard('Paid payments', '$_paidCount', Icons.receipt_long,
                scheme.primary),
            const SizedBox(width: 10),
            _statCard('Waiting now', '$_waitingCount', Icons.hourglass_top,
                RemedooTheme.warning),
          ],
        ),
        const SizedBox(height: 20),
        // ---------- settings ----------
        const Text('Settings',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Money goes straight to this UPI ID. No fees.',
            style:
                TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: const Text('Enable Remedoo Pay',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  contentPadding: EdgeInsets.zero,
                ),
                RTextField(
                    label: 'Your UPI ID',
                    hint: 'e.g. yourname@okhdfcbank',
                    controller: _vpa),
                const SizedBox(height: 10),
                RTextField(
                    label: 'Payee Name',
                    hint: 'Name customers see on the payment page',
                    controller: _payeeName),
                const SizedBox(height: 10),
                RTextField(
                    label: 'Server URL',
                    hint: 'https://remedoo-pay.southkhanday.workers.dev',
                    controller: _serverUrl),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payment alerts (SMS observer)',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                          'Install any free SMS-forwarder app on the phone '
                          'that receives your bank SMS. Forward "credited" '
                          'messages to:\n'
                          '${_serverUrl.text.trim().isEmpty ? '<Server URL>' : _serverUrl.text.trim()}/api/v1/observer/sms\n'
                          'with header  X-Observer-Token:',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              height: 1.5)),
                      const SizedBox(height: 4),
                      SelectableText(
                        _observerToken.isEmpty
                            ? '(created automatically when you Save)'
                            : _observerToken,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(),
                      icon: const Icon(Icons.save, size: 17),
                      label: Text(_saving ? 'Saving…' : 'Save Settings'),
                    ),
                    const SizedBox(width: 10),
                    if (!isActive)
                      OutlinedButton.icon(
                        onPressed: _saving ? null : () => _save(makeActive: true),
                        icon: const Icon(Icons.bolt, size: 16),
                        label: const Text('Set as Active'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ---------- gmail automation ----------
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.mark_email_read_outlined, size: 19),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Gmail Automation — automatic payment confirmation',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                    'Connect the Gmail account that receives your '
                    'bank\'s credit-alert emails. When a customer pays, '
                    'the alert email confirms the payment by itself — '
                    'no phone app needed, no taps by anyone. Remedoo '
                    'checks the inbox every minute.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                        height: 1.5)),
                const SizedBox(height: 12),
                RTextField(
                    label: 'Google Client ID',
                    hint: '…apps.googleusercontent.com',
                    controller: _gmailClientId),
                const SizedBox(height: 10),
                RTextField(
                    label: 'Google Client Secret',
                    hint: 'From the same Google Cloud OAuth client',
                    controller: _gmailClientSecret,
                    obscureText: true),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _gmailBusy ? null : _saveGmailCredentials,
                  icon: const Icon(Icons.save, size: 17),
                  label: Text(_gmailBusy ? 'Working…' : 'Save Gmail Settings'),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _gmailConnected
                                ? Icons.check_circle
                                : Icons.info_outline,
                            size: 16,
                            color: _gmailConnected
                                ? RemedooTheme.success
                                : RemedooTheme.warning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _gmailConnected
                                  ? 'Connected as $_gmailConnectedEmail'
                                  : 'Not connected',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      if (_gmailConnected) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Last check ${_when(_gmailLastPollAt).isEmpty ? '—' : _when(_gmailLastPollAt)}'
                          '${_gmailLastResult.isEmpty ? '' : ' · $_gmailLastResult'}',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _gmailBusy ? null : _connectGmail,
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text('Connect Gmail'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _gmailBusy ? null : _testGmail,
                      icon: const Icon(Icons.wifi_tethering, size: 16),
                      label: const Text('Test connection'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _gmailBusy ? null : _pollGmail,
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Check now'),
                    ),
                    if (_gmailConnected)
                      TextButton.icon(
                        onPressed: _gmailBusy ? null : _disconnectGmail,
                        icon: Icon(Icons.link_off,
                            size: 16, color: RemedooTheme.emergency),
                        label: Text('Disconnect',
                            style:
                                TextStyle(color: RemedooTheme.emergency)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Covers payments received on the Remedoo central UPI. '
                  'Payments to panelists\' own UPIs still confirm by '
                  'SMS app or their Confirm Paid tap.',
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // ---------- payments ----------
        Row(
          children: [
            const Text('Payments',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loadSessions,
            ),
          ],
        ),
        if (_sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No payments yet. When a customer pays with Remedoo Pay, '
              'the payment appears here automatically.',
              style:
                  TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < _sessions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _paymentRow(_sessions[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentRow(Map<String, dynamic> s) {
    final scheme = Theme.of(context).colorScheme;
    final status = '${s['status'] ?? ''}';
    final paise = (s['amount_paise'] as num?)?.toInt() ?? 0;
    final customer = s['customer'] is Map
        ? Map<String, dynamic>.from(s['customer'])
        : const <String, dynamic>{};
    final name = '${customer['name'] ?? ''}'.trim();
    final utr = '${s['utr'] ?? ''}'.trim();
    final actions = _rowActions(s);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_rupees(paise),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (name.isNotEmpty) name,
                        'Order ${s['order_id'] ?? ''}',
                        _when(s['created_at']?.toString()),
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    if (utr.isNotEmpty)
                      Text('UTR $utr',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant)),
                    if (s['vpa'] != null &&
                        '${s['vpa']}'.isNotEmpty)
                      Text(
                          'To: ${s['payee_name'] ?? ''} · ${s['vpa']}',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant)),
                    if (sessionCustomerUpi(s) != null)
                      Text(
                          'Customer UPI: ${sessionCustomerUpi(s)}',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant)),
                    if ('${s['refund_status'] ?? ''}'.isNotEmpty)
                      Text(
                          'Refund: ${s['refund_status']}'
                          '${('${s['refund_utr'] ?? ''}'.trim().isNotEmpty) ? ' · UTR ${s['refund_utr']}' : ''}',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusChip(status),
                  if (isRefundOverdue(
                    refundStatus: '${s['refund_status'] ?? ''}',
                    requestedAt: DateTime.tryParse(
                        '${s['refund_requested_at'] ?? ''}'),
                    createdAt:
                        DateTime.tryParse('${s['created_at'] ?? ''}'),
                  )) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Overdue refund',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 4, children: actions),
            ),
        ],
      ),
    );
  }

  /// Manual controls per payment: Confirm / Cancel / Pending,
  /// shown according to the payment's current status.
  List<Widget> _rowActions(Map<String, dynamic> s) {
    final status = '${s['status'] ?? ''}';
    final btn = (
      String label,
      IconData icon,
      Color color,
      String newStatus,
      Map<String, dynamic> patch,
      String confirmTitle,
      String confirmMsg,
    ) =>
        TextButton.icon(
          onPressed: _saving
              ? null
              : () => _applyStatus(
                  s, newStatus, patch, confirmTitle, confirmMsg, label),
          icon: Icon(icon, size: 15, color: color),
          label:
              Text(label, style: TextStyle(fontSize: 12.5, color: color)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
    return switch (status) {
      'ACTIVE' || 'QUEUED' => [
          btn(
              'Confirm Paid',
              Icons.check_circle_outline,
              RemedooTheme.success,
              'SUCCESS',
              {
                'status': 'SUCCESS',
                'paid_at': DateTime.now().toUtc().toIso8601String(),
              },
              'Mark this payment as PAID?',
              'Use this only if the money is in your bank account. '
                  'The customer will see the payment as confirmed.'),
          btn(
              'Cancel',
              Icons.cancel_outlined,
              RemedooTheme.emergency,
              'CANCELLED',
              {'status': 'CANCELLED'},
              'Cancel this payment?',
              'The payment page will stop and the customer cannot pay '
                  'with this link anymore.'),
        ],
      'SUCCESS' => [
          btn(
              'Mark Pending',
              Icons.hourglass_top,
              RemedooTheme.warning,
              'ACTIVE',
              {'status': 'ACTIVE', 'paid_at': null},
              'Re-open this payment as Pending?',
              'It becomes the one open payment again (any other open '
                  'payment is cancelled first) and can be paid or '
                  'confirmed again.'),
        ],
      'EXPIRED' || 'CANCELLED' || 'FAILED' => [
          btn(
              'Mark Pending',
              Icons.hourglass_top,
              RemedooTheme.warning,
              'ACTIVE',
              {'status': 'ACTIVE', 'paid_at': null},
              'Re-open this payment as Pending?',
              'It becomes the one open payment again (any other open '
                  'payment is cancelled first) and can be paid or '
                  'confirmed again.'),
        ],
      _ => const [],
    };
  }

  Future<void> _applyStatus(
    Map<String, dynamic> session,
    String newStatus,
    Map<String, dynamic> patch,
    String title,
    String message,
    String actionLabel,
  ) async {
    final ok = await confirmDialog(context,
        title: title, message: message, confirmLabel: actionLabel);
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    var effectivePatch = patch;
    if (newStatus == 'SUCCESS') {
      effectivePatch = {
        ...patch,
        'paid_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
    final state = AppStateScope.of(context);
    if (newStatus == 'ACTIVE') {
      // No queue: only one open payment. Cancel any other open one,
      // then re-open this one with a fresh 5-minute window.
      for (final other in _sessions) {
        if (other['id'] != session['id'] && other['status'] == 'ACTIVE') {
          await state.supabaseRepository.updateRemedooPaySession(
              '${other['id']}', {'status': 'CANCELLED'});
        }
      }
      effectivePatch = {
        ...patch,
        'activated_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
    final done = await state.supabaseRepository
        .updateRemedooPaySession('${session['id']}', effectivePatch);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(
        context,
        done
            ? 'Payment updated: $newStatus'
            : 'Could not update — please try again');
    if (done) _loadSessions();
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'SUCCESS' => ('Paid', RemedooTheme.success),
      'ACTIVE' => ('Waiting for payment', RemedooTheme.warning),
      'QUEUED' => ('Pending', RemedooTheme.teal),
      'EXPIRED' => ('Expired', Colors.grey),
      'CANCELLED' => ('Cancelled', Colors.grey),
      'FAILED' => ('Failed', RemedooTheme.emergency),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

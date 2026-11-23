import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/form_kit.dart';
import 'admin_remedoo_pay_screen.dart';

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}

String _rupees(int paise) =>
    '₹${(paise / 100).toStringAsFixed(2)}';

String _when(dynamic v) {
  if (v == null) return '—';
  final d = DateTime.tryParse('$v')?.toLocal();
  if (d == null) return '$v';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}

Color _statusColor(BuildContext context, String status) {
  switch (status) {
    case 'SUCCESS':
      return RemedooTheme.success;
    case 'ACTIVE':
    case 'QUEUED':
      return RemedooTheme.warning;
    case 'FAILED':
    case 'EXPIRED':
      return Theme.of(context).colorScheme.error;
    default:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

/// Remedoo Pay Admin — the full payment-system console, served at
/// /remedoopayadmin (admin login required, same gate as the admin
/// panel). Tabs: Dashboard, Payments, Panelists, Refunds, Settings
/// (the existing Remedoo Pay screen) and Test Tools.
///
/// Read-only where the standing rules demand it: panelist UPI
/// activation stays email-OTP only (no bypass buttons here), and
/// refunds are a read-only queue — the refund flow itself is
/// unchanged. Payments still go to each panelist's own UPI.
class AdminRemedooPayAdminScreen extends StatefulWidget {
  const AdminRemedooPayAdminScreen({super.key});

  @override
  State<AdminRemedooPayAdminScreen> createState() =>
      _AdminRemedooPayAdminScreenState();
}

class _AdminRemedooPayAdminScreenState
    extends State<AdminRemedooPayAdminScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _projects = [];
  String _baseUrl = '';
  String _activeGateway = '';
  bool _gatewayEnabled = false;
  String _observerToken = '';
  String _workerHealth = 'Not checked yet';
  String _statusFilter = 'ALL';

  // Test tools state.
  bool _testBusy = false;
  String _testCheckoutUrl = '';
  int? _testAmountPaise;
  String _testResult = '';
  final _simAmount = TextEditingController();
  final _testProjectId = TextEditingController(text: 'remedoo');
  final _testApiKey = TextEditingController();

  // Add-project form.
  final _projId = TextEditingController();
  final _projName = TextEditingController();
  final _projVpa = TextEditingController();
  final _projPayee = TextEditingController();
  final _projKey = TextEditingController();
  bool _projBusy = false;

  static const _statuses = [
    'ALL',
    'QUEUED',
    'ACTIVE',
    'SUCCESS',
    'FAILED',
    'EXPIRED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _simAmount.dispose();
    _testProjectId.dispose();
    _testApiKey.dispose();
    _projId.dispose();
    _projName.dispose();
    _projVpa.dispose();
    _projPayee.dispose();
    _projKey.dispose();
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
    final secrets =
        await repo.fetchSecureSettings(['remedoo_pay_observer_token']);
    final sessions =
        await repo.fetchRemedooPaySessions(limit: 500);
    final projects = await repo.fetchRemedooPayProjects();
    if (!mounted) return;
    setState(() {
      _activeGateway = '${cfg['active'] ?? ''}';
      _gatewayEnabled = yp['enabled'] == true;
      _baseUrl = '${yp['base_url'] ?? ''}'.trim();
      _observerToken = secrets['remedoo_pay_observer_token'] ?? '';
      _sessions = sessions;
      _projects = projects;
      _loading = false;
    });
    _checkWorkerHealth();
  }

  Future<void> _checkWorkerHealth() async {
    if (_baseUrl.isEmpty) {
      if (mounted) {
        setState(() => _workerHealth = 'Server URL not set');
      }
      return;
    }
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/'))
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _workerHealth = body['ok'] == true
          ? 'Online — ${body['service'] ?? 'Remedoo Pay'} '
              '${body['version'] ?? ''}'
          : 'Unexpected reply (HTTP ${r.statusCode})');
    } catch (e) {
      if (mounted) setState(() => _workerHealth = 'Offline: $e');
    }
  }

  // ---- dashboard numbers ----
  int get _volumePaise => _sessions
      .where((s) => s['status'] == 'SUCCESS')
      .fold(0, (a, s) => a + ((s['amount_paise'] as num?)?.toInt() ?? 0));

  int get _verifiedCount =>
      _sessions.where((s) => s['status'] == 'SUCCESS').length;

  int get _openCount => _sessions
      .where((s) => s['status'] == 'QUEUED' || s['status'] == 'ACTIVE')
      .length;

  String get _avgVerifySpeed {
    final secs = <double>[];
    for (final s in _sessions) {
      if (s['status'] != 'SUCCESS') continue;
      final a = DateTime.tryParse('${s['activated_at'] ?? ''}');
      final p = DateTime.tryParse('${s['paid_at'] ?? ''}');
      if (a != null && p != null) {
        secs.add(p.difference(a).inSeconds.toDouble());
      }
    }
    if (secs.isEmpty) return '—';
    final avg = secs.reduce((a, b) => a + b) / secs.length;
    if (avg < 120) return '${avg.toStringAsFixed(0)} sec';
    return '${(avg / 60).toStringAsFixed(1)} min';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Remedoo Pay Admin'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Projects'),
              Tab(text: 'Payments'),
              Tab(text: 'Panelists'),
              Tab(text: 'Refunds'),
              Tab(text: 'Settings'),
              Tab(text: 'Test Tools'),
            ],
          ),
        ),
        body: _loading
            ? const RLoading()
            : TabBarView(
                children: [
                  _dashboardTab(context),
                  _projectsTab(context),
                  _paymentsTab(context),
                  const _PanelistsTab(),
                  _refundsTab(context),
                  const AdminRemedooPayScreen(),
                  _testToolsTab(context),
                ],
              ),
      ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboardTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = _activeGateway == 'youpi' && _gatewayEnabled;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: live
                  ? RemedooTheme.success.withValues(alpha: 0.12)
                  : RemedooTheme.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(live ? Icons.check_circle : Icons.info_outline,
                    color: live
                        ? RemedooTheme.success
                        : RemedooTheme.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    live
                        ? 'Remedoo Pay is ACTIVE.'
                        : 'Remedoo Pay is not live. Active gateway: '
                            '${_activeGateway.isEmpty ? 'none' : _activeGateway}.',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statCard('Total volume', _rupees(_volumePaise),
                  Icons.payments, RemedooTheme.success),
              const SizedBox(width: 10),
              _statCard('Verified payments', '$_verifiedCount',
                  Icons.receipt_long, scheme.primary),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statCard('Open sessions', '$_openCount',
                  Icons.hourglass_top, RemedooTheme.warning),
              const SizedBox(width: 10),
              _statCard('Avg verify speed', _avgVerifySpeed,
                  Icons.speed, scheme.primary),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gateway status',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Worker: $_workerHealth',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                      'Server URL: '
                      '${_baseUrl.isEmpty ? '(not set)' : _baseUrl}',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                      'Sessions loaded: ${_sessions.length} '
                      '(newest 500)',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                      'Projects: ${_projects.length} '
                      '(Remedoo Pay is reusable — see Projects tab)',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _checkWorkerHealth,
                    icon: const Icon(Icons.health_and_safety, size: 16),
                    label: const Text('Check worker again'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProject() async {
    final id = _projId.text.trim().toLowerCase();
    final name = _projName.text.trim();
    if (id.isEmpty || name.isEmpty) {
      _snack(context, 'Project ID and name are required.');
      return;
    }
    if (!RegExp(r'^[a-z0-9][a-z0-9\-_]{1,39}$').hasMatch(id)) {
      _snack(context,
          'Project ID: small letters, numbers, - or _ only.');
      return;
    }
    setState(() => _projBusy = true);
    final repo = AppStateScope.of(context).supabaseRepository;
    final ok = await repo.upsertRemedooPayProject({
      'id': id,
      'name': name,
      'vpa': _projVpa.text.trim().isEmpty ? null : _projVpa.text.trim(),
      'payee_name': _projPayee.text.trim().isEmpty
          ? null
          : _projPayee.text.trim(),
      'api_key':
          _projKey.text.trim().isEmpty ? null : _projKey.text.trim(),
      'enabled': true,
    });
    if (!mounted) return;
    setState(() => _projBusy = false);
    if (ok) {
      _projId.clear();
      _projName.clear();
      _projVpa.clear();
      _projPayee.clear();
      _projKey.clear();
      _snack(context, 'Project saved.');
      _load();
    } else {
      _snack(context,
          'Could not save. Run migration remedoo_pay_projects.sql '
          'once in the Supabase SQL editor, then retry.');
    }
  }

  void _generateApiKey() {
    final r = Random.secure();
    _projKey.text =
        List.generate(32, (_) => r.nextInt(16).toRadixString(16))
            .join();
    setState(() {});
  }

  Widget _projectsTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final repo = AppStateScope.of(context).supabaseRepository;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Remedoo Pay is a standalone payment system. Any '
            'project can use it through the Worker API '
            '(POST /api/v1/payments with projectId + x-api-key). '
            'The Remedoo app is the built-in project "remedoo".',
            style: TextStyle(
                fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (_projects.isEmpty)
            const REmptyState(
              icon: Icons.folder_outlined,
              title: 'No projects yet',
              subtitle: 'Run migration remedoo_pay_projects.sql '
                  'once in the Supabase SQL editor, then add '
                  'projects here.',
            )
          else
            for (final p in _projects)
              Card(
                child: ListTile(
                  leading: Icon(
                    p['enabled'] == true
                        ? Icons.check_circle
                        : Icons.cancel_outlined,
                    color: p['enabled'] == true
                        ? RemedooTheme.success
                        : scheme.onSurfaceVariant,
                  ),
                  title: Text('${p['name'] ?? p['id']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    'ID: ${p['id']} · '
                    'UPI: ${p['vpa'] ?? 'central UPI'}\n'
                    'API key: ${p['api_key'] ?? '(none — open)'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant),
                  ),
                  trailing: Switch(
                    value: p['enabled'] == true,
                    onChanged: (v) async {
                      final ok = await repo
                          .setRemedooPayProjectEnabled(
                              '${p['id']}', v);
                      if (!mounted) return;
                      if (ok) {
                        _load();
                      } else {
                        _snack(context, 'Could not update.');
                      }
                    },
                  ),
                ),
              ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add project',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  RKitField(
                      label: 'Project ID',
                      hint: 'e.g. my-shop (small letters)',
                      controller: _projId),
                  const SizedBox(height: 10),
                  RKitField(
                      label: 'Project name',
                      hint: 'Name shown in this console',
                      controller: _projName),
                  const SizedBox(height: 10),
                  RKitField(
                      label: 'UPI ID (optional)',
                      hint: 'Leave empty to use the central UPI',
                      controller: _projVpa),
                  const SizedBox(height: 10),
                  RKitField(
                      label: 'Payee name (optional)',
                      hint: 'Name customers see at checkout',
                      controller: _projPayee),
                  const SizedBox(height: 10),
                  RKitField(
                      label: 'API key (optional)',
                      hint: 'Caller must send it as x-api-key',
                      controller: _projKey),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _generateApiKey,
                    icon: const Icon(Icons.key, size: 16),
                    label: const Text('Generate API key'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _projBusy ? null : _saveProject,
                    icon: const Icon(Icons.save, size: 17),
                    label:
                        Text(_projBusy ? 'Saving…' : 'Save project'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentsTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _statusFilter == 'ALL'
        ? _sessions
        : _sessions
            .where((s) => s['status'] == _statusFilter)
            .toList();
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              for (final st in _statuses)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(st == 'ALL' ? 'All' : st),
                    selected: _statusFilter == st,
                    onSelected: (_) =>
                        setState(() => _statusFilter = st),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const REmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No payments',
                  subtitle:
                      'Payments with this status will appear here.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final s = rows[i];
                      final paise =
                          (s['amount_paise'] as num?)?.toInt() ?? 0;
                      final status = '${s['status'] ?? ''}';
                      return Card(
                        child: ListTile(
                          leading: Icon(Icons.qr_code_2,
                              color: _statusColor(context, status)),
                          title: Text(
                            '${_rupees(paise)}  ·  $status',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'Order ${s['order_id'] ?? '—'} · '
                            '${_when(s['created_at'])}'
                            '${s['project_id'] != null ? ' · Project ${s['project_id']}' : ''}\n'
                            'To: ${s['vpa'] ?? 'central UPI'}'
                            '${s['utr'] != null ? ' · UTR ${s['utr']}' : ''}',
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showDetail(context, s),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> s) {
    final paise = (s['amount_paise'] as num?)?.toInt() ?? 0;
    final fields = <(String, String)>[
      ('Session ID', '${s['id'] ?? '—'}'),
      ('Order ID', '${s['order_id'] ?? '—'}'),
      ('Project', '${s['project_id'] ?? 'remedoo'}'),
      ('Status', '${s['status'] ?? '—'}'),
      ('Amount', '${_rupees(paise)} ($paise paise)'),
      ('Payee UPI', '${s['vpa'] ?? 'central UPI'}'),
      ('Payee name', '${s['payee_name'] ?? '—'}'),
      ('UTR', '${s['utr'] ?? '—'}'),
      ('Payer UPI', '${s['payer_vpa'] ?? '—'}'),
      ('Payer name', '${s['payer_name'] ?? '—'}'),
      ('Provider', '${s['provider_kind'] ?? '—'} '
          '${s['provider_id'] ?? ''}'),
      ('Description', '${s['description'] ?? '—'}'),
      ('Created', _when(s['created_at'])),
      ('Activated', _when(s['activated_at'])),
      ('Paid', _when(s['paid_at'])),
      ('Refund status', '${s['refund_status'] ?? '—'}'),
      ('Refund UTR', '${s['refund_utr'] ?? '—'}'),
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment detail'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (k, v) in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                              text: '$k: ',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          TextSpan(text: v),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _refundsTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _sessions
        .where((s) =>
            s['refund_status'] != null ||
            s['refund_requested_at'] != null)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Read-only queue. Paid-online refunds are due in '
            '48 hours or 3 working days. Refunds are paid by the '
            'panelist from their own UPI — this view only shows '
            'status.',
            style: TextStyle(
                fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const REmptyState(
                  icon: Icons.replay,
                  title: 'No refunds due',
                  subtitle:
                      'Refund-due payments will appear here.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final s = rows[i];
                      final paise =
                          (s['amount_paise'] as num?)?.toInt() ?? 0;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.replay),
                          title: Text(
                            '${_rupees(paise)}  ·  '
                            '${s['refund_status'] ?? 'requested'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'Order ${s['order_id'] ?? '—'} · '
                            'Requested ${_when(s['refund_requested_at'])}\n'
                            'Paid to: ${s['vpa'] ?? 'central UPI'}'
                            '${s['refund_utr'] != null ? ' · Refund UTR ${s['refund_utr']}' : ''}',
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showDetail(context, s),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ---- test tools ----
  Future<void> _createTestPayment() async {
    if (_baseUrl.isEmpty) {
      _snack(context, 'Set the Server URL in Settings first.');
      return;
    }
    setState(() {
      _testBusy = true;
      _testResult = '';
    });
    try {
      final orderId =
          'ADMIN-TEST-${DateTime.now().millisecondsSinceEpoch}';
      final projId = _testProjectId.text.trim();
      final apiKey = _testApiKey.text.trim();
      final r = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/payments'),
            headers: {
              'Content-Type': 'application/json',
              if (apiKey.isNotEmpty) 'x-api-key': apiKey,
            },
            body: jsonEncode({
              'orderId': orderId,
              'amount': 1,
              'description': 'Remedoo Pay admin test payment',
              if (projId.isNotEmpty) 'projectId': projId,
            }),
          )
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (r.statusCode >= 200 && r.statusCode < 300) {
        setState(() {
          _testCheckoutUrl = '${body['checkoutUrl'] ?? ''}';
          _testAmountPaise =
              int.tryParse('${body['amountPaise'] ?? ''}');
          _testResult = 'Test session created: '
              '${body['paymentId']} · status ${body['status']} · '
              'payable ₹${body['amount']}';
          if (_testAmountPaise != null) {
            _simAmount.text =
                (_testAmountPaise! / 100).toStringAsFixed(2);
          }
        });
      } else {
        setState(() =>
            _testResult = 'Failed (HTTP ${r.statusCode}): '
                '${body['error'] ?? r.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _testResult = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _testBusy = false);
    }
  }

  Future<void> _simulateSms() async {
    if (_baseUrl.isEmpty) {
      _snack(context, 'Set the Server URL in Settings first.');
      return;
    }
    if (_observerToken.isEmpty) {
      _snack(context,
          'Observer token not set yet — save Settings once first.');
      return;
    }
    final amt = double.tryParse(_simAmount.text.trim());
    if (amt == null || amt <= 0) {
      _snack(context, 'Enter the exact test amount first.');
      return;
    }
    setState(() {
      _testBusy = true;
      _testResult = '';
    });
    try {
      final r = Random.secure();
      final utr =
          List.generate(12, (_) => r.nextInt(10)).join();
      final text = 'Your account XXXX0000 has been credited with '
          'Rs. ${amt.toStringAsFixed(2)} on test. '
          'UPI Ref No: $utr';
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/observer/sms'),
            headers: {
              'Content-Type': 'application/json',
              'x-observer-token': _observerToken,
            },
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() => _testResult =
          'Observer reply (HTTP ${resp.statusCode}): ${resp.body}');
      _load();
    } catch (e) {
      if (mounted) setState(() => _testResult = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _testBusy = false);
    }
  }

  Widget _testToolsTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create ₹1 test payment',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Creates a real ₹1 session on the Worker and '
                  'shows its checkout link. Use it to test the '
                  'full flow end to end.',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                RKitField(
                  label: 'Project ID',
                  hint: 'remedoo = this app; or a Projects-tab ID',
                  controller: _testProjectId,
                ),
                const SizedBox(height: 10),
                RKitField(
                  label: 'API key (if the project has one)',
                  hint: 'Sent as x-api-key header',
                  controller: _testApiKey,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _testBusy ? null : _createTestPayment,
                  icon: const Icon(Icons.science, size: 17),
                  label: const Text('Create test payment'),
                ),
                if (_testCheckoutUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Checkout link:',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  SelectableText(_testCheckoutUrl,
                      style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                        Uri.parse(_testCheckoutUrl),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open checkout'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Simulate observer SMS',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Sends a fake bank-credit SMS to the observer '
                  'endpoint with the stored token. It only '
                  'confirms an ACTIVE session whose exact '
                  'payable amount matches — use it with the '
                  'test payment above.',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                RKitField(
                  label: 'Exact amount (₹)',
                  hint: 'e.g. 1.00 — auto-filled from the test '
                      'payment',
                  controller: _simAmount,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _testBusy ? null : _simulateSms,
                  icon: const Icon(Icons.sms, size: 17),
                  label: const Text('Simulate credit SMS'),
                ),
              ],
            ),
          ),
        ),
        if (_testResult.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(_testResult,
                  style: const TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ],
    );
  }
}

/// Read-only panelist UPI status across the four provider tables.
/// Activation / UPI changes stay email-OTP only — no edit controls
/// here by design.
class _PanelistsTab extends StatefulWidget {
  const _PanelistsTab();

  @override
  State<_PanelistsTab> createState() => _PanelistsTabState();
}

class _PanelistsTabState extends State<_PanelistsTab> {
  bool _loading = true;

  static const _tables = [
    'doctors',
    'hospitals',
    'labs',
    'pharmacies',
  ];
  static const _labels = [
    'Doctors',
    'Hospitals',
    'Labs',
    'Pharmacies',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    for (final t in _tables) {
      await state.loadAdminTable(t);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const RLoading();
    return DefaultTabController(
      length: _tables.length,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Read-only. A panelist turns online payment on or '
              'changes UPI only with an email code — nothing here '
              'can bypass that.',
              style: TextStyle(
                  fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final l in _labels) Tab(text: l)],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final t in _tables)
                  _tableList(context, state.adminTable(t)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableList(
      BuildContext context, List<Map<String, dynamic>> rows) {
    final scheme = Theme.of(context).colorScheme;
    if (rows.isEmpty) {
      return const REmptyState(
        icon: Icons.payments_outlined,
        title: 'No providers',
        subtitle: 'Providers will appear here once added.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        final name = '${r['name'] ?? r['full_name'] ?? '—'}';
        final upi = '${r['upi_id'] ?? ''}'.trim();
        final on = r['upi_enabled'] == true;
        return Card(
          child: ListTile(
            leading: Icon(
              on ? Icons.check_circle : Icons.cancel_outlined,
              color: on
                  ? RemedooTheme.success
                  : scheme.onSurfaceVariant,
            ),
            title: Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              upi.isEmpty ? 'UPI not set' : 'UPI: $upi',
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            trailing: Chip(
              label: Text(on ? 'ON' : 'OFF',
                  style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }
}

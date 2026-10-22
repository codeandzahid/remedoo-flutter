import 'package:flutter/material.dart';

import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/form_kit.dart';

// Configuration screens — every setting persists in the Supabase
// `app_config` table and applies across the website and app.

class _Scaffold extends StatelessWidget {
  final Widget child;

  const _Scaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      maxWidth: 640,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// Platform commission rules — the REAL
/// `platform_commission_config` table (audit Admin gap 5 /
/// M16: this screen used to save percentage sliders into
/// app_config while the table with flat fees and per-service
/// rules was never touched).
class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await AppStateScope.of(context)
        .loadAdminTable('platform_commission_config');
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addRule() async {
    var provider = 'doctor';
    var service = 'appointment';
    final percent = TextEditingController(text: '10');
    final flat = TextEditingController(text: '0');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add commission rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RKitDropdown<String>(
                  label: 'Provider type',
                  value: provider,
                  items: const [
                    DropdownMenuItem(
                        value: 'doctor', child: Text('Doctor')),
                    DropdownMenuItem(
                        value: 'hospital', child: Text('Hospital')),
                    DropdownMenuItem(
                        value: 'pharmacy', child: Text('Pharmacy')),
                    DropdownMenuItem(value: 'lab', child: Text('Lab')),
                  ],
                  onChanged: (v) =>
                      setD(() => provider = v ?? 'doctor'),
                ),
                RKitDropdown<String>(
                  label: 'Service type',
                  value: service,
                  items: const [
                    DropdownMenuItem(
                        value: 'appointment',
                        child: Text('Appointment')),
                    DropdownMenuItem(
                        value: 'order', child: Text('Order')),
                    DropdownMenuItem(
                        value: 'ambulance', child: Text('Ambulance')),
                    DropdownMenuItem(
                        value: 'lab_test', child: Text('Lab test')),
                  ],
                  onChanged: (v) =>
                      setD(() => service = v ?? 'appointment'),
                ),
                RKitField(controller: percent, label: 'Commission %', keyboardType: TextInputType.number),
                RKitField(controller: flat, label: 'Flat fee (₹)', keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add rule')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    // Validate like the row editor does — garbage used to save
    // silently as 0.
    final percentValue = num.tryParse(percent.text.trim());
    final flatValue = num.tryParse(flat.text.trim());
    if (percentValue == null || flatValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter valid numbers for % and flat fee.')));
      return;
    }
    final ok = await AppStateScope.of(context).adminSaveRow(
        'platform_commission_config', {
      'provider_type': provider,
      'service_type': service,
      'commission_percent': percentValue,
      'flat_fee': flatValue,
      'is_active': true,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Rule added.'
              : 'Could not add — a rule for this pair may already exist.')),
    );
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const RLoading();
    final state = AppStateScope.of(context);
    final rows = state.adminTable('platform_commission_config');
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: RSectionHeader(
                    title: 'Commission',
                    subtitle:
                        'Percent plus flat fee per provider + service, taken when an earning is created'),
              ),
              RButton(
                  label: 'Add rule',
                  small: true,
                  icon: Icons.add,
                  onPressed: _addRule),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const REmptyState(
              icon: Icons.percent,
              title: 'No commission rules yet',
              subtitle:
                  'Add the first rule — one per provider + service pair.',
              compact: true,
            )
          else
            ...rows.map((r) => _CommissionRow(row: r)),
        ],
      ),
    );
  }
}

/// One editable commission rule.
class _CommissionRow extends StatefulWidget {
  final Map<String, dynamic> row;

  const _CommissionRow({required this.row});

  @override
  State<_CommissionRow> createState() => _CommissionRowState();
}

class _CommissionRowState extends State<_CommissionRow> {
  late final TextEditingController _percent;
  late final TextEditingController _flat;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _percent = TextEditingController(
        text: '${widget.row['commission_percent'] ?? 0}');
    _flat =
        TextEditingController(text: '${widget.row['flat_fee'] ?? 0}');
    _active = widget.row['is_active'] == true;
  }

  @override
  void dispose() {
    _percent.dispose();
    _flat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final percent = num.tryParse(_percent.text.trim());
    final flat = num.tryParse(_flat.text.trim());
    if (percent == null || flat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter valid numbers for % and flat fee.')));
      return;
    }
    setState(() => _saving = true);
    final ok = await AppStateScope.of(context).adminSaveRow(
        'platform_commission_config', {
      'id': widget.row['id'],
      'commission_percent': percent,
      'flat_fee': flat,
      'is_active': _active,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(ok ? 'Rule saved.' : 'Could not save (admin only)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r['provider_type']} · ${r['service_type']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Switch(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: RKitField(
                    label: 'Commission %',
                    controller: _percent,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RKitField(
                    label: 'Flat fee (₹)',
                    controller: _flat,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                RButton(
                  label: 'Save',
                  small: true,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Subscription plans — the REAL `subscription_plans` table
/// (audit Admin gaps 5 + 23 / M16: this editor used to store
/// only {name, price} in app_config, and the table's
/// description / provider_type / duration_days / features /
/// is_active could not be entered anywhere).
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await AppStateScope.of(context).loadAdminTable('subscription_plans');
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final name =
        TextEditingController(text: '${row?['name'] ?? ''}');
    final description =
        TextEditingController(text: '${row?['description'] ?? ''}');
    final price =
        TextEditingController(text: '${row?['price'] ?? ''}');
    final days = TextEditingController(
        text: '${row?['duration_days'] ?? 30}');
    final featuresRaw = row?['features'];
    final features = TextEditingController(
        text: featuresRaw is List ? featuresRaw.join(', ') : '');
    var provider = '${row?['provider_type'] ?? 'doctor'}';
    var active = row?['is_active'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(row == null ? 'Add plan' : 'Edit plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RKitField(controller: name, label: 'Name'),
                RKitField(controller: description, label: 'Description', maxLines: 2),
                RKitDropdown<String>(
                  label: 'Provider type',
                  value: provider,
                  items: const [
                    DropdownMenuItem(
                        value: 'doctor', child: Text('Doctor')),
                    DropdownMenuItem(
                        value: 'hospital', child: Text('Hospital')),
                    DropdownMenuItem(
                        value: 'lab', child: Text('Lab')),
                    DropdownMenuItem(
                        value: 'pharmacy', child: Text('Pharmacy')),
                  ],
                  onChanged: (v) =>
                      setD(() => provider = v ?? 'doctor'),
                ),
                RKitField(controller: price, label: 'Price (₹)', keyboardType: TextInputType.number),
                RKitField(controller: days, label: 'Duration (days)', keyboardType: TextInputType.number),
                RKitField(controller: features, label: 'Features (comma separated)'),
                RFormSwitchTile(
                  title: 'Active',
                  value: active,
                  onChanged: (v) => setD(() => active = v),
                ),
              ],
            ),
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
      ),
    );
    if (saved != true || !mounted) return;
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A plan needs a name.')));
      return;
    }
    // No silent ₹0 (gap 23, full-check 2026-10-22): a blank or
    // unparseable price used to save as 0 without a word. Zero
    // is allowed only when the admin actually types 0.
    final priceValue = num.tryParse(price.text.trim());
    if (priceValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Enter a price (type 0 for a free plan).')));
      return;
    }
    final ok = await AppStateScope.of(context)
        .adminSaveRow('subscription_plans', {
      if (row != null) 'id': row['id'],
      'name': name.text.trim(),
      'description': description.text.trim().isEmpty
          ? null
          : description.text.trim(),
      'provider_type': provider,
      'price': priceValue,
      'duration_days': int.tryParse(days.text.trim()) ?? 30,
      'features': features.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'is_active': active,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              ok ? 'Plan saved.' : 'Could not save (admin only)')),
    );
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const RLoading();
    final state = AppStateScope.of(context);
    final rows = state.adminTable('subscription_plans');
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: RSectionHeader(
                    title: 'Subscription Plans',
                    subtitle:
                        'Provider plans from the subscription_plans table'),
              ),
              RButton(
                  label: 'Add plan',
                  small: true,
                  icon: Icons.add,
                  onPressed: () => _edit()),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const REmptyState(
              icon: Icons.card_membership,
              title: 'No plans yet',
              subtitle: 'Add the first subscription plan.',
              compact: true,
            )
          else
            ...rows.map((r) {
              final feats = r['features'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r['name'] ?? ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${r['provider_type'] ?? ''} · ₹${r['price'] ?? 0} · '
                      '${r['duration_days'] ?? 30} days'
                      '${r['is_active'] == true ? '' : ' · inactive'}'
                      '${feats is List && feats.isNotEmpty ? '\n${feats.join(', ')}' : ''}',
                    ),
                    isThreeLine: feats is List && feats.isNotEmpty,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit',
                          onPressed: () => _edit(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () async {
                            final ok = await AppStateScope.of(context)
                                .adminDeleteRow(
                                    'subscription_plans', '${r['id']}');
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(ok
                                      ? 'Plan deleted.'
                                      : 'Could not delete.')),
                            );
                            if (ok) _load();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Corporate plans — the REAL `corporate_plans` table
/// (full-check fix 2026-10-22: this screen used to save a
/// name+price list into app_config key 'corporate_plans', which
/// nothing in the app reads, behind a "Saved" message. The real
/// table is a company subscription record: company, contact,
/// plan type, employee cap, monthly price, services, dates.)
class CorporatePlansScreen extends StatefulWidget {
  const CorporatePlansScreen({super.key});

  @override
  State<CorporatePlansScreen> createState() =>
      _CorporatePlansScreenState();
}

class _CorporatePlansScreenState extends State<CorporatePlansScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await AppStateScope.of(context).loadAdminTable('corporate_plans');
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final company =
        TextEditingController(text: '${row?['company_name'] ?? ''}');
    final email =
        TextEditingController(text: '${row?['contact_email'] ?? ''}');
    final phone =
        TextEditingController(text: '${row?['contact_phone'] ?? ''}');
    final employees = TextEditingController(
        text: '${row?['max_employees'] ?? 50}');
    final price = TextEditingController(
        text: row == null ? '' : '${row['monthly_price'] ?? ''}');
    final servicesRaw = row?['services_included'];
    final services = TextEditingController(
        text: servicesRaw is List ? servicesRaw.join(', ') : '');
    final startDate = TextEditingController(
        text: '${row?['start_date'] ?? ''}'.split('T').first);
    final endDate = TextEditingController(
        text: '${row?['end_date'] ?? ''}'.split('T').first);
    var planType = '${row?['plan_type'] ?? 'basic'}';
    if (!const ['basic', 'premium', 'enterprise'].contains(planType)) {
      planType = 'basic';
    }
    var active = row?['is_active'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(row == null
              ? 'Add corporate plan'
              : 'Edit corporate plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RKitField(controller: company, label: 'Company name'),
                RKitField(controller: email, label: 'Contact email'),
                RKitField(controller: phone, label: 'Contact phone'),
                RKitDropdown<String>(
                  label: 'Plan type',
                  value: planType,
                  items: const [
                    DropdownMenuItem(
                        value: 'basic', child: Text('Basic')),
                    DropdownMenuItem(
                        value: 'premium', child: Text('Premium')),
                    DropdownMenuItem(
                        value: 'enterprise',
                        child: Text('Enterprise')),
                  ],
                  onChanged: (v) => setD(() => planType = v ?? 'basic'),
                ),
                RKitField(
                    controller: employees,
                    label: 'Max employees',
                    keyboardType: TextInputType.number),
                RKitField(
                    controller: price,
                    label: 'Monthly price (₹)',
                    keyboardType: TextInputType.number),
                RKitField(
                    controller: services,
                    label:
                        'Services included (comma separated)'),
                RKitField(
                    controller: startDate,
                    label: 'Start date (YYYY-MM-DD, optional)'),
                RKitField(
                    controller: endDate,
                    label: 'End date (YYYY-MM-DD, optional)'),
                RFormSwitchTile(
                  title: 'Active',
                  value: active,
                  onChanged: (v) => setD(() => active = v),
                ),
              ],
            ),
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
      ),
    );
    if (saved != true || !mounted) return;
    void fail(String msg) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
    if (company.text.trim().isEmpty) {
      fail('A corporate plan needs a company name.');
      return;
    }
    final priceValue = num.tryParse(price.text.trim());
    if (priceValue == null) {
      fail('Enter the monthly price (type 0 for a free plan).');
      return;
    }
    final startText = startDate.text.trim();
    final endText = endDate.text.trim();
    DateTime? startParsed;
    DateTime? endParsed;
    if (startText.isNotEmpty) {
      startParsed = DateTime.tryParse(startText);
      if (startParsed == null) {
        fail('Start date must be YYYY-MM-DD.');
        return;
      }
    }
    if (endText.isNotEmpty) {
      endParsed = DateTime.tryParse(endText);
      if (endParsed == null) {
        fail('End date must be YYYY-MM-DD.');
        return;
      }
    }
    if (startParsed != null &&
        endParsed != null &&
        endParsed.isBefore(startParsed)) {
      fail('End date is before the start date.');
      return;
    }
    final ok = await AppStateScope.of(context)
        .adminSaveRow('corporate_plans', {
      if (row != null) 'id': row['id'],
      'company_name': company.text.trim(),
      'contact_email':
          email.text.trim().isEmpty ? null : email.text.trim(),
      'contact_phone':
          phone.text.trim().isEmpty ? null : phone.text.trim(),
      'plan_type': planType,
      'max_employees': int.tryParse(employees.text.trim()) ?? 50,
      'monthly_price': priceValue,
      'services_included': services.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'is_active': active,
      'start_date': startText.isEmpty ? null : startText,
      'end_date': endText.isEmpty ? null : endText,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Corporate plan saved.'
              : 'Could not save (admin only)')),
    );
    if (ok) _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final sure = await confirmDialog(
      context,
      title: 'Delete corporate plan?',
      message:
          'Remove the plan for ${row['company_name'] ?? 'this company'}? This cannot be undone.',
    );
    if (!sure || !mounted) return;
    final ok = await AppStateScope.of(context)
        .adminDeleteRow('corporate_plans', '${row['id']}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              ok ? 'Plan deleted.' : 'Could not delete.')),
    );
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const RLoading();
    final state = AppStateScope.of(context);
    final rows = state.adminTable('corporate_plans');
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: RSectionHeader(
                    title: 'Corporate Plans',
                    subtitle:
                        'Company subscriptions from the corporate_plans table'),
              ),
              RButton(
                  label: 'Add plan',
                  small: true,
                  icon: Icons.add,
                  onPressed: () => _edit()),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const REmptyState(
              icon: Icons.business,
              title: 'No corporate plans yet',
              subtitle: 'Add the first company subscription.',
              compact: true,
            )
          else
            ...rows.map((r) {
              final services = r['services_included'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r['company_name'] ?? ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${r['plan_type'] ?? 'basic'} · '
                      '₹${r['monthly_price'] ?? 0}/month · '
                      'up to ${r['max_employees'] ?? 50} employees'
                      '${r['is_active'] == true ? '' : ' · inactive'}'
                      '${services is List && services.isNotEmpty ? '\n${services.join(', ')}' : ''}',
                    ),
                    isThreeLine:
                        services is List && services.isNotEmpty,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit',
                          onPressed: () => _edit(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _delete(r),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Healthcare packages — the REAL `healthcare_packages` table
/// (full-check fix 2026-10-22: same write-only app_config problem
/// as Corporate Plans. Every package belongs to a hospital or a
/// lab — provider_id is NOT NULL in the table — so the editor
/// picks the provider from the live catalogue.)
class HealthcarePackagesScreen extends StatefulWidget {
  const HealthcarePackagesScreen({super.key});

  @override
  State<HealthcarePackagesScreen> createState() =>
      _HealthcarePackagesScreenState();
}

class _HealthcarePackagesScreenState
    extends State<HealthcarePackagesScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    await state.loadAdminTable('healthcare_packages');
    if (state.activeHospitals.isEmpty && state.activeLabs.isEmpty) {
      await state.loadProductionCatalog();
    }
    if (mounted) setState(() => _loading = false);
  }

  String _providerName(AppState state, Map<String, dynamic> row) {
    final id = '${row['provider_id'] ?? ''}';
    if (row['provider_type'] == 'lab') {
      for (final l in state.activeLabs) {
        if (l.id == id) return l.name;
      }
      return 'Lab';
    }
    for (final h in state.activeHospitals) {
      if (h.id == id) return h.name;
    }
    return 'Hospital';
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final state = AppStateScope.of(context);
    final name =
        TextEditingController(text: '${row?['name'] ?? ''}');
    final description =
        TextEditingController(text: '${row?['description'] ?? ''}');
    final testsRaw = row?['tests_included'];
    final tests = TextEditingController(
        text: testsRaw is List ? testsRaw.join(', ') : '');
    final price = TextEditingController(
        text: row == null ? '' : '${row['original_price'] ?? ''}');
    final discounted = TextEditingController(
        text: row?['discounted_price'] == null
            ? ''
            : '${row?['discounted_price']}');
    final days = TextEditingController(
        text: '${row?['duration_days'] ?? 1}');
    final sortOrder =
        TextEditingController(text: '${row?['sort_order'] ?? 0}');
    var providerType = '${row?['provider_type'] ?? 'hospital'}';
    if (!const ['hospital', 'lab'].contains(providerType)) {
      providerType = 'hospital';
    }
    String? providerId = row?['provider_id']?.toString();
    var active = row?['is_active'] != false;

    List<(String, String)> providerOptions() {
      if (providerType == 'lab') {
        return [for (final l in state.activeLabs) (l.id, l.name)];
      }
      return [for (final h in state.activeHospitals) (h.id, h.name)];
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final options = providerOptions();
          if (providerId != null &&
              !options.any((o) => o.$1 == providerId)) {
            providerId = null;
          }
          return AlertDialog(
            title: Text(row == null
                ? 'Add healthcare package'
                : 'Edit healthcare package'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RKitField(controller: name, label: 'Package name'),
                  RKitField(
                      controller: description,
                      label: 'Description',
                      maxLines: 2),
                  RKitDropdown<String>(
                    label: 'Provider type',
                    value: providerType,
                    items: const [
                      DropdownMenuItem(
                          value: 'hospital', child: Text('Hospital')),
                      DropdownMenuItem(
                          value: 'lab', child: Text('Lab')),
                    ],
                    onChanged: (v) => setD(() {
                      providerType = v ?? 'hospital';
                      providerId = null;
                    }),
                  ),
                  if (options.isEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        providerType == 'lab'
                            ? 'No labs in the catalogue yet — add a lab first.'
                            : 'No hospitals in the catalogue yet — add a hospital first.',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13),
                      ),
                    )
                  else
                    RKitDropdown<String>(
                      label: 'Provider',
                      value: providerId,
                      items: [
                        for (final o in options)
                          DropdownMenuItem(
                              value: o.$1, child: Text(o.$2)),
                      ],
                      onChanged: (v) =>
                          setD(() => providerId = v),
                    ),
                  RKitField(
                      controller: tests,
                      label: 'Tests included (comma separated)'),
                  RKitField(
                      controller: price,
                      label: 'Price (₹)',
                      keyboardType: TextInputType.number),
                  RKitField(
                      controller: discounted,
                      label: 'Discounted price (₹, optional)',
                      keyboardType: TextInputType.number),
                  RKitField(
                      controller: days,
                      label: 'Duration (days)',
                      keyboardType: TextInputType.number),
                  RKitField(
                      controller: sortOrder,
                      label: 'Sort order',
                      keyboardType: TextInputType.number),
                  RFormSwitchTile(
                    title: 'Active',
                    value: active,
                    onChanged: (v) => setD(() => active = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save')),
            ],
          );
        },
      ),
    );
    if (saved != true || !mounted) return;
    void fail(String msg) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
    if (name.text.trim().isEmpty) {
      fail('A package needs a name.');
      return;
    }
    if (providerId == null) {
      fail('Pick the hospital or lab this package belongs to.');
      return;
    }
    final priceValue = num.tryParse(price.text.trim());
    if (priceValue == null) {
      fail('Enter the price (type 0 for a free package).');
      return;
    }
    num? discountedValue;
    if (discounted.text.trim().isNotEmpty) {
      discountedValue = num.tryParse(discounted.text.trim());
      if (discountedValue == null) {
        fail('Discounted price must be a number.');
        return;
      }
      if (discountedValue > priceValue) {
        fail('Discounted price cannot be higher than the price.');
        return;
      }
    }
    final ok = await AppStateScope.of(context)
        .adminSaveRow('healthcare_packages', {
      if (row != null) 'id': row['id'],
      'provider_type': providerType,
      'provider_id': providerId,
      'name': name.text.trim(),
      'description': description.text.trim().isEmpty
          ? null
          : description.text.trim(),
      'tests_included': tests.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'original_price': priceValue,
      'discounted_price': discountedValue,
      'duration_days': int.tryParse(days.text.trim()) ?? 1,
      'sort_order': int.tryParse(sortOrder.text.trim()) ?? 0,
      'is_active': active,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Package saved.'
              : 'Could not save (admin only)')),
    );
    if (ok) _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final sure = await confirmDialog(
      context,
      title: 'Delete healthcare package?',
      message:
          'Remove "${row['name'] ?? 'this package'}"? This cannot be undone.',
    );
    if (!sure || !mounted) return;
    final ok = await AppStateScope.of(context)
        .adminDeleteRow('healthcare_packages', '${row['id']}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              ok ? 'Package deleted.' : 'Could not delete.')),
    );
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const RLoading();
    final state = AppStateScope.of(context);
    final rows = [...state.adminTable('healthcare_packages')]
      ..sort((a, b) => ((a['sort_order'] as num?) ?? 0)
          .compareTo((b['sort_order'] as num?) ?? 0));
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: RSectionHeader(
                    title: 'Healthcare Packages',
                    subtitle:
                        'Bundled checkup packages from the healthcare_packages table'),
              ),
              RButton(
                  label: 'Add package',
                  small: true,
                  icon: Icons.add,
                  onPressed: () => _edit()),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const REmptyState(
              icon: Icons.medical_services_outlined,
              title: 'No packages yet',
              subtitle: 'Add the first healthcare package.',
              compact: true,
            )
          else
            ...rows.map((r) {
              final tests = r['tests_included'];
              final discounted = r['discounted_price'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r['name'] ?? ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${_providerName(state, r)} · '
                      '${discounted != null ? '₹$discounted (was ₹${r['original_price'] ?? 0})' : '₹${r['original_price'] ?? 0}'} · '
                      '${r['duration_days'] ?? 1} days · '
                      '${r['bookings_count'] ?? 0} bookings'
                      '${r['is_active'] == true ? '' : ' · inactive'}'
                      '${tests is List && tests.isNotEmpty ? '\n${tests.join(', ')}' : ''}',
                    ),
                    isThreeLine: tests is List && tests.isNotEmpty,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit',
                          onPressed: () => _edit(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _delete(r),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Branding: app name + tagline in app_config, plus the real theme controls.
class BrandingScreen extends StatefulWidget {
  const BrandingScreen({super.key});

  @override
  State<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends State<BrandingScreen> {
  late final TextEditingController _name;
  late final TextEditingController _tagline;
  bool _init = false;
  bool _saving = false;
  bool _touched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      final s = AppStateScope.of(context);
      final b = s.appConfigValue('branding');
      _name = TextEditingController(text: '${b['app_name'] ?? 'Remedoo'}');
      _tagline = TextEditingController(
          text: '${b['tagline'] ?? 'Healthcare, simplified'}');
      _name.addListener(() => _touched = true);
      _tagline.addListener(() => _touched = true);
      _init = true;
      // The controllers above were seeded from whatever config
      // was already in memory (audit Admin gap 24 — SUSPECTED,
      // verified real): when the fresh config arrives, refill
      // them unless the admin has already started typing.
      s.loadAppConfig().then((_) {
        if (!mounted || _touched) return;
        final loaded = s.appConfigValue('branding');
        setState(() {
          _name.text = '${loaded['app_name'] ?? 'Remedoo'}';
          _tagline.text =
              '${loaded['tagline'] ?? 'Healthcare, simplified'}';
        });
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final state = AppStateScope.of(context);
    // Merge over the stored value (full-check fix 2026-10-22):
    // saveAppConfigValue replaces the whole 'branding' value, so
    // saving only name+tagline used to wipe any other branding
    // keys stored under it.
    final ok = await state.saveAppConfigValue('branding', {
      ...state.appConfigValue('branding'),
      'app_name': _name.text.trim(),
      'tagline': _tagline.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Branding saved — shown in the header and on the login page'
              : 'Could not save (admin only)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RSectionHeader(
              title: 'Branding',
              subtitle:
                  'App name shows in the website header; tagline on the login page'),
          const SizedBox(height: 12),
          RCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RKitField(label: 'App name', controller: _name),
                const SizedBox(height: 12),
                RKitField(label: 'Tagline', controller: _tagline),
                const SizedBox(height: 16),
                RButton(
                    label: 'Save branding',
                    small: true,
                    onPressed: _saving ? null : _save),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const RSectionHeader(
              title: 'App Themes',
              subtitle:
                  'Turn themes on or off project-wide — website and app'),
          const SizedBox(height: 12),
          _ThemePackAdminCard(),
        ],
      ),
    );
  }
}

/// Admin control for theme pack availability. The primary
/// theme (Remidy) cannot be turned off.
class _ThemePackAdminCard extends StatefulWidget {
  @override
  State<_ThemePackAdminCard> createState() => _ThemePackAdminCardState();
}

class _ThemePackAdminCardState extends State<_ThemePackAdminCard> {
  bool _loading = true;
  List<Map<String, dynamic>> _packs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final rows = await SupabaseRepository.instance.fetchThemePacks();
    if (!mounted) return;
    setState(() {
      // Full-check fix 2026-10-22: an empty result used to be
      // replaced with invented built-in packs, all shown enabled —
      // but fetchThemePacks returns [] both when the table cannot
      // be read AND when it has no rows, and toggling an invented
      // pack updated zero database rows. Show the honest empty
      // state with a retry instead.
      _packs = rows;
      _loading = false;
    });
    // Keep AppState's availability map in sync.
    if (rows.isNotEmpty && mounted) {
      await AppStateScope.of(context).loadThemeAvailability();
    }
  }

  Future<void> _toggle(String id, bool enabled) async {
    final ok = await AppStateScope.of(context)
        .setThemePackEnabled(id, enabled);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final i = _packs.indexWhere((p) => p['id'] == id);
        if (i >= 0) _packs[i]['enabled'] = enabled;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(enabled
                ? 'Theme enabled project-wide'
                : 'Theme disabled project-wide')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not update theme (admin only)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const RCard(
        padding: EdgeInsets.all(20),
        child: const RLoading(),
      );
    }
    if (_packs.isEmpty) {
      return RCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'The theme list could not be loaded from the database. '
              'No themes can be changed until it loads.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            RButton(
              label: 'Retry',
              small: true,
              icon: Icons.refresh,
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
            ),
          ],
        ),
      );
    }
    return RCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < _packs.length; i++) ...[
            _themeRow(scheme, _packs[i], i == _packs.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _themeRow(
      ColorScheme scheme, Map<String, dynamic> pack, bool last) {
    final id = '${pack['id']}';
    final builtin = ThemePack.byId(id);
    final enabled = pack['enabled'] == true;
    final isPrimary = pack['is_primary'] == true;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: builtin == null
                      ? null
                      : LinearGradient(colors: [
                          builtin.primary,
                          builtin.primaryDark,
                        ]),
                  color: builtin == null ? scheme.secondary : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${pack['name']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        if (isPrimary) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('PRIMARY',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      isPrimary
                          ? 'Default theme · always on'
                          : (enabled ? 'Available to users' : 'Hidden from users'),
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: scheme.primary,
                onChanged: isPrimary
                    ? null
                    : (v) => _toggle(id, v),
              ),
            ],
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}

/// Service areas, stored in app_config.
/// Service areas — the REAL `service_areas` table (audit
/// Admin gap 5 / M16: this screen used to keep a list of name
/// strings in app_config while the table's type / parent /
/// coordinates / radius / active flag were never touched).
class ServiceAreasScreen extends StatefulWidget {
  const ServiceAreasScreen({super.key});

  @override
  State<ServiceAreasScreen> createState() => _ServiceAreasScreenState();
}

class _ServiceAreasScreenState extends State<ServiceAreasScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await AppStateScope.of(context).loadAdminTable('service_areas');
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit(List<Map<String, dynamic>> rows,
      [Map<String, dynamic>? row]) async {
    final name =
        TextEditingController(text: '${row?['name'] ?? ''}');
    final lat =
        TextEditingController(text: '${row?['latitude'] ?? ''}');
    final lng =
        TextEditingController(text: '${row?['longitude'] ?? ''}');
    final radius =
        TextEditingController(text: '${row?['radius_km'] ?? ''}');
    var type = '${row?['type'] ?? 'city'}';
    String? parentId = row?['parent_id']?.toString();
    var active = row?['is_active'] != false;
    final candidates = rows
        .where((r) => row == null || '${r['id']}' != '${row['id']}')
        .toList();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(row == null ? 'Add area' : 'Edit area'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RKitField(controller: name, label: 'Name'),
                RKitDropdown<String>(
                  label: 'Type',
                  value: type,
                  items: const [
                    DropdownMenuItem(
                        value: 'city', child: Text('City')),
                    DropdownMenuItem(
                        value: 'state', child: Text('State')),
                    DropdownMenuItem(
                        value: 'area', child: Text('Area')),
                  ],
                  onChanged: (v) => setD(() => type = v ?? 'city'),
                ),
                RKitDropdown<String?>(
                  label: 'Parent area',
                  value: parentId,
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('None (top level)')),
                    for (final r in candidates)
                      DropdownMenuItem<String?>(
                        value: '${r['id']}',
                        child: Text('${r['name'] ?? ''}'),
                      ),
                  ],
                  onChanged: (v) => setD(() => parentId = v),
                ),
                RKitField(controller: lat, label: 'Latitude', keyboardType: TextInputType.number),
                RKitField(controller: lng, label: 'Longitude', keyboardType: TextInputType.number),
                RKitField(controller: radius, label: 'Radius (km)', keyboardType: TextInputType.number),
                RFormSwitchTile(
                  title: 'Active',
                  value: active,
                  onChanged: (v) => setD(() => active = v),
                ),
              ],
            ),
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
      ),
    );
    if (saved != true || !mounted) return;
    void failArea(String msg) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
    if (name.text.trim().isEmpty) {
      failArea('An area needs a name.');
      return;
    }
    // Full-check fix 2026-10-22: blank-or-garbage latitude,
    // longitude and radius were silently written as NULL (a typo
    // quietly erased the area's coordinates). Blank is allowed
    // only as a deliberate pair; anything typed must be a valid
    // in-range number.
    final latText = lat.text.trim();
    final lngText = lng.text.trim();
    double? latValue;
    double? lngValue;
    if (latText.isEmpty != lngText.isEmpty) {
      failArea('Latitude and longitude must be entered together, '
          'or both left blank.');
      return;
    }
    if (latText.isNotEmpty) {
      latValue = double.tryParse(latText);
      if (latValue == null || latValue < -90 || latValue > 90) {
        failArea('Latitude must be a number between -90 and 90.');
        return;
      }
      lngValue = double.tryParse(lngText);
      if (lngValue == null || lngValue < -180 || lngValue > 180) {
        failArea('Longitude must be a number between -180 and 180.');
        return;
      }
    }
    final radiusText = radius.text.trim();
    double? radiusValue;
    if (radiusText.isNotEmpty) {
      radiusValue = double.tryParse(radiusText);
      if (radiusValue == null || radiusValue <= 0) {
        failArea('Radius must be a positive number of km, or blank.');
        return;
      }
    }
    final ok = await AppStateScope.of(context)
        .adminSaveRow('service_areas', {
      if (row != null) 'id': row['id'],
      'name': name.text.trim(),
      'type': type,
      'parent_id': parentId,
      'latitude': latValue,
      'longitude': lngValue,
      'radius_km': radiusValue,
      'is_active': active,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              ok ? 'Area saved.' : 'Could not save (admin only)')),
    );
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const RLoading();
    final state = AppStateScope.of(context);
    final rows = state.adminTable('service_areas');
    String parentName(dynamic id) {
      for (final r in rows) {
        if ('${r['id']}' == '$id') return '${r['name'] ?? ''}';
      }
      return '';
    }

    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: RSectionHeader(
                    title: 'Service Areas',
                    subtitle:
                        'Where Remedoo operates (real service_areas table)'),
              ),
              RButton(
                  label: 'Add area',
                  small: true,
                  icon: Icons.add,
                  onPressed: () => _edit(rows)),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const REmptyState(
              icon: Icons.map,
              title: 'No service areas yet',
              subtitle: 'Add the first city or area.',
              compact: true,
            )
          else
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${r['name'] ?? ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${r['type'] ?? 'city'}'
                        '${r['parent_id'] != null ? ' · under ${parentName(r['parent_id'])}' : ''}'
                        '${r['radius_km'] != null ? ' · ${r['radius_km']} km radius' : ''}'
                        '${r['is_active'] == true ? '' : ' · inactive'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: r['is_active'] == true,
                            onChanged: (v) async {
                              // Full-check fix 2026-10-22: the
                              // save result was ignored — a failed
                              // toggle looked exactly like a
                              // successful one until the reload.
                              final ok = await AppStateScope.of(
                                      context)
                                  .adminSaveRow('service_areas', {
                                'id': r['id'],
                                'is_active': v,
                              });
                              if (!context.mounted) return;
                              if (!ok) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                        content: Text(
                                            'Could not update the area. Try again.')));
                              }
                              _load();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit',
                            onPressed: () => _edit(rows, r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () async {
                              // Full-check fix 2026-10-22:
                              // delete had no confirmation and
                              // ignored the result — a failed
                              // delete was indistinguishable from
                              // a successful one.
                              final sure = await confirmDialog(
                                context,
                                title: 'Delete service area?',
                                message:
                                    'Remove "${r['name'] ?? 'this area'}"? This cannot be undone.',
                              );
                              if (!sure || !context.mounted) return;
                              final ok = await AppStateScope.of(
                                      context)
                                  .adminDeleteRow(
                                      'service_areas', '${r['id']}');
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                      content: Text(ok
                                          ? 'Area deleted.'
                                          : 'Could not delete.')));
                              if (ok) _load();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

/// Featured doctors / medicines — toggles the real `is_featured` column.
class FeaturedScreen extends StatefulWidget {
  const FeaturedScreen({super.key});

  @override
  State<FeaturedScreen> createState() => _FeaturedScreenState();
}

class _FeaturedScreenState extends State<FeaturedScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    await Future.wait([
      state.loadAdminTable('doctors'),
      state.loadAdminTable('medicines'),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(String table, Map<String, dynamic> row) async {
    final state = AppStateScope.of(context);
    // Send ONLY the flag (audit Admin gap 24 — SUSPECTED, verified
    // real): resending the whole loaded row could overwrite
    // concurrent edits with stale values and trip read-only or
    // generated columns.
    final updated = <String, dynamic>{
      'id': row['id'],
      'is_featured': !(row['is_featured'] == true),
    };
    final ok = await state.adminSaveRow(table, updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? (updated['is_featured'] == true
                  ? 'Marked as featured'
                  : 'Removed from featured')
              : 'Could not save (admin only)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const RLoading();
    }
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          tabs: const [
            Tab(text: 'Doctors'),
            Tab(text: 'Medicines'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _list('doctors'),
              _list('medicines'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _list(String table) {
    final state = AppStateScope.of(context);
    final rows = state.adminTable(table);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        final featured = r['is_featured'] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text('${r['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: table == 'doctors'
                  ? Text('${r['specialization'] ?? ''}')
                  : Text('${r['category'] ?? ''}'),
              trailing: IconButton(
                icon: Icon(
                  featured ? Icons.star : Icons.star_border,
                  color: featured
                      ? RemedooTheme.warning
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                tooltip:
                    featured ? 'Remove from featured' : 'Mark as featured',
                onPressed: () => _toggle(table, r),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Broadcast notifications (audit Admin gap 1: the
/// `broadcast_notifications` table had no UI and no writer).
/// Sending delivers in-app through the announcements system
/// patients actually see, and records the broadcast row —
/// stamped with the sender — as the audit log.
class BroadcastsScreen extends StatefulWidget {
  const BroadcastsScreen({super.key});

  @override
  State<BroadcastsScreen> createState() => _BroadcastsScreenState();
}

class _BroadcastsScreenState extends State<BroadcastsScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  String _audience = 'all';
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await AppStateScope.of(context)
        .loadAdminTable('broadcast_notifications');
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final message = _message.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Write a title and a message first.')));
      return;
    }
    setState(() => _sending = true);
    final state = AppStateScope.of(context);
    final delivered =
        await state.createAnnouncement(title, message, _audience);
    // Full-check fix 2026-10-22: the history log row was written
    // even when the announcement itself failed to save, so the
    // "Sent broadcasts" list gained phantom rows for messages
    // nobody ever received. Log only what was actually sent.
    final logged = delivered
        ? await state.supabaseRepository.sendBroadcast(
            title: title, message: message, audience: _audience)
        : false;
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(delivered
              ? (logged
                  ? 'Broadcast sent and logged.'
                  : 'Broadcast sent (log row failed).')
              : 'Could not send the broadcast.')),
    );
    if (delivered) {
      _title.clear();
      _message.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const RLoading();
    final state = AppStateScope.of(context);
    final rows = state.adminTable('broadcast_notifications');
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RSectionHeader(
              title: 'Broadcasts',
              subtitle:
                  'Message every user in-app; each send is logged with its sender'),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: [
                RKitField(label: 'Title', controller: _title),
                const SizedBox(height: 12),
                RKitField(
                    label: 'Message',
                    controller: _message,
                    maxLines: 4),
                const SizedBox(height: 12),
                RKitDropdown<String>(
                  label: 'Audience',
                  value: _audience,
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('Everyone')),
                    DropdownMenuItem(
                        value: 'users', child: Text('Patients only')),
                    DropdownMenuItem(
                        value: 'providers',
                        child: Text('Providers only')),
                  ],
                  onChanged: (v) =>
                      setState(() => _audience = v ?? 'all'),
                ),
                const SizedBox(height: 16),
                RButton(
                  label: _sending ? 'Sending…' : 'Send broadcast',
                  icon: Icons.send,
                  fullWidth: true,
                  onPressed: _sending ? null : _send,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          RSectionHeader(
              title: 'Sent broadcasts',
              subtitle: '${rows.length} on record'),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const REmptyState(
              icon: Icons.campaign_outlined,
              title: 'No broadcasts yet',
              subtitle: 'Sent broadcasts appear here.',
              compact: true,
            )
          else
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.campaign),
                      title: Text('${r['title'] ?? ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${r['message'] ?? ''}\n'
                        '${r['target_audience'] ?? 'all'} · '
                        '${'${r['sent_at'] ?? ''}'.split('T').first}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

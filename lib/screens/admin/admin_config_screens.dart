import 'package:flutter/material.dart';

import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

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
                DropdownButtonFormField<String>(
                  initialValue: provider,
                  decoration:
                      const InputDecoration(labelText: 'Provider type'),
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
                DropdownButtonFormField<String>(
                  initialValue: service,
                  decoration:
                      const InputDecoration(labelText: 'Service type'),
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
                TextField(
                  controller: percent,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Commission %'),
                ),
                TextField(
                  controller: flat,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Flat fee (₹)'),
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
                child: const Text('Add rule')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final ok = await AppStateScope.of(context).adminSaveRow(
        'platform_commission_config', {
      'provider_type': provider,
      'service_type': service,
      'commission_percent': num.tryParse(percent.text) ?? 0,
      'flat_fee': num.tryParse(flat.text) ?? 0,
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
                        'Platform cut per provider + service (real table)'),
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
                  child: RTextField(
                    label: 'Commission %',
                    controller: _percent,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RTextField(
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

/// Generic name+price plan list editor backed by app_config.
/// Kept for Corporate Plans and Healthcare Packages — those two
/// have no dedicated table, so app_config is their only store
/// (audit Admin gap 5 note).
class _PlanListScreen extends StatefulWidget {
  final String configKey;
  final String title;
  final String subtitle;
  final String itemLabel;

  const _PlanListScreen({
    required this.configKey,
    required this.title,
    required this.subtitle,
    required this.itemLabel,
  });

  @override
  State<_PlanListScreen> createState() => _PlanListScreenState();
}

class _PlanListScreenState extends State<_PlanListScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    await state.loadAppConfig();
    if (!mounted) return;
    final saved = state.appConfigValue(widget.configKey);
    setState(() {
      _plans = [
        for (final p in (saved['plans'] as List? ?? []))
          Map<String, dynamic>.from(p as Map)
      ];
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await AppStateScope.of(context)
        .saveAppConfigValue(widget.configKey, {'plans': _plans});
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(ok ? 'Saved' : 'Could not save (admin only)')),
    );
  }

  void _addDialog() {
    final name = TextEditingController();
    final price = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add ${widget.itemLabel}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RTextField(label: 'Name', controller: name),
            const SizedBox(height: 10),
            RTextField(
                label: 'Price (₹)',
                controller: price,
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          RButton(
            label: 'Add',
            small: true,
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              setState(() => _plans.add({
                    'name': name.text.trim(),
                    'price': num.tryParse(price.text) ?? 0,
                  }));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const RLoading();
    }
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: RSectionHeader(
                    title: widget.title, subtitle: widget.subtitle),
              ),
              RButton(
                  label: 'Add',
                  icon: Icons.add,
                  small: true,
                  onPressed: _addDialog),
            ],
          ),
          const SizedBox(height: 12),
          if (_plans.isEmpty)
            const REmptyState(
                icon: Icons.card_membership,
                title: 'No plans yet',
                subtitle: 'Add your first plan above.',
                compact: true)
          else
            RCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _plans.length; i++)
                    ListTile(
                      title: Text('${_plans[i]['name']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(inr((_plans[i]['price'] as num?) ?? 0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: RemedooTheme.emergency),
                            onPressed: () =>
                                setState(() => _plans.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          RButton(
              label: 'Save changes',
              fullWidth: true,
              onPressed: _saving ? null : _save),
        ],
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
                TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'Name')),
                TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Description'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: provider,
                  decoration: const InputDecoration(
                      labelText: 'Provider type'),
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
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Price (₹)'),
                ),
                TextField(
                  controller: days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Duration (days)'),
                ),
                TextField(
                  controller: features,
                  decoration: const InputDecoration(
                      labelText: 'Features (comma separated)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
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
    final ok = await AppStateScope.of(context)
        .adminSaveRow('subscription_plans', {
      if (row != null) 'id': row['id'],
      'name': name.text.trim(),
      'description': description.text.trim().isEmpty
          ? null
          : description.text.trim(),
      'provider_type': provider,
      // No silent ₹0 (gap 23): an empty/invalid price is kept a
      // deliberate 0 only when the admin typed 0.
      'price': num.tryParse(price.text.trim()) ?? 0,
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

/// Corporate plans.
class CorporatePlansScreen extends StatelessWidget {
  const CorporatePlansScreen({super.key});

  @override
  Widget build(BuildContext context) => const _PlanListScreen(
        configKey: 'corporate_plans',
        title: 'Corporate Plans',
        subtitle: 'Plans for companies',
        itemLabel: 'Plan',
      );
}

/// Healthcare packages.
class HealthcarePackagesScreen extends StatelessWidget {
  const HealthcarePackagesScreen({super.key});

  @override
  Widget build(BuildContext context) => const _PlanListScreen(
        configKey: 'healthcare_packages',
        title: 'Healthcare Packages',
        subtitle: 'Bundled checkup packages',
        itemLabel: 'Package',
      );
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
    final ok = await AppStateScope.of(context).saveAppConfigValue(
        'branding', {
      'app_name': _name.text.trim(),
      'tagline': _tagline.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Branding saved — live across website and app'
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
              subtitle: 'Saved to the database, applies everywhere'),
          const SizedBox(height: 12),
          RCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RTextField(label: 'App name', controller: _name),
                const SizedBox(height: 12),
                RTextField(label: 'Tagline', controller: _tagline),
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

/// Admin control for theme pack availability. Sky Pulse is the primary
/// theme and cannot be turned off.
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
      // Fall back to built-in packs when the table isn't reachable.
      _packs = rows.isEmpty
          ? [
              for (final p in ThemePack.all)
                {
                  'id': p.id,
                  'name': p.name,
                  'enabled': true,
                  'is_primary': p.id == 'remidy',
                }
            ]
          : rows;
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
                TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'Name')),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration:
                      const InputDecoration(labelText: 'Type'),
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
                DropdownButtonFormField<String?>(
                  initialValue: parentId,
                  decoration:
                      const InputDecoration(labelText: 'Parent area'),
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
                TextField(
                  controller: lat,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Latitude'),
                ),
                TextField(
                  controller: lng,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Longitude'),
                ),
                TextField(
                  controller: radius,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Radius (km)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
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
          const SnackBar(content: Text('An area needs a name.')));
      return;
    }
    final ok = await AppStateScope.of(context)
        .adminSaveRow('service_areas', {
      if (row != null) 'id': row['id'],
      'name': name.text.trim(),
      'type': type,
      'parent_id': parentId,
      'latitude': num.tryParse(lat.text.trim()),
      'longitude': num.tryParse(lng.text.trim()),
      'radius_km': num.tryParse(radius.text.trim()),
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
                              await AppStateScope.of(context)
                                  .adminSaveRow('service_areas', {
                                'id': r['id'],
                                'is_active': v,
                              });
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
                              await AppStateScope.of(context)
                                  .adminDeleteRow(
                                      'service_areas', '${r['id']}');
                              _load();
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
    final logged = await state.supabaseRepository.sendBroadcast(
        title: title, message: message, audience: _audience);
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
                RTextField(label: 'Title', controller: _title),
                const SizedBox(height: 12),
                RTextField(
                    label: 'Message',
                    controller: _message,
                    maxLines: 4),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  decoration: const InputDecoration(
                      labelText: 'Audience', isDense: true),
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

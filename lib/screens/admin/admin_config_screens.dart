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

/// Notice shown by screens that were removed during the admin cleanup.
/// Kept as stubs so admin_shell.dart still compiles until the nav is rewired.
class _RemovedNotice extends StatelessWidget {
  final String title;
  final String reason;

  const _RemovedNotice({required this.title, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: REmptyState(
          icon: Icons.info_outline,
          title: '$title removed',
          subtitle: reason,
        ),
      ),
    );
  }
}

/// OTP length + expiry — removed: auth is Supabase-managed.
class OtpSettingsScreen extends StatelessWidget {
  const OtpSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _RemovedNotice(
        title: 'OTP Settings',
        reason:
            'Verification codes are managed by Supabase Auth. This screen is no longer needed.',
      );
}

/// API keys — removed: the generator produced fake keys.
class ApiKeysScreen extends StatelessWidget {
  const ApiKeysScreen({super.key});

  @override
  Widget build(BuildContext context) => const _RemovedNotice(
        title: 'API Keys',
        reason: 'The key generator was a demo. Real keys live in your '
            'Supabase / Cloudflare dashboards.',
      );
}

/// Quick actions toggles — removed: no app screen reads these.
class QuickActionsScreen extends StatelessWidget {
  const QuickActionsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _RemovedNotice(
        title: 'Quick Actions',
        reason: 'No screen in the app reads these shortcuts. Removed.',
      );
}

/// Category actions toggles — removed: no app screen reads these.
class CategoryActionsScreen extends StatelessWidget {
  const CategoryActionsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _RemovedNotice(
        title: 'Category Actions',
        reason: 'No screen in the app reads these shortcuts. Removed.',
      );
}

/// Per-category commission percentages, stored in app_config.
class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  bool _loading = true;
  bool _saving = false;
  Map<String, double> _values = {
    'Doctor': 15,
    'Hospital': 8,
    'Lab': 12,
    'Pharmacy': 10,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    await state.loadAppConfig();
    if (!mounted) return;
    final saved = state.appConfigValue('commission');
    setState(() {
      if (saved.isNotEmpty) {
        _values = {
          for (final e in saved.entries)
            e.key: (e.value as num).toDouble()
        };
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await AppStateScope.of(context)
        .saveAppConfigValue('commission', _values);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(ok ? 'Commission saved' : 'Could not save (admin only)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const RLoading();
    }
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RSectionHeader(
              title: 'Commission',
              subtitle: 'Platform cut per category'),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: [
                ..._values.keys.map((k) {
                  final v = _values[k]!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(k,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: scheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${v.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: scheme.primary)),
                            ),
                          ],
                        ),
                        Slider(
                          value: v,
                          min: 0,
                          max: 30,
                          divisions: 30,
                          activeColor: scheme.primary,
                          onChanged: (nv) =>
                              setState(() => _values[k] = nv),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                RButton(
                    label: 'Save',
                    small: true,
                    onPressed: _saving ? null : _save),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic name+price plan list editor backed by app_config.
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

/// Subscription plans.
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _PlanListScreen(
        configKey: 'subscriptions',
        title: 'Subscription Plans',
        subtitle: 'Recurring care plans',
        itemLabel: 'Plan',
      );
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      final s = AppStateScope.of(context);
      final b = s.appConfigValue('branding');
      _name = TextEditingController(text: '${b['app_name'] ?? 'Remedoo'}');
      _tagline = TextEditingController(
          text: '${b['tagline'] ?? 'Healthcare, simplified'}');
      _init = true;
      s.loadAppConfig();
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
                  'is_primary': p.id == 'sky_pulse',
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
class ServiceAreasScreen extends StatefulWidget {
  const ServiceAreasScreen({super.key});

  @override
  State<ServiceAreasScreen> createState() => _ServiceAreasScreenState();
}

class _ServiceAreasScreenState extends State<ServiceAreasScreen> {
  bool _loading = true;
  bool _saving = false;
  List<String> _areas = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    await state.loadAppConfig();
    if (!mounted) return;
    setState(() {
      _areas = [
        for (final a in (state.appConfigValue('service_areas')['areas'] as List? ?? []))
          '$a'
      ];
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await AppStateScope.of(context)
        .saveAppConfigValue('service_areas', {'areas': _areas});
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(ok ? 'Service areas saved' : 'Could not save (admin only)')),
    );
  }

  void _addDialog() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add service area'),
        content: RTextField(label: 'Area name', controller: c),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          RButton(
            label: 'Add',
            small: true,
            onPressed: () {
              if (c.text.trim().isEmpty) return;
              setState(() => _areas.add(c.text.trim()));
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
              const Expanded(
                child: RSectionHeader(
                    title: 'Service Areas',
                    subtitle: 'Where Remedoo operates'),
              ),
              RButton(
                  label: 'Add',
                  icon: Icons.add,
                  small: true,
                  onPressed: _addDialog),
            ],
          ),
          const SizedBox(height: 12),
          if (_areas.isEmpty)
            const REmptyState(
                icon: Icons.map,
                title: 'No areas yet',
                subtitle: 'Add the first service area.',
                compact: true)
          else
            RCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _areas.length; i++)
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(_areas[i],
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: RemedooTheme.emergency),
                        onPressed: () =>
                            setState(() => _areas.removeAt(i)),
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
    final updated = Map<String, dynamic>.from(row)
      ..['is_featured'] = !(row['is_featured'] == true);
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

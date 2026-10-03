import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';
import 'admin_crud_screen.dart';

// Configuration screens — each saves into the AdminConfig state in AppState.

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

/// OTP length + expiry.
class OtpSettingsScreen extends StatelessWidget {
  const OtpSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RSectionHeader(
              title: 'OTP Settings',
              subtitle: 'Verification code policy'),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                        child: Text('OTP length (digits)',
                            style: TextStyle(
                                fontWeight: FontWeight.w600))),
                    QtyStepper(
                      qty: state.otpLength,
                      onMinus: () {
                        state.otpLength =
                            (state.otpLength - 1).clamp(4, 8);
                        state.refresh();
                      },
                      onPlus: () {
                        state.otpLength =
                            (state.otpLength + 1).clamp(4, 8);
                        state.refresh();
                      },
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Expanded(
                        child: Text('Expiry (minutes)',
                            style: TextStyle(
                                fontWeight: FontWeight.w600))),
                    QtyStepper(
                      qty: state.otpExpiryMinutes,
                      onMinus: () {
                        state.otpExpiryMinutes =
                            (state.otpExpiryMinutes - 1)
                                .clamp(1, 30);
                        state.refresh();
                      },
                      onPlus: () {
                        state.otpExpiryMinutes =
                            (state.otpExpiryMinutes + 1)
                                .clamp(1, 30);
                        state.refresh();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-category commission percentages.
class CommissionScreen extends StatelessWidget {
  const CommissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
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
                ...state.commission.keys.map((k) {
                  final v = state.commission[k]!;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(k,
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600))),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5),
                              decoration: BoxDecoration(
                                color: scheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(
                                  '${v.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.w700,
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
                          onChanged: (nv) {
                            state.commission[k] = nv;
                            state.refresh();
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Subscription plans CRUD.
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AdminCrudScreen(
        spec: state.mapSpec('Subscription Plans', 'Plan', const [
      FieldSpec(key: 'name', label: 'Name', required: true),
      FieldSpec(key: 'price', label: 'Price (₹)', type: 'number'),
    ], state.subscriptionPlans));
  }
}

/// Corporate plans CRUD.
class CorporatePlansScreen extends StatelessWidget {
  const CorporatePlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AdminCrudScreen(
        spec: state.mapSpec('Corporate Plans', 'Plan', const [
      FieldSpec(key: 'name', label: 'Name', required: true),
      FieldSpec(key: 'price', label: 'Price (₹)', type: 'number'),
    ], state.corporatePlans));
  }
}

/// Healthcare packages CRUD.
class HealthcarePackagesScreen extends StatelessWidget {
  const HealthcarePackagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AdminCrudScreen(
        spec: state.mapSpec(
            'Healthcare Packages', 'Package', const [
      FieldSpec(key: 'name', label: 'Name', required: true),
      FieldSpec(key: 'price', label: 'Price (₹)', type: 'number'),
    ], state.healthcarePackages));
  }
}

/// API keys list + regenerate.
class ApiKeysScreen extends StatelessWidget {
  const ApiKeysScreen({super.key});

  String _newKey() {
    final h = DateTime.now()
        .millisecondsSinceEpoch
        .toRadixString(16);
    return 'rk_live_${h.substring(0, 4)}…${h.substring(h.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const Expanded(
                child: RSectionHeader(
                    title: 'API Keys',
                    subtitle: 'Regenerate keys anytime'),
              ),
              RButton(
                label: 'Add Key',
                icon: Icons.add,
                small: true,
                onPressed: () {
                  state.collectionAdd(state.apiKeys, {
                    'name': 'New key',
                    'key': _newKey(),
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.apiKeys.length,
            itemBuilder: (_, i) {
              final k = state.apiKeys[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(13),
                      ),
                      child: Icon(Icons.key,
                          color: Theme.of(context)
                              .colorScheme
                              .primary),
                    ),
                    title: Text(k['name'] ?? 'Key',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    subtitle: Text(k['key'] ?? '',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                              Icons.refresh, size: 20),
                          tooltip: 'Regenerate',
                          onPressed: () {
                            k['key'] = _newKey();
                            state.refresh();
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Key regenerated (demo)')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color:
                                  RemedooTheme.emergency),
                          onPressed: () => state
                              .collectionRemove(
                                  state.apiKeys,
                                  k['id']!),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Branding: app name, tagline, primary color swatches (re-themes the app).
class BrandingScreen extends StatefulWidget {
  const BrandingScreen({super.key});

  @override
  State<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends State<BrandingScreen> {
  late final TextEditingController _name;
  late final TextEditingController _tagline;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      final s = AppStateScope.of(context);
      _name = TextEditingController(text: s.brandName);
      _tagline = TextEditingController(text: s.brandTagline);
      _init = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RSectionHeader(
              title: 'Branding',
              subtitle: 'Applies instantly across the app'),
          const SizedBox(height: 12),
          RCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RTextField(
                  label: 'App name',
                  controller: _name,
                  onChanged: (v) => state.brandName = v,
                ),
                const SizedBox(height: 12),
                RTextField(
                  label: 'Tagline',
                  controller: _tagline,
                  onChanged: (v) => state.brandTagline = v,
                ),
                const SizedBox(height: 20),
                const Text('Primary color',
                    style:
                        TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(
                      AppState.brandSwatches.length, (i) {
                    final c = AppState.brandSwatches[i];
                    final sel = state.brandColorIndex == i;
                    return GestureDetector(
                      onTap: () {
                        state.brandColorIndex = i;
                        state.refresh();
                      },
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel
                                ? scheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow:
                              RemedooTheme.softShadow,
                        ),
                        child: sel
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Text(
                  'Applies instantly across the whole app.',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant),
                ),
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
    _load();
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
        child: Center(child: CircularProgressIndicator()),
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

/// Service areas CRUD.
class ServiceAreasScreen extends StatelessWidget {
  const ServiceAreasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AdminCrudScreen(
        spec: state.mapSpec('Service Areas', 'Area', const [
      FieldSpec(key: 'name', label: 'Area name', required: true),
    ], state.serviceAreas));
  }
}

/// Quick actions toggles.
class QuickActionsScreen extends StatelessWidget {
  const QuickActionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RSectionHeader(
              title: 'Quick Actions',
              subtitle: 'Home screen shortcuts'),
          const SizedBox(height: 12),
          RCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: state.quickActions.keys.map((k) {
                return SwitchListTile(
                  value: state.quickActions[k]!,
                  activeThumbColor: RemedooTheme.success,
                  onChanged: (v) {
                    state.quickActions[k] = v;
                    state.refresh();
                  },
                  title: Text(k),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category actions toggles.
class CategoryActionsScreen extends StatelessWidget {
  const CategoryActionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return _Scaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RSectionHeader(
              title: 'Category Actions',
              subtitle: 'Category row shortcuts'),
          const SizedBox(height: 12),
          RCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: state.categoryActions.keys.map((k) {
                return SwitchListTile(
                  value: state.categoryActions[k]!,
                  activeThumbColor: RemedooTheme.success,
                  onChanged: (v) {
                    state.categoryActions[k] = v;
                    state.refresh();
                  },
                  title: Text(k),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Featured doctors / medicines / providers pickers.
class FeaturedScreen extends StatelessWidget {
  const FeaturedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _picker(
          context,
          state,
          'Featured Doctors',
          state.featuredDoctors,
          doctors
              .map((d) => (d.id, d.name))
              .toList(),
        ),
        const SizedBox(height: 12),
        _picker(
          context,
          state,
          'Featured Medicines',
          state.featuredMedicines,
          medicines
              .map((m) => (m.id, m.name))
              .toList(),
        ),
        const SizedBox(height: 12),
        _picker(
          context,
          state,
          'Featured Providers',
          state.featuredProviders,
          [
            ...hospitals.map((h) => (h.id, h.name)),
            ...labs.map((l) => (l.id, l.name)),
            ...pharmacies.map((p) => (p.id, p.name)),
          ],
        ),
      ],
    );
  }

  Widget _picker(
    BuildContext context,
    AppState state,
    String title,
    List<String> selected,
    List<(String, String)> options,
  ) {
    final scheme = Theme.of(context).colorScheme;
    String nameOf(String id) {
      final hit = options.where((o) => o.$1 == id);
      return hit.isEmpty ? id : hit.first.$2;
    }

    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              RButton(
                label: 'Pick',
                icon: Icons.add,
                small: true,
                variant: RButtonVariant.outline,
                onPressed: () => _pickDialog(
                    context, state, title, selected, options),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selected.isEmpty)
            Text('None selected.',
                style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selected
                  .map((id) => Chip(
                        label: Text(nameOf(id)),
                        deleteIcon:
                            const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          selected.remove(id);
                          state.refresh();
                        },
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  void _pickDialog(
    BuildContext context,
    AppState state,
    String title,
    List<String> selected,
    List<(String, String)> options,
  ) {
    final temp = Set<String>.of(selected);
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 400,
            height: 400,
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (_, i) {
                final (id, name) = options[i];
                final sel = temp.contains(id);
                return CheckboxListTile(
                  value: sel,
                  onChanged: (v) => setD(() => v!
                      ? temp.add(id)
                      : temp.remove(id)),
                  title: Text(name),
                  dense: true,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            RButton(
              label: 'Save',
              small: true,
              onPressed: () {
                selected
                  ..clear()
                  ..addAll(temp);
                state.refresh();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

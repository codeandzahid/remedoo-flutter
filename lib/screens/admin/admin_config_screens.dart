import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OTP Settings',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Text('OTP length (digits)')),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Expiry (minutes)')),
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
    return _Scaffold(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Commission (%)',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
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
                          Expanded(child: Text(k)),
                          Text('${v.toStringAsFixed(0)}%'),
                        ],
                      ),
                      Slider(
                        value: v,
                        min: 0,
                        max: 30,
                        divisions: 30,
                        activeColor: RemedooTheme.primary,
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
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                state.collectionAdd(state.apiKeys, {
                  'name': 'New key',
                  'key': _newKey(),
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Key'),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: state.apiKeys.length,
            itemBuilder: (_, i) {
              final k = state.apiKeys[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.key,
                      color: RemedooTheme.primary),
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
    return _Scaffold(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Branding',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'App name'),
                onChanged: (v) => state.brandName = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagline,
                decoration: const InputDecoration(
                    labelText: 'Tagline'),
                onChanged: (v) => state.brandTagline = v,
              ),
              const SizedBox(height: 16),
              const Text('Primary color',
                  style:
                      TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
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
                      width: 48,
                      height: 48,
                      margin:
                          const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: sel
                            ? Border.all(
                                color: Colors.black,
                                width: 3)
                            : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check,
                              color: Colors.white)
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              const Text(
                'Applies instantly across the whole app.',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
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
      child: Card(
        child: Column(
          children: state.quickActions.keys.map((k) {
            return SwitchListTile(
              value: state.quickActions[k]!,
              onChanged: (v) {
                state.quickActions[k] = v;
                state.refresh();
              },
              title: Text(k),
            );
          }).toList(),
        ),
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
      child: Card(
        child: Column(
          children: state.categoryActions.keys.map((k) {
            return SwitchListTile(
              value: state.categoryActions[k]!,
              onChanged: (v) {
                state.categoryActions[k] = v;
                state.refresh();
              },
              title: Text(k),
            );
          }).toList(),
        ),
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
    String nameOf(String id) {
      final hit = options.where((o) => o.$1 == id);
      return hit.isEmpty ? id : hit.first.$2;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                TextButton.icon(
                  onPressed: () => _pickDialog(
                      context, state, title, selected, options),
                  icon: const Icon(Icons.add),
                  label: const Text('Pick'),
                ),
              ],
            ),
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
          title: Text(title),
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
            FilledButton(
              onPressed: () {
                selected
                  ..clear()
                  ..addAll(temp);
                state.refresh();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

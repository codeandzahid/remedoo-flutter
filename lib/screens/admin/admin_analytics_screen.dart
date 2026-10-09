import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Platform analytics computed from real Supabase data.
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    await Future.wait([
      state.loadAllProfiles(),
      state.loadAdminOrders(),
      state.loadAdminAppointments(),
      state.loadAdminTable('doctors'),
      state.loadAdminTable('hospitals'),
      state.loadAdminTable('labs'),
      state.loadAdminTable('pharmacies'),
      state.loadAdminTable('medicines'),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const RLoading();
    }

    // Catalog mix
    final catalog = [
      ('Doctors', state.adminTable('doctors').length, Icons.person_search,
          scheme.primary),
      ('Hospitals', state.adminTable('hospitals').length,
          Icons.local_hospital, RemedooTheme.teal),
      ('Labs', state.adminTable('labs').length, Icons.science,
          RemedooTheme.purple),
      ('Pharmacies', state.adminTable('pharmacies').length,
          Icons.storefront, RemedooTheme.warning),
      ('Medicines', state.adminTable('medicines').length,
          Icons.medication, RemedooTheme.success),
    ];

    // Top specialties from the real doctors table
    final specCount = <String, int>{};
    for (final d in state.adminTable('doctors')) {
      final s = '${d['specialization'] ?? 'General'}';
      specCount[s] = (specCount[s] ?? 0) + 1;
    }
    final topSpecs = specCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Medicine categories
    final catCount = <String, int>{};
    for (final m in state.adminTable('medicines')) {
      final c = '${m['category'] ?? 'General'}';
      catCount[c] = (catCount[c] ?? 0) + 1;
    }
    final topCats = catCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Appointments by status
    final apptByStatus = <String, int>{};
    for (final a in state.adminAppointments) {
      final st = '${a['status'] ?? 'pending'}';
      apptByStatus[st] = (apptByStatus[st] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const RSectionHeader(
            title: 'Platform Overview',
            subtitle: 'Live counts from the database'),
        const SizedBox(height: 12),
        RCard(
          child: Column(
            children: [
              _row(context, 'Registered users', '${state.allProfiles.length}',
                  Icons.people),
              const Divider(height: 20),
              _row(context, 'Appointments',
                  '${state.adminAppointments.length}', Icons.calendar_month),
              const Divider(height: 20),
              _row(context, 'Medicine orders',
                  '${state.adminOrders.length}', Icons.shopping_bag),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const RSectionHeader(
            title: 'Catalog', subtitle: 'Providers and products'),
        const SizedBox(height: 12),
        ...catalog.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: ListTile(
                  leading: _tile(context, c.$3, c.$4),
                  title: Text(c.$1,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text('${c.$2}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            )),
        const SizedBox(height: 24),
        const RSectionHeader(
            title: 'Appointments by Status',
            subtitle: 'Live pipeline'),
        const SizedBox(height: 12),
        RCard(
          child: apptByStatus.isEmpty
              ? Text('No appointments yet.',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 13))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: apptByStatus.entries
                      .map((e) => Chip(
                            label: Text(
                                '${e.key.replaceAll('_', ' ')} · ${e.value}'),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: 24),
        const RSectionHeader(
            title: 'Top Specialties',
            subtitle: 'Doctor count per specialty'),
        const SizedBox(height: 12),
        if (topSpecs.isEmpty)
          Text('No doctors yet.',
              style:
                  TextStyle(color: scheme.onSurfaceVariant, fontSize: 13))
        else
          ...topSpecs.take(6).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: ListTile(
                    leading: _tile(context, Icons.medical_services,
                        scheme.primary),
                    title: Text(e.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    trailing: Text('${e.value} doctors',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              )),
        const SizedBox(height: 24),
        const RSectionHeader(
            title: 'Medicine Categories',
            subtitle: 'Catalog mix'),
        const SizedBox(height: 12),
        if (topCats.isEmpty)
          Text('No medicines yet.',
              style:
                  TextStyle(color: scheme.onSurfaceVariant, fontSize: 13))
        else
          ...topCats.take(6).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: ListTile(
                    leading: _tile(
                        context, Icons.medication, RemedooTheme.teal),
                    title: Text(e.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    trailing: Text('${e.value} items',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _row(
      BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        _tile(context, icon, Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: dark
            ? color.withValues(alpha: 0.18)
            : Color.lerp(color, Colors.white, 0.85),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

import 'package:flutter/material.dart';

import '../app_navigator.dart';
import '../data/mock_data.dart' as mock;
import '../responsive/animations.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'labs_screen.dart';
import 'remedoo_pharmacy_screen.dart';

/// Global search (2026-10-19): one box for doctors, medicines, lab
/// tests and hospitals — the dashboard search used to find doctors only.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _hit(String text) => text.toLowerCase().contains(_q.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final q = _q.trim();
    final doctors = q.isEmpty
        ? const []
        : state.activeDoctors
            .where((d) => _hit(d.name) || _hit(d.specialty))
            .take(6)
            .toList();
    final medicines = q.isEmpty
        ? const []
        : state.activeMedicines
            .where((m) => _hit(m.name) || _hit(m.brand) || _hit(m.category))
            .take(6)
            .toList();
    final tests = q.isEmpty
        ? const []
        : mock.labTests
            .where((t) => _hit(t.name) || _hit(t.category))
            .take(6)
            .toList();
    final hospitals = q.isEmpty
        ? const []
        : state.activeHospitals.where((h) => _hit(h.name)).take(6).toList();
    final nothing = q.isNotEmpty &&
        doctors.isEmpty &&
        medicines.isEmpty &&
        tests.isEmpty &&
        hospitals.isEmpty;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => goBack(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      onChanged: (v) => setState(() => _q = v),
                      decoration: InputDecoration(
                        hintText: 'Search doctors, medicines, tests...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: scheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: q.isEmpty
                  ? _hint(context)
                  : nothing
                      ? const REmptyState(
                          icon: Icons.search_off,
                          title: 'No results found',
                          subtitle:
                              'Try a doctor name, a medicine, or a test name.',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            if (doctors.isNotEmpty) ...[
                              _groupLabel('Doctors'),
                              for (final d in doctors)
                                _row(
                                  context,
                                  icon: Icons.medical_services,
                                  color: RemedooTheme.primary,
                                  title: d.name,
                                  subtitle:
                                      '${d.specialty} • ${inr(d.fee)}',
                                  onTap: () => pushPage(context,
                                      DoctorDetailScreen(doctor: d)),
                                ),
                            ],
                            if (medicines.isNotEmpty) ...[
                              _groupLabel('Medicines'),
                              for (final m in medicines)
                                _row(
                                  context,
                                  icon: Icons.medication,
                                  color: RemedooTheme.emergency,
                                  title: m.name,
                                  subtitle: '${m.pack} • ${inr(m.price)}',
                                  onTap: () => pushPage(context,
                                      const RemedooPharmacyScreen()),
                                ),
                            ],
                            if (tests.isNotEmpty) ...[
                              _groupLabel('Lab Tests'),
                              for (final t in tests)
                                _row(
                                  context,
                                  icon: Icons.science,
                                  color: RemedooTheme.success,
                                  title: t.name,
                                  subtitle:
                                      '${t.category} • ${inr(t.price)}',
                                  onTap: () => pushPage(
                                      context, const LabsScreen()),
                                ),
                            ],
                            if (hospitals.isNotEmpty) ...[
                              _groupLabel('Hospitals'),
                              for (final h in hospitals)
                                _row(
                                  context,
                                  icon: Icons.local_hospital,
                                  color: RemedooTheme.warning,
                                  title: h.name,
                                  subtitle: h.location,
                                  onTap: () => pushPage(context,
                                      HospitalDetailScreen(hospital: h)),
                                ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What are you looking for?',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in const [
                'Paracetamol',
                'Blood Test',
                'Cardiologist',
                'Hospital',
                'Vitamin',
                'X-Ray',
              ])
                ActionChip(
                  label: Text(s),
                  onPressed: () {
                    _ctrl.text = s;
                    setState(() => _q = s);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _groupLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

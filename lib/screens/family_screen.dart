import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../widgets/form_kit.dart';
import '../app_navigator.dart';

/// Family members management.
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.isSignedIn) {
      return const GuestGate();
    }
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 20),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white),
                  onPressed: () => goBack(context),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.group_outlined,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Family Members',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          'Manage health profiles for your family',
                          style: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: 0.75),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: MaxWidthBox(
              maxWidth: 760,
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: RButton(
                      label: 'Add Family Member',
                      icon: Icons.add,
                      fullWidth: true,
                      onPressed: () =>
                          _addDialog(context, state),
                    ),
                  ),
                  Expanded(
                    child: state.family.isEmpty
                        ? const REmptyState(
                            icon: Icons.family_restroom,
                            title: 'No family members yet',
                            subtitle:
                                'Add your loved ones to manage their health in one place.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                20, 12, 20, 24),
                            itemCount: state.family.length,
                            itemBuilder: (_, i) => StaggerItem(
                              index: i % 6,
                              child: _card(context, state,
                                  state.family[i]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
      BuildContext context, AppState state, FamilyMember m) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color:
                    scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.person,
                  color: scheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(m.relation,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip(context, m.relation),
                      _chip(context, '${m.age} yrs'),
                      if ((m.gender ?? '').isNotEmpty)
                        _chip(context, m.gender!),
                      if ((m.bloodGroup ?? '').isNotEmpty)
                        _chip(context, 'Blood ${m.bloodGroup}'),
                      if ((m.allergies ?? '').isNotEmpty)
                        _chip(context, 'Allergy: ${m.allergies}'),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.1),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Edit member',
                icon: Icon(Icons.edit_outlined,
                    size: 17, color: scheme.primary),
                onPressed: () =>
                    _addDialog(context, state, existing: m),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: RemedooTheme.destructive
                    .withValues(alpha: 0.1),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.delete_outline,
                    size: 17,
                    color: RemedooTheme.destructive),
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Remove ${m.name}?',
                    message:
                        'They will be removed from your family list.',
                    confirmLabel: 'Remove',
                  );
                  if (ok) state.removeFamilyMember(m.id);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, color: scheme.onSurfaceVariant)),
    );
  }

  static const _genders = ['Female', 'Male', 'Other'];
  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  /// Add dialog, or edit dialog when [existing] is passed.
  ///
  /// Collects the full family_members record (audit Patient 9):
  /// date of birth (age derives from it, so age survives reload),
  /// gender, blood group, allergies and chronic conditions.
  /// Validation is visible (Patient 26): an empty name, a missing
  /// relation or a missing date of birth shows an error in the
  /// dialog instead of silently doing nothing or inventing age 30.
  void _addDialog(BuildContext context, AppState state,
      {FamilyMember? existing}) {
    final name = TextEditingController(text: existing?.name ?? '');
    final relation =
        TextEditingController(text: existing?.relation ?? '');
    final allergies =
        TextEditingController(text: existing?.allergies ?? '');
    final conditions =
        TextEditingController(text: existing?.chronicConditions ?? '');
    DateTime? dob = existing?.dateOfBirth;
    String? gender = existing?.gender;
    String? blood = existing?.bloodGroup;
    String? error;
    showResponsiveDialog(
      context,
      (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null
              ? 'Add Family Member'
              : 'Edit Family Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RKitField(
                    label: 'Full name *',
                    hint: 'Full name',
                    controller: name),
                const SizedBox(height: 12),
                RKitField(
                    label: 'Relation *',
                    hint: 'Relation (e.g. Mother)',
                    controller: relation),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Date of birth *',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(ctx).colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cake_outlined, size: 18),
                    label: Text(dob == null
                        ? 'Select date of birth'
                        : '${dob!.day}/${dob!.month}/${dob!.year}'
                            ' (${FamilyMember.ageFromDob(dob!)} yrs)'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dob ??
                            DateTime.now()
                                .subtract(const Duration(days: 365 * 30)),
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setLocal(() => dob = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                RKitDropdown<String>(
                  label: 'Gender',
                  value: _genders.contains(gender) ? gender : null,
                  items: _genders
                      .map((g) =>
                          DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setLocal(() => gender = v),
                ),
                const SizedBox(height: 12),
                RKitDropdown<String>(
                  label: 'Blood group',
                  value: _bloodGroups.contains(blood) ? blood : null,
                  items: _bloodGroups
                      .map((g) =>
                          DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setLocal(() => blood = v),
                ),
                const SizedBox(height: 12),
                RKitField(
                    label: 'Allergies',
                    hint: 'e.g. Penicillin, peanuts',
                    controller: allergies),
                const SizedBox(height: 12),
                RKitField(
                    label: 'Chronic conditions',
                    hint: 'e.g. Diabetes, asthma',
                    controller: conditions),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(error!,
                        style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            RButton(
              label: existing == null ? 'Add' : 'Save',
              small: true,
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  setLocal(() => error = 'Please enter a name.');
                  return;
                }
                if (relation.text.trim().isEmpty) {
                  setLocal(
                      () => error = 'Please enter the relation.');
                  return;
                }
                if (dob == null && existing?.dateOfBirth == null) {
                  setLocal(() =>
                      error = 'Please pick a date of birth.');
                  return;
                }
                final chosenDob = dob ?? existing?.dateOfBirth;
                if (existing != null) {
                  state.updateFamilyMember(
                    id: existing.id,
                    name: name.text.trim(),
                    relation: relation.text.trim(),
                    age: existing.age,
                    dateOfBirth: chosenDob,
                    gender: gender,
                    bloodGroup: blood,
                    allergies: allergies.text,
                    chronicConditions: conditions.text,
                  );
                } else {
                  state.addFamilyMember(
                    name: name.text.trim(),
                    relation: relation.text.trim(),
                    age: chosenDob != null
                        ? FamilyMember.ageFromDob(chosenDob)
                        : 0,
                    dateOfBirth: chosenDob,
                    gender: gender,
                    bloodGroup: blood,
                    allergies: allergies.text,
                    chronicConditions: conditions.text,
                  );
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

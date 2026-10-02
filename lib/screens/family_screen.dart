import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Family members management.
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
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
                  onPressed: () => Navigator.maybePop(context),
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
                  Row(
                    children: [
                      _chip(context, m.relation),
                      const SizedBox(width: 6),
                      _chip(context, '${m.age} yrs'),
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

  void _addDialog(BuildContext context, AppState state) {
    final name = TextEditingController();
    final relation = TextEditingController();
    final age = TextEditingController();
    showResponsiveDialog(
      context,
      (_) => AlertDialog(
        title: const Text('Add Family Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RTextField(
                label: 'Full name',
                hint: 'Full name',
                controller: name),
            const SizedBox(height: 12),
            RTextField(
                label: 'Relation',
                hint: 'Relation (e.g. Mother)',
                controller: relation),
            const SizedBox(height: 12),
            RTextField(
                label: 'Age',
                hint: 'Age',
                controller: age,
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          RButton(
            label: 'Add',
            small: true,
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              state.addFamilyMember(
                name: name.text.trim(),
                relation: relation.text.trim().isEmpty
                    ? 'Family'
                    : relation.text.trim(),
                age: int.tryParse(age.text) ?? 30,
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

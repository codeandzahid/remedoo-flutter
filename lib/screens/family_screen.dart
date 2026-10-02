import 'package:flutter/material.dart';

import '../models.dart';
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
      appBar: AppBar(title: const Text('Family Members')),
      body: state.family.isEmpty
          ? const EmptyState(
              icon: Icons.family_restroom,
              title: 'No family members yet',
              subtitle:
                  'Add your loved ones to manage their health in one place.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.family.length,
              itemBuilder: (_, i) =>
                  _card(context, state, state.family[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, state),
        icon: const Icon(Icons.add),
        label: const Text('Add Family Member'),
      ),
    );
  }

  Widget _card(
      BuildContext context, AppState state, FamilyMember m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: InitialsAvatar(name: m.name, radius: 24),
        title: Text(m.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${m.relation} • ${m.age} yrs'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              color: RemedooTheme.emergency),
          onPressed: () async {
            final ok = await confirmDialog(
              context,
              title: 'Remove ${m.name}?',
              message: 'They will be removed from your family list.',
              confirmLabel: 'Remove',
            );
            if (ok) state.removeFamilyMember(m.id);
          },
        ),
      ),
    );
  }

  void _addDialog(BuildContext context, AppState state) {
    final name = TextEditingController();
    final relation = TextEditingController();
    final age = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Family Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration:
                  const InputDecoration(labelText: 'Full name'),
            ),
            TextField(
              controller: relation,
              decoration: const InputDecoration(
                  labelText: 'Relation (e.g. Mother)'),
            ),
            TextField(
              controller: age,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Age'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

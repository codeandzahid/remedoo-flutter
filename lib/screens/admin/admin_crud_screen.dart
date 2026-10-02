import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Generic admin list: search, add/edit dialog from field specs,
/// delete with confirm, active toggle.
class AdminCrudScreen extends StatefulWidget {
  final EntitySpec spec;

  const AdminCrudScreen({super.key, required this.spec});

  @override
  State<AdminCrudScreen> createState() => _AdminCrudScreenState();
}

class _AdminCrudScreenState extends State<AdminCrudScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _title(Map<String, String> r) {
    for (final k in ['name', 'title', 'code', 'question']) {
      if ((r[k] ?? '').isNotEmpty) return r[k]!;
    }
    return r['id'] ?? 'Item';
  }

  String _subtitle(Map<String, String> r) {
    for (final k in ['specialty', 'email', 'subtitle', 'answer', 'role']) {
      if ((r[k] ?? '').isNotEmpty) return r[k]!;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final q = _search.text.trim().toLowerCase();
    var rows = spec.read();
    if (q.isNotEmpty) {
      rows = rows
          .where((r) => r.values
              .any((v) => v.toLowerCase().contains(q)))
          .toList();
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _editDialog(null),
                icon: const Icon(Icons.add),
                label: Text('Add ${spec.singular}'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${rows.length} ${spec.title.toLowerCase()}',
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox,
                  title: 'Nothing here',
                  subtitle: 'Add the first entry.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (_, i) =>
                      _row(rows[i], spec),
                ),
        ),
      ],
    );
  }

  Widget _row(Map<String, String> r, EntitySpec spec) {
    final id = r['id'] ?? '';
    final hasToggle = spec.rowActive != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(_title(r),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle:
            _subtitle(r).isEmpty ? null : Text(_subtitle(r)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasToggle)
              Switch(
                value: spec.rowActive!(r),
                activeThumbColor: RemedooTheme.ratingGreen,
                onChanged: (v) =>
                    spec.setRowActive!(id, v),
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _editDialog(r),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: RemedooTheme.emergency),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Delete ${spec.singular}?',
                  message: '"${_title(r)}" will be removed.',
                  confirmLabel: 'Delete',
                );
                if (ok) spec.remove(id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editDialog(Map<String, String>? row) {
    final spec = widget.spec;
    final ctrls = {
      for (final f in spec.fields)
        f.key: TextEditingController(text: row?[f.key] ?? '')
    };
    final toggles = {
      for (final f in spec.fields.where((f) => f.type == 'toggle'))
        f.key: (row?[f.key] ?? '0') == '1'
    };
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(
              '${row == null ? 'Add' : 'Edit'} ${spec.singular}'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: spec.fields.map((f) {
                  if (f.type == 'toggle') {
                    return SwitchListTile(
                      value: toggles[f.key]!,
                      onChanged: (v) =>
                          setD(() => toggles[f.key] = v),
                      title: Text(f.label),
                      contentPadding: EdgeInsets.zero,
                    );
                  }
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: ctrls[f.key],
                      keyboardType: f.type == 'number'
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText:
                            '${f.label}${f.required ? ' *' : ''}',
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                for (final f in spec.fields) {
                  if (f.required &&
                      ctrls[f.key]!.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              '${f.label} is required')),
                    );
                    return;
                  }
                }
                final values = {
                  for (final f in spec.fields)
                    f.key: f.type == 'toggle'
                        ? (toggles[f.key]! ? '1' : '0')
                        : ctrls[f.key]!.text.trim(),
                };
                if (row == null) {
                  spec.create(values);
                } else {
                  spec.update(row['id']!, values);
                }
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

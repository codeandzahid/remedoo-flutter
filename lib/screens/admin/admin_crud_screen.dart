import 'package:flutter/material.dart';

import '../../responsive/responsive.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Generic admin list: search, add/edit dialog from field specs,
/// delete with confirm, active toggle.
/// On phones/tablets the rows render as cards; on desktop (>=1100)
/// they render as a real DataTable.
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
          .where((r) =>
              r.values.any((v) => v.toLowerCase().contains(q)))
          .toList();
    }
    return MaxWidthBox(
      child: Column(
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
                  style: const TextStyle(
                      fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const EmptyState(
                    icon: Icons.inbox,
                    title: 'Nothing here',
                    subtitle: 'Add the first entry.',
                  )
                : context.isDesktop
                    ? _dataTable(rows, spec)
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: rows.length,
                        itemBuilder: (_, i) =>
                            _row(rows[i], spec),
                      ),
          ),
        ],
      ),
    );
  }

  /// Desktop layout: real DataTable built from the entity field specs.
  Widget _dataTable(
      List<Map<String, String>> rows, EntitySpec spec) {
    final hasToggle = spec.rowActive != null;
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              for (final f in spec.fields)
                DataColumn(
                  label: Text(f.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800)),
                ),
              if (hasToggle)
                const DataColumn(
                    label: Text('Active',
                        style: TextStyle(
                            fontWeight: FontWeight.w800))),
              const DataColumn(
                  label: Text('Actions',
                      style:
                          TextStyle(fontWeight: FontWeight.w800))),
            ],
            rows: [
              for (final r in rows)
                DataRow(cells: [
                  for (final f in spec.fields)
                    DataCell(
                      ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 220),
                        child: Text(
                          f.type == 'toggle'
                              ? ((r[f.key] ?? '0') == '1'
                                  ? 'Yes'
                                  : 'No')
                              : (r[f.key] ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (hasToggle)
                    DataCell(Switch(
                      value: spec.rowActive!(r),
                      activeThumbColor:
                          RemedooTheme.ratingGreen,
                      onChanged: (v) =>
                          spec.setRowActive!(r['id'] ?? '', v),
                    )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 20),
                        tooltip: 'Edit',
                        onPressed: () => _editDialog(r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20,
                            color: RemedooTheme.emergency),
                        tooltip: 'Delete',
                        onPressed: () =>
                            _confirmDelete(r, spec),
                      ),
                    ],
                  )),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(Map<String, String> r, EntitySpec spec) {
    final id = r['id'] ?? '';
    final hasToggle = spec.rowActive != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(_title(r),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: _subtitle(r).isEmpty
            ? null
            : Text(_subtitle(r),
                maxLines: 1, overflow: TextOverflow.ellipsis),
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
              onPressed: () => _confirmDelete(r, spec),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      Map<String, String> r, EntitySpec spec) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${spec.singular}?',
      message: '"${_title(r)}" will be removed.',
      confirmLabel: 'Delete',
    );
    if (ok) spec.remove(r['id'] ?? '');
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
    showResponsiveDialog(
      context,
      (_) => StatefulBuilder(
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

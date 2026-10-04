import 'package:flutter/material.dart';

import '../../responsive/responsive.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Field types for [AdminField]: 'text', 'int', 'double', 'bool', 'fk'.
class AdminField {
  final String key;
  final String label;
  final String type;
  final bool required;
  final dynamic defaultValue;

  /// For type 'fk': the referenced admin table and the label column to show.
  final String? fkTable;

  const AdminField({
    required this.key,
    required this.label,
    this.type = 'text',
    this.required = false,
    this.defaultValue,
    this.fkTable,
  });
}

/// Backend-driven generic admin table screen: search, add/edit dialog from
/// field specs, delete with confirm. Reads/writes Supabase via
/// [AppState.adminTable]/[AppState.loadAdminTable]/[AppState.adminSaveRow]/
/// [AppState.adminDeleteRow].
class AdminTableScreen extends StatefulWidget {
  final String table;
  final String title;
  final String singular;
  final List<AdminField>? fields;

  const AdminTableScreen({
    super.key,
    required this.table,
    required this.title,
    required this.singular,
    this.fields,
  });

  @override
  State<AdminTableScreen> createState() => _AdminTableScreenState();
}

class _AdminTableScreenState extends State<AdminTableScreen> {
  final _search = TextEditingController();
  bool _loading = true;

  List<AdminField> get _fields =>
      widget.fields ?? adminTableFields(widget.table);

  /// Tables referenced by 'fk' fields that must be loaded for pickers.
  Iterable<String> get _fkTables =>
      _fields.where((f) => f.type == 'fk').map((f) => f.fkTable!).toSet();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    setState(() => _loading = true);
    await state.loadAdminTable(widget.table);
    for (final t in _fkTables) {
      await state.loadAdminTable(t);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _title(Map<String, dynamic> r) =>
      adminTableTitle(widget.table, r);

  String _subtitle(Map<String, dynamic> r) =>
      adminTableSubtitle(widget.table, r);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = AppStateScope.of(context);
    final q = _search.text.trim().toLowerCase();
    var rows = state.adminTable(widget.table);
    if (q.isNotEmpty) {
      rows = rows
          .where((r) => r.values.any(
              (v) => '${v ?? ''}'.toLowerCase().contains(q)))
          .toList();
    }
    return MaxWidthBox(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: RSearchBar(
                    hint: 'Search ${widget.title.toLowerCase()}…',
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                RButton(
                  label: 'Add ${widget.singular}',
                  icon: Icons.add,
                  small: true,
                  onPressed: () => _editDialog(null),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${rows.length} ${widget.title.toLowerCase()}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant)),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: rows.isEmpty
                        ? REmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Nothing here',
                            subtitle:
                                'Add the first ${widget.singular.toLowerCase()}.',
                            actionLabel: 'Add ${widget.singular}',
                            onAction: () => _editDialog(null),
                          )
                        : context.isDesktop
                            ? _dataTable(rows)
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                itemCount: rows.length,
                                itemBuilder: (_, i) =>
                                    _row(rows[i]),
                              ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dataTable(List<Map<String, dynamic>> rows) {
    final scheme = Theme.of(context).colorScheme;
    final textFields =
        _fields.where((f) => f.type != 'fk').take(6).toList();
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: RCard(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.4,
                color: scheme.onSurfaceVariant,
              ),
              columns: [
                for (final f in textFields)
                  DataColumn(
                    label: Text(f.label.toUpperCase()),
                  ),
                const DataColumn(label: Text('ACTIONS')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(cells: [
                    for (final f in textFields)
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: 220),
                          child: Text(
                            _cellText(f, r),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 20,
                              color: scheme.onSurfaceVariant),
                          tooltip: 'Edit',
                          onPressed: () => _editDialog(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20,
                              color: RemedooTheme.emergency),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(r),
                        ),
                      ],
                    )),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _cellText(AdminField f, Map<String, dynamic> r) {
    final v = r[f.key];
    if (v == null) return '';
    if (f.type == 'bool') return (v == true) ? 'Yes' : 'No';
    return '$v';
  }

  Widget _row(Map<String, dynamic> r) {
    final scheme = Theme.of(context).colorScheme;
    final title = _title(r);
    final subtitle = _subtitle(r);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: ListTile(
          leading: InitialsAvatar(name: title, radius: 20),
          title: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 20, color: scheme.onSurfaceVariant),
                tooltip: 'Edit',
                onPressed: () => _editDialog(r),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: RemedooTheme.emergency),
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(r),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> r) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${widget.singular}?',
      message: '"${_title(r)}" will be permanently removed.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    final state = AppStateScope.of(context);
    final success =
        await state.adminDeleteRow(widget.table, '${r['id']}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(success
              ? '${widget.singular} deleted.'
              : 'Delete failed. Please try again.')),
    );
  }

  void _editDialog(Map<String, dynamic>? row) {
    final state = AppStateScope.of(context);
    final fields = _fields;
    final ctrls = {
      for (final f in fields.where((f) => f.type != 'bool'))
        f.key: TextEditingController(
            text: _initialText(f, row?[f.key]))
    };
    final bools = {
      for (final f in fields.where((f) => f.type == 'bool'))
        f.key: _initialBool(f, row?[f.key])
    };
    final fkValues = {
      for (final f in fields.where((f) => f.type == 'fk'))
        f.key: row?[f.key]?.toString(),
    };
    showResponsiveDialog(
      context,
      (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(
              '${row == null ? 'Add' : 'Edit'} ${widget.singular}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: fields.map((f) {
                  if (f.type == 'bool') {
                    return SwitchListTile(
                      value: bools[f.key]!,
                      onChanged: (v) =>
                          setD(() => bools[f.key] = v),
                      title: Text(f.label),
                      contentPadding: EdgeInsets.zero,
                    );
                  }
                  if (f.type == 'fk') {
                    final options =
                        state.adminTable(f.fkTable!);
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: fkValues[f.key],
                        decoration: InputDecoration(
                          labelText:
                              '${f.label}${f.required ? ' *' : ''}',
                          border:
                              const OutlineInputBorder(),
                        ),
                        items: [
                          for (final o in options)
                            DropdownMenuItem(
                              value: '${o['id']}',
                              child: Text(
                                  '${o['name'] ?? o['id']}',
                                  overflow:
                                      TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) =>
                            setD(() => fkValues[f.key] = v),
                      ),
                    );
                  }
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12),
                    child: RTextField(
                      label:
                          '${f.label}${f.required ? ' *' : ''}',
                      controller: ctrls[f.key],
                      keyboardType: (f.type == 'int' ||
                              f.type == 'double')
                          ? TextInputType.number
                          : TextInputType.text,
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
            RButton(
              label: 'Save',
              small: true,
              onPressed: () async {
                for (final f in fields) {
                  if (!f.required) continue;
                  final empty = f.type == 'bool'
                      ? false
                      : f.type == 'fk'
                          ? (fkValues[f.key] == null ||
                              fkValues[f.key]!.isEmpty)
                          : ctrls[f.key]!.text.trim().isEmpty;
                  if (empty) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      SnackBar(
                          content: Text(
                              '${f.label} is required')),
                    );
                    return;
                  }
                }
                final values =
                    <String, dynamic>{};
                for (final f in fields) {
                  if (f.type == 'bool') {
                    values[f.key] = bools[f.key]!;
                  } else if (f.type == 'fk') {
                    values[f.key] = fkValues[f.key];
                  } else if (f.type == 'int') {
                    values[f.key] = int.tryParse(
                            ctrls[f.key]!.text.trim()) ??
                        0;
                  } else if (f.type == 'double') {
                    values[f.key] = double.tryParse(
                            ctrls[f.key]!.text.trim()) ??
                        0;
                  } else {
                    values[f.key] =
                        ctrls[f.key]!.text.trim();
                  }
                }
                if (row != null) {
                  values['id'] = row['id'];
                }
                Navigator.pop(context);
                final ok = await state.adminSaveRow(
                    widget.table, values);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(ok
                          ? '${widget.singular} saved.'
                          : 'Save failed. Please try again.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _initialText(AdminField f, dynamic v) {
    if (v != null) return '$v';
    if (f.defaultValue != null) return '${f.defaultValue}';
    return '';
  }

  bool _initialBool(AdminField f, dynamic v) {
    if (v is bool) return v;
    if (f.defaultValue is bool) return f.defaultValue as bool;
    return false;
  }
}

/// Field specs per catalog table.
List<AdminField> adminTableFields(String table) {
  switch (table) {
    case 'doctors':
      return const [
        AdminField(key: 'name', label: 'Name', required: true),
        AdminField(key: 'specialization', label: 'Specialty'),
        AdminField(
            key: 'consultation_fee',
            label: 'Fee (₹)',
            type: 'double'),
        AdminField(
            key: 'rating', label: 'Rating', type: 'double'),
        AdminField(
            key: 'experience_years',
            label: 'Experience (yrs)',
            type: 'int'),
        AdminField(key: 'phone', label: 'Phone'),
        AdminField(key: 'bio', label: 'About'),
        AdminField(
            key: 'approval_status',
            label: 'Status',
            defaultValue: 'approved'),
        AdminField(
            key: 'is_featured',
            label: 'Featured',
            type: 'bool'),
        AdminField(key: 'upi_id', label: 'UPI ID'),
        AdminField(
            key: 'upi_enabled',
            label: 'UPI Payments',
            type: 'bool',
            defaultValue: true),
        AdminField(
            key: 'pay_in_clinic_enabled',
            label: 'Pay in Clinic',
            type: 'bool',
            defaultValue: true),
      ];
    case 'hospitals':
      return const [
        AdminField(key: 'name', label: 'Name', required: true),
        AdminField(key: 'location', label: 'Location'),
        AdminField(
            key: 'beds', label: 'Beds', type: 'int'),
        AdminField(
            key: 'icu_available',
            label: 'ICU Available',
            type: 'bool'),
        AdminField(
            key: 'is_government',
            label: 'Government',
            type: 'bool'),
        AdminField(key: 'phone', label: 'Phone'),
        AdminField(
            key: 'rating', label: 'Rating', type: 'double'),
        AdminField(
            key: 'approval_status',
            label: 'Status',
            defaultValue: 'approved'),
        AdminField(
            key: 'is_featured',
            label: 'Featured',
            type: 'bool'),
        AdminField(key: 'upi_id', label: 'UPI ID'),
        AdminField(
            key: 'upi_enabled',
            label: 'UPI Payments',
            type: 'bool',
            defaultValue: true),
        AdminField(
            key: 'pay_in_clinic_enabled',
            label: 'Pay in Clinic',
            type: 'bool',
            defaultValue: true),
      ];
    case 'labs':
      return const [
        AdminField(key: 'name', label: 'Name', required: true),
        AdminField(key: 'location', label: 'Location'),
        AdminField(key: 'phone', label: 'Phone'),
        AdminField(
            key: 'rating', label: 'Rating', type: 'double'),
        AdminField(
            key: 'approval_status',
            label: 'Status',
            defaultValue: 'approved'),
        AdminField(
            key: 'is_featured',
            label: 'Featured',
            type: 'bool'),
        AdminField(key: 'upi_id', label: 'UPI ID'),
        AdminField(
            key: 'upi_enabled',
            label: 'UPI Payments',
            type: 'bool',
            defaultValue: true),
        AdminField(
            key: 'pay_in_clinic_enabled',
            label: 'Pay in Clinic',
            type: 'bool',
            defaultValue: true),
      ];
    case 'lab_tests':
      return const [
        AdminField(key: 'name', label: 'Name', required: true),
        AdminField(
            key: 'lab_id',
            label: 'Lab',
            type: 'fk',
            required: true,
            fkTable: 'labs'),
        AdminField(key: 'category', label: 'Category'),
        AdminField(
            key: 'price', label: 'Price (₹)', type: 'double'),
        AdminField(
            key: 'discount_percent',
            label: 'Discount %',
            type: 'double'),
        AdminField(
            key: 'sample_type', label: 'Sample Type'),
        AdminField(
            key: 'turnaround_time',
            label: 'Turnaround Time'),
        AdminField(
            key: 'is_popular',
            label: 'Popular',
            type: 'bool'),
        AdminField(
            key: 'requires_fasting',
            label: 'Requires Fasting',
            type: 'bool'),
        AdminField(
            key: 'home_collection',
            label: 'Home Collection',
            type: 'bool',
            defaultValue: true),
        AdminField(key: 'description', label: 'Description'),
      ];
    case 'pharmacies':
      return const [
        AdminField(key: 'name', label: 'Name', required: true),
        AdminField(key: 'location', label: 'Location'),
        AdminField(key: 'phone', label: 'Phone'),
        AdminField(
            key: 'rating', label: 'Rating', type: 'double'),
        AdminField(
            key: 'approval_status',
            label: 'Status',
            defaultValue: 'approved'),
        AdminField(key: 'upi_id', label: 'UPI ID'),
        AdminField(
            key: 'upi_enabled',
            label: 'UPI Payments',
            type: 'bool',
            defaultValue: true),
        AdminField(
            key: 'pay_in_clinic_enabled',
            label: 'Pay in Clinic',
            type: 'bool',
            defaultValue: true),
      ];
    case 'medicines':
      return const [
        AdminField(key: 'name', label: 'Name', required: true),
        AdminField(
            key: 'pharmacy_id',
            label: 'Pharmacy',
            type: 'fk',
            required: true,
            fkTable: 'pharmacies'),
        AdminField(
            key: 'generic_name', label: 'Generic Name'),
        AdminField(key: 'category', label: 'Category'),
        AdminField(
            key: 'price', label: 'Price (₹)', type: 'double'),
        AdminField(
            key: 'discount_percent',
            label: 'Discount %',
            type: 'double'),
        AdminField(
            key: 'requires_prescription',
            label: 'Requires Prescription',
            type: 'bool'),
        AdminField(
            key: 'in_stock',
            label: 'In Stock',
            type: 'bool',
            defaultValue: true),
        AdminField(
            key: 'stock_quantity',
            label: 'Stock Qty',
            type: 'int'),
        AdminField(key: 'unit', label: 'Unit'),
        AdminField(
            key: 'manufacturer', label: 'Manufacturer'),
      ];
    default:
      return const [
        AdminField(key: 'name', label: 'Name', required: true),
      ];
  }
}

/// Display title for a row.
String adminTableTitle(String table, Map<String, dynamic> r) {
  final name = '${r['name'] ?? r['title'] ?? r['id'] ?? 'Item'}';
  return name;
}

/// Display subtitle for a row.
String adminTableSubtitle(String table, Map<String, dynamic> r) {
  switch (table) {
    case 'doctors':
      final spec = '${r['specialization'] ?? ''}';
      final fee = r['consultation_fee'];
      final feeStr =
          fee != null ? ' · ₹$fee' : '';
      return '$spec$feeStr'.trim();
    case 'lab_tests':
      final price = r['price'];
      return '${r['category'] ?? ''}${price != null ? ' · ₹$price' : ''}'
          .trim();
    case 'medicines':
      final price = r['price'];
      return '${r['category'] ?? ''}${price != null ? ' · ₹$price' : ''}'
          .trim();
    default:
      return '${r['location'] ?? ''}';
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/mock_data.dart' show specialties;
import '../../responsive/responsive.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/device_actions.dart';
import '../../widgets/existing_user_lookup.dart';
import '../../widgets/widgets.dart';
import '../../widgets/form_kit.dart';

/// Field types for [AdminField]: 'text', 'textarea', 'int',
/// 'double', 'bool', 'fk', 'dropdown', 'date', 'array', 'json',
/// 'url'. (The engine used to know only text/int/double/bool/fk,
/// so whole column families — arrays, JSONB hours, dates, enum
/// statuses — could not be edited at all: audit Admin gaps
/// 3/11/12/13.)
class AdminField {
  final String key;
  final String label;
  final String type;
  final bool required;
  final dynamic defaultValue;

  /// For type 'fk': the referenced admin table and the label column to show.
  final String? fkTable;

  /// For type 'dropdown': the constrained choices (enum fields
  /// were free text — a typo silently created a wrongly-approved
  /// or invalid record).
  final List<String>? options;

  /// Numeric range validation for 'int'/'double' fields
  /// (rating 0–5, discount 0–100…).
  final num? min;
  final num? max;

  const AdminField({
    required this.key,
    required this.label,
    this.type = 'text',
    this.required = false,
    this.defaultValue,
    this.fkTable,
    this.options,
    this.min,
    this.max,
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
                ? const RLoading()
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

  Future<void> _editDialog(Map<String, dynamic>? row) async {
    final state = AppStateScope.of(context);
    final fields = _fields;
    final ctrls = {
      for (final f in fields.where((f) =>
          f.type != 'bool' && f.type != 'fk' && f.type != 'dropdown'))
        f.key: TextEditingController(text: _initialText(f, row?[f.key]))
    };
    final bools = {
      for (final f in fields.where((f) => f.type == 'bool'))
        f.key: _initialBool(f, row?[f.key])
    };
    final fkValues = {
      for (final f in fields.where((f) => f.type == 'fk'))
        f.key: row?[f.key]?.toString(),
    };
    final dropValues = {
      for (final f in fields.where((f) => f.type == 'dropdown'))
        f.key: _initialDrop(f, row?[f.key]),
    };
    // Busy state for the "Use GPS" fill button (owner order
    // 2026-10-23: forms take latitude/longitude from the device
    // GPS instead of typed values). Lives with the controllers so
    // the StatefulBuilder below can rebuild around it.
    var gpsBusy = false;
    await showResponsiveDialog(
      context,
      (_) => StatefulBuilder(
        builder: (ctx, setD) {
          Widget fieldWidget(AdminField f) {
            if (f.type == 'bool') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: RFormSwitchTile(
                  title: f.label,
                  value: bools[f.key]!,
                  onChanged: (v) => setD(() => bools[f.key] = v),
                ),
              );
            }
            if (f.type == 'fk' || f.type == 'dropdown') {
              final isFk = f.type == 'fk';
              final options = isFk
                  ? state.adminTable(f.fkTable!)
                  : const <Map<String, dynamic>>[];
              final value = isFk ? fkValues[f.key] : dropValues[f.key];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RKitDropdown<String>(
                  label: '${f.label}${f.required ? ' *' : ''}',
                  value: value,
                  items: [
                    if (!f.required)
                      const DropdownMenuItem(
                          value: null, child: Text('—')),
                    if (isFk)
                      for (final o in options)
                        DropdownMenuItem(
                          value: '${o['id']}',
                          child: Text('${o['name'] ?? o['id']}',
                              overflow: TextOverflow.ellipsis),
                        )
                    else
                      for (final o in f.options ?? const <String>[])
                        DropdownMenuItem(value: o, child: Text(o)),
                  ],
                  onChanged: (v) => setD(() {
                    if (isFk) {
                      fkValues[f.key] = v;
                    } else {
                      dropValues[f.key] = v;
                    }
                  }),
                ),
              );
            }
            if (f.type == 'date') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RKitField(
                  label: '${f.label}${f.required ? ' *' : ''}',
                  controller: ctrls[f.key],
                  hint: 'YYYY-MM-DD',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_month_outlined,
                        size: 20),
                    onPressed: () async {
                      final current =
                          DateTime.tryParse(ctrls[f.key]!.text.trim());
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: current ?? DateTime.now(),
                        firstDate: DateTime(1930),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        ctrls[f.key]!.text =
                            picked.toIso8601String().substring(0, 10);
                        setD(() {});
                      }
                    },
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RKitField(
                label: '${f.label}${f.required ? ' *' : ''}',
                controller: ctrls[f.key],
                hint: f.type == 'array'
                    ? 'Separate items with commas'
                    : f.type == 'json'
                        ? 'JSON, e.g. {"mon-fri": "09:00-17:00"}'
                        : null,
                maxLines: (f.type == 'json' || f.type == 'textarea')
                    ? 3
                    : 1,
                keyboardType: (f.type == 'int' || f.type == 'double')
                    ? TextInputType.number
                    : TextInputType.text,
              ),
            );
          }

          // The form's widgets, with the GPS fill button placed
          // directly under the longitude field whenever this form
          // carries BOTH coordinate fields (provider tables).
          final hasLatLng = ctrls.containsKey('latitude') &&
              ctrls.containsKey('longitude');
          final formChildren = <Widget>[];
          for (final f in fields) {
            formChildren.add(fieldWidget(f));
            if (hasLatLng && f.key == 'longitude') {
              formChildren.add(Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: gpsBusy
                        ? null
                        : () async {
                            setD(() => gpsBusy = true);
                            final coords =
                                await fetchCurrentCoordinates();
                            if (!mounted) return;
                            setD(() => gpsBusy = false);
                            if (coords != null) {
                              ctrls['latitude']!.text =
                                  coords.$1.toStringAsFixed(6);
                              ctrls['longitude']!.text =
                                  coords.$2.toStringAsFixed(6);
                              // Rebuild so the filled values are
                              // what the admin sees before saving.
                              setD(() {});
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                      content:
                                          Text('Location set from GPS')));
                            } else {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                      content: Text(
                                          'Could not get GPS location. '
                                          'Check location permission.')));
                            }
                          },
                    icon: gpsBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    label: const Text(
                        'Use GPS (fill Latitude & Longitude)'),
                  ),
                ),
              ));
            }
          }

          final dialog = Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RFormHeaderBand(
                    title:
                        '${row == null ? 'Add' : 'Edit'} ${widget.singular}',
                    icon: Icons.edit_note_outlined,
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(20, 18, 20, 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: formChildren,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: RFormActions(
                      onCancel: () => Navigator.pop(context),
                      primaryLabel: 'Save',
                      onPrimary: () async {
                  void fail(String msg) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                  }

                  final values = <String, dynamic>{};
                  for (final f in fields) {
                    if (f.type == 'bool') {
                      values[f.key] = bools[f.key]!;
                      continue;
                    }
                    if (f.type == 'fk') {
                      if (f.required &&
                          (fkValues[f.key] == null ||
                              fkValues[f.key]!.isEmpty)) {
                        fail('${f.label} is required');
                        return;
                      }
                      values[f.key] = fkValues[f.key];
                      continue;
                    }
                    if (f.type == 'dropdown') {
                      if (f.required &&
                          (dropValues[f.key] == null ||
                              dropValues[f.key]!.isEmpty)) {
                        fail('${f.label} is required');
                        return;
                      }
                      values[f.key] = dropValues[f.key];
                      continue;
                    }
                    final text = ctrls[f.key]!.text.trim();
                    if (text.isEmpty) {
                      if (f.required) {
                        fail('${f.label} is required');
                        return;
                      }
                      // Blank on EDIT keeps the stored value —
                      // the key is simply not sent (audit Admin
                      // gap 14: a cleared field used to be saved
                      // back as 0 / '' over real data).
                      if (row == null) {
                        if (f.type == 'int' || f.type == 'double') {
                          if (f.defaultValue != null) {
                            values[f.key] = f.defaultValue;
                          }
                        } else if (f.type == 'date' ||
                            f.type == 'json' ||
                            f.type == 'array') {
                          // Full-check fix 2026-10-22: a blank
                          // date/JSON/array field sent as '' makes
                          // Postgres reject the whole insert (Add
                          // Doctor broke on working_hours, Add
                          // Medicine on a blank expiry). Skip the
                          // key — the column default/null applies.
                        } else {
                          values[f.key] = '';
                        }
                      }
                      continue;
                    }
                    if (f.type == 'int' || f.type == 'double') {
                      final n = f.type == 'int'
                          ? int.tryParse(text)
                          : double.tryParse(text);
                      if (n == null) {
                        fail('${f.label} must be a number');
                        return;
                      }
                      if ((f.min != null && n < f.min!) ||
                          (f.max != null && n > f.max!)) {
                        fail('${f.label} must be between '
                            '${f.min} and ${f.max}');
                        return;
                      }
                      values[f.key] = n;
                    } else if (f.type == 'array') {
                      values[f.key] = text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                    } else if (f.type == 'json') {
                      try {
                        values[f.key] = jsonDecode(text);
                      } catch (_) {
                        fail('${f.label} must be valid JSON');
                        return;
                      }
                    } else if (f.type == 'date') {
                      if (DateTime.tryParse(text) == null) {
                        fail('${f.label} must be a date (YYYY-MM-DD)');
                        return;
                      }
                      values[f.key] = text;
                    } else if (f.type == 'url') {
                      // Full-check fix 2026-10-22: 'url' fields
                      // fell through to plain text with no
                      // validation, so any string landed in
                      // photo/doc/media URL columns.
                      if (!text.startsWith('http://') &&
                          !text.startsWith('https://')) {
                        fail('${f.label} must be a full URL '
                            'starting with https://');
                        return;
                      }
                      values[f.key] = text;
                    } else {
                      values[f.key] = text;
                    }
                  }
                  if (widget.table == 'coupons' &&
                      values['code'] is String) {
                    // Store coupon codes in the canonical
                    // upper-case form that is shared with
                    // customers (bug fix 2026-10-23: a code saved
                    // in mixed case, e.g. "Save10", was reported
                    // "Coupon not found" at patient checkout,
                    // which queried a different casing than the
                    // one stored). Checkout lookup is also
                    // case-insensitive now, so existing mixed-case
                    // rows keep working; this just keeps new and
                    // edited rows canonical.
                    values['code'] =
                        (values['code'] as String).toUpperCase();
                  }
                  if (row != null) values['id'] = row['id'];
                  // Full-check fix 2026-10-22: the dialog used to
                  // pop BEFORE the save ran, so a failed save lost
                  // everything the admin typed. Save first; only
                  // close on success, and on failure keep the
                  // dialog (and the entered values) for a retry.
                  final ok =
                      await state.adminSaveRow(widget.table, values);
                  if (!mounted) return;
                  if (!ok) {
                    fail('Save failed. Your entries are kept — '
                        'please try again.');
                    return;
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('${widget.singular} saved.')),
                  );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
          // Existing-patient autofill (owner order, 2026-10-21):
          // when the typed Phone exactly matches a patient account,
          // ExistingUserLookup offers their saved details; Fill maps
          // name / phone / address / gender / DOB onto the fields
          // the form actually has (audit Admin gap 20: gender and
          // DOB used to be silently discarded).
          final phoneCtrl = ctrls['phone'];
          if (phoneCtrl == null) return dialog;
          return ExistingUserLookup(
            trigger: phoneCtrl,
            onFill: (record) {
              final nameCtrl = ctrls['name'];
              if (nameCtrl != null && record.fullName.isNotEmpty) {
                nameCtrl.text = record.fullName;
              }
              if (record.phone.isNotEmpty) {
                phoneCtrl.text = record.phone;
              }
              final locationCtrl = ctrls['location'];
              if (locationCtrl != null && record.address.isNotEmpty) {
                locationCtrl.text = record.address;
              }
              if (record.gender.isNotEmpty &&
                  dropValues.containsKey('gender')) {
                final g = record.gender.toLowerCase();
                final match = (fields
                        .firstWhere((f) => f.key == 'gender')
                        .options ??
                    const <String>[])
                    .where((o) => o.toLowerCase() == g);
                if (match.isNotEmpty) dropValues['gender'] = match.first;
              }
              final dobCtrl = ctrls['date_of_birth'];
              if (dobCtrl != null && record.dateOfBirth.isNotEmpty) {
                dobCtrl.text = record.dateOfBirth;
              }
              setD(() {});
            },
            child: dialog,
          );
        },
      ),
    );
    // The dialog's controllers are disposed once it closes
    // (they used to leak on every open — audit SUSPECTED,
    // verified in code).
    for (final c in ctrls.values) {
      c.dispose();
    }
  }

  String? _initialDrop(AdminField f, dynamic v) {
    final s = v?.toString();
    if (s != null && s.isNotEmpty) return s;
    if (f.defaultValue != null) return '${f.defaultValue}';
    return null;
  }

  String _initialText(AdminField f, dynamic v) {
    if (v != null) {
      // Array columns (text[]) arrive as Lists and JSONB columns
      // as Maps — render them in the editable text form the
      // dialog parses back on save.
      if (v is List) return v.join(', ');
      if (v is Map) return jsonEncode(v);
      return '$v';
    }
    if (f.defaultValue != null) return '${f.defaultValue}';
    return '';
  }

  bool _initialBool(AdminField f, dynamic v) {
    if (v is bool) return v;
    if (f.defaultValue is bool) return f.defaultValue as bool;
    // Full-check fix 2026-10-22: is_active/active columns default
    // TRUE in the database, but a new FAQ/coupon/slider/ad was
    // saved inactive because this fell through to false.
    if (f.key == 'is_active' || f.key == 'active') return true;
    return false;
  }
}

/// Field specs per catalog table.
/// Field specs per catalog table. Completed under the
/// form-pages audit (Admin gaps 3/11/12/13): every panel-relevant
/// column is present, enum columns are dropdowns, and numeric
/// columns carry their real ranges.
List<AdminField> adminTableFields(String table) {
  switch (table) {
    case 'doctors':
      return [
        const AdminField(key: 'name', label: 'Name', required: true),
        AdminField(
            key: 'specialization',
            label: 'Specialty',
            type: 'dropdown',
            options: specialties),
        const AdminField(
            key: 'hospital_id',
            label: 'Hospital',
            type: 'fk',
            fkTable: 'hospitals'),
        const AdminField(
            key: 'latitude', label: 'Latitude', type: 'double'),
        const AdminField(
            key: 'longitude', label: 'Longitude', type: 'double'),
        const AdminField(
            key: 'consultation_fee', label: 'Fee (₹)', type: 'double'),
        const AdminField(
            key: 'rating',
            label: 'Rating',
            type: 'double',
            min: 0,
            max: 5),
        const AdminField(
            key: 'experience_years',
            label: 'Experience (yrs)',
            type: 'int',
            min: 0,
            max: 70),
        const AdminField(key: 'phone', label: 'Phone'),
        const AdminField(
            key: 'gender',
            label: 'Gender',
            type: 'dropdown',
            options: ['male', 'female', 'other']),
        const AdminField(key: 'bio', label: 'About', type: 'textarea'),
        const AdminField(key: 'image_url', label: 'Photo URL', type: 'url'),
        const AdminField(
            key: 'working_hours',
            label: 'Working Hours (JSON)',
            type: 'json'),
        const AdminField(
            key: 'vacation_dates',
            label: 'Vacation Dates (YYYY-MM-DD, comma separated)',
            type: 'array'),
        const AdminField(
            key: 'license_url', label: 'License Doc URL', type: 'url'),
        const AdminField(
            key: 'gst_url', label: 'GST Doc URL', type: 'url'),
        const AdminField(
            key: 'additional_docs_urls',
            label: 'Other Doc URLs (comma separated)',
            type: 'array'),
        const AdminField(key: 'user_id', label: 'Linked User ID'),
        const AdminField(
            key: 'approval_status',
            label: 'Status',
            type: 'dropdown',
            options: ['pending', 'approved', 'rejected'],
            defaultValue: 'approved'),
        const AdminField(
            key: 'is_featured', label: 'Featured', type: 'bool'),
        const AdminField(key: 'upi_id', label: 'UPI ID'),
        const AdminField(
            key: 'upi_enabled',
            label: 'UPI Payments',
            type: 'bool',
            defaultValue: true),
        const AdminField(
            key: 'pay_in_clinic_enabled',
            label: 'Pay in Clinic',
            type: 'bool',
            defaultValue: true),
      ];
    case 'hospitals':
      return const [
        AdminField(key: 'name', label: 'Name', required: true),
        AdminField(key: 'location', label: 'Location'),
        AdminField(key: 'latitude', label: 'Latitude', type: 'double'),
        AdminField(key: 'longitude', label: 'Longitude', type: 'double'),
        AdminField(key: 'beds', label: 'Beds', type: 'int', min: 0),
        AdminField(
            key: 'total_icu_beds',
            label: 'ICU Beds',
            type: 'int',
            min: 0),
        AdminField(
            key: 'icu_available', label: 'ICU Available', type: 'bool'),
        AdminField(
            key: 'is_government', label: 'Government', type: 'bool'),
        AdminField(key: 'phone', label: 'Phone'),
        AdminField(key: 'emergency_contact', label: 'Emergency Contact'),
        AdminField(
            key: 'consultation_fee',
            label: 'Consultation Fee (₹)',
            type: 'double'),
        AdminField(key: 'rating', label: 'Rating', type: 'double', min: 0, max: 5),
        AdminField(key: 'image_url', label: 'Photo URL', type: 'url'),
        AdminField(
            key: 'working_hours', label: 'Working Hours (JSON)', type: 'json'),
        AdminField(
            key: 'holidays',
            label: 'Holidays (YYYY-MM-DD, comma separated)',
            type: 'array'),
        AdminField(key: 'license_url', label: 'License Doc URL', type: 'url'),
        AdminField(key: 'gst_url', label: 'GST Doc URL', type: 'url'),
        AdminField(
            key: 'additional_docs_urls',
            label: 'Other Doc URLs (comma separated)',
            type: 'array'),
        AdminField(key: 'user_id', label: 'Linked User ID'),
        AdminField(
            key: 'approval_status',
            label: 'Status',
            type: 'dropdown',
            options: ['pending', 'approved', 'rejected'],
            defaultValue: 'approved'),
        AdminField(key: 'is_featured', label: 'Featured', type: 'bool'),
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
        AdminField(key: 'latitude', label: 'Latitude', type: 'double'),
        AdminField(key: 'longitude', label: 'Longitude', type: 'double'),
        AdminField(key: 'phone', label: 'Phone'),
        AdminField(
            key: 'services',
            label: 'Services (comma separated)',
            type: 'array'),
        AdminField(key: 'rating', label: 'Rating', type: 'double', min: 0, max: 5),
        AdminField(key: 'image_url', label: 'Photo URL', type: 'url'),
        AdminField(
            key: 'working_hours', label: 'Working Hours (JSON)', type: 'json'),
        AdminField(key: 'license_url', label: 'License Doc URL', type: 'url'),
        AdminField(key: 'gst_url', label: 'GST Doc URL', type: 'url'),
        AdminField(
            key: 'additional_docs_urls',
            label: 'Other Doc URLs (comma separated)',
            type: 'array'),
        AdminField(key: 'user_id', label: 'Linked User ID'),
        AdminField(
            key: 'approval_status',
            label: 'Status',
            type: 'dropdown',
            options: ['pending', 'approved', 'rejected'],
            defaultValue: 'approved'),
        AdminField(key: 'is_featured', label: 'Featured', type: 'bool'),
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
        AdminField(
            key: 'category',
            label: 'Category',
            type: 'dropdown',
            options: [
              'General',
              'Blood',
              'Urine',
              'Imaging',
              'Cardiac',
              'Diabetes',
              'Thyroid',
              'Vitamins',
              'Infection',
              'Hormones',
            ]),
        AdminField(key: 'price', label: 'Price (₹)', type: 'double', min: 0),
        AdminField(
            key: 'discount_percent',
            label: 'Discount %',
            type: 'double',
            min: 0,
            max: 100),
        AdminField(
            key: 'sample_type',
            label: 'Sample Type',
            type: 'dropdown',
            options: ['Blood', 'Urine', 'Swab', 'Stool', 'Other']),
        AdminField(key: 'turnaround_time', label: 'Turnaround Time'),
        AdminField(key: 'is_popular', label: 'Popular', type: 'bool'),
        AdminField(
            key: 'requires_fasting', label: 'Requires Fasting', type: 'bool'),
        AdminField(
            key: 'home_collection',
            label: 'Home Collection',
            type: 'bool',
            defaultValue: true),
        AdminField(
            key: 'home_collection_fee',
            label: 'Home Collection Fee (₹)',
            type: 'double',
            min: 0),
        AdminField(key: 'description', label: 'Description', type: 'textarea'),
      ];
    case 'pharmacies':
      return const [
        AdminField(key: 'name', label: 'Name', required: true),
        AdminField(key: 'location', label: 'Location'),
        AdminField(key: 'latitude', label: 'Latitude', type: 'double'),
        AdminField(key: 'longitude', label: 'Longitude', type: 'double'),
        AdminField(key: 'phone', label: 'Phone'),
        AdminField(key: 'rating', label: 'Rating', type: 'double', min: 0, max: 5),
        AdminField(key: 'image_url', label: 'Photo URL', type: 'url'),
        AdminField(
            key: 'working_hours', label: 'Working Hours (JSON)', type: 'json'),
        AdminField(key: 'license_url', label: 'License Doc URL', type: 'url'),
        AdminField(key: 'gst_url', label: 'GST Doc URL', type: 'url'),
        AdminField(
            key: 'additional_docs_urls',
            label: 'Other Doc URLs (comma separated)',
            type: 'array'),
        AdminField(key: 'user_id', label: 'Linked User ID'),
        AdminField(
            key: 'approval_status',
            label: 'Status',
            type: 'dropdown',
            options: ['pending', 'approved', 'rejected'],
            defaultValue: 'approved'),
        AdminField(key: 'is_featured', label: 'Featured', type: 'bool'),
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
        AdminField(key: 'generic_name', label: 'Generic Name'),
        AdminField(key: 'category', label: 'Category'),
        AdminField(key: 'price', label: 'Price (₹)', type: 'double', min: 0),
        AdminField(
            key: 'discount_percent',
            label: 'Discount %',
            type: 'double',
            min: 0,
            max: 100),
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
            key: 'stock_quantity', label: 'Stock Qty', type: 'int', min: 0),
        AdminField(
            key: 'unit',
            label: 'Unit',
            type: 'dropdown',
            options: ['strip', 'bottle', 'tablet', 'syrup', 'tube', 'pack', 'piece']),
        AdminField(key: 'manufacturer', label: 'Manufacturer'),
        AdminField(key: 'batch_number', label: 'Batch Number'),
        AdminField(key: 'expiry_date', label: 'Expiry Date', type: 'date'),
        AdminField(key: 'description', label: 'Description', type: 'textarea'),
        AdminField(key: 'image_url', label: 'Photo URL', type: 'url'),
      ];
    // Audit-76 Batch 9 (Admin gap 1 / M15): whole backend tables
    // that had NO admin UI at all — they could only be managed by
    // writing SQL. Each now gets a full CRUD spec.
    case 'coupons':
      return const [
        AdminField(key: 'code', label: 'Code', required: true),
        AdminField(
            key: 'description', label: 'Description', type: 'textarea'),
        AdminField(
            key: 'discount_type',
            label: 'Discount Type',
            type: 'dropdown',
            options: ['percentage', 'flat'],
            defaultValue: 'percentage'),
        AdminField(
            key: 'discount_value',
            label: 'Discount Value',
            type: 'double',
            required: true,
            min: 0),
        AdminField(
            key: 'min_order_amount',
            label: 'Min Order Amount (₹)',
            type: 'double',
            min: 0),
        AdminField(
            key: 'max_discount_amount',
            label: 'Max Discount (₹)',
            type: 'double',
            min: 0),
        AdminField(
            key: 'usage_limit', label: 'Usage Limit', type: 'int', min: 0),
        AdminField(
            key: 'applicable_for',
            label: 'Applies To',
            type: 'dropdown',
            options: ['all', 'pharmacy', 'lab', 'doctor', 'hospital'],
            defaultValue: 'all'),
        AdminField(key: 'valid_from', label: 'Valid From', type: 'date'),
        AdminField(key: 'valid_until', label: 'Valid Until', type: 'date'),
        AdminField(key: 'is_active', label: 'Active', type: 'bool'),
      ];
    case 'delivery_drivers':
      // Sidebar rearrange 2026-10-23: the Drivers item is new —
      // delivery_drivers had no admin screen, so a driver profile
      // (required before a driver can receive deliveries) could
      // never be created or fixed from the panel.
      return const [
        AdminField(key: 'name', label: 'Name', required: true),
        AdminField(key: 'phone', label: 'Phone'),
        AdminField(
            key: 'vehicle_type',
            label: 'Vehicle Type',
            type: 'dropdown',
            options: ['bike', 'scooter', 'car', 'van', 'bicycle'],
            defaultValue: 'bike'),
        AdminField(key: 'vehicle_number', label: 'Vehicle Number'),
        AdminField(
            key: 'status',
            label: 'Status',
            type: 'dropdown',
            options: ['available', 'offline'],
            defaultValue: 'available'),
        AdminField(key: 'user_id', label: 'Linked User ID'),
        AdminField(key: 'is_active', label: 'Active', type: 'bool'),
      ];
    case 'faqs':
      return const [
        AdminField(
            key: 'question', label: 'Question', required: true, type: 'textarea'),
        AdminField(
            key: 'answer', label: 'Answer', required: true, type: 'textarea'),
        AdminField(
            key: 'category', label: 'Category', defaultValue: 'general'),
        AdminField(key: 'sort_order', label: 'Sort Order', type: 'int'),
        AdminField(key: 'is_active', label: 'Active', type: 'bool'),
      ];
    case 'legal_pages':
      return const [
        AdminField(key: 'slug', label: 'Slug', required: true),
        AdminField(key: 'title', label: 'Title', required: true),
        AdminField(
            key: 'content', label: 'Content', type: 'textarea'),
      ];
    case 'slider_media':
      return const [
        AdminField(
            key: 'type',
            label: 'Type',
            type: 'dropdown',
            options: ['image', 'video'],
            defaultValue: 'image'),
        AdminField(key: 'url', label: 'Media URL', required: true, type: 'url'),
        AdminField(key: 'target_link', label: 'Target Link', type: 'url'),
        AdminField(key: 'title', label: 'Title'),
        AdminField(
            key: 'description', label: 'Description', type: 'textarea'),
        AdminField(key: 'sort_order', label: 'Sort Order', type: 'int'),
        AdminField(key: 'active', label: 'Active', type: 'bool'),
      ];
    case 'ads':
      return const [
        AdminField(
            key: 'type',
            label: 'Type',
            type: 'dropdown',
            options: ['banner', 'interstitial'],
            defaultValue: 'banner'),
        AdminField(
            key: 'content_url', label: 'Content URL', required: true, type: 'url'),
        AdminField(key: 'target_link', label: 'Target Link', type: 'url'),
        AdminField(key: 'placement', label: 'Placement'),
        AdminField(key: 'title', label: 'Title'),
        AdminField(key: 'active', label: 'Active', type: 'bool'),
      ];
    case 'platform_settings':
      return const [
        AdminField(key: 'key', label: 'Key', required: true),
        AdminField(key: 'value', label: 'Value', type: 'textarea'),
        AdminField(key: 'label', label: 'Label', required: true),
        AdminField(
            key: 'category', label: 'Category', defaultValue: 'general'),
        AdminField(
            key: 'type',
            label: 'Value Type',
            type: 'dropdown',
            options: ['text', 'number', 'boolean', 'json'],
            defaultValue: 'text'),
      ];
    default:
      return const [
        AdminField(key: 'name', label: 'Name', required: true),
      ];
  }
}

/// Display title for a row.
String adminTableTitle(String table, Map<String, dynamic> r) {
  final name =
      '${r['name'] ?? r['code'] ?? r['question'] ?? r['title'] ?? r['label'] ?? r['slug'] ?? r['key'] ?? r['url'] ?? r['content_url'] ?? r['id'] ?? 'Item'}';
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
    case 'coupons':
      return '${r['discount_type'] ?? 'percentage'} ${r['discount_value'] ?? 0}'
          '${r['is_active'] == true ? '' : ' · inactive'}';
    case 'delivery_drivers':
      return '${r['vehicle_type'] ?? 'bike'}'
          '${r['vehicle_number'] != null ? ' · ${r['vehicle_number']}' : ''}'
          ' · ${r['status'] ?? ''}'
          '${r['is_active'] == true ? '' : ' · inactive'}';
    case 'faqs':
      return '${r['category'] ?? 'general'}'
          '${r['is_active'] == true ? '' : ' · inactive'}';
    case 'legal_pages':
      return '${r['slug'] ?? ''}';
    case 'slider_media':
    case 'ads':
      return '${r['type'] ?? ''}'
          '${r['active'] == true ? '' : ' · inactive'}';
    case 'platform_settings':
      return '${r['category'] ?? 'general'} · ${r['value'] ?? ''}';
    default:
      return '${r['location'] ?? ''}';
  }
}

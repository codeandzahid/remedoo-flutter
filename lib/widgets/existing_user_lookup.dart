import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'widgets.dart';

/// A patient's saved details as returned by the `lookup_user_for_form`
/// RPC (supabase/migration/lookup_user_for_form.sql) for the
/// admin/panel form autofill feature (owner order, 2026-10-21).
///
/// The RPC only ever returns PATIENT accounts — the owner scoped the
/// feature to patient data, never panelist/provider data — and only
/// to admin/staff/provider callers. Every field may be empty when
/// the profile on file is incomplete.
class FormUserRecord {
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String gender;

  /// Raw date from the profile ('yyyy-mm-dd'), '' when unknown.
  final String dateOfBirth;

  const FormUserRecord({
    required this.userId,
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.gender = '',
    this.dateOfBirth = '',
  });

  factory FormUserRecord.fromRow(Map<String, dynamic> row) {
    return FormUserRecord(
      userId: '${row['user_id'] ?? ''}',
      fullName: '${row['full_name'] ?? ''}'.trim(),
      email: '${row['email'] ?? ''}'.trim(),
      phone: '${row['phone'] ?? ''}'.trim(),
      address: '${row['address'] ?? ''}'.trim(),
      gender: '${row['gender'] ?? ''}'.trim(),
      dateOfBirth: '${row['date_of_birth'] ?? ''}'.trim(),
    );
  }

  /// Date of birth formatted d/m/yyyy for display, '' when unknown
  /// or unparseable.
  String get dateOfBirthLabel {
    final d = DateTime.tryParse(dateOfBirth);
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }
}

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// True when [value] is a complete email address (not a prefix of
/// one), so the lookup fires once per finished address instead of
/// on every keystroke.
bool isCompleteEmailValue(String value) =>
    _emailPattern.hasMatch(value.trim());

/// The 10-digit mobile number inside [value], or null when the
/// value does not hold a complete mobile. A leading +91 country
/// code or 0 trunk prefix is accepted and stripped, mirroring the
/// normalisation inside the lookup RPC.
String? completeMobileDigits(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return digits.length == 10 ? digits : null;
}

/// True when [value] is worth a lookup: a complete email or a
/// complete mobile number. Partial values never trigger a lookup.
bool isLookupReadyValue(String value) =>
    isCompleteEmailValue(value) || completeMobileDigits(value) != null;

/// Watches an email/mobile [trigger] field in an admin or panelist
/// form. When the typed value is complete and exactly matches an
/// existing PATIENT account (via [AppState.lookupUserForForm], which
/// calls the role-gated, patient-only `lookup_user_for_form` RPC), a
/// popup shows the details already on file:
///
///   Existing user found — [Fill] [Cancel]
///
/// Fill closes the popup and calls [onFill] so the form populates
/// its fields from the record. Cancel closes it and changes nothing;
/// the popup does not re-appear for that same unchanged value — it
/// re-arms only when the typed value changes. No popup appears for
/// partial values, unknown values, or provider/admin accounts (the
/// RPC returns nothing for those).
///
/// The check is debounced ([debounce]) so it fires on a completed
/// value, not per keystroke, and at most one popup is open at a
/// time. If the RPC is unavailable (migration not applied yet), the
/// lookup fails soft and the form behaves exactly as before.
class ExistingUserLookup extends StatefulWidget {
  /// The email or mobile field to watch.
  final TextEditingController trigger;

  /// Called with the found record when the user taps Fill.
  final void Function(FormUserRecord record) onFill;

  final Widget child;

  /// Quiet period after the last keystroke before the lookup runs.
  final Duration debounce;

  const ExistingUserLookup({
    super.key,
    required this.trigger,
    required this.onFill,
    required this.child,
    this.debounce = const Duration(milliseconds: 600),
  });

  @override
  State<ExistingUserLookup> createState() => _ExistingUserLookupState();
}

class _ExistingUserLookupState extends State<ExistingUserLookup> {
  Timer? _timer;
  bool _checking = false;
  bool _dialogOpen = false;

  /// The value the popup was last shown (and dismissed) for. The
  /// popup never re-appears for this exact value again.
  String? _handledValue;

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant ExistingUserLookup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      oldWidget.trigger.removeListener(_onChanged);
      widget.trigger.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.trigger.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    _timer?.cancel();
    final value = widget.trigger.text.trim();
    if (value == _handledValue) return;
    if (!isLookupReadyValue(value)) return;
    _timer = Timer(widget.debounce, () => _check(value));
  }

  Future<void> _check(String value) async {
    if (!mounted || _checking || _dialogOpen) return;
    if (widget.trigger.text.trim() != value) return;
    _checking = true;
    FormUserRecord? record;
    try {
      record = await AppStateScope.of(context).lookupUserForForm(value);
    } finally {
      _checking = false;
    }
    if (!mounted || record == null) return;
    // The field moved on (or a popup is already up) while the
    // lookup was in flight — stay silent.
    if (widget.trigger.text.trim() != value || _dialogOpen) return;
    _dialogOpen = true;
    final fill = await showDialog<bool>(
      context: context,
      builder: (_) => _ExistingUserDialog(record: record!),
    );
    _dialogOpen = false;
    // Whether the user filled or cancelled, this value is handled:
    // the popup must not re-appear until the value changes.
    _handledValue = value;
    if (fill == true && mounted) widget.onFill(record);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The "Existing user found" popup: the patient's saved details
/// with Fill / Cancel, in the admin panel's dialog style.
class _ExistingUserDialog extends StatelessWidget {
  final FormUserRecord record;

  const _ExistingUserDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (record.fullName.isNotEmpty) ('Name', record.fullName),
      if (record.email.isNotEmpty) ('Email', record.email),
      if (record.phone.isNotEmpty) ('Mobile', record.phone),
      if (record.address.isNotEmpty) ('Address', record.address),
      if (record.gender.isNotEmpty) ('Gender', record.gender),
      if (record.dateOfBirthLabel.isNotEmpty)
        ('Date of birth', record.dateOfBirthLabel),
    ];
    return AlertDialog(
      title: const Text('Existing user found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'A patient with this email or mobile number already '
                'exists in Remedoo. Fill the form with their saved '
                'details?'),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Text(value)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        RButton(
          label: 'Fill',
          small: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

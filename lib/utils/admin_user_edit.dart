// Pure helpers for Admin > Users editing (owner order 2026-10-22):
// which edits are sensitive enough to need the admin's email OTP,
// and the small validations the dialog runs before saving.

/// Email and password changes are sensitive: they change how the
/// account signs in, so the admin must pass an email OTP first.
/// Normal detail edits (name, phone, address...) need no OTP.
bool editNeedsOtp({
  required String oldEmail,
  required String newEmail,
  required String newPassword,
}) {
  if (newPassword.trim().isNotEmpty) return true;
  return newEmail.trim().toLowerCase() != oldEmail.trim().toLowerCase();
}

/// Returns a problem message for the edit form, or null when valid.
/// [newPassword] may be empty (keep the current password).
String? validateAdminUserEdit({
  required String email,
  required String newPassword,
  String dateOfBirth = '',
}) {
  final e = email.trim();
  if (e.isEmpty || !e.contains('@') || !e.contains('.')) {
    return 'Please enter a valid email address.';
  }
  final p = newPassword.trim();
  if (p.isNotEmpty && p.length < 8) {
    return 'New password must be at least 8 characters.';
  }
  // Full-check fix 2026-10-22: the date of birth went to the DB
  // unvalidated, so one typo failed the whole profile update with
  // only a generic "Update failed."
  final d = dateOfBirth.trim();
  if (d.isNotEmpty && DateTime.tryParse(d) == null) {
    return 'Date of birth must be a valid date (YYYY-MM-DD).';
  }
  return null;
}

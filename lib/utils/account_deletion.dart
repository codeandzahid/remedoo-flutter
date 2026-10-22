// Pure helpers for the 72-hour account-deletion window
// (owner order 2026-10-22). The server stores the request moment on
// profiles.deletion_requested_at; everything else derives from it.

/// How long a deletion request can still be undone by admin/support.
const Duration accountDeletionWindow = Duration(hours: 72);

/// The moment the account's data is erased forever.
DateTime deletionEraseTime(DateTime requestedAt) =>
    requestedAt.add(accountDeletionWindow);

/// True once the 72 hours have passed (the purge may erase the account).
bool deletionWindowExpired(DateTime requestedAt, DateTime now) =>
    !now.isBefore(deletionEraseTime(requestedAt));

/// Whole hours left before erasure, never negative.
int deletionHoursLeft(DateTime requestedAt, DateTime now) {
  final diff = deletionEraseTime(requestedAt).difference(now);
  if (diff.isNegative) return 0;
  return diff.inHours + (diff.inMinutes % 60 > 0 ? 1 : 0);
}

/// Parses a profiles.deletion_requested_at value (ISO string or
/// DateTime) into a DateTime, or null when absent/unparseable.
DateTime? parseDeletionRequest(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse('$value');
}

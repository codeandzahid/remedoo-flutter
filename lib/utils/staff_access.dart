/// Staff access levels (owner order 2026-10-23): the super admin
/// no longer just ticks a section on or off for a team member —
/// every option gets a level: no access, view only, or full
/// access.
///
/// Storage stays the existing `staff_permissions.sections` jsonb
/// array so the live RLS helper `staff_has_section()` keeps
/// working unchanged:
/// - full access to `coupons`  -> the entry `'coupons'`
/// - view only for `coupons`   -> the entries `'coupons'` AND
///   `'view:coupons'` (the base entry keeps the data readable;
///   the marker tells the app to hide every change action).
///
/// Server-side write enforcement for view-only staff arrives
/// with the staff_view_only_enforcement migration (dashboard
/// sitting): its `staff_can_write()` mirrors [staffLevelsDecode].
library;

/// Prefix marking a section as view-only inside the sections list.
const String kStaffViewPrefix = 'view:';

/// Encodes an option-key -> level map ('view' | 'full') into the
/// stored sections list. Options missing from the map (or set to
/// anything else) get no access and no entry.
List<String> staffSectionsEncode(Map<String, String> levels) {
  final out = <String>[];
  for (final e in levels.entries) {
    if (e.value == 'full') {
      out.add(e.key);
    } else if (e.value == 'view') {
      out.add(e.key);
      out.add('$kStaffViewPrefix${e.key}');
    }
  }
  return out;
}

/// Decodes a stored sections list into an option-key -> level
/// map ('view' | 'full'). A view marker without its base entry
/// still means view-only; unknown entries are ignored.
Map<String, String> staffLevelsDecode(List<String> sections) {
  final out = <String, String>{};
  for (final s in sections) {
    if (s.startsWith(kStaffViewPrefix)) {
      out[s.substring(kStaffViewPrefix.length)] = 'view';
    }
  }
  for (final s in sections) {
    if (!s.startsWith(kStaffViewPrefix)) {
      out.putIfAbsent(s, () => 'full');
    }
  }
  return out;
}

/// The option keys whose level in [sections] is view-only.
Set<String> staffViewOnlyKeys(List<String> sections) => staffLevelsDecode(
      sections,
    ).entries.where((e) => e.value == 'view').map((e) => e.key).toSet();

/// The option keys with any access (view or full) in [sections].
Set<String> staffAccessibleKeys(List<String> sections) =>
    staffLevelsDecode(sections).keys.toSet();

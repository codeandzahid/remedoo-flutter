/// Provider teams (owner order 2026-10-24): every panelist can
/// create a team; hospitals, labs and pharmacies can also add
/// drivers. A team member signs in with the same role as the
/// provider and opens the same panel, gated by this per-tab
/// access map: 'full' | 'view' | 'none'. The owner always has
/// full access; the Team tab itself is owner-only.

/// (tab key, label) offered by each provider panel, in tab order.
/// Must match the provider-team Edge Function's PANEL_TABS.
const Map<String, List<(String, String)>> kProviderPanelTabs = {
  'doctor': [
    ('visits', 'Visits'),
    ('profile', 'Profile'),
    ('payments', 'Payments'),
    ('reviews', 'Reviews'),
  ],
  'hospital': [
    ('appointments', 'Appointments'),
    ('profile', 'Profile'),
    ('payments', 'Payments'),
    ('reviews', 'Reviews'),
    ('drivers', 'Drivers'),
  ],
  'lab': [
    ('bookings', 'Bookings'),
    ('my_tests', 'My Tests'),
    ('profile', 'Profile'),
    ('payments', 'Payments'),
    ('reviews', 'Reviews'),
    ('drivers', 'Drivers'),
  ],
  'pharmacy': [
    ('orders', 'Orders'),
    ('medicines', 'Medicines'),
    ('profile', 'Profile'),
    ('payments', 'Payments'),
    ('reviews', 'Reviews'),
    ('drivers', 'Drivers'),
  ],
};

/// Provider table name for a provider type.
String providerTableFor(String providerType) {
  switch (providerType) {
    case 'doctor':
      return 'doctors';
    case 'hospital':
      return 'hospitals';
    case 'lab':
      return 'labs';
    case 'pharmacy':
      return 'pharmacies';
    default:
      return providerType;
  }
}

/// Provider type for a provider table name.
String providerTypeForTable(String table) {
  switch (table) {
    case 'doctors':
      return 'doctor';
    case 'hospitals':
      return 'hospital';
    case 'labs':
      return 'lab';
    case 'pharmacies':
      return 'pharmacy';
    default:
      return table;
  }
}

/// Decode a stored access map (jsonb) into tab -> level, failing
/// closed: unknown tabs are dropped, missing tabs are 'none'.
Map<String, String> decodeTeamAccess(
    String providerType, Map<String, dynamic>? raw) {
  final tabs = kProviderPanelTabs[providerType] ?? const [];
  final out = <String, String>{};
  for (final (key, _) in tabs) {
    final level = raw?[key];
    out[key] = (level == 'full' || level == 'view') ? level as String : 'none';
  }
  return out;
}

/// Full access on every tab (the provider owner).
Map<String, String> fullTeamAccess(String providerType) {
  final tabs = kProviderPanelTabs[providerType] ?? const [];
  return {for (final (key, _) in tabs) key: 'full'};
}

/// Level for one tab ('full' | 'view' | 'none').
String teamAccessLevel(Map<String, String> access, String tab) {
  return access[tab] ?? 'none';
}

const List<String> kTeamAccessLevels = ['full', 'view', 'none'];

String teamAccessLabel(String level) {
  switch (level) {
    case 'full':
      return 'Full access';
    case 'view':
      return 'View only';
    default:
      return 'No access';
  }
}

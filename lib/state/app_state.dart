import 'dart:async';

import 'package:flutter/material.dart';
import '../app_navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../data/mock_data.dart';
import '../services/auth_service.dart';
import '../services/supabase_repository.dart';
import '../theme.dart';

/// Inherited access to the single AppState for the whole app.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in widget tree');
    return scope!.notifier!;
  }
}

/// In-memory app state. Swap the mutation bodies for Supabase calls later.
class AppState extends ChangeNotifier {
  AppState() {
    _seed();
  }

  // ---------- Auth ----------
  //
  // Two session kinds:
  //  - Supabase session (_supaUser != null): real account, persisted +
  //    auto-refreshed by supabase_flutter in secure web storage.
  //  - Guest session (_guest): local only, no credentials.
  // Admin login stays fully mock (see AdminLoginScreen) and uses login().

  bool _guest = false;
  bool _mockLoggedIn = false; // mock login() (admin console + tests)
  bool _seenOnboarding = false;
  String _name = 'Patient';
  String _email = '';
  String _phone = '';
  String _gender = 'Male';
  String _address = 'Bakura, Srinagar, J&K 190006';

  User? _supaUser;
  bool _authAttached = false;

  /// Called by RootGate after Supabase init. Restores any persisted session
  /// and subscribes to auth changes (sign-out, expiry, recovery links).
  void attachAuthListener() {
    if (_authAttached) return;
    _authAttached = true;
    // Offline / init failed (e.g. widget tests): stay in mock/guest mode.
    if (!AuthService.instance.isInitialized) return;
    _syncUserFromSession();
    // Production catalog for everyone (guests browse it too); user data
    // loads inside _syncUserFromSession when a session exists.
    unawaited(loadProductionCatalog());
    // Admin-controlled theme availability (also for guests).
    unawaited(loadThemeAvailability());
    // AppState lives for the whole app lifetime, so the subscription is
    // intentionally never cancelled.
    AuthService.instance.authStateChanges.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        _supaUser = null;
        _resetProductionFlags();
        _stopThemeWatch();
        _clearAuthLocal(notify: false);
        notifyListeners();
      } else if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated ||
          event == AuthChangeEvent.initialSession) {
        final user = data.session?.user;
        if (user != null) {
          _supaUser = user;
          _guest = false;
          _mockLoggedIn = false;
          notifyListeners();
          unawaited(loadUserProductionData());
        }
      } else if (event == AuthChangeEvent.passwordRecovery) {
        _supaUser = data.session?.user;
        _guest = false;
        _mockLoggedIn = false;
        notifyListeners();
        unawaited(loadUserProductionData());
        final cb = onPasswordRecovery;
        if (cb != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => cb());
        }
      }
    });
  }

  /// Fired when a password-recovery link is opened (RootGate navigates to
  /// the new-password screen). Set by RootGate; null everywhere else.
  void Function()? onPasswordRecovery;

  void _syncUserFromSession() {
    final session = AuthService.instance.currentSession;
    if (session?.user != null) {
      _supaUser = session!.user;
      _guest = false;
      _mockLoggedIn = false;
      notifyListeners();
      unawaited(loadUserProductionData());
    }
  }

  /// True when a Supabase session, a mock login, OR a guest session is active.
  bool get isLoggedIn => _supaUser != null || _guest || _mockLoggedIn;
  bool get isGuest => _guest && _supaUser == null && !_mockLoggedIn;
  /// True only for a real signed-in account (Supabase user or mock login).
  /// Guests — and the logged-out state right after a guest is redirected —
  /// return false, so login gates stay closed even if a pushed page lingers.
  bool get isSignedIn => _supaUser != null || _mockLoggedIn;
  bool get seenOnboarding => _seenOnboarding;

  /// Display name: Supabase user metadata -> email fallback -> mock name.
  String get userName => _supaUser != null
      ? AuthService.instance.displayNameOf(_supaUser!)
      : _name;

  /// Email: Supabase user email first, then the mock value.
  String get email =>
      _supaUser?.email ?? _email;

  String get phone => _phone;
  String get gender => _gender;
  String get address => _address;

  void markOnboardingSeen() {
    _seenOnboarding = true;
    unawaited(_persistSeenOnboarding());
    notifyListeners();
  }

  static const _kSeenOnboardingKey = 'remedoo_seen_onboarding';

  /// Loads persisted flags. Called once at boot (see RootGate) before the
  /// first frame that depends on them, so onboarding shows only once ever.
  /// Never blocks boot for long: storage is local and fast, and the timeout
  /// guards against a hung platform channel (e.g. in widget tests).
  Future<void> loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      final seen = prefs.getBool(_kSeenOnboardingKey);
      if (seen != null) {
        _seenOnboarding = seen;
      }
      final themeId = prefs.getString(_kThemePackKey);
      if (themeId != null) {
        final pack = ThemePack.byId(themeId);
        if (pack != null) {
          _themePack = pack;
          RemedooTheme.setPack(pack);
        }
      }
    } catch (_) {
      // Storage unavailable (e.g. private browsing): keep in-memory default.
    }
  }

  Future<void> _persistSeenOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await prefs.setBool(_kSeenOnboardingKey, true);
    } catch (_) {
      // Best-effort only; in-memory flag still applies for this session.
    }
  }

  static const _kThemePackKey = 'remedoo_theme_pack';

  ThemePack _themePack = ThemePack.skyPulse;

  /// Admin-controlled availability: pack id -> enabled. Fetched from
  /// Supabase at boot; defaults to all-enabled when offline.
  final Map<String, bool> _packEnabled = {
    for (final p in ThemePack.all) p.id: true,
  };

  StreamSubscription<String?>? _themeSub;

  /// The active UI theme pack. Sky Pulse is the primary (default) theme.
  ThemePack get themePack => _themePack;

  /// Themes the user may pick from (admin-enabled only). Falls back to all
  /// built-in packs when the availability fetch hasn't completed.
  List<ThemePack> get availablePacks {
    final enabled =
        ThemePack.all.where((p) => _packEnabled[p.id] != false).toList();
    return enabled.isEmpty ? ThemePack.all : enabled;
  }

  /// Fetches admin-controlled theme availability. Called at boot for
  /// everyone (guests included). If the current pack got disabled, falls
  /// back to the primary theme.
  Future<void> loadThemeAvailability() async {
    try {
      final rows = await _repo.fetchThemePacks();
      if (rows.isEmpty) return;
      for (final r in rows) {
        final id = '${r['id']}';
        _packEnabled[id] = r['enabled'] == true;
      }
      // Primary theme can never be off.
      _packEnabled['sky_pulse'] = true;
      if (_packEnabled[_themePack.id] == false) {
        unawaited(_applyPack(ThemePack.skyPulse, persist: true));
      }
      notifyListeners();
    } catch (_) {
      // Offline: keep all packs available.
    }
  }

  /// Applies a pack locally + persists to device storage.
  Future<void> _applyPack(ThemePack pack, {bool persist = true}) async {
    _themePack = pack;
    RemedooTheme.setPack(pack);
    notifyListeners();
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await prefs.setString(_kThemePackKey, pack.id);
    } catch (_) {
      // Best-effort persistence only.
    }
  }

  /// Switches the app theme. Persists on-device and, when signed in, to
  /// Supabase so the website and the app stay in sync.
  Future<void> setThemePack(ThemePack pack) async {
    if (pack.id == _themePack.id) return;
    await _applyPack(pack);
    if (_supaUser != null) {
      unawaited(_repo.saveUserTheme(pack.id));
    }
  }

  /// Loads the signed-in user's theme from Supabase and starts the realtime
  /// subscription: a theme change on the website applies live in the app
  /// (and vice versa).
  Future<void> syncUserTheme() async {
    if (_supaUser == null) return;
    try {
      final profile = await _repo.fetchProfile();
      final id = profile?['theme_pack'] as String?;
      final pack = id == null ? null : ThemePack.byId(id);
      if (pack != null &&
          pack.id != _themePack.id &&
          _packEnabled[pack.id] != false) {
        await _applyPack(pack);
      }
    } catch (_) {}
    _startThemeWatch();
  }

  void _startThemeWatch() {
    _themeSub?.cancel();
    _themeSub = _repo.watchUserTheme().listen((id) async {
      if (id == null) return;
      final pack = ThemePack.byId(id);
      if (pack == null ||
          pack.id == _themePack.id ||
          _packEnabled[pack.id] == false) {
        return;
      }
      await _applyPack(pack);
    });
  }

  /// Stops the realtime theme subscription (on sign-out).
  void _stopThemeWatch() {
    _themeSub?.cancel();
    _themeSub = null;
  }

  /// Admin: enable/disable a theme pack project-wide. The primary theme
  /// (Sky Pulse) cannot be disabled.
  Future<bool> setThemePackEnabled(String id, bool enabled) async {
    if (id == 'sky_pulse' && !enabled) return false;
    final ok = await _repo.setThemePackEnabled(id, enabled);
    if (ok) {
      _packEnabled[id] = enabled;
      if (!enabled && _themePack.id == id) {
        unawaited(_applyPack(ThemePack.skyPulse, persist: true));
      }
      notifyListeners();
    }
    return ok;
  }

  void loginAsGuest() {
    _supaUser = null;
    _mockLoggedIn = false;
    _guest = true;
    _name = 'Patient';
    // Guests have no account: drop the seeded demo notifications (e.g. the
    // fake "Order Update") so a guest never sees order/booking alerts.
    notifications.clear();
    notifyListeners();
  }

  /// Mock login (admin console + tests). Real user auth uses the async
  /// methods below; do NOT route real users through this.
  void login({required String name, required String email}) {
    _supaUser = null;
    _guest = false;
    _mockLoggedIn = true;
    _name = name.isEmpty ? 'Patient' : name;
    _email = email;
    notifyListeners();
  }

  /// Real email+password sign-in via Supabase. On success the auth listener
  /// flips isLoggedIn and RootGate routes into the app.
  Future<AuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final result = await AuthService.instance.signIn(
      email: email,
      password: password,
    );
    if (result.ok) _syncUserFromSession();
    return result;
  }

  /// Real sign-up via Supabase. Returns needsConfirmation when the project
  /// requires email confirmation (user must click the email link).
  Future<AuthResult> signUpWithPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await AuthService.instance.signUp(
      email: email,
      password: password,
      name: name,
    );
    if (result.ok && !result.confirmationRequired) {
      _syncUserFromSession();
    }
    return result;
  }

  Future<AuthResult> resendConfirmationEmail(String email) {
    return AuthService.instance.resendConfirmation(email);
  }

  Future<AuthResult> sendMagicLink(String email) {
    return AuthService.instance.sendMagicLink(email);
  }

  Future<AuthResult> sendPasswordReset(String email) {
    return AuthService.instance.sendPasswordReset(email);
  }

  /// Sets a new password after a recovery link (requires the recovery
  /// session created when the link was opened).
  Future<AuthResult> updatePassword(String newPassword) {
    return AuthService.instance.updatePassword(newPassword);
  }

  void _clearAuthLocal({bool notify = true}) {
    _guest = false;
    _mockLoggedIn = false;
    _name = 'Patient';
    _email = '';
    appointments.clear();
    orders.clear();
    cart.clear();
    cartPharmacyId = null;
    cartPharmacyName = null;
    testCart.clear();
    if (notify) notifyListeners();
  }

  /// Signs out of Supabase (best-effort, never blocks the UI) and clears
  /// all local session state including guest mode. The Supabase sign-out is
  /// fire-and-forget: signOut() catches all its own errors, and the local
  /// session is cleared synchronously below so logout is always instant.
  void logout() {
    unawaited(AuthService.instance.signOut());
    _supaUser = null;
    _clearAuthLocal();
    // Pop any pushed pages: after logout the RootGate shows LoginScreen,
    // and inner screens must not linger on top with the gates down.
    appNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  // ---------- Production data (Supabase) ----------
  //
  // The catalog (doctors, hospitals, labs, pharmacies, medicines, lab tests)
  // loads from the live Supabase tables at boot, replacing the bundled demo
  // data. User data (appointments, orders, favorites, family, profile) loads
  // when a real Supabase session is present, and every mutation below writes
  // through to Supabase (fire-and-forget; local state updates instantly so
  // the UI never waits on the network). Demo data stays as the offline
  // fallback when Supabase is unreachable.

  final SupabaseRepository _repo = SupabaseRepository.instance;

  /// Local model id -> Supabase row id, for rows created this session
  /// (Supabase generates its own UUIDs on insert).
  final Map<String, String> _remoteAppointmentIds = {};
  final Map<String, String> _remoteOrderIds = {};
  final Map<String, String> _remoteFamilyIds = {};

  bool _catalogLoaded = false;
  bool _userDataLoaded = false;

  /// One-time catalog load at boot (guests browse it too).
  Future<void> loadProductionCatalog() async {
    if (_catalogLoaded) return;
    _catalogLoaded = true;
    final results = await Future.wait([
      _repo.fetchDoctors(),
      _repo.fetchHospitals(),
      _repo.fetchLabs(),
      _repo.fetchPharmacies(),
      _repo.fetchMedicines(),
      _repo.fetchLabTests(),
    ]);
    final ds = results[0] as List<Doctor>;
    final hs = results[1] as List<Hospital>;
    final ls = results[2] as List<Lab>;
    final ps = results[3] as List<Pharmacy>;
    final ms = results[4] as List<Medicine>;
    final ts = results[5] as List<LabTest>;
    var changed = false;
    if (ds.isNotEmpty) {
      doctors
        ..clear()
        ..addAll(ds);
      changed = true;
    }
    if (hs.isNotEmpty) {
      hospitals
        ..clear()
        ..addAll(hs);
      changed = true;
    }
    if (ls.isNotEmpty) {
      labs
        ..clear()
        ..addAll(ls);
      changed = true;
    }
    if (ps.isNotEmpty) {
      pharmacies
        ..clear()
        ..addAll(ps);
      changed = true;
    }
    if (ms.isNotEmpty) {
      medicines
        ..clear()
        ..addAll(ms);
      changed = true;
    }
    if (ts.isNotEmpty) {
      labTests
        ..clear()
        ..addAll(ts);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Loads the signed-in user's data from Supabase. Called whenever a real
  /// session is established (sign-in, session restore, recovery).
  Future<void> loadUserProductionData() async {
    if (_supaUser == null || _userDataLoaded) return;
    _userDataLoaded = true;
    // Cross-device theme sync (website <-> app).
    unawaited(syncUserTheme());
    final arows = await _repo.fetchAppointments();
    if (arows.isNotEmpty) {
      appointments
        ..clear()
        ..addAll(arows.map(_apptFromRow));
      appointments.sort((a, b) => b.date.compareTo(a.date));
    }
    final orows = await _repo.fetchOrders();
    if (orows.isNotEmpty) {
      orders
        ..clear()
        ..addAll(orows.map(_orderFromRow));
    }
    final favs = await _repo.fetchFavorites();
    if (favs.isNotEmpty) {
      _favorites
        ..clear()
        ..addAll(favs);
    }
    final frows = await _repo.fetchFamily();
    if (frows.isNotEmpty) {
      family
        ..clear()
        ..addAll(frows.map(_familyFromRow));
    }
    final prof = await _repo.fetchProfile();
    if (prof != null) {
      final n = '${prof['full_name'] ?? ''}';
      final p = '${prof['phone'] ?? ''}';
      if (n.isNotEmpty) _name = n;
      if (p.isNotEmpty) _phone = p;
    }
    notifyListeners();
  }

  /// Resets production flags so the next real sign-in reloads user data.
  void _resetProductionFlags() {
    _userDataLoaded = false;
    _remoteAppointmentIds.clear();
    _remoteOrderIds.clear();
    _remoteFamilyIds.clear();
  }

  static String _embeddedName(Map<String, dynamic> r, String key) {
    final v = r[key];
    return v is Map ? '${v['name'] ?? ''}' : '';
  }

  Appointment _apptFromRow(Map<String, dynamic> r) {
    final kind = '${r['service_type'] ?? 'doctor'}';
    String refId = '';
    String title = 'Appointment';
    if (kind == 'doctor') {
      refId = '${r['doctor_id'] ?? ''}';
      final n = _embeddedName(r, 'doctors');
      if (n.isNotEmpty) title = n;
    } else if (kind == 'hospital') {
      refId = '${r['hospital_id'] ?? ''}';
      final n = _embeddedName(r, 'hospitals');
      if (n.isNotEmpty) title = n;
    } else if (kind == 'lab') {
      refId = '${r['lab_id'] ?? ''}';
      final n = _embeddedName(r, 'labs');
      if (n.isNotEmpty) title = n;
    } else {
      refId = '${r['pharmacy_id'] ?? ''}';
    }
    DateTime date;
    try {
      date = DateTime.parse('${r['appointment_date']}');
    } catch (_) {
      date = DateTime.now();
    }
    var timeLabel = '${r['appointment_time'] ?? ''}';
    if (timeLabel.length >= 5) timeLabel = timeLabel.substring(0, 5);
    final st = '${r['status'] ?? 'pending'}';
    return Appointment(
      id: '${r['id']}',
      doctorName: title,
      specialty: kind,
      place: '',
      date: date,
      timeLabel: timeLabel,
      fee: 0,
      payment: 'online',
      kind: kind,
      refId: refId,
      notes: '${r['notes'] ?? ''}',
      status: st == 'cancelled' ? 'cancelled' : 'upcoming',
    );
  }

  MedOrder _orderFromRow(Map<String, dynamic> r) {
    final items = <CartLine>[];
    final raw = r['order_items'];
    if (raw is List) {
      for (final it in raw) {
        if (it is Map) {
          final price = (it['unit_price'] as num?)?.toDouble() ?? 0;
          items.add(CartLine(
            medicine: Medicine(
              id: '${it['medicine_id'] ?? ''}',
              pharmacyId: '${r['pharmacy_id'] ?? ''}',
              name: '${it['medicine_name'] ?? ''}',
              pack: 'strip',
              brand: '',
              price: price,
              mrp: price,
              rxRequired: false,
              category: 'General',
            ),
            qty: (it['quantity'] as num?)?.toInt() ?? 1,
          ));
        }
      }
    }
    DateTime placed;
    try {
      placed = DateTime.parse('${r['placed_at']}');
    } catch (_) {
      placed = DateTime.now();
    }
    return MedOrder(
      id: '${r['id']}',
      pharmacyName: _embeddedName(r, 'pharmacies').isNotEmpty
          ? _embeddedName(r, 'pharmacies')
          : 'Pharmacy',
      items: items,
      subtotal: (r['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (r['delivery_fee'] as num?)?.toDouble() ?? 0,
      total: (r['total'] as num?)?.toDouble() ?? 0,
      address: '${r['delivery_address'] ?? ''}',
      payment: '${r['payment_method'] ?? 'cod'}',
      placedAt: placed,
      status: '${r['status'] ?? 'placed'}',
    );
  }

  FamilyMember _familyFromRow(Map<String, dynamic> r) {
    var age = 0;
    final dob = '${r['date_of_birth'] ?? ''}';
    try {
      if (dob.isNotEmpty) {
        final d = DateTime.parse(dob);
        age = DateTime.now().year - d.year;
      }
    } catch (_) {}
    return FamilyMember(
      id: '${r['id']}',
      name: '${r['name'] ?? ''}',
      relation: '${r['relationship'] ?? ''}',
      age: age,
    );
  }

  // ---------- Production write-through helpers ----------

  /// Fire-and-forget Supabase insert for a new appointment; records the real
  /// row id so cancel works against the production table.
  void _syncBookAppointment(Appointment appt) {
    if (_supaUser == null) return;
    _repo
        .bookAppointment(
      serviceType: appt.kind,
      doctorId: appt.kind == 'doctor' ? appt.refId : null,
      hospitalId: appt.kind == 'hospital' ? appt.refId : null,
      labId: appt.kind == 'lab' ? appt.refId : null,
      pharmacyId: appt.kind == 'pharmacy' ? appt.refId : null,
      date: appt.date,
      timeLabel: appt.timeLabel,
      notes: appt.notes.isEmpty ? null : appt.notes,
    )
        .then((remoteId) {
      if (remoteId != null) _remoteAppointmentIds[appt.id] = remoteId;
    });
  }

  void _syncCancelAppointment(String localId) {
    if (_supaUser == null) return;
    _repo.cancelAppointment(_remoteAppointmentIds[localId] ?? localId);
  }

  void _syncPlaceOrder(MedOrder order, String? pharmacyId) {
    if (_supaUser == null || pharmacyId == null || pharmacyId.isEmpty) return;
    _repo
        .placeOrder(
      pharmacyId: pharmacyId,
      lines: order.items,
      subtotal: order.subtotal,
      deliveryFee: order.deliveryFee,
      total: order.total,
      address: order.address,
      payment: order.payment,
      notes: null,
    )
        .then((remoteId) {
      if (remoteId != null) _remoteOrderIds[order.id] = remoteId;
    });
  }

  void _syncToggleFavorite(String key, bool added) {
    if (_supaUser == null) return;
    final parts = key.split(':');
    if (parts.length != 2) return;
    if (added) {
      _repo.addFavorite(parts[0], parts[1]);
    } else {
      _repo.removeFavorite(parts[0], parts[1]);
    }
  }

  void _syncSaveProfile() {
    if (_supaUser == null) return;
    _repo.saveProfile({'full_name': _name, 'phone': _phone});
  }

  void saveProfile({
    required String name,
    required String phone,
    required String gender,
    required String address,
  }) {
    _name = name;
    _phone = phone;
    _gender = gender;
    _address = address;
    _syncSaveProfile();
    notifyListeners();
  }

  // ---------- Preferences ----------

  bool _darkMode = false;
  bool _emailNotif = true;
  bool _pushNotif = true;
  String _language = 'English';
  bool _maintenanceMode = false;

  bool get darkMode => _darkMode;
  bool get emailNotif => _emailNotif;
  bool get pushNotif => _pushNotif;
  String get language => _language;
  bool get maintenanceMode => _maintenanceMode;

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    notifyListeners();
  }

  void toggleEmailNotif() {
    _emailNotif = !_emailNotif;
    notifyListeners();
  }

  void togglePushNotif() {
    _pushNotif = !_pushNotif;
    notifyListeners();
  }

  void setLanguage(String v) {
    _language = v;
    notifyListeners();
  }

  void setMaintenanceMode(bool v) {
    _maintenanceMode = v;
    notifyListeners();
  }

  // ---------- Favorites ----------

  final Set<String> _favorites = {};
  Set<String> get favorites => _favorites;

  bool isFavorite(String key) => _favorites.contains(key);

  void toggleFavorite(String key) {
    final added = !_favorites.contains(key);
    if (added) {
      _favorites.add(key);
    } else {
      _favorites.remove(key);
    }
    _syncToggleFavorite(key, added);
    notifyListeners();
  }

  List<Doctor> get favoriteDoctors =>
      doctors.where((d) => _favorites.contains('doctor:${d.id}')).toList();
  List<Hospital> get favoriteHospitals =>
      hospitals.where((h) => _favorites.contains('hospital:${h.id}')).toList();
  List<Lab> get favoriteLabs =>
      labs.where((l) => _favorites.contains('lab:${l.id}')).toList();
  List<Pharmacy> get favoritePharmacies => pharmacies
      .where((p) => _favorites.contains('pharmacy:${p.id}'))
      .toList();

  // ---------- Appointments ----------

  final List<Appointment> appointments = [];
  final Set<String> _takenSlots = {};

  List<Appointment> get upcoming => appointments
      .where((a) => a.status == 'upcoming')
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  List<Appointment> get past => appointments
      .where((a) => a.status != 'upcoming')
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  Appointment bookAppointment({
    required String kind,
    required String refId,
    required String title,
    required String subtitle,
    required String place,
    required DateTime date,
    required String timeLabel,
    required double fee,
    required String payment,
    String notes = '',
    List<LabTest> tests = const [],
  }) {
    final appt = Appointment(
      id: 'A${DateTime.now().millisecondsSinceEpoch}',
      doctorName: title,
      specialty: subtitle,
      place: place,
      date: date,
      timeLabel: timeLabel,
      fee: fee,
      payment: payment,
      kind: kind,
      refId: refId,
      notes: notes,
      tests: List.of(tests),
    );
    appointments.add(appt);
    _takenSlots.add(_slotKey(title, date, timeLabel));
    _syncBookAppointment(appt);
    addNotification(
      title: 'Appointment booked',
      message: '$title on ${date.day}/${date.month} at $timeLabel',
      category: 'appointments',
    );
    notifyListeners();
    return appt;
  }

  void cancelAppointment(String id) {
    final appt = appointments.firstWhere((a) => a.id == id);
    appt.status = 'cancelled';
    _syncCancelAppointment(id);
    addNotification(
      title: 'Appointment cancelled',
      message: '${appt.doctorName} on ${appt.date.day}/${appt.date.month}',
      category: 'appointments',
    );
    notifyListeners();
  }

  void rescheduleAppointment(String id, DateTime date, String timeLabel) {
    final appt = appointments.firstWhere((a) => a.id == id);
    final updated = Appointment(
      id: 'A${DateTime.now().millisecondsSinceEpoch}',
      doctorName: appt.doctorName,
      specialty: appt.specialty,
      place: appt.place,
      date: date,
      timeLabel: timeLabel,
      fee: appt.fee,
      payment: appt.payment,
      kind: appt.kind,
      notes: appt.notes,
      tests: appt.tests,
    );
    appt.status = 'cancelled';
    appointments.add(updated);
    notifyListeners();
  }

  static String _slotKey(String title, DateTime day, String label) =>
      '$title|${day.year}-${day.month}-${day.day}|$label';

  List<DateTime> nextDays(int n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(n, (i) => today.add(Duration(days: i)));
  }

  /// 09:00–16:30 pill grid; some slots deterministically pre-booked.
  List<String> timeSlotsFor(String title, DateTime day) {
    final out = <String>[];
    for (var h = 9; h <= 16; h++) {
      for (final m in [0, 30]) {
        if (h == 16 && m == 30) continue;
        final label =
            '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        final pseudoBooked =
            (title.hashCode + day.day * 31 + h * 7 + m) % 10 < 3;
        final taken = _takenSlots.contains(_slotKey(title, day, label));
        if (!pseudoBooked && !taken) out.add(label);
      }
    }
    return out;
  }

  // ---------- Medicine cart & orders ----------

  final List<CartLine> cart = [];
  String? cartPharmacyId;
  String? cartPharmacyName;
  final List<MedOrder> orders = [];

  int get cartCount => cart.fold(0, (s, l) => s + l.qty);

  double get cartSubtotal =>
      cart.fold(0.0, (s, l) => s + l.medicine.price * l.qty);

  List<MedOrder> get activeOrders =>
      orders.where((o) => o.isActive).toList();
  List<MedOrder> get pastOrders =>
      orders.where((o) => !o.isActive).toList();

  /// Returns false when the product belongs to a different vendor.
  bool addToCart(
    Medicine m, {
    required String pharmacyId,
    required String pharmacyName,
  }) {
    if (cartPharmacyId != null && cartPharmacyId != pharmacyId) return false;
    cartPharmacyId = pharmacyId;
    cartPharmacyName = pharmacyName;
    final existing = cart.where((l) => l.medicine.id == m.id);
    if (existing.isNotEmpty) {
      existing.first.qty++;
    } else {
      cart.add(CartLine(medicine: m));
    }
    notifyListeners();
    return true;
  }

  void changeQty(String medicineId, int delta) {
    final line = cart.firstWhere((l) => l.medicine.id == medicineId);
    line.qty += delta;
    if (line.qty <= 0) cart.remove(line);
    if (cart.isEmpty) {
      cartPharmacyId = null;
      cartPharmacyName = null;
    }
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    cartPharmacyId = null;
    cartPharmacyName = null;
    notifyListeners();
  }

  MedOrder placeOrder({required String address, required String payment}) {
    final subtotal = cartSubtotal;
    final deliveryFee = subtotal >= 499 ? 0.0 : 30.0;
    final pharmacyId = cartPharmacyId;
    final order = MedOrder(
      id: 'R${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      pharmacyName: cartPharmacyName ?? 'Pharmacy',
      items: List.of(cart),
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: subtotal + deliveryFee,
      address: address,
      payment: payment,
      placedAt: DateTime.now(),
    );
    orders.insert(0, order);
    cart.clear();
    cartPharmacyId = null;
    cartPharmacyName = null;
    _syncPlaceOrder(order, pharmacyId);
    addNotification(
      title: 'Order placed',
      message: '${order.pharmacyName} • ${order.id} • ₹${order.total.toStringAsFixed(0)}',
      category: 'orders',
    );
    notifyListeners();
    return order;
  }

  // ---------- Lab test booking list ----------

  final List<LabTest> testCart = [];
  String? testCartLabId;
  String? testCartLabName;

  double get testCartTotal =>
      testCart.fold(0.0, (s, t) => s + t.price);

  bool addTest(LabTest t, {required String labId, required String labName}) {
    if (testCartLabId != null && testCartLabId != labId) return false;
    testCartLabId = labId;
    testCartLabName = labName;
    if (!testCart.any((e) => e.id == t.id)) testCart.add(t);
    notifyListeners();
    return true;
  }

  void removeTest(String id) {
    testCart.removeWhere((t) => t.id == id);
    if (testCart.isEmpty) {
      testCartLabId = null;
      testCartLabName = null;
    }
    notifyListeners();
  }

  void clearTests() {
    testCart.clear();
    testCartLabId = null;
    testCartLabName = null;
    notifyListeners();
  }

  // ---------- Notifications ----------

  final List<AppNotification> notifications = [];

  int get unreadCount => notifications.where((n) => !n.read).length;

  void addNotification({
    required String title,
    required String message,
    required String category,
  }) {
    notifications.insert(
      0,
      AppNotification(
        id: 'N${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        message: message,
        time: DateTime.now(),
        category: category,
      ),
    );
    notifyListeners();
  }

  void markAllRead() {
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  // ---------- Family ----------

  final List<FamilyMember> family = [];

  void addFamilyMember({
    required String name,
    required String relation,
    required int age,
  }) {
    final member = FamilyMember(
      id: 'F${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      relation: relation,
      age: age,
    );
    family.add(member);
    if (_supaUser != null) {
      _repo.addFamilyMember({
        'name': name,
        'relationship': relation,
      }).then((remoteId) {
        if (remoteId != null) _remoteFamilyIds[member.id] = remoteId;
      });
    }
    notifyListeners();
  }

  void removeFamilyMember(String id) {
    family.removeWhere((f) => f.id == id);
    if (_supaUser != null) {
      _repo.deleteFamilyMember(_remoteFamilyIds[id] ?? id);
    }
    notifyListeners();
  }

  // ---------- Reminders ----------

  final List<Reminder> reminders = [];

  List<Reminder> get upcomingReminders =>
      reminders.where((r) => !r.done).toList();
  List<Reminder> get completedReminders =>
      reminders.where((r) => r.done).toList();

  void addReminder({
    required String title,
    required DateTime date,
    required String timeLabel,
    required String notes,
  }) {
    reminders.add(Reminder(
      id: 'R${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      date: date,
      timeLabel: timeLabel,
      notes: notes,
    ));
    notifyListeners();
  }

  void toggleReminder(String id) {
    final r = reminders.firstWhere((e) => e.id == id);
    r.done = !r.done;
    notifyListeners();
  }

  void deleteReminder(String id) {
    reminders.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  // ---------- Support tickets ----------

  final List<SupportTicket> tickets = [];

  void addTicket({
    required String subject,
    required String category,
    required String description,
  }) {
    tickets.insert(
      0,
      SupportTicket(
        id: 'T${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        subject: subject,
        category: category,
        description: description,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  // ---------- Reviews ----------

  final Map<String, Review> reviews = {};

  void addReview(String appointmentId, int stars, String comment) {
    reviews[appointmentId] = Review(
      appointmentId: appointmentId,
      stars: stars,
      comment: comment,
    );
    notifyListeners();
  }

  // ---------- Provider application ----------

  String? providerApplicationId;

  // ---------- Driver ----------

  bool driverOnline = false;
  final List<DriverDelivery> deliveries = [];

  void toggleDriverOnline() {
    driverOnline = !driverOnline;
    notifyListeners();
  }

  void acceptDelivery(String id) {
    deliveries.firstWhere((d) => d.id == id).status = 'accepted';
    notifyListeners();
  }

  void advanceDelivery(String id) {
    final d = deliveries.firstWhere((e) => e.id == id);
    if (d.status == 'accepted') {
      d.status = 'picked_up';
    } else if (d.status == 'picked_up') {
      d.status = 'delivered';
    }
    notifyListeners();
  }

  // ---------- Seed ----------

  void _seed() {
    final ph = pharmacies[0];
    final meds = medicinesForPharmacy(ph.id).take(2).toList();
    final lines = meds.map((m) => CartLine(medicine: m)).toList();
    final subtotal =
        lines.fold(0.0, (s, l) => s + l.medicine.price * l.qty);
    orders.add(MedOrder(
      id: 'R049B076',
      pharmacyName: ph.name,
      items: lines,
      subtotal: subtotal,
      deliveryFee: 30,
      total: subtotal + 30,
      address: _address,
      payment: 'Online Payment',
      placedAt: DateTime.now().subtract(const Duration(hours: 5)),
      status: 'placed',
    ));
    notifications.addAll([
      AppNotification(
        id: 'N1',
        title: 'Order Update',
        message: '${ph.name} • R049B076 confirmed and being packed',
        time: DateTime.now().subtract(const Duration(hours: 4)),
        category: 'orders',
      ),
      AppNotification(
        id: 'N2',
        title: 'Welcome to Remedoo',
        message: 'Your health companion is ready. Book your first appointment.',
        time: DateTime.now().subtract(const Duration(days: 1)),
        category: 'system',
        read: true,
      ),
    ]);
    tickets.add(SupportTicket(
      id: 'T1001',
      subject: 'How do I upload a prescription?',
      category: 'Order',
      description: 'I want to order medicines that need a prescription.',
      date: DateTime.now().subtract(const Duration(days: 2)),
      status: 'resolved',
    ));
    providerApplications.addAll([
      ProviderApplication(
        id: 'PA881100',
        name: 'Dr. Sameer Koul',
        email: 'sameer.koul@example.com',
        phone: '9876543210',
        role: 'Doctor',
        license: 'JKMC-45210',
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ProviderApplication(
        id: 'PA881101',
        name: 'CityCare Diagnostics',
        email: 'hello@citycare.example.com',
        phone: '9876543211',
        role: 'Lab',
        license: 'LAB-JK-8831',
        date: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ]);
    sosAlerts.addAll([
      SosAlert(
        id: 'S1',
        name: 'Rafiq Ahmad',
        phone: '9906123456',
        location: 'Dalgate, Srinagar',
        time: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
      SosAlert(
        id: 'S2',
        name: 'Priya Sharma',
        phone: '9419012345',
        location: 'Gandhi Nagar, Jammu',
        time: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'acknowledged',
      ),
      SosAlert(
        id: 'S3',
        name: 'Mohd Yousuf',
        phone: '9906987654',
        location: 'Anantnag',
        time: DateTime.now().subtract(const Duration(days: 1)),
        status: 'dispatched',
      ),
    ]);
    refundRequests.addAll([
      RefundRequest(
        id: 'RF7001',
        orderId: 'R049B071',
        amount: 245,
        reason: 'Medicines not delivered on time',
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
      RefundRequest(
        id: 'RF7002',
        orderId: 'R049B060',
        amount: 120,
        reason: 'Wrong item received',
        date: DateTime.now().subtract(const Duration(days: 3)),
        status: 'approved',
      ),
    ]);
    adminUsers.addAll([
      {'id': 'U1', 'name': 'Zahid Manzoor', 'email': 'zahid391105@gmail.com', 'phone': '9876543210', 'active': '1'},
      {'id': 'U2', 'name': 'Aisha Khan', 'email': 'aisha.k@example.com', 'phone': '9876543211', 'active': '1'},
      {'id': 'U3', 'name': 'Rohan Gupta', 'email': 'rohan.g@example.com', 'phone': '9876543212', 'active': '0'},
    ]);
    coupons.addAll([
      {'id': 'C1', 'code': 'FIRST30', 'percent': '30', 'active': '1'},
      {'id': 'C2', 'code': 'MED20', 'percent': '20', 'active': '1'},
    ]);
    promoBanners.addAll([
      {'id': 'B1', 'title': 'Flat 30% OFF', 'subtitle': 'On first doctor consultation', 'active': '1'},
      {'id': 'B2', 'title': 'Free Health Checkup', 'subtitle': 'On first hospital visit', 'active': '1'},
    ]);
    faqs.addAll([
      {'id': 'F1', 'question': 'How do I book an appointment?', 'answer': 'Pick a doctor and choose a time slot.', 'active': '1'},
      {'id': 'F2', 'question': 'Is my data private?', 'answer': 'Yes, all data is encrypted.', 'active': '1'},
    ]);
    sliderItems.addAll([
      {'id': 'S1', 'title': 'Book Appointments', 'subtitle': 'Doctors, hospitals, labs in one place', 'active': '1'},
      {'id': 'S2', 'title': 'Emergency SOS', 'subtitle': 'One tap ambulance dispatch', 'active': '1'},
    ]);
    serviceAreas.addAll([
      {'id': 'A1', 'name': 'Srinagar', 'active': '1'},
      {'id': 'A2', 'name': 'Jammu', 'active': '1'},
      {'id': 'A3', 'name': 'Anantnag', 'active': '1'},
    ]);
    teamMembers.addAll([
      {'id': 'T1', 'name': 'Support Lead', 'role': 'Support', 'active': '1'},
      {'id': 'T2', 'name': 'Ops Manager', 'role': 'Operations', 'active': '1'},
    ]);
    subscriptionPlans.addAll([
      {'id': 'P1', 'name': 'Remedoo Plus Monthly', 'price': '199', 'active': '1'},
      {'id': 'P2', 'name': 'Remedoo Plus Yearly', 'price': '1999', 'active': '1'},
    ]);
    corporatePlans.addAll([
      {'id': 'CP1', 'name': 'Corporate Basic', 'price': '9999', 'active': '1'},
    ]);
    healthcarePackages.addAll([
      {'id': 'H1', 'name': 'Full Body Checkup', 'price': '1499', 'active': '1'},
      {'id': 'H2', 'name': 'Diabetes Care Pack', 'price': '899', 'active': '1'},
    ]);
    apiKeys.addAll([
      {'id': 'K1', 'name': 'Mobile App', 'key': 'rk_live_9f2a…c41d', 'active': '1'},
      {'id': 'K2', 'name': 'Partner API', 'key': 'rk_live_77b0…e9a2', 'active': '1'},
    ]);
    infoCards.addAll([
      {'id': 'I1', 'title': '24x7 Support', 'text': 'We are here to help anytime', 'active': '1'},
    ]);
    quickAccess.addAll([
      {'id': 'Q1', 'title': 'Book Appointment', 'icon': 'calendar', 'active': '1'},
      {'id': 'Q2', 'title': 'Order Medicines', 'icon': 'pill', 'active': '1'},
    ]);
    reports.addAll([
      LabReport(
        id: 'LR1',
        patientName: _name,
        labName: labs[0].name,
        date: DateTime.now().subtract(const Duration(days: 6)),
        status: 'Completed',
        tests: const [
          {
            'name': 'Complete Blood Count',
            'result': '5.1',
            'unit': '10^9/L',
            'range': '4.0 - 11.0',
            'flag': 'Normal'
          },
          {
            'name': 'HbA1c',
            'result': '6.8',
            'unit': '%',
            'range': '4.0 - 5.6',
            'flag': 'High'
          },
          {
            'name': 'Lipid Profile',
            'result': '185',
            'unit': 'mg/dL',
            'range': '< 200',
            'flag': 'Normal'
          },
        ],
      ),
      LabReport(
        id: 'LR2',
        patientName: _name,
        labName: labs[2].name,
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'In Progress',
        tests: const [
          {
            'name': 'Thyroid Panel (T3/T4/TSH)',
            'result': '—',
            'unit': '',
            'range': '—',
            'flag': 'Pending'
          },
        ],
      ),
    ]);
    deliveries.addAll([
      DriverDelivery(
        id: 'D1',
        orderId: 'R049B076',
        pharmacy: ph.name,
        address: _address,
        amount: subtotal + 30,
      ),
      DriverDelivery(
        id: 'D2',
        orderId: 'R049B071',
        pharmacy: pharmacies[3].name,
        address: 'Rajbagh, Srinagar, J&K 190008',
        amount: 245,
        status: 'accepted',
      ),
      DriverDelivery(
        id: 'D3',
        orderId: 'R049B066',
        pharmacy: pharmacies[7].name,
        address: 'Gandhi Nagar, Jammu, J&K 180004',
        amount: 180,
        status: 'delivered',
      ),
    ]);
  }

  // ---------- Roles ----------

  String _role = 'patient';
  String get role => _role;

  void switchRole(String r) {
    _role = r;
    notifyListeners();
  }

  // ---------- Active-filtered patient lists ----------

  List<Doctor> get activeDoctors =>
      doctors.where((d) => d.active).toList();
  List<Hospital> get activeHospitals =>
      hospitals.where((h) => h.active).toList();
  List<Lab> get activeLabs => labs.where((l) => l.active).toList();
  List<Pharmacy> get activePharmacies =>
      pharmacies.where((p) => p.active).toList();
  List<Medicine> get activeMedicines =>
      medicines.where((m) => m.active).toList();

  final List<String> prescriptionsSeed = const [
    'Rx-2026-0912',
    'Rx-2026-0820'
  ];

  List<String> get prescriptions => prescriptionsSeed;

  /// Force a rebuild (used after mutating a nested object directly).
  void refresh() => notifyListeners();

  // ---------- Convenience aliases used by the UI ----------

  String get displayName => userName;
  String? get userEmail => email.isEmpty ? null : email;
  String? get userPhone => _phone.isEmpty ? null : _phone;
  String? get userAddress => _address.isEmpty ? null : _address;

  void setDarkMode(bool v) {
    _darkMode = v;
    notifyListeners();
  }

  bool get notificationsEnabled => _pushNotif;
  void setNotificationsEnabled(bool v) {
    _pushNotif = v;
    notifyListeners();
  }

  int get unreadNotifications => unreadCount;
  void markAllNotificationsRead() => markAllRead();

  double get cartTotal => cartSubtotal;
  List<CartLine> get cartLines => cart;

  int cartQty(String medicineId) {
    final line = cart.where((l) => l.medicine.id == medicineId);
    return line.isEmpty ? 0 : line.first.qty;
  }

  void removeFromCart(String medicineId) => changeQty(medicineId, -1);

  void setDriverOnline(bool v) {
    driverOnline = v;
    notifyListeners();
  }

  void updateProfile({String? name, String? phone, String? address}) {
    if (name != null) _name = name;
    if (phone != null) _phone = phone;
    if (address != null) _address = address;
    notifyListeners();
  }

  List<String> slotsFor(DateTime day) => timeSlotsFor('', day);

  bool canReview(String appointmentId) {
    final a = appointments.where((e) => e.id == appointmentId);
    if (a.isEmpty) return false;
    return a.first.status != 'upcoming' &&
        !reviews.containsKey(appointmentId);
  }

  // ---------- Lab reports ----------

  final List<LabReport> reports = [];

  // ---------- Provider applications ----------

  final List<ProviderApplication> providerApplications = [];

  void submitProviderApplication({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String license,
  }) {
    final app = ProviderApplication(
      id: 'PA${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      name: name,
      email: email,
      phone: phone,
      role: role,
      license: license,
      date: DateTime.now(),
    );
    providerApplications.insert(0, app);
    providerApplicationId = app.id;
    notifyListeners();
  }

  void setApplicationStatus(String id, String status) {
    providerApplications.firstWhere((a) => a.id == id).status = status;
    notifyListeners();
  }

  // ---------- SOS alerts ----------

  final List<SosAlert> sosAlerts = [];

  void setSosStatus(String id, String status) {
    sosAlerts.firstWhere((a) => a.id == id).status = status;
    notifyListeners();
  }

  // ---------- Refund requests ----------

  final List<RefundRequest> refundRequests = [];

  void setRefundStatus(String id, String status) {
    refundRequests.firstWhere((r) => r.id == id).status = status;
    notifyListeners();
  }

  void requestRefund({
    required String orderId,
    required double amount,
    required String reason,
  }) {
    refundRequests.insert(
      0,
      RefundRequest(
        id: 'RF${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        orderId: orderId,
        amount: amount,
        reason: reason,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  // ---------- Reviews admin ----------

  void toggleReviewHidden(String appointmentId) {
    final r = reviews[appointmentId];
    if (r != null) {
      r.hidden = !r.hidden;
      notifyListeners();
    }
  }

  // ---------- Orders admin ----------

  static const List<String> orderStatuses = [
    'placed',
    'packed',
    'out_for_delivery',
    'delivered'
  ];

  void setOrderStatus(String id, String status) {
    orders.firstWhere((o) => o.id == id).status = status;
    notifyListeners();
  }

  void advanceOrderStatus(String id) {
    final o = orders.firstWhere((e) => e.id == id);
    final i = orderStatuses.indexOf(o.status);
    if (i >= 0 && i < orderStatuses.length - 1) {
      o.status = orderStatuses[i + 1];
      notifyListeners();
    }
  }

  // ---------- Doctor schedule (doctor portal) ----------

  final Map<String, List<String>> _doctorSlots = {};

  List<String> doctorSlots(String doctorId, int dayIdx) {
    final key = '$doctorId|$dayIdx';
    return _doctorSlots.putIfAbsent(
        key, () => ['09:00', '09:30', '10:00', '17:00', '17:30']);
  }

  void addDoctorSlot(String doctorId, int dayIdx, String slot) {
    final key = '$doctorId|$dayIdx';
    final list = _doctorSlots.putIfAbsent(key, () => []);
    if (!list.contains(slot)) {
      list.add(slot);
      list.sort();
      notifyListeners();
    }
  }

  void removeDoctorSlot(String doctorId, int dayIdx, String slot) {
    final key = '$doctorId|$dayIdx';
    _doctorSlots[key]?.remove(slot);
    notifyListeners();
  }

  // ---------- Pharmacy inventory (pharmacy portal) ----------

  final Map<String, int> _medStock = {};
  final Map<String, double> _medPrice = {};

  int stockOf(String medicineId) => _medStock[medicineId] ?? 50;

  void setStock(String medicineId, int v) {
    _medStock[medicineId] = v.clamp(0, 9999);
    notifyListeners();
  }

  double priceOf(Medicine m) => _medPrice[m.id] ?? m.price;

  void setPrice(String medicineId, double v) {
    _medPrice[medicineId] = v;
    notifyListeners();
  }

  // ---------- Admin config ----------

  int otpLength = 6;
  int otpExpiryMinutes = 5;

  final Map<String, double> commission = {
    'Doctor': 15,
    'Hospital': 8,
    'Lab': 12,
    'Pharmacy': 10,
  };

  String brandName = 'Remedoo';
  String brandTagline = 'Your Health, Our Priority';
  int brandColorIndex = 0;

  static const List<Color> brandSwatches = [
    Color(0xFFE86A1C),
    Color(0xFF0E9F8A),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFD43D3D),
  ];

  Color get brandPrimary => brandSwatches[brandColorIndex];

  final Map<String, bool> quickActions = {
    'Book Appointment': true,
    'Order Medicines': true,
    'Emergency SOS': true,
    'Lab Tests': true,
  };

  final Map<String, bool> categoryActions = {
    'Doctors': true,
    'Hospitals': true,
    'Labs': true,
    'Pharmacy': true,
    'Emergency': true,
    'Favorites': true,
    'Orders': true,
    'Reports': true,
  };

  final List<String> featuredDoctors = ['d0', 'd1', 'd2', 'd3'];
  final List<String> featuredMedicines = ['m0', 'm1', 'm10', 'm11'];
  final List<String> featuredProviders = ['h0', 'l0', 'p0'];

  final List<Map<String, String>> adminUsers = [];
  final List<Map<String, String>> coupons = [];
  final List<Map<String, String>> promoBanners = [];
  final List<Map<String, String>> faqs = [];
  final List<Map<String, String>> sliderItems = [];
  final List<Map<String, String>> teamMembers = [];
  final List<Map<String, String>> subscriptionPlans = [];
  final List<Map<String, String>> corporatePlans = [];
  final List<Map<String, String>> healthcarePackages = [];
  final List<Map<String, String>> apiKeys = [];
  final List<Map<String, String>> infoCards = [];
  final List<Map<String, String>> quickAccess = [];
  final List<Map<String, String>> serviceAreas = [];

  void collectionAdd(List<Map<String, String>> c, Map<String, String> row) {
    c.add({
      'id': 'X${DateTime.now().millisecondsSinceEpoch}',
      'active': '1',
      ...row,
    });
    notifyListeners();
  }

  void collectionUpdate(
      List<Map<String, String>> c, String id, Map<String, String> row) {
    final i = c.indexWhere((e) => e['id'] == id);
    if (i >= 0) {
      c[i] = {'id': id, 'active': c[i]['active'] ?? '1', ...row};
      notifyListeners();
    }
  }

  void collectionRemove(List<Map<String, String>> c, String id) {
    c.removeWhere((e) => e['id'] == id);
    notifyListeners();
  }

  void collectionToggle(List<Map<String, String>> c, String id, bool v) {
    final e = c.firstWhere((x) => x['id'] == id);
    e['active'] = v ? '1' : '0';
    notifyListeners();
  }

  // ---------- Generic CRUD specs ----------

  EntitySpec mapSpec(
    String title,
    String singular,
    List<FieldSpec> fields,
    List<Map<String, String>> coll,
  ) =>
      EntitySpec(
        title: title,
        singular: singular,
        fields: fields,
        read: () => coll,
        create: (v) => collectionAdd(coll, v),
        update: (id, v) => collectionUpdate(coll, id, v),
        remove: (id) => collectionRemove(coll, id),
        rowActive: (r) => r['active'] != '0',
        setRowActive: (id, v) => collectionToggle(coll, id, v),
      );

  EntitySpec doctorSpec() => EntitySpec(
        title: 'Doctors',
        singular: 'Doctor',
        fields: const [
          FieldSpec(key: 'name', label: 'Full name', required: true),
          FieldSpec(key: 'specialty', label: 'Specialty'),
          FieldSpec(key: 'hospital', label: 'Hospital'),
          FieldSpec(key: 'fee', label: 'Fee (₹)', type: 'number'),
          FieldSpec(key: 'rating', label: 'Rating', type: 'number'),
          FieldSpec(key: 'exp', label: 'Experience (yrs)', type: 'number'),
          FieldSpec(key: 'verified', label: 'Verified', type: 'toggle'),
        ],
        read: () => doctors
            .map((d) => {
                  'id': d.id,
                  'name': d.name,
                  'specialty': d.specialty,
                  'hospital': d.hospital,
                  'fee': d.fee.toStringAsFixed(0),
                  'rating': d.rating.toString(),
                  'exp': d.expYears.toString(),
                  'verified': d.verified ? '1' : '0',
                })
            .toList(),
        create: (v) {
          doctors.add(Doctor(
            id: 'd${DateTime.now().millisecondsSinceEpoch}',
            name: v['name']!,
            specialty: v['specialty']!.isEmpty
                ? 'General Physician'
                : v['specialty']!,
            hospital: v['hospital']!,
            fee: double.tryParse(v['fee'] ?? '') ?? 500,
            rating: double.tryParse(v['rating'] ?? '') ?? 4.5,
            reviews: 0,
            expYears: int.tryParse(v['exp'] ?? '') ?? 5,
            waitMin: 15,
            distanceKm: 2.0,
            verified: v['verified'] == '1',
            about: 'Experienced practitioner.',
          ));
          notifyListeners();
        },
        update: (id, v) {
          final i = doctors.indexWhere((d) => d.id == id);
          if (i < 0) return;
          final d = doctors[i];
          doctors[i] = Doctor(
            id: d.id,
            name: v['name']!,
            specialty: v['specialty']!,
            hospital: v['hospital']!,
            fee: double.tryParse(v['fee'] ?? '') ?? d.fee,
            rating: double.tryParse(v['rating'] ?? '') ?? d.rating,
            reviews: d.reviews,
            expYears: int.tryParse(v['exp'] ?? '') ?? d.expYears,
            waitMin: d.waitMin,
            distanceKm: d.distanceKm,
            verified: v['verified'] == '1',
            about: d.about,
            active: d.active,
          );
          notifyListeners();
        },
        remove: (id) {
          doctors.removeWhere((d) => d.id == id);
          notifyListeners();
        },
        rowActive: (r) =>
            doctors.firstWhere((d) => d.id == r['id']).active,
        setRowActive: (id, v) {
          final i = doctors.indexWhere((d) => d.id == id);
          if (i < 0) return;
          final d = doctors[i];
          doctors[i] = Doctor(
            id: d.id,
            name: d.name,
            specialty: d.specialty,
            hospital: d.hospital,
            fee: d.fee,
            rating: d.rating,
            reviews: d.reviews,
            expYears: d.expYears,
            waitMin: d.waitMin,
            distanceKm: d.distanceKm,
            verified: d.verified,
            about: d.about,
            active: v,
          );
          notifyListeners();
        },
      );

  EntitySpec hospitalSpec() => EntitySpec(
        title: 'Hospitals',
        singular: 'Hospital',
        fields: const [
          FieldSpec(key: 'name', label: 'Name', required: true),
          FieldSpec(key: 'location', label: 'Location'),
          FieldSpec(key: 'beds', label: 'Beds', type: 'number'),
          FieldSpec(key: 'rating', label: 'Rating', type: 'number'),
          FieldSpec(key: 'government', label: 'Government', type: 'toggle'),
          FieldSpec(key: 'icu', label: 'Has ICU', type: 'toggle'),
        ],
        read: () => hospitals
            .map((h) => {
                  'id': h.id,
                  'name': h.name,
                  'location': h.location,
                  'beds': h.beds.toString(),
                  'rating': h.rating.toString(),
                  'government': h.government ? '1' : '0',
                  'icu': h.hasIcu ? '1' : '0',
                })
            .toList(),
        create: (v) {
          hospitals.add(Hospital(
            id: 'h${DateTime.now().millisecondsSinceEpoch}',
            name: v['name']!,
            location: v['location']!,
            government: v['government'] == '1',
            hasIcu: v['icu'] == '1',
            beds: int.tryParse(v['beds'] ?? '') ?? 100,
            rating: double.tryParse(v['rating'] ?? '') ?? 4.5,
            reviews: 0,
            waitMin: 15,
            distanceKm: 3.0,
            verified: true,
          ));
          notifyListeners();
        },
        update: (id, v) {
          final i = hospitals.indexWhere((h) => h.id == id);
          if (i < 0) return;
          final h = hospitals[i];
          hospitals[i] = Hospital(
            id: h.id,
            name: v['name']!,
            location: v['location']!,
            government: v['government'] == '1',
            hasIcu: v['icu'] == '1',
            beds: int.tryParse(v['beds'] ?? '') ?? h.beds,
            rating: double.tryParse(v['rating'] ?? '') ?? h.rating,
            reviews: h.reviews,
            waitMin: h.waitMin,
            distanceKm: h.distanceKm,
            verified: h.verified,
            active: h.active,
          );
          notifyListeners();
        },
        remove: (id) {
          hospitals.removeWhere((h) => h.id == id);
          notifyListeners();
        },
        rowActive: (r) =>
            hospitals.firstWhere((h) => h.id == r['id']).active,
        setRowActive: (id, v) {
          final i = hospitals.indexWhere((h) => h.id == id);
          if (i < 0) return;
          final h = hospitals[i];
          hospitals[i] = Hospital(
            id: h.id,
            name: h.name,
            location: h.location,
            government: h.government,
            hasIcu: h.hasIcu,
            beds: h.beds,
            rating: h.rating,
            reviews: h.reviews,
            waitMin: h.waitMin,
            distanceKm: h.distanceKm,
            verified: h.verified,
            active: v,
          );
          notifyListeners();
        },
      );

  EntitySpec labSpec() => EntitySpec(
        title: 'Labs',
        singular: 'Lab',
        fields: const [
          FieldSpec(key: 'name', label: 'Name', required: true),
          FieldSpec(key: 'location', label: 'Location'),
          FieldSpec(key: 'tests', label: 'Test count', type: 'number'),
          FieldSpec(key: 'rating', label: 'Rating', type: 'number'),
          FieldSpec(key: 'nabl', label: 'NABL Accredited', type: 'toggle'),
        ],
        read: () => labs
            .map((l) => {
                  'id': l.id,
                  'name': l.name,
                  'location': l.location,
                  'tests': l.testCount.toString(),
                  'rating': l.rating.toString(),
                  'nabl': l.nabl ? '1' : '0',
                })
            .toList(),
        create: (v) {
          labs.add(Lab(
            id: 'l${DateTime.now().millisecondsSinceEpoch}',
            name: v['name']!,
            location: v['location']!,
            testCount: int.tryParse(v['tests'] ?? '') ?? 100,
            offers: 2,
            turnaround: '6-12 hrs',
            rating: double.tryParse(v['rating'] ?? '') ?? 4.5,
            reviews: 0,
            nabl: v['nabl'] == '1',
            verified: true,
            distanceKm: 2.5,
          ));
          notifyListeners();
        },
        update: (id, v) {
          final i = labs.indexWhere((l) => l.id == id);
          if (i < 0) return;
          final l = labs[i];
          labs[i] = Lab(
            id: l.id,
            name: v['name']!,
            location: v['location']!,
            testCount: int.tryParse(v['tests'] ?? '') ?? l.testCount,
            offers: l.offers,
            turnaround: l.turnaround,
            rating: double.tryParse(v['rating'] ?? '') ?? l.rating,
            reviews: l.reviews,
            nabl: v['nabl'] == '1',
            verified: l.verified,
            distanceKm: l.distanceKm,
            active: l.active,
          );
          notifyListeners();
        },
        remove: (id) {
          labs.removeWhere((l) => l.id == id);
          notifyListeners();
        },
        rowActive: (r) => labs.firstWhere((l) => l.id == r['id']).active,
        setRowActive: (id, v) {
          final i = labs.indexWhere((l) => l.id == id);
          if (i < 0) return;
          final l = labs[i];
          labs[i] = Lab(
            id: l.id,
            name: l.name,
            location: l.location,
            testCount: l.testCount,
            offers: l.offers,
            turnaround: l.turnaround,
            rating: l.rating,
            reviews: l.reviews,
            nabl: l.nabl,
            verified: l.verified,
            distanceKm: l.distanceKm,
            active: v,
          );
          notifyListeners();
        },
      );

  EntitySpec pharmacySpec() => EntitySpec(
        title: 'Pharmacies',
        singular: 'Pharmacy',
        fields: const [
          FieldSpec(key: 'name', label: 'Name', required: true),
          FieldSpec(key: 'location', label: 'Location'),
          FieldSpec(key: 'delivery', label: 'Delivery time'),
          FieldSpec(key: 'rating', label: 'Rating', type: 'number'),
        ],
        read: () => pharmacies
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'location': p.location,
                  'delivery': p.deliveryTime,
                  'rating': p.rating.toString(),
                })
            .toList(),
        create: (v) {
          pharmacies.add(Pharmacy(
            id: 'p${DateTime.now().millisecondsSinceEpoch}',
            name: v['name']!,
            location: v['location']!,
            rating: double.tryParse(v['rating'] ?? '') ?? 4.5,
            reviews: 0,
            deliveryTime: v['delivery']!.isEmpty ? '30-45 min' : v['delivery']!,
            itemCount: 60,
            offers: 2,
            verified: true,
            distanceKm: 2.0,
          ));
          notifyListeners();
        },
        update: (id, v) {
          final i = pharmacies.indexWhere((p) => p.id == id);
          if (i < 0) return;
          final p = pharmacies[i];
          pharmacies[i] = Pharmacy(
            id: p.id,
            name: v['name']!,
            location: v['location']!,
            rating: double.tryParse(v['rating'] ?? '') ?? p.rating,
            reviews: p.reviews,
            deliveryTime: v['delivery']!,
            itemCount: p.itemCount,
            offers: p.offers,
            verified: p.verified,
            distanceKm: p.distanceKm,
            active: p.active,
          );
          notifyListeners();
        },
        remove: (id) {
          pharmacies.removeWhere((p) => p.id == id);
          notifyListeners();
        },
        rowActive: (r) =>
            pharmacies.firstWhere((p) => p.id == r['id']).active,
        setRowActive: (id, v) {
          final i = pharmacies.indexWhere((p) => p.id == id);
          if (i < 0) return;
          final p = pharmacies[i];
          pharmacies[i] = Pharmacy(
            id: p.id,
            name: p.name,
            location: p.location,
            rating: p.rating,
            reviews: p.reviews,
            deliveryTime: p.deliveryTime,
            itemCount: p.itemCount,
            offers: p.offers,
            verified: p.verified,
            distanceKm: p.distanceKm,
            active: v,
          );
          notifyListeners();
        },
      );

  EntitySpec medicineSpec() => EntitySpec(
        title: 'Medicines',
        singular: 'Medicine',
        fields: const [
          FieldSpec(key: 'name', label: 'Name', required: true),
          FieldSpec(key: 'pack', label: 'Pack'),
          FieldSpec(key: 'brand', label: 'Brand'),
          FieldSpec(key: 'price', label: 'Price (₹)', type: 'number'),
          FieldSpec(key: 'mrp', label: 'MRP (₹)', type: 'number'),
          FieldSpec(key: 'category', label: 'Category'),
          FieldSpec(key: 'rx', label: 'Rx required', type: 'toggle'),
        ],
        read: () => medicines
            .map((m) => {
                  'id': m.id,
                  'name': m.name,
                  'pack': m.pack,
                  'brand': m.brand,
                  'price': m.price.toStringAsFixed(0),
                  'mrp': m.mrp.toStringAsFixed(0),
                  'category': m.category,
                  'rx': m.rxRequired ? '1' : '0',
                })
            .toList(),
        create: (v) {
          medicines.add(Medicine(
            id: 'm${DateTime.now().millisecondsSinceEpoch}',
            pharmacyId: 'p0',
            name: v['name']!,
            pack: v['pack']!,
            brand: v['brand']!,
            price: double.tryParse(v['price'] ?? '') ?? 100,
            mrp: double.tryParse(v['mrp'] ?? '') ?? 120,
            rxRequired: v['rx'] == '1',
            category: v['category']!.isEmpty ? 'General' : v['category']!,
          ));
          notifyListeners();
        },
        update: (id, v) {
          final i = medicines.indexWhere((m) => m.id == id);
          if (i < 0) return;
          final m = medicines[i];
          medicines[i] = Medicine(
            id: m.id,
            pharmacyId: m.pharmacyId,
            name: v['name']!,
            pack: v['pack']!,
            brand: v['brand']!,
            price: double.tryParse(v['price'] ?? '') ?? m.price,
            mrp: double.tryParse(v['mrp'] ?? '') ?? m.mrp,
            rxRequired: v['rx'] == '1',
            category: v['category']!,
            active: m.active,
          );
          notifyListeners();
        },
        remove: (id) {
          medicines.removeWhere((m) => m.id == id);
          notifyListeners();
        },
        rowActive: (r) =>
            medicines.firstWhere((m) => m.id == r['id']).active,
        setRowActive: (id, v) {
          final i = medicines.indexWhere((m) => m.id == id);
          if (i < 0) return;
          final m = medicines[i];
          medicines[i] = Medicine(
            id: m.id,
            pharmacyId: m.pharmacyId,
            name: m.name,
            pack: m.pack,
            brand: m.brand,
            price: m.price,
            mrp: m.mrp,
            rxRequired: m.rxRequired,
            category: m.category,
            active: v,
          );
          notifyListeners();
        },
      );
}

/// Field descriptor for the generic admin CRUD dialog.
class FieldSpec {
  final String key;
  final String label;
  final String type; // text, number, toggle
  final bool required;

  const FieldSpec({
    required this.key,
    required this.label,
    this.type = 'text',
    this.required = false,
  });
}

/// Wiring spec for one admin-managed entity collection.
class EntitySpec {
  final String title;
  final String singular;
  final List<FieldSpec> fields;
  final List<Map<String, String>> Function() read;
  final void Function(Map<String, String>) create;
  final void Function(String id, Map<String, String>) update;
  final void Function(String id) remove;
  final bool Function(Map<String, String> row)? rowActive;
  final void Function(String id, bool v)? setRowActive;

  const EntitySpec({
    required this.title,
    required this.singular,
    required this.fields,
    required this.read,
    required this.create,
    required this.update,
    required this.remove,
    this.rowActive,
    this.setRowActive,
  });
}

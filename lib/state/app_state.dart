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
  AppState();

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

  /// The signed-in Supabase user id, or null.
  String? get supaUserId => _supaUser?.id;

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
    // Admin-controlled app config: branding, fees, emergency numbers,
    // maintenance mode (also for guests).
    unawaited(loadAppConfig());
    // Admin announcements shown in-app.
    unawaited(loadLatestAnnouncements());
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

  /// True while the phone navigation drawer is open; the bottom nav
  /// hides while the drawer is visible.
  bool _drawerOpen = false;
  bool get drawerOpen => _drawerOpen;
  set drawerOpen(bool v) {
    if (_drawerOpen == v) return;
    _drawerOpen = v;
    notifyListeners();
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
  String get userName {
    // Prefer the explicitly saved name (profile edits) over auth metadata.
    if (_name.isNotEmpty && _name != 'Patient') return _name;
    return _supaUser != null
        ? AuthService.instance.displayNameOf(_supaUser!)
        : _name;
  }

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

  /// Completes registration after the email OTP was verified (the user is
  /// already signed in at this point): sets the password and the profile
  /// name. Returns failure if the email already belongs to a finished
  /// account (profile has a name) so the caller can sign the user in.
  Future<AuthResult> completeOtpSignup({
    required String name,
    required String password,
    String? phone,
    String? gender,
    String? dateOfBirth,
  }) async {
    final existing = await _repo.fetchProfile();
    final existingName =
        '${existing?['full_name'] ?? ''}'.trim();
    if (existingName.isNotEmpty) {
      return const AuthResult.failure(
          'An account with this email already exists. Signed you in instead.');
    }
    final pw = await AuthService.instance.updatePassword(password);
    if (!pw.ok) return pw;
    // Store the typed name in the auth user's metadata too, so the app
    // never falls back to showing the email prefix as the display name.
    await AuthService.instance.updateUserMetadata({
      'display_name': name,
      'full_name': name,
    });
    final profile = <String, dynamic>{'full_name': name};
    if (phone != null && phone.isNotEmpty) profile['phone'] = phone;
    if (gender != null && gender.isNotEmpty) profile['gender'] = gender;
    if (dateOfBirth != null && dateOfBirth.isNotEmpty) {
      profile['date_of_birth'] = dateOfBirth;
    }
    await _repo.saveProfile(profile);
    // Set local fields immediately (no waiting on a profile re-fetch).
    _name = name;
    if (phone != null && phone.isNotEmpty) _phone = phone;
    if (gender != null && gender.isNotEmpty) _gender = gender;
    _syncUserFromSession();
    return const AuthResult.success();
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
    // Pop any pushed pages: after logout the RootGate shows the dashboard
    // in guest-browsing state, and inner screens must not linger on top
    // with the gates down.
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

  /// Direct access to the Supabase repository (for partner dashboards).
  SupabaseRepository get supabaseRepository => _repo;

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
    // Same pharmacy if IDs match, or names match (handles ID format
    // inconsistencies across screens).
    final samePharmacy = cartPharmacyId == null ||
        cartPharmacyId == pharmacyId ||
        (cartPharmacyName != null &&
            cartPharmacyName!.toLowerCase() ==
                pharmacyName.toLowerCase());
    if (!samePharmacy) return false;
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

  final List<String> prescriptionsSeed = const [];

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

  void removeFromCart(String medicineId) {
    cart.removeWhere((l) => l.medicine.id == medicineId);
    if (cart.isEmpty) {
      cartPharmacyId = null;
      cartPharmacyName = null;
    }
    notifyListeners();
  }

  /// Removes a cart line by object identity - cannot fail on ID mismatch.
  void removeCartLine(CartLine line) {
    cart.remove(line);
    if (cart.isEmpty) {
      cartPharmacyId = null;
      cartPharmacyName = null;
    }
    notifyListeners();
  }

  void setDriverOnline(bool v) {
    driverOnline = v;
    notifyListeners();
  }

  // ================= ADMIN =================
  // Supabase-backed admin controls. Writes require the signed-in user to
  // hold the 'admin' role (enforced by RLS policies); reads degrade
  // gracefully when offline or not admin.

  bool _isAdmin = false;

  /// Whether the signed-in user holds the admin role.
  bool get isAdmin => _isAdmin;

  Future<void> checkAdminRole() async {
    _isAdmin = await _repo.isCurrentUserAdmin();
    notifyListeners();
  }

  String? _providerRole;

  /// The signed-in user's provider role (doctor/pharmacy/lab/hospital).
  String? get providerRole => _providerRole;

  Future<void> checkProviderRole() async {
    _providerRole = await AuthService.instance.currentUserRole();
    notifyListeners();
  }

  // ---------- App config ----------

  final Map<String, Map<String, dynamic>> _appConfig = {};

  /// One app_config entry (branding, fees, emergency, maintenance...).
  Map<String, dynamic> appConfigValue(String key) => _appConfig[key] ?? {};

  Future<void> loadAppConfig() async {
    final cfg = await _repo.fetchAppConfig();
    _appConfig
      ..clear()
      ..addAll(cfg);
    // Apply maintenance mode immediately (RootGate gates on it).
    final maint = cfg['maintenance'];
    if (maint is Map<String, dynamic>) {
      _maintenanceMode = maint['enabled'] == true;
    }
    notifyListeners();
  }

  /// Delivery fee from admin Settings (fees.delivery_fee), default ₹30.
  double get deliveryFee =>
      ((appConfigValue('fees')['delivery_fee'] as num?)?.toDouble() ??
          30);

  /// Free-delivery threshold from admin Settings, default ₹499.
  double get freeDeliveryThreshold =>
      ((appConfigValue('fees')['free_delivery_threshold'] as num?)
              ?.toDouble() ??
          499);

  /// Emergency numbers from admin Settings (emergency.numbers).
  List<(String, String)> get emergencyNumbers {
    final raw = appConfigValue('emergency')['numbers'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => (
                '${m['label'] ?? 'Emergency'}',
                '${m['number'] ?? ''}'
              ))
          .where((e) => e.$2.isNotEmpty)
          .toList();
    }
    return const [
      ('Ambulance', '108'),
      ('Emergency', '112'),
    ];
  }

  /// SOS message from admin Settings.
  String get sosMessage =>
      '${appConfigValue('emergency')['sos_message'] ?? 'Emergency! I need help.'}';

  /// Support contact from admin Settings.
  String get supportPhone =>
      '${appConfigValue('support')['phone'] ?? ''}';
  String get supportEmail =>
      '${appConfigValue('support')['email'] ?? 'support@remedoo.app'}';

  // ---------- Announcements (admin broadcast -> in-app) ----------

  List<Map<String, dynamic>> _latestAnnouncements = [];

  List<Map<String, dynamic>> get latestAnnouncements =>
      _latestAnnouncements;

  Future<void> loadLatestAnnouncements() async {
    _latestAnnouncements =
        await _repo.fetchLatestAnnouncements();
    notifyListeners();
  }

  /// Dismisses an announcement for this session.
  void dismissAnnouncement(int index) {
    if (index >= 0 && index < _latestAnnouncements.length) {
      _latestAnnouncements.removeAt(index);
      notifyListeners();
    }
  }

  Future<bool> saveAppConfigValue(
      String key, Map<String, dynamic> value) async {
    final ok = await _repo.saveAppConfig(key, value);
    if (ok) {
      _appConfig[key] = value;
      notifyListeners();
    }
    return ok;
  }

  // ---------- Generic catalog tables ----------

  final Map<String, List<Map<String, dynamic>>> _adminTables = {};

  /// Raw rows of a catalog table as last loaded by [loadAdminTable].
  List<Map<String, dynamic>> adminTable(String t) =>
      _adminTables[t] ?? const [];

  Future<void> loadAdminTable(String t) async {
    _adminTables[t] = await _repo.adminFetchAll(t);
    notifyListeners();
  }

  Future<bool> adminSaveRow(
      String t, Map<String, dynamic> row) async {
    final id = await _repo.adminUpsert(t, row);
    if (id != null) {
      await loadAdminTable(t);
      return true;
    }
    return false;
  }

  Future<bool> adminDeleteRow(String t, String id) async {
    final ok = await _repo.adminDelete(t, id);
    if (ok) {
      _adminTables[t]?.removeWhere((r) => '${r['id']}' == id);
      notifyListeners();
    }
    return ok;
  }

  // ---------- Provider applications (DB-backed) ----------

  final List<Map<String, dynamic>> _adminProviderApplications = [];

  List<Map<String, dynamic>> get adminProviderApplications =>
      _adminProviderApplications;

  Future<void> loadAdminProviderApplications() async {
    _adminProviderApplications
      ..clear()
      ..addAll(await _repo.fetchProviderApplications());
    notifyListeners();
  }

  /// Submits a provider application to the database.
  Future<bool> submitProviderApplicationDb(
      Map<String, dynamic> app) async {
    final row = Map<String, dynamic>.from(app);
    final uid = _supaUser?.id;
    if (uid != null) row['user_id'] = uid;
    final id = await _repo.submitProviderApplication(row);
    return id != null;
  }

  static const _appTypeToTable = <String, String>{
    'doctor': 'doctors',
    'hospital': 'hospitals',
    'lab': 'labs',
    'pharmacy': 'pharmacies',
  };

  /// Approves/rejects a provider application. On approval a provider
  /// record is created in the matching catalog table and linked to the
  /// applicant's user id. Returns true only if everything succeeded.
  Future<bool> decideProviderApplication(String id, String status,
      Map<String, dynamic> app) async {
    final ok = await _repo.decideProviderApplication(id, status);
    if (!ok) return false;
    if (status == 'approved') {
      final providerType = '${app['provider_type'] ?? ''}';
      final table = _appTypeToTable[providerType];
      if (table == null) return false;
      final row = <String, dynamic>{
        'name': app['name'],
        'phone': app['phone'],
        'user_id': app['user_id'],
        'approval_status': 'approved',
        'admin_note':
            'License: ${app['license_no'] ?? ''} (via application $id)',
      };
      if (table == 'doctors') {
        row['bio'] = app['address'];
      } else {
        row['location'] = app['address'];
      }
      final newId = await _repo.adminUpsert(table, row);
      if (newId == null) return false;
      // Grant the provider role so they can sign in to the Partner app.
      await _repo.grantUserRole('${app['user_id']}', providerType);
    }
    await loadAdminProviderApplications();
    return true;
  }

  // ---------- Announcements ----------

  final List<Map<String, dynamic>> _announcements = [];

  List<Map<String, dynamic>> get announcements => _announcements;

  Future<void> loadAnnouncements() async {
    _announcements
      ..clear()
      ..addAll(await _repo.fetchAnnouncements());
    notifyListeners();
  }

  Future<bool> createAnnouncement(
      String title, String message, String audience) async {
    final ok = await _repo.createAnnouncement(title, message, audience);
    if (ok) await loadAnnouncements();
    return ok;
  }

  Future<bool> deleteAnnouncement(String id) async {
    final ok = await _repo.deleteAnnouncement(id);
    if (ok) {
      _announcements.removeWhere((a) => '${a['id']}' == id);
      notifyListeners();
    }
    return ok;
  }

  // ---------- Users ----------

  final List<Map<String, dynamic>> _allProfiles = [];

  List<Map<String, dynamic>> get allProfiles => _allProfiles;

  Future<void> loadAllProfiles() async {
    _allProfiles
      ..clear()
      ..addAll(await _repo.fetchAllProfiles());
    notifyListeners();
  }

  // ---------- Operations ----------

  final List<Map<String, dynamic>> _adminOrders = [];

  List<Map<String, dynamic>> get adminOrders => _adminOrders;

  Future<void> loadAdminOrders() async {
    _adminOrders
      ..clear()
      ..addAll(await _repo.adminFetchOrders());
    notifyListeners();
  }

  Future<bool> updateAdminOrder(
      String id, Map<String, dynamic> fields) async {
    final ok = await _repo.adminUpdateOrder(id, fields);
    if (ok) {
      for (final o in _adminOrders) {
        if ('${o['id']}' == id) o.addAll(fields);
      }
      notifyListeners();
    }
    return ok;
  }

  final List<Map<String, dynamic>> _adminAppointments = [];

  List<Map<String, dynamic>> get adminAppointments => _adminAppointments;

  Future<void> loadAdminAppointments() async {
    _adminAppointments
      ..clear()
      ..addAll(await _repo.adminFetchAppointments());
    notifyListeners();
  }

  Future<bool> updateAdminAppointment(
      String id, Map<String, dynamic> fields) async {
    final ok = await _repo.adminUpdateAppointment(id, fields);
    if (ok) {
      for (final a in _adminAppointments) {
        if ('${a['id']}' == id) a.addAll(fields);
      }
      notifyListeners();
    }
    return ok;
  }

  final List<Map<String, dynamic>> _supportTickets = [];

  List<Map<String, dynamic>> get supportTickets => _supportTickets;

  Future<void> loadSupportTickets() async {
    _supportTickets
      ..clear()
      ..addAll(await _repo.fetchSupportTickets());
    notifyListeners();
  }

  Future<bool> updateSupportTicket(
      String id, Map<String, dynamic> fields) async {
    final ok = await _repo.updateSupportTicket(id, fields);
    if (ok) {
      for (final t in _supportTickets) {
        if ('${t['id']}' == id) t.addAll(fields);
      }
      notifyListeners();
    }
    return ok;
  }

  final List<Map<String, dynamic>> _refunds = [];

  List<Map<String, dynamic>> get refunds => _refunds;

  Future<void> loadRefunds() async {
    _refunds
      ..clear()
      ..addAll(await _repo.fetchRefunds());
    notifyListeners();
  }

  Future<bool> updateRefund(String id, String status) async {
    final ok = await _repo.updateRefund(id, status);
    if (ok) {
      for (final r in _refunds) {
        if ('${r['id']}' == id) r['status'] = status;
      }
      notifyListeners();
    }
    return ok;
  }

  final List<Map<String, dynamic>> _emergencyRequests = [];

  List<Map<String, dynamic>> get emergencyRequests => _emergencyRequests;

  Future<void> loadEmergencyRequests() async {
    _emergencyRequests
      ..clear()
      ..addAll(await _repo.fetchEmergencyRequests());
    notifyListeners();
  }

  Future<bool> updateEmergencyRequest(
      String id, Map<String, dynamic> fields) async {
    final ok = await _repo.updateEmergencyRequest(id, fields);
    if (ok) {
      for (final r in _emergencyRequests) {
        if ('${r['id']}' == id) r.addAll(fields);
      }
      notifyListeners();
    }
    return ok;
  }

  final List<Map<String, dynamic>> _ambulances = [];

  List<Map<String, dynamic>> get ambulances => _ambulances;

  Future<void> loadAmbulances() async {
    _ambulances
      ..clear()
      ..addAll(await _repo.fetchAmbulances());
    notifyListeners();
  }

  Future<bool> updateAmbulance(
      String id, Map<String, dynamic> fields) async {
    final ok = await _repo.updateAmbulance(id, fields);
    if (ok) {
      for (final a in _ambulances) {
        if ('${a['id']}' == id) a.addAll(fields);
      }
      notifyListeners();
    }
    return ok;
  }

  // ---------- Provider payments ----------

  /// Updates a provider's payment settings in the catalog table, then
  /// refreshes that table's admin rows.
  Future<bool> updateProviderPayment(String table, String id,
      {String? upiId, bool? upiEnabled, bool? payInClinicEnabled}) async {
    final ok = await _repo.updateProviderPayment(table, id,
        upiId: upiId,
        upiEnabled: upiEnabled,
        payInClinicEnabled: payInClinicEnabled);
    if (ok) await loadAdminTable(table);
    return ok;
  }

  /// Saves the provider's UPI ID. Returns true on success.
  /// The UPI ID is stored in the user's profile and on the provider's own
  /// catalog record (so patients paying that provider use the right ID).
  Future<bool> saveProviderUpiId(String upiId) async {
    // Save to profiles table
    final saved = await _repo.saveProfile({'upi_id': upiId});
    if (saved) {
      _providerUpiId = upiId;
      // Also write the UPI ID onto the provider's own catalog record so
      // patients paying that provider are shown the correct ID.
      final uid = _supaUser?.id;
      if (uid != null) {
        for (final table in _appTypeToTable.values) {
          await _repo.setProviderUpiOnRecord(table, uid, upiId);
        }
      }
      notifyListeners();
    }
    return saved;
  }

  String? _providerUpiId;
  String? get providerUpiId => _providerUpiId;

  /// Checks if the UPI setup popup should be shown:
  /// user has an approved provider application but no UPI ID set.
  bool get shouldShowUpiSetup {
    if (!isSignedIn) return false;
    if (_providerUpiId?.isNotEmpty ?? false) return false;
    final email = this.email;
    return providerApplications.any((a) =>
        a.email == email && a.status == 'approved');
  }

  Future<bool> updateProfile(
      {String? name, String? phone, String? address}) async {
    if (name != null) _name = name;
    if (phone != null) _phone = phone;
    if (address != null) _address = address;
    // Persist to Supabase so the name/phone survive reloads.
    bool saved = true;
    final fields = <String, dynamic>{};
    if (name != null) fields['full_name'] = name;
    if (phone != null) fields['phone'] = phone;
    if (fields.isNotEmpty) {
      saved = await _repo.saveProfile(fields);
    }
    notifyListeners();
    return saved;
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
    String? upiId,
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
}

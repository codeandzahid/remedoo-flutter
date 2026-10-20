import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/auth_url.dart';
import 'supabase_config.dart';

/// Result of an auth attempt: either a signed-in user or a friendly error.
class AuthResult {
  final bool ok;
  final String? error;
  final bool confirmationRequired;

  const AuthResult._({
    required this.ok,
    this.error,
    this.confirmationRequired = false,
  });

  const AuthResult.success() : this._(ok: true);
  const AuthResult.needsConfirmation()
      : this._(ok: true, confirmationRequired: true);
  const AuthResult.failure(String error) : this._(ok: false, error: error);
}

/// Where an email address stands in the signup flow (see
/// [AuthService.emailSignupState]).
enum EmailSignupState {
  /// No account with this email: a fresh signup.
  newAccount,

  /// An account exists but signup was never finished (Step 2 not
  /// completed). The owner may resume and finish the SAME account.
  incomplete,

  /// A finished account: the duplicate-email guard blocks signup and
  /// points the user to log in instead.
  complete,
}

/// What an auth-callback URL landing turned out to be, decided by
/// [AuthService.callbackKindFor] from the session exchange's redirect
/// type and the resulting user's confirmation timestamp.
enum AuthCallbackKind {
  /// No callback in the URL, or the exchange failed / left no session
  /// (expired or already-used link): boot continues untouched.
  none,

  /// Password-recovery return: RootGate shows ResetPasswordScreen,
  /// exactly as it always has (decided by gotrue's passwordRecovery
  /// event, not by this classification).
  recovery,

  /// Signup email-confirmation return (the "Verify automatically" /
  /// "Confirm email address" link in the confirmation email): the
  /// account's email was confirmed by this very landing, so RootGate
  /// shows the Email Verified screen before anything else.
  emailConfirmation,

  /// Any other link sign-in — e.g. a magic link for an account whose
  /// email was confirmed long ago: an ordinary sign-in that lands in
  /// the app as usual, with no Verified screen and no sign-out.
  signIn,
}

/// The outcome of processing the page URL's auth callback
/// ([AuthService.handleAuthCallbackFromUrl]).
class AuthCallbackResult {
  final AuthCallbackKind kind;
  final bool sessionEstablished;

  const AuthCallbackResult(
    this.kind, {
    this.sessionEstablished = false,
  });

  /// No callback was processed (plain URL, offline, or failed exchange).
  static const AuthCallbackResult none =
      AuthCallbackResult(AuthCallbackKind.none);
}

/// Wraps Supabase Auth for the Remedoo app.
///
/// - Email/password sign-up (with optional email confirmation), sign-in,
///   magic-link sign-in, password reset via email, sign-out.
/// - Session persistence + auto-refresh are handled by supabase_flutter
///   (secure web storage on the website).
/// - Passwords are never stored or logged anywhere; hashing is done
///   server-side by Supabase.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// Test-only: disables the token auto-refresh timer (which would otherwise
  /// keep a periodic Timer pending and break pumpAndSettle in widget tests).
  /// Production always keeps auto-refresh enabled.
  @visibleForTesting
  static bool disableAutoRefresh = false;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  SupabaseClient get _client => Supabase.instance.client;

  /// Public accessor for the data layer (repository). Only valid after
  /// [init] succeeded ([isInitialized]); guard with that flag.
  SupabaseClient get client => _client;

  /// Must be called once during app boot (RootGate shows the splash meanwhile).
  /// Never throws and never hangs: after [initTimeout] without a result the
  /// app falls back to guest/mock mode (offline).
  static const initTimeout = Duration(seconds: 8);

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: !disableAutoRefresh,
          // Do NOT let supabase_flutter exchange the auth code from the
          // page URL during initialize(): it emits signedIn /
          // passwordRecovery on a broadcast stream at that moment —
          // before AppState has subscribed — so a password-recovery
          // return was silently consumed as a normal sign-in and the
          // new-password screen never appeared. The app exchanges the
          // URL itself in [handleAuthCallbackFromUrl], which
          // AppState.attachAuthListener calls AFTER subscribing.
          detectSessionInUri: false,
        ),
      ).timeout(initTimeout);
      _initialized = true;
    } on TimeoutException {
      debugPrint('Supabase init timed out, continuing in offline mode');
      _initialized = false;
    } catch (e) {
      debugPrint('Supabase init failed, continuing in offline mode: $e');
      _initialized = false;
    }
  }

  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  /// True when [uri] carries Supabase auth-callback parameters: a PKCE
  /// `code`, implicit-flow tokens (`access_token` / `token_hash`), or an
  /// auth `error` — in the query string or the fragment. Plain app URLs
  /// (no query, or unrelated parameters) return false.
  static bool isAuthCallbackUri(Uri uri) {
    bool hasAuthKey(Map<String, String> params) =>
        params.containsKey('code') ||
        params.containsKey('access_token') ||
        params.containsKey('token_hash') ||
        params.containsKey('error') ||
        params.containsKey('error_description');
    if (hasAuthKey(uri.queryParameters)) return true;
    if (uri.fragment.isNotEmpty) {
      try {
        return hasAuthKey(Uri.splitQueryString(uri.fragment));
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// How long before the URL exchange an email confirmation still
  /// counts as "confirmed by this landing". GoTrue stamps
  /// `email_confirmed_at` at the moment the emailed link is tapped,
  /// seconds before it redirects back into the app, so a confirmation
  /// return always falls inside this window; a magic-link sign-in for
  /// an established account carries a confirmation timestamp from
  /// signup day instead and never does.
  static const confirmationLandingWindow = Duration(minutes: 15);

  /// Classifies an auth-callback URL exchange into an
  /// [AuthCallbackKind]. Pure and testable: the decision inputs are
  /// the exchange's own signals, nothing else.
  ///
  /// [redirectType] is gotrue's marker for the exchange: the string
  /// 'passwordRecovery' when the flow was started as a password reset
  /// in this browser (PKCE verifier suffix), or the landing URL's
  /// `type` parameter on implicit returns ('recovery', 'signup',
  /// 'magiclink', …). A PKCE *confirmation* return carries no marker
  /// at all — the URL is just `?code=` — so it is recognised by
  /// [emailConfirmedAt] (the resulting user's `email_confirmed_at`):
  /// only a landing that itself confirmed the email has that
  /// timestamp within [confirmationLandingWindow] of the exchange
  /// (a few minutes of clock skew in the other direction is allowed).
  static AuthCallbackKind callbackKindFor({
    required bool sessionEstablished,
    required String? redirectType,
    required String? emailConfirmedAt,
    required DateTime now,
  }) {
    if (!sessionEstablished) return AuthCallbackKind.none;
    final type = (redirectType ?? '').trim().toLowerCase();
    if (type == 'passwordrecovery' || type == 'recovery') {
      return AuthCallbackKind.recovery;
    }
    if (type == 'signup') return AuthCallbackKind.emailConfirmation;
    final confirmedAt = DateTime.tryParse(emailConfirmedAt ?? '');
    if (confirmedAt != null) {
      final delta = now.difference(confirmedAt);
      if (delta >= const Duration(minutes: -5) &&
          delta <= confirmationLandingWindow) {
        return AuthCallbackKind.emailConfirmation;
      }
    }
    return AuthCallbackKind.signIn;
  }

  /// Exchanges the auth callback in the current page URL (web) for a
  /// session: password-recovery, email-confirmation and magic-link
  /// returns all arrive this way (a `?code=` in the URL).
  ///
  /// MUST be called only after the app has subscribed to
  /// [authStateChanges] — the exchange is what emits the signedIn /
  /// passwordRecovery events, and the stream does not replay them
  /// (see [init] for why supabase_flutter's automatic handling is
  /// disabled). Never throws: an expired or already-used link just
  /// returns [AuthCallbackResult.none] and boot continues with
  /// whatever session (if any) was restored. On success the result
  /// also classifies the landing (see [callbackKindFor]) so callers
  /// can tell a signup confirmation return — which shows the Email
  /// Verified screen — apart from an ordinary link sign-in.
  Future<AuthCallbackResult> handleAuthCallbackFromUrl() async {
    if (!_initialized || !kIsWeb) return AuthCallbackResult.none;
    final uri = Uri.base;
    if (!isAuthCallbackUri(uri)) return AuthCallbackResult.none;
    try {
      final response = await _client.auth.getSessionFromUrl(uri);
      clearAuthUrlParameters();
      return AuthCallbackResult(
        callbackKindFor(
          sessionEstablished: true,
          redirectType: response.redirectType,
          emailConfirmedAt: response.session.user.emailConfirmedAt,
          now: DateTime.now(),
        ),
        sessionEstablished: true,
      );
    } catch (e) {
      debugPrint('Auth callback handling failed: $e');
      return AuthCallbackResult.none;
    }
  }

  Session? get currentSession =>
      _initialized ? _client.auth.currentSession : null;

  User? get currentUser => _initialized ? _client.auth.currentUser : null;

  bool get isSignedIn => currentSession != null;

  /// Display name: user metadata `display_name` -> `full_name` -> email prefix.
  String displayNameOf(User user) {
    final meta = user.userMetadata;
    final dn = (meta?['display_name'] ?? meta?['full_name'] ?? '')
        .toString()
        .trim();
    if (dn.isNotEmpty) return dn;
    final email = user.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'Patient';
  }

  /// Create an account. Returns [AuthResult.needsConfirmation] when the
  /// project requires email confirmation (no session yet).
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': name},
        emailRedirectTo: Uri.base.origin,
      );
      if (res.session == null) {
        // Email confirmation required (or user already exists and
        // confirmation is pending) - Supabase sends the confirm email.
        return const AuthResult.needsConfirmation();
      }
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    } catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    }
  }

  /// Resend the signup confirmation email.
  Future<AuthResult> resendConfirmation(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: Uri.base.origin,
      );
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    } catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    }
  }

  /// Email + password sign-in.
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    } catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    }
  }

  /// Whether this email already belongs to a registered account.
  /// Backed by the `email_registered` RPC, which returns only true/false
  /// (no account data is exposed). Fails open (false) if the check can't
  /// run, so signup is never blocked by the check itself.
  Future<bool> emailAlreadyRegistered(String email) async {
    try {
      final res = await _client.rpc(
        'email_registered',
        params: {'check_email': email.trim()},
      );
      return res == true;
    } catch (e) {
      debugPrint('emailAlreadyRegistered failed: $e');
      return false;
    }
  }

  /// Maps an `email_signup_state` RPC value to [EmailSignupState].
  /// Anything unrecognized (including null) is treated as a new email:
  /// the send itself stays the authority on real duplicates.
  static EmailSignupState emailSignupStateFromValue(Object? value) {
    switch ('$value'.trim().toLowerCase()) {
      case 'complete':
        return EmailSignupState.complete;
      case 'incomplete':
        return EmailSignupState.incomplete;
      default:
        return EmailSignupState.newAccount;
    }
  }

  /// Signup state of an email address: no account, a half-created
  /// account (user exists but signup Step 2 was never finished — no
  /// name on the profile, no role, no name in metadata), or a finished
  /// account. Backed by the `email_signup_state` RPC
  /// (supabase/migration/email_signup_state.sql), which returns only
  /// one of those three words — no account data is exposed.
  ///
  /// The duplicate-email guard must only hard-block FINISHED accounts:
  /// a half-created account belongs to the same person returning to
  /// finish signup, and blocking them dead-ends the account (no
  /// password was ever set, so they cannot log in either). Resuming
  /// re-uses the same account — one email stays one account.
  ///
  /// If the RPC is unavailable (migration not applied yet), falls back
  /// to the plain [emailAlreadyRegistered] check: an existing email is
  /// then treated as complete, a new one as new.
  Future<EmailSignupState> emailSignupState(String email) async {
    try {
      final res = await _client.rpc(
        'email_signup_state',
        params: {'check_email': email.trim()},
      );
      return emailSignupStateFromValue(res);
    } catch (e) {
      debugPrint('emailSignupState failed, falling back: $e');
      final used = await emailAlreadyRegistered(email);
      return used
          ? EmailSignupState.complete
          : EmailSignupState.newAccount;
    }
  }

  /// Send an email OTP for registration verification.
  /// Unlike [sendMagicLink], this omits the redirect so Supabase sends a
  /// code the user types back into the form.
  ///
  /// What lands in the inbox is decided by the project's Magic Link
  /// email template (Authentication -> Email Templates -> Magic Link):
  /// it must contain {{ .Token }} — with only {{ .ConfirmationURL }}
  /// the user receives a link and no code, while this UI waits for a
  /// code (Live Test 3, 2026-10-20). [shouldCreateUser] is passed
  /// explicitly: registration relies on the OTP send creating the
  /// (unconfirmed) account that Step 2 then completes.
  Future<AuthResult> sendEmailOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    } catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    }
  }

  /// Verify the email OTP. On success the user is signed in.
  Future<AuthResult> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      final res = await _client.auth.verifyOTP(
        type: OtpType.email,
        token: token.trim(),
        email: email,
      );
      if (res.session == null) {
        return const AuthResult.failure(
            'Wrong OTP. Please check the code and try again.');
      }
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    } catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    }
  }

  /// Passwordless magic-link sign-in email.
  Future<AuthResult> sendMagicLink(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: Uri.base.origin,
      );
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    } catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    }
  }

  /// Send a password-reset email. The link redirects back to this site;
  /// on return the app exchanges the code and shows the new-password screen.
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: Uri.base.origin,
      );
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    } catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    }
  }

  /// Set custom metadata (e.g. display_name) on the auth user.
  Future<AuthResult> updateUserMetadata(Map<String, dynamic> data) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(data: data),
      );
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    } catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    }
  }

  /// Set a new password (used after clicking the recovery link).
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return const AuthResult.success();
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    } catch (e) {
      return AuthResult.failure(_friendlyMessage(e));
    }
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      // Local-scope sign-out clears the session from device storage.
      // Callers must treat this as best-effort and never await it for UI
      // flow: the underlying call can block on a network round-trip.
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Supabase signOut failed: $e');
    }
  }

  /// True when the signed-in user has the `admin` role in `user_roles`.
  Future<bool> isCurrentUserAdmin() async {
    if (!_initialized) return false;
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return false;
      final rows = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', uid)
          .eq('role', 'admin')
          .limit(1);
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('isCurrentUserAdmin failed: $e');
      return false;
    }
  }

  /// Returns the user's provider role (doctor/pharmacy/lab/hospital),
  /// or null if they don't have one.
  Future<String?> currentUserRole() async {
    if (!_initialized) return null;
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return null;
      final rows = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', uid)
          .inFilter('role', ['doctor', 'pharmacy', 'lab', 'hospital'])
          .order('role')
          .limit(1);
      if (rows.isEmpty) return null;
      return '${rows.first['role']}';
    } catch (e) {
      debugPrint('currentUserRole failed: $e');
      return null;
    }
  }

  /// The account's single backend role of ANY kind (admin, staff,
  /// doctor, pharmacy, lab, hospital, driver, user), or null when
  /// the account has no role row. The separate login entrances use
  /// this to tell the user when an email belongs to another type.
  Future<String?> currentAccountRole() async {
    if (!_initialized) return null;
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return null;
      final rows = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', uid)
          .limit(1);
      if (rows.isEmpty) return null;
      return '${rows.first['role']}';
    } catch (e) {
      debugPrint('currentAccountRole failed: $e');
      return null;
    }
  }

  /// Maps Supabase/auth errors to short, user-friendly messages.
  /// Never includes raw tokens or sensitive data.
  String _friendlyMessage(Object e) {
    final raw = e is AuthException ? e.message : e.toString();
    final m = raw.toLowerCase();
    if (m.contains('invalid login credentials') ||
        m.contains('invalid email or password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (m.contains('token has expired') ||
        m.contains('invalid token') ||
        m.contains('otp expired') ||
        m.contains('code is invalid')) {
      return 'Wrong OTP. Please check the code and try again.';
    }
    if (m.contains('email not confirmed') ||
        m.contains('email not verified')) {
      return 'Please confirm your email first - check your inbox for the confirmation link.';
    }
    if (m.contains('user already registered') ||
        m.contains('already exists') ||
        m.contains('already been registered')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (m.contains('password') &&
        (m.contains('weak') ||
            m.contains('short') ||
            m.contains('6 characters') ||
            m.contains('at least'))) {
      return 'Password is too weak - use at least 8 characters.';
    }
    if (m.contains('invalid email') || m.contains('email address')) {
      return 'Please enter a valid email address.';
    }
    if (m.contains('network') ||
        m.contains('socket') ||
        m.contains('connection') ||
        m.contains('timeout') ||
        m.contains('failed host')) {
      return 'Network error - check your connection and try again.';
    }
    if (m.contains('too many requests') || m.contains('rate limit')) {
      return 'Too many attempts - please wait a minute and try again.';
    }
    if (m.contains('expired') && m.contains('otp')) {
      return 'This link has expired - please request a new one.';
    }
    if (raw.trim().isNotEmpty && raw.length < 160 && !m.contains('token')) {
      return raw.trim();
    }
    return 'Something went wrong. Please try again.';
  }
}

/// Message shown when someone signs in at the WRONG entrance
/// (owner's rule: Admin, Panel and User logins are separate). It
/// names the account type the email is actually registered as and
/// points to the right login.
String wrongEntranceMessage(String role) {
  switch (role) {
    case 'admin':
    case 'staff':
      return 'This email is already registered as an Admin account. '
          'Please use the Admin login.';
    case 'doctor':
      return 'This email is already registered as a Doctor. '
          'Please use the Panel login.';
    case 'pharmacy':
      return 'This email is already registered as a Pharmacy. '
          'Please use the Panel login.';
    case 'lab':
      return 'This email is already registered as a Lab. '
          'Please use the Panel login.';
    case 'hospital':
      return 'This email is already registered as a Hospital. '
          'Please use the Panel login.';
    case 'driver':
      return 'This email is already registered as a Driver. '
          'Please use the Driver app.';
    default:
      return 'This email is already registered as a Patient account. '
          'Please use the User login.';
  }
}

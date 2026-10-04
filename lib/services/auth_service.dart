import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Send an email OTP for registration verification.
  /// Unlike [sendMagicLink], this omits the redirect so Supabase sends a
  /// code the user types back into the form.
  Future<AuthResult> sendEmailOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email);
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

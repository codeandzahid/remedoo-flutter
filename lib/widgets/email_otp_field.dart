import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'widgets.dart';

/// Locked card showing a verified email address (not editable).
class VerifiedEmailCard extends StatelessWidget {  final String email;

  const VerifiedEmailCard({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: RemedooTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RemedooTheme.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.verified,
              color: RemedooTheme.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  'Verified — cannot be changed',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline,
              size: 16, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
/// Email field with built-in OTP verification.
///
/// Flow: user types a complete email -> "Send OTP" button appears -> tapping
/// it emails a one-time code -> an OTP input appears -> "Verify OTP" checks the
/// code. Wrong codes show a "Wrong OTP" error; a correct code locks the field
/// with a verified badge and notifies [onVerifiedChanged].
class EmailOtpField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<bool> onVerifiedChanged;
  final String? label;
  final String hint;

  /// When true (signup / registration), an email that already belongs to
  /// an existing account is rejected with "email already used" before any
  /// OTP is sent. Leave false for login flows, where existing emails are
  /// expected.
  final bool blockExistingEmail;

  const EmailOtpField({
    super.key,
    required this.controller,
    required this.onVerifiedChanged,
    this.label = 'Email',
    this.hint = 'you@example.com',
    this.blockExistingEmail = false,
  });

  @override
  State<EmailOtpField> createState() => _EmailOtpFieldState();
}

class _EmailOtpFieldState extends State<EmailOtpField> {
  static final _emailRegex =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _otp = TextEditingController();
  bool _verified = false;
  bool _otpSent = false;
  bool _busy = false;
  String? _error;
  String? _info;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onEmailChanged);
    _otp.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onEmailChanged() {
    // Email edited after verification -> must re-verify.
    if (_verified) {
      setState(() {
        _verified = false;
        _otpSent = false;
        _otp.clear();
        _error = null;
        _info = null;
      });
      widget.onVerifiedChanged(false);
    } else if (_otpSent || _error != null || _info != null) {
      setState(() {
        _otpSent = false;
        _error = null;
        _info = null;
      });
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final email = widget.controller.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    if (widget.blockExistingEmail) {
      final used =
          await AuthService.instance.emailAlreadyRegistered(email);
      if (!mounted) return;
      if (used) {
        setState(() {
          _busy = false;
          _error =
              'This email is already used. Please log in instead.';
        });
        return;
      }
    }
    final result = await AuthService.instance.sendEmailOtp(email);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      setState(() => _error = result.error ?? 'Could not send OTP.');
      return;
    }
    setState(() {
      _otpSent = true;
      _info = 'Code sent to $email';
    });
    _startCooldown();
  }

  Future<void> _verifyOtp() async {
    final code = _otp.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Please enter the full code from the email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await AuthService.instance.verifyEmailOtp(
      email: widget.controller.text.trim(),
      token: code,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      setState(
          () => _error = result.error ?? 'Wrong OTP. Please try again.');
      return;
    }
    _timer?.cancel();
    setState(() {
      _verified = true;
      _error = null;
      _info = null;
    });
    widget.onVerifiedChanged(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RTextField(
          label: widget.label,
          hint: widget.hint,
          controller: widget.controller,
          keyboardType: TextInputType.emailAddress,
          enabled: !_verified && !_busy,
          prefixIcon:
              const Icon(Icons.email_outlined, size: 18),
          suffixIcon: _verified
              ? Icon(Icons.verified,
                  color: RemedooTheme.success, size: 20)
              : null,
        ),
        if (_verified) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle,
                  color: RemedooTheme.success, size: 16),
              const SizedBox(width: 6),
              Text(
                'Email verified',
                style: TextStyle(
                  color: RemedooTheme.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ] else if (!_otpSent) ...[
          const SizedBox(height: 10),
          RButton(
            label: 'Send OTP',
            icon: Icons.mark_email_read_outlined,
            onPressed: _busy ? null : _sendOtp,
          ),
        ] else ...[
          const SizedBox(height: 10),
          RTextField(
            label: 'Enter OTP',
            hint: 'Enter the code',
            controller: _otp,
            keyboardType: TextInputType.number,
            enabled: !_busy,
            prefixIcon:
                const Icon(Icons.pin_outlined, size: 18),
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: RButton(
                  label: 'Verify OTP',
                  icon: Icons.verified_outlined,
                  onPressed: _busy ? null : _verifyOtp,
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: (_busy || _cooldown > 0)
                    ? null
                    : _sendOtp,
                child: Text(
                  _cooldown > 0
                      ? 'Resend (${_cooldown}s)'
                      : 'Resend code',
                ),
              ),
            ],
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: 10),
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ],
        if (_info != null) ...[
          const SizedBox(height: 8),
          Text(
            _info!,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline,
                  color: RemedooTheme.emergency, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: RemedooTheme.emergency,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

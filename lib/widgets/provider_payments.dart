import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/auth_service.dart';
import '../services/supabase_repository.dart';
import '../theme.dart';
import '../utils/refunds.dart';
import 'widgets.dart';

/// Shared email-OTP gate: sends a 6-digit code to the signed-in
/// user's own account email and returns true only when the correct
/// code was entered. Used for payment activation (provider panels)
/// and for cancelling a CONFIRMED order/appointment (patients).
Future<bool> requireEmailOtp(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final email = AuthService.instance.currentUser?.email ?? '';
  if (email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Could not read your account email.')),
    );
    return false;
  }
  final sent = await AuthService.instance.sendEmailOtp(email);
  if (!sent.ok) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sent.error ?? 'Could not send the code.')),
      );
    }
    return false;
  }
  if (!context.mounted) return false;
  final ctrl = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
          children: [
          Text(
            'We sent a 6-digit code to $email. $message',
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '6-digit code',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
          child: const Text('Verify'),
        ),
      ],
    ),
  );
  if (code == null || code.isEmpty) return false;
  final res =
      await AuthService.instance.verifyEmailOtp(email: email, token: code);
  if (!res.ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res.error ?? 'Wrong code. Not saved.')),
    );
  }
  return res.ok;
}

/// Email-OTP gate for payment activation (owner's rule): switching a
/// payment option ON — or changing the UPI ID money goes to — requires
/// a 6-digit code sent to the provider's own account email. Returns
/// true only when the correct code was entered.
Future<bool> requirePaymentOtp(BuildContext context) async {
  return requireEmailOtp(
    context,
    title: 'Confirm with email code',
    message: 'Enter it here to activate this payment option.',
  );
}

/// Patient gate for cancelling an appointment (owner order
/// 2026-10-19): the confirm dialog always runs; a CONFIRMED
/// appointment (backend status) additionally needs the email code,
/// and a paid-online appointment shows that the payment is already
/// made and will be refunded in 48 hours or 3 working days.
/// Returns true only when the cancel may proceed.
Future<bool> confirmAppointmentCancel(
  BuildContext context, {
  required Appointment appt,
}) async {
  final paidOnline = appt.isPaidOnline;
  final ok = await confirmDialog(
    context,
    title: 'Cancel appointment?',
    message: 'This slot will be released. This cannot be undone.'
        '${paidOnline ? '\n\nPayment of ${inr(appt.fee)} is already made. $kRefundTimingLine' : ''}',
    confirmLabel: 'Yes, cancel',
  );
  if (!ok || !context.mounted) return false;
  if (appt.remoteStatus == 'confirmed') {
    final verified = await requireEmailOtp(
      context,
      title: 'Confirm cancellation',
      message: 'Enter it here to cancel this confirmed appointment.'
          '${paidOnline ? ' Payment of ${inr(appt.fee)} is already made — if you cancel, the provider will refund it in 48 hours or 3 working days.' : ''}',
    );
    if (!verified) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Appointment not cancelled — email code was not verified.')),
        );
      }
      return false;
    }
  }
  return context.mounted;
}

/// Panelist refund dialog (owner order 2026-10-19): shows the
/// amount and the customer's UPI, offers a "Refund now with UPI
/// app" deep link, and only allows "Mark refunded" after the
/// panelist enters the refund UTR / UPI reference number
/// (9–22 digits) — the UTR is shown to the patient as proof.
/// Returns the UTR when the refund is marked, null otherwise.
Future<String?> showRefundDialog(
  BuildContext context, {
  required double amount,
  required String? customerUpi,
  required String customerName,
  required String ref,
}) async {
  final upi = (customerUpi ?? '').trim();
  final hasUpi = upi.isNotEmpty;
  final ctrl = TextEditingController();
  final utr = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      var valid = false;
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Refund ${inr(amount)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Refund to customer UPI: '
                  '${hasUpi ? upi : 'not captured — ask the customer'}',
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Send the money back from your UPI app to the '
                  'customer\'s UPI. Then enter the refund UTR / UPI '
                  'reference number from that payment and tap '
                  '"Mark refunded".',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                RButton(
                  label: 'Refund now with UPI app',
                  icon: Icons.open_in_new,
                  fullWidth: true,
                  onPressed: hasUpi
                      ? () async {
                          final link = refundUpiLink(
                            customerUpi: upi,
                            customerName: customerName,
                            amount: amount,
                            ref: ref,
                          );
                          try {
                            await launchUrl(Uri.parse(link),
                                mode: LaunchMode.externalApplication);
                          } catch (_) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Could not open UPI app. Please pay manually to the UPI ID shown.')),
                              );
                            }
                          }
                        }
                      : null,
                ),
                if (!hasUpi) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Customer UPI not captured — refund manually from your UPI app.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  maxLength: 22,
                  decoration: const InputDecoration(
                    labelText: 'Refund UTR / UPI reference number',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onChanged: (v) =>
                      setLocal(() => valid = isValidRefundUtr(v)),
                ),
                if (!valid)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Enter the 9–22 digit UTR to enable Mark refunded.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  valid ? () => Navigator.of(ctx).pop(ctrl.text.trim()) : null,
              child: const Text('Mark refunded'),
            ),
          ],
        ),
      );
    },
  );
  return (utr != null && isValidRefundUtr(utr)) ? utr : null;
}

/// Whether saving [profile] changes requires the email-OTP gate:
/// turning a payment option ON, or changing the UPI ID while it's on.
bool paymentChangeNeedsOtp({
  required Map<String, dynamic>? profile,
  required bool upiEnabled,
  required bool payInClinic,
  required String upiId,
}) {
  final wasUpiOn = profile?['upi_enabled'] == true;
  final wasClinicOn = profile?['pay_in_clinic_enabled'] == true;
  final oldUpiId = '${profile?['upi_id'] ?? ''}'.trim();
  final activating =
      (!wasUpiOn && upiEnabled) || (!wasClinicOn && payInClinic);
  final upiChanged = upiEnabled &&
      wasUpiOn &&
      oldUpiId.isNotEmpty &&
      upiId.isNotEmpty &&
      upiId != oldUpiId;
  return activating || upiChanged;
}

/// Provider payment settings: the provider adds THEIR OWN UPI ID and
/// online payments for their bookings go straight to them (Remedoo Pay
/// per-provider UPI). Shared by the doctor / pharmacy / lab / hospital
/// panels. [table] is the provider's own table name.
class ProviderUpiSettingsCard extends StatefulWidget {
  final String table;
  final Map<String, dynamic>? profile;
  final SupabaseRepository repo;
  final VoidCallback onSaved;

  const ProviderUpiSettingsCard({
    super.key,
    required this.table,
    required this.profile,
    required this.repo,
    required this.onSaved,
  });

  @override
  State<ProviderUpiSettingsCard> createState() =>
      _ProviderUpiSettingsCardState();
}

class _ProviderUpiSettingsCardState extends State<ProviderUpiSettingsCard> {
  late final TextEditingController _upiId;
  late final TextEditingController _upiName;
  late bool _upiEnabled;
  late bool _payInClinic;
  bool _saving = false;

  static final _upiRegex = RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$');

  @override
  void initState() {
    super.initState();
    final p = widget.profile ?? {};
    _upiId = TextEditingController(text: '${p['upi_id'] ?? ''}');
    _upiName = TextEditingController(text: '${p['upi_payee_name'] ?? ''}');
    _upiEnabled = p['upi_enabled'] == true;
    _payInClinic = p['pay_in_clinic_enabled'] == true;
  }

  @override
  void dispose() {
    _upiId.dispose();
    _upiName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _upiId.text.trim();
    if (_upiEnabled && id.isNotEmpty && !_upiRegex.hasMatch(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Enter a valid UPI ID (e.g. yourname@okhdfcbank).')),
      );
      return;
    }
    if (_upiEnabled && id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter your UPI ID first, then turn this on.')),
      );
      return;
    }
    // Owner's rule: activating a payment option (or changing the UPI
    // ID) needs the email code first.
    if (paymentChangeNeedsOtp(
      profile: widget.profile,
      upiEnabled: _upiEnabled,
      payInClinic: _payInClinic,
      upiId: id,
    )) {
      final verified = await requirePaymentOtp(context);
      if (!verified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Not saved — email code was not verified.')),
          );
        }
        return;
      }
    }
    setState(() => _saving = true);
    final ok = await widget.repo.updateOwnProviderRecord(widget.table, {
      'upi_id': id.isEmpty ? null : id,
      'upi_payee_name': _upiName.text.trim().isEmpty
          ? null
          : _upiName.text.trim(),
      'upi_enabled': _upiEnabled,
      'pay_in_clinic_enabled': _payInClinic,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Payment settings saved.'
            : 'Could not save. Try again.'),
      ),
    );
    if (ok) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_upiEnabled && !_payInClinic) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: RemedooTheme.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      size: 18, color: RemedooTheme.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No payment option is ON. Turn on at least one below — patients cannot pay you until you activate one.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Get paid directly — your UPI',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'When a customer pays online for your booking, the money goes '
            'straight to YOUR UPI ID below — not to Remedoo.',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          RTextField(
            controller: _upiId,
            label: 'Your UPI ID (e.g. name@okhdfcbank)',
          ),
          const SizedBox(height: 10),
          RTextField(
            controller: _upiName,
            label: 'Name on your UPI account (optional)',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Accept online UPI payments'),
            subtitle: const Text(
                'Customers pay you online when booking'),
            value: _upiEnabled,
            onChanged: (v) => setState(() => _upiEnabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pay in person'),
            subtitle:
                const Text('Customers can choose to pay you directly'),
            value: _payInClinic,
            onChanged: (v) => setState(() => _payInClinic = v),
          ),
          const SizedBox(height: 8),
          RButton(
            label: _saving ? 'Saving…' : 'Save payment settings',
            fullWidth: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// The provider's own Remedoo Pay payments (RLS returns only their
/// rows). Money lands in the provider's own bank, so when auto-confirm
/// can't see it, the provider confirms receipt here with one tap.
class ProviderOnlinePayments extends StatefulWidget {
  final SupabaseRepository repo;

  const ProviderOnlinePayments({super.key, required this.repo});

  @override
  State<ProviderOnlinePayments> createState() =>
      _ProviderOnlinePaymentsState();
}

class _ProviderOnlinePaymentsState extends State<ProviderOnlinePayments> {
  List<Map<String, dynamic>> _sessions = [];

  /// Pharmacy orders of this provider keyed by payment_ref, so a
  /// refund requested on the order row also surfaces on its session.
  Map<String, Map<String, dynamic>> _ordersByRef = {};
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.repo.fetchRemedooPaySessions(limit: 30);
    final orders = await widget.repo.fetchPharmacyOrders();
    if (!mounted) return;
    setState(() {
      _sessions = rows;
      _ordersByRef = {
        for (final o in orders)
          if ('${o['payment_ref'] ?? ''}'.isNotEmpty)
            '${o['payment_ref']}': o,
      };
      _loading = false;
    });
  }

  /// A refund is owed on this session when its own flag says so, or
  /// when the cancelled order carrying this payment ref requested one.
  bool _refundNeeded(Map<String, dynamic> s) {
    if ('${s['refund_status'] ?? ''}' == 'requested') return true;
    final o = _ordersByRef['${s['order_id'] ?? ''}'];
    return o != null && '${o['refund_status'] ?? ''}' == 'requested';
  }

  Future<void> _doRefund(Map<String, dynamic> s) async {
    final paise = (s['amount_paise'] as num?)?.toInt() ?? 0;
    final orderRow = _ordersByRef['${s['order_id'] ?? ''}'];
    final amount = (orderRow?['refund_amount'] as num?)?.toDouble() ??
        (orderRow?['total'] as num?)?.toDouble() ??
        paise / 100;
    final cust = s['customer'];
    final custName = cust is Map ? '${cust['name'] ?? ''}' : '';
    final customerUpi = sessionCustomerUpi(s) ??
        ((orderRow?['customer_upi'] ?? '').toString().trim().isEmpty
            ? null
            : '${orderRow!['customer_upi']}');
    final utr = await showRefundDialog(
      context,
      amount: amount,
      customerUpi: customerUpi,
      customerName: custName,
      ref: '${s['order_id'] ?? ''}',
    );
    if (utr == null || !mounted) return;
    setState(() => _busyId = '${s['id']}');
    final sessionOk = await widget.repo.updateRemedooPaySession(
      '${s['id']}',
      {
        'refund_status': 'refunded',
        'refund_at': DateTime.now().toUtc().toIso8601String(),
        'refund_utr': utr,
      },
    );
    var rowOk = true;
    if (sessionOk) {
      final ref = '${s['order_id'] ?? ''}';
      final orderOk = await widget.repo
          .updateOrderRefundByPaymentRef(ref, 'refunded', refundUtr: utr);
      final apptOk = await widget.repo.updateAppointmentRefundByPaymentRef(
          ref, 'refunded',
          refundUtr: utr);
      rowOk = orderOk && apptOk;
    }
    if (!mounted) return;
    setState(() => _busyId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sessionOk
            ? (rowOk
                ? 'Refund marked as done.'
                : 'Refund marked on the payment. The booking record could not be updated — check it in your orders.')
            : 'Could not update. Try again.'),
      ),
    );
    if (sessionOk) _load();
  }

  Future<void> _act(Map<String, dynamic> s, Map<String, dynamic> patch,
      String doneMsg) async {
    setState(() => _busyId = '${s['id']}');
    final ok =
        await widget.repo.updateRemedooPaySession('${s['id']}', patch);
    if (!mounted) return;
    setState(() => _busyId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? doneMsg : 'Could not update. Try again.')),
    );
    if (ok) _load();
  }

  Color _statusColor(String st) {
    switch (st) {
      case 'SUCCESS':
        return RemedooTheme.success;
      case 'ACTIVE':
        return RemedooTheme.warning;
      case 'FAILED':
      case 'CANCELLED':
      case 'EXPIRED':
        return RemedooTheme.destructive;
      default:
        return RemedooTheme.mutedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Online payments to you',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
              ),
            ],
          ),
          Text(
            'When a customer pays, check your UPI app — then tap '
            '"Confirm Paid" here so the booking is confirmed.',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (!_loading && _sessions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RemedooTheme.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet,
                      size: 20, color: RemedooTheme.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Payment received: '
                      '${inr(totalReceivedPaise(_sessions) / 100)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${receivedCount(_sessions)} payments',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No online payments yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._sessions.map((s) {
              final st = '${s['status'] ?? ''}';
              final paise = (s['amount_paise'] as num?)?.toInt() ?? 0;
              final cust = s['customer'];
              final custName = cust is Map ? '${cust['name'] ?? ''}' : '';
              final created = '${s['created_at'] ?? ''}';
              final when = created.length >= 16
                  ? created.substring(0, 16).replaceAll('T', ' ')
                  : created;
              final busy = _busyId == '${s['id']}';
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '₹${(paise / 100).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(st)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            st,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _statusColor(st),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          when,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s['order_id'] ?? ''}'
                      '${custName.isNotEmpty ? ' · $custName' : ''}'
                      '${s['utr'] != null ? ' · UTR ${s['utr']}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paid to UPI: '
                      '${('${s['vpa'] ?? ''}'.trim().isEmpty) ? 'Remedoo central UPI' : s['vpa']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Customer: '
                      '${custName.isNotEmpty ? '$custName · ' : ''}'
                      '${sessionCustomerUpi(s) ?? 'UPI not captured'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if ('${s['refund_status'] ?? ''}' == 'refunded')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Refunded'
                          '${('${s['refund_utr'] ?? ''}'.trim().isNotEmpty) ? ' · UTR ${s['refund_utr']}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: RemedooTheme.success,
                          ),
                        ),
                      ),
                    if (_refundNeeded(s)) ...[
                      const SizedBox(height: 8),
                      RButton(
                        label: busy
                            ? 'Working…'
                            : 'Refund ${inr(paise / 100)}',
                        icon: Icons.currency_rupee,
                        small: true,
                        variant: RButtonVariant.danger,
                        onPressed: busy ? null : () => _doRefund(s),
                      ),
                    ],
                    if (st == 'ACTIVE') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RButton(
                              label: busy ? 'Working…' : 'Confirm Paid',
                              small: true,
                              onPressed: busy
                                  ? null
                                  : () => _act(
                                        s,
                                        {
                                          'status': 'SUCCESS',
                                          'paid_at': DateTime.now()
                                              .toUtc()
                                              .toIso8601String(),
                                        },
                                        'Marked as paid.',
                                      ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RButton(
                              label: 'Cancel',
                              small: true,
                              variant: RButtonVariant.danger,
                              onPressed: busy
                                  ? null
                                  : () => _act(
                                        s,
                                        {'status': 'CANCELLED'},
                                        'Payment cancelled.',
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

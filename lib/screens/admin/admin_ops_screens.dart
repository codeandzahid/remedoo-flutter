import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

// Operations screens: payouts, refunds, ambulance, drivers,
// inventory, sessions, logs, suspicious activity.

/// Payouts to providers (demo data).
class AdminPayoutsScreen extends StatelessWidget {
  const AdminPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final payouts = [
      ('Dr. Aabid Shah', 'Doctor', 12400.0, 'Pending'),
      ('CityCare Labs', 'Lab', 8300.0, 'Processed'),
      ('MediPlus Pharmacy', 'Pharmacy', 15200.0, 'Pending'),
      ('Irfan Dar (Driver)', 'Driver', 1450.0, 'Processed'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: payouts.length,
      itemBuilder: (_, i) {
        final (name, role, amount, status) = payouts[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: RemedooTheme.ratingGreen
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.payments,
                  color: RemedooTheme.ratingGreen),
            ),
            title: Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(role),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(inr(amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800)),
                StatusChip(status: status),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Refund requests with Approve / Reject → updates RefundTracking.
class AdminRefundsScreen extends StatelessWidget {
  const AdminRefundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = state.refundRequests;
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.replay,
        title: 'No refund requests',
        subtitle: 'Refund requests will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (_, i) => _card(state, list[i]),
    );
  }

  Widget _card(AppState state, RefundRequest r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Refund ${r.id}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800)),
                ),
                StatusChip(status: r.status),
              ],
            ),
            Text(
                'Order ${r.orderId} • ${inr(r.amount)} • ${r.reason}'),
            if (r.status == 'requested') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                      onPressed: () => state.setRefundStatus(
                          r.id, 'rejected'),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => state.setRefundStatus(
                          r.id, 'approved'),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ] else if (r.status == 'approved') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => state.setRefundStatus(
                      r.id, 'completed'),
                  child: const Text('Mark Completed'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ambulance fleet with status.
class AdminAmbulanceScreen extends StatefulWidget {
  const AdminAmbulanceScreen({super.key});

  @override
  State<AdminAmbulanceScreen> createState() =>
      _AdminAmbulanceScreenState();
}

class _AdminAmbulanceScreenState
    extends State<AdminAmbulanceScreen> {
  final _fleet = [
    ('AMB-101', 'Dalgate, Srinagar', 'Available'),
    ('AMB-102', 'Lal Chowk, Srinagar', 'On Trip'),
    ('AMB-201', 'Gandhi Nagar, Jammu', 'Available'),
    ('AMB-202', 'Trikuta Nagar, Jammu', 'Maintenance'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _fleet.length,
      itemBuilder: (_, i) {
        final (id, base, status) = _fleet[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: RemedooTheme.emergency
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.emergency,
                  color: RemedooTheme.emergency),
            ),
            title: Text(id,
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Base: $base'),
            trailing: DropdownButton<String>(
              value: status,
              underline: const SizedBox.shrink(),
              items: const [
                'Available',
                'On Trip',
                'Maintenance'
              ]
                  .map((s) => DropdownMenuItem(
                      value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() =>
                  _fleet[i] = (id, base, v ?? status)),
            ),
          ),
        );
      },
    );
  }
}

/// Delivery drivers + assign.
class AdminDeliveryDriversScreen extends StatelessWidget {
  const AdminDeliveryDriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final drivers = [
      ('Irfan Dar', '9906123456', 'Online'),
      ('Sahil Bhat', '9419012345', 'Online'),
      ('Danish Lone', '9906987654', 'Offline'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: drivers.length,
      itemBuilder: (_, i) {
        final (name, phone, status) = drivers[i];
        final assigned = state.deliveries
            .where((d) => d.status != 'delivered')
            .length;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: InitialsAvatar(name: name, radius: 22),
            title: Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('$phone • $assigned active'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusChip(status: status),
                IconButton(
                  icon: const Icon(Icons.assignment_ind),
                  tooltip: 'Assign delivery',
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      SnackBar(
                          content: Text(
                              'Delivery assigned to $name (demo)')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Remedoo Pharmacy stock editor.
class AdminInventoryScreen extends StatelessWidget {
  const AdminInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = state.activeMedicines.take(20).toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final m = list[i];
        final stock = state.stockOf(m.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(m.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      Text(
                          '${m.pack} • ${inr(state.priceOf(m))}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey)),
                    ],
                  ),
                ),
                QtyStepper(
                  qty: stock,
                  onMinus: () =>
                      state.setStock(m.id, stock - 1),
                  onPlus: () =>
                      state.setStock(m.id, stock + 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Active sessions (demo).
class AdminSessionsScreen extends StatelessWidget {
  const AdminSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = [
      ('Zahid Manzoor', 'Android • Srinagar', 'Active now'),
      ('Aisha Khan', 'iPhone • Jammu', '12 min ago'),
      ('Rohan Gupta', 'Web • Delhi', '1 hr ago'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sessions.length,
      itemBuilder: (_, i) {
        final (name, device, last) = sessions[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.devices,
                color: RemedooTheme.primary),
            title: Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(device),
            trailing: Text(last,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        );
      },
    );
  }
}

/// Login logs (demo).
class AdminLogsScreen extends StatelessWidget {
  const AdminLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = [
      ('admin@remedoo.app', 'Success', 'Today, 09:42'),
      ('zahid391105@gmail.com', 'Success', 'Today, 08:15'),
      ('unknown@example.com', 'Failed', 'Yesterday, 22:03'),
      ('aisha.k@example.com', 'Success', 'Yesterday, 18:31'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: logs.length,
      itemBuilder: (_, i) {
        final (email, result, at) = logs[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              result == 'Success'
                  ? Icons.check_circle
                  : Icons.error,
              color: result == 'Success'
                  ? RemedooTheme.ratingGreen
                  : RemedooTheme.emergency,
            ),
            title: Text(email,
                style:
                    const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(at),
            trailing: StatusChip(status: result),
          ),
        );
      },
    );
  }
}

/// Flagged suspicious activity (demo).
class AdminSuspiciousActivityScreen extends StatelessWidget {
  const AdminSuspiciousActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flags = [
      ('Multiple failed logins', 'unknown@example.com',
          '5 attempts in 2 minutes'),
      ('Unusual refund pattern', 'Order R049B060',
          '3 refunds in 24 hours'),
      ('Bulk appointment booking', '94190XXXXX',
          '12 slots booked at once'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: flags.length,
      itemBuilder: (_, i) {
        final (title, subject, detail) = flags[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.warning,
                  color: Colors.orange),
            ),
            title: Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('$subject\n$detail'),
            isThreeLine: true,
            trailing: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Flagged for review (demo)')),
                );
              },
              child: const Text('Review'),
            ),
          ),
        );
      },
    );
  }
}

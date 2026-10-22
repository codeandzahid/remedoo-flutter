import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/account_deletion.dart';
import '../../widgets/widgets.dart';

/// Admin > Support > Account Deletion (owner order 2026-10-22):
/// every account inside its 72-hour deletion window, nearest erase
/// time first, with a one-tap Reactivate. Visible to the super
/// admin and to staff holding the 'support' section — the same
/// people who answer the reactivation requests in Support Tickets.
/// Reactivation is enforced again in the database function.
class AdminAccountDeletionScreen extends StatefulWidget {
  const AdminAccountDeletionScreen({super.key});

  @override
  State<AdminAccountDeletionScreen> createState() =>
      _AdminAccountDeletionScreenState();
}

class _AdminAccountDeletionScreenState
    extends State<AdminAccountDeletionScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    await state.loadAllProfiles();
    await state.loadSupportTickets();
    if (mounted) setState(() => _loading = false);
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $h:$mm $ampm';
  }

  Future<void> _reactivate(Map<String, dynamic> u) async {
    final ok = await confirmDialog(
      context,
      title: 'Reactivate this account?',
      message:
          '${u['full_name'] ?? 'This user'} (${u['email'] ?? ''}) will be able to log in again. The scheduled deletion is cancelled and the user gets an email that the account is back.',
      confirmLabel: 'Reactivate',
    );
    if (ok != true || !mounted) return;
    final state = AppStateScope.of(context);
    final done = await state.reactivateUserAccount('${u['user_id']}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(done
            ? 'Account reactivated. The user can log in again.'
            : 'Reactivation failed. Please try again.'),
      ),
    );
    if (done) _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const RLoading();

    final now = DateTime.now();
    final pending = state.allProfiles
        .where((u) => parseDeletionRequest(u['deletion_requested_at']) != null)
        .toList()
      ..sort((a, b) => parseDeletionRequest(a['deletion_requested_at'])!
          .compareTo(parseDeletionRequest(b['deletion_requested_at'])!));
    final requests = state.supportTickets
        .where((t) =>
            '${t['category']}' == 'reactivation' &&
            '${t['status'] ?? 'open'}' == 'open')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '${pending.length} account${pending.length == 1 ? '' : 's'} waiting for deletion'
            '${requests > 0 ? ' • $requests reactivation request${requests == 1 ? '' : 's'} in Support Tickets' : ''}',
            style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: pending.isEmpty
              ? const REmptyState(
                  icon: Icons.verified_user_outlined,
                  title: 'No accounts waiting for deletion',
                  subtitle:
                      'Accounts appear here for 72 hours after the user asks to delete, until they are erased or reactivated.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pending.length,
                  itemBuilder: (_, i) {
                    final u = pending[i];
                    final requestedAt =
                        parseDeletionRequest(u['deletion_requested_at'])!
                            .toLocal();
                    final eraseAt = deletionEraseTime(requestedAt);
                    final hoursLeft =
                        deletionHoursLeft(requestedAt, now);
                    final name = '${u['full_name'] ?? 'Unnamed'}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: RemedooTheme.destructive
                                .withValues(alpha: 0.12),
                            child: Icon(Icons.schedule_outlined,
                                color: RemedooTheme.destructive, size: 20),
                          ),
                          title: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ('${u['email'] ?? ''}'.isNotEmpty)
                                Text('${u['email']}',
                                    style: const TextStyle(fontSize: 12)),
                              if ('${u['phone'] ?? ''}'.isNotEmpty)
                                Text('${u['phone']}',
                                    style: const TextStyle(fontSize: 12)),
                              Text(
                                'Erases ${_fmt(eraseAt)} • $hoursLeft hours left',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: RemedooTheme.destructive),
                              ),
                            ],
                          ),
                          trailing: FilledButton.icon(
                            onPressed: () => _reactivate(u),
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Reactivate'),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

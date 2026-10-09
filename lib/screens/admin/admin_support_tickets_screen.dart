import 'package:flutter/material.dart';

import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../widgets/support_chat_widgets.dart';
import '../../widgets/widgets.dart';
import 'admin_support_chat_screen.dart';

/// Admin support — WhatsApp-style chat list.
/// Every user query is a conversation: sender name + avatar, last
/// message preview, time and unread badge. Tap to open the chat;
/// the sender's full details are inside.
class AdminSupportTicketsScreen extends StatefulWidget {
  const AdminSupportTicketsScreen({super.key});

  @override
  State<AdminSupportTicketsScreen> createState() =>
      _AdminSupportTicketsScreenState();
}

class _AdminSupportTicketsScreenState
    extends State<AdminSupportTicketsScreen> {
  bool _loading = true;
  String _search = '';

  /// user_id -> profile (full_name, email, phone, role, created_at).
  final Map<String, Map<String, dynamic>> _profiles = {};

  /// ticket_id -> latest message row.
  final Map<String, Map<String, dynamic>> _lastMsg = {};

  /// ticket_id -> unread user messages count.
  final Map<String, int> _unread = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final state = AppStateScope.of(context);
    await state.loadSupportTickets();
    final repo = SupabaseRepository.instance;

    final profiles = await repo.fetchAllProfiles();
    _profiles
      ..clear()
      ..addEntries(profiles.map(
          (p) => MapEntry('${p['user_id']}', p)));

    final ids =
        state.supportTickets.map((t) => '${t['id']}').toList();
    final msgs = await repo.fetchMessagesForTickets(ids);
    _lastMsg.clear();
    _unread.clear();
    for (final m in msgs) {
      final tid = '${m['ticket_id']}';
      _lastMsg.putIfAbsent(tid, () => m); // newest first
      if (m['sender_role'] == 'user' && m['is_read'] != true) {
        _unread[tid] = (_unread[tid] ?? 0) + 1;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _nameFor(Map<String, dynamic> t) {
    final p = _profiles['${t['user_id']}'];
    final n = '${p?['full_name'] ?? ''}'.trim();
    return n.isNotEmpty ? n : 'Remedoo User';
  }

  DateTime _activityFor(Map<String, dynamic> t) {
    final last = _lastMsg['${t['id']}'];
    final lt = last == null
        ? null
        : DateTime.tryParse('${last['created_at']}');
    return lt ??
        DateTime.tryParse('${t['created_at']}') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int get _totalUnread =>
      _unread.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (_loading) {
      return const RLoading();
    }
    var tickets = [...state.supportTickets];
    // Latest conversation activity first.
    tickets.sort((a, b) => _activityFor(b).compareTo(_activityFor(a)));
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      tickets = tickets.where((t) {
        final last = _lastMsg['${t['id']}'];
        return _nameFor(t).toLowerCase().contains(q) ||
            '${t['subject'] ?? ''}'.toLowerCase().contains(q) ||
            '${last?['message'] ?? ''}'.toLowerCase().contains(q);
      }).toList();
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: RSearchBar(
                  hint: 'Search chats, names, subjects...',
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              if (_totalUnread > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_totalUnread unread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ],
          ),
        ),
        Expanded(
          child: tickets.isEmpty
              ? const REmptyState(
                  icon: Icons.support_agent_outlined,
                  title: 'No chats',
                  subtitle:
                      'User queries will appear here as chats.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: tickets.length,
                    itemBuilder: (_, i) => _row(tickets[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> t) {
    final scheme = Theme.of(context).colorScheme;
    final tid = '${t['id']}';
    final name = _nameFor(t);
    final last = _lastMsg[tid];
    final unread = _unread[tid] ?? 0;
    final when = _activityFor(t);

    String preview;
    if (last != null) {
      final mine = last['sender_role'] == 'admin';
      var msg = '${last['message'] ?? ''}'.trim();
      if (msg.isEmpty && last['attachment_url'] != null) {
        msg = attachmentPreviewLabel(last);
      }
      preview = '${mine ? 'You: ' : ''}$msg';
    } else {
      preview = '${t['description'] ?? ''}';
    }

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminSupportChatScreen(
              ticket: t,
              profile: _profiles['${t['user_id']}'],
            ),
          ),
        );
        if (mounted) _load();
      },
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ChatAvatar(name: name, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: unread > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text(chatListTime(when.toLocal()),
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: unread > 0
                                  ? const Color(0xFF1FA855)
                                  : scheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: scheme.onSurfaceVariant)),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        UnreadBadge(count: unread),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${t['subject'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: scheme.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(status: '${t['status'] ?? 'open'}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

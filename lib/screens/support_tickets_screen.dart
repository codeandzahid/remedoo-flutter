import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/responsive.dart';
import '../services/supabase_repository.dart';
import '../state/app_state.dart';
import '../widgets/support_chat_widgets.dart';
import '../widgets/widgets.dart';
import '../app_navigator.dart';
import 'new_query_sheet.dart';
import 'support_chat_screen.dart';

/// Support chats ("My Queries") — WhatsApp-style chat list: each query
/// is a conversation with last-message preview, time and unread badge.
/// Tap a row to open the chat.
class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  String _search = '';
  String _section = 'all';

  /// remote ticket id -> latest message row (preview + time).
  final Map<String, Map<String, dynamic>> _lastMsg = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadPreviews());
  }

  Future<void> _loadPreviews() async {
    final state = AppStateScope.of(context);
    await state.loadUserTickets();
    if (!mounted) return;
    final ids = state.tickets
        .map((t) => state.remoteTicketIdFor(t))
        .toSet()
        .toList();
    final msgs =
        await SupabaseRepository.instance.fetchMessagesForTickets(ids);
    if (!mounted) return;
    _lastMsg.clear();
    for (final m in msgs) {
      // Rows come newest-first: first hit per ticket is its last message.
      _lastMsg.putIfAbsent('${m['ticket_id']}', () => m);
    }
    setState(() {});
    unawaited(state.refreshSupportUnread());
  }

  Future<void> _openChat(AppState state, SupportTicket t) async {
    final remoteId = state.remoteTicketIdFor(t);
    final chatTicket = SupportTicket(
      id: remoteId,
      subject: t.subject,
      category: t.category,
      description: t.description,
      date: t.date,
      status: t.status,
      response: t.response,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportChatScreen(ticket: chatTicket),
      ),
    );
    if (mounted) _loadPreviews();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Sections: the first section groups every unfinished query
    // (waiting in queue, opened, or pending); Solved = resolved or
    // closed. The per-chat chip still shows the exact status.
    bool inSection(SupportTicket t) {
      final s = t.status.toLowerCase();
      return switch (_section) {
        'opened' =>
          s == 'open' || s == 'opened' || s == 'in_progress',
        'solved' => s == 'resolved' || s == 'closed',
        _ => true,
      };
    }

    final activeCount = state.tickets.where((t) {
      final s = t.status.toLowerCase();
      return s == 'open' || s == 'opened' || s == 'in_progress';
    }).length;
    final solvedCount = state.tickets.length - activeCount;
    final tickets = state.tickets.where((t) {
      if (!inSection(t)) return false;
      if (_search.trim().isEmpty) return true;
      final q = _search.toLowerCase();
      return t.subject.toLowerCase().contains(q) ||
          t.status.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q);
    }).toList()
      // Latest conversation activity first (WhatsApp ordering).
      ..sort((a, b) {
        final ta =
            _lastTime(state, a) ?? a.date;
        final tb =
            _lastTime(state, b) ?? b.date;
        return tb.compareTo(ta);
      });
    final unreadTotal = state.supportUnreadCount;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header: back + title + count + New button.
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).dividerColor),
                ),
              ),
              padding:
                  const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => goBack(context),
                      ),
                      Icon(Icons.forum_outlined,
                          color: scheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('My Queries',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            Text(
                                unreadTotal > 0
                                    ? '$unreadTotal unread ${unreadTotal == 1 ? 'reply' : 'replies'}'
                                    : '${state.tickets.length} total queries',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: unreadTotal > 0
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: unreadTotal > 0
                                        ? const Color(0xFF1FA855)
                                        : scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      RButton(
                        label: 'New',
                        icon: Icons.add,
                        small: true,
                        onPressed: () => _newTicket(context, state),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    child: RSearchBar(
                      hint: 'Search queries...',
                      onChanged: (v) =>
                          setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ChatSectionChips(
                    sections: [
                      ('all', 'All', state.tickets.length),
                      ('opened', 'Waiting in Queue', activeCount),
                      ('solved', 'Solved', solvedCount),
                    ],
                    selected: _section,
                    onSelect: (k) =>
                        setState(() => _section = k),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tickets.isEmpty
                  ? MaxWidthBox(
                      child: _section == 'all'
                          ? REmptyState(
                              icon: Icons.support_agent,
                              title: 'No queries yet',
                              subtitle:
                                  'Need help? Create a query and chat with our support team.',
                              actionLabel: 'Create Query',
                              onAction: () =>
                                  _newTicket(context, state),
                            )
                          : REmptyState(
                              icon: Icons.support_agent,
                              title: _section == 'opened'
                                  ? 'Nothing waiting in queue'
                                  : 'No solved queries',
                              subtitle: _section == 'opened'
                                  ? 'All your queries are solved. New queries will appear here.'
                                  : 'Queries the support team solves will appear here.',
                            ),
                    )
                  : MaxWidthBox(
                      child: RefreshIndicator(
                        onRefresh: _loadPreviews,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          itemCount: tickets.length,
                          itemBuilder: (_, i) =>
                              _chatRow(state, tickets[i]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _lastTime(AppState state, SupportTicket t) {
    final m = _lastMsg[state.remoteTicketIdFor(t)];
    if (m == null) return null;
    return DateTime.tryParse('${m['created_at']}');
  }

  Widget _chatRow(AppState state, SupportTicket t) {
    final scheme = Theme.of(context).colorScheme;
    final remoteId = state.remoteTicketIdFor(t);
    final last = _lastMsg[remoteId];
    final unread = state.supportUnreadFor(t);
    final lastTime = _lastTime(state, t) ?? t.date;

    String preview;
    if (last != null) {
      final mine = last['sender_role'] == 'user';
      var msg = '${last['message'] ?? ''}'.trim();
      if (msg.isEmpty && last['attachment_url'] != null) {
        msg = attachmentPreviewLabel(last);
      }
      preview = '${mine ? 'You: ' : ''}$msg';
    } else {
      preview = t.description;
    }

    return InkWell(
      onTap: () => _openChat(state, t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              child: Icon(Icons.support_agent,
                  color: scheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: unread > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text(chatListTime(lastTime),
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
                      const SizedBox(width: 8),
                      StatusChip(status: t.status),
                      if (unread > 0) ...[
                        const SizedBox(width: 6),
                        UnreadBadge(count: unread),
                      ],
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

  void _newTicket(BuildContext context, AppState state) {
    NewQuerySheet.show(context, onSubmitted: _loadPreviews);
  }
}

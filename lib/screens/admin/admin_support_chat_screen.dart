import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/support_chat_widgets.dart';
import '../../widgets/widgets.dart';

/// Admin WhatsApp-style chat for one support query.
/// Header shows who is chatting; tapping it opens the sender's
/// details (name, email, phone, role, member since) + ticket info
/// and status controls.
class AdminSupportChatScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final Map<String, dynamic>? profile;

  const AdminSupportChatScreen({
    super.key,
    required this.ticket,
    this.profile,
  });

  @override
  State<AdminSupportChatScreen> createState() =>
      _AdminSupportChatScreenState();
}

class _AdminSupportChatScreenState
    extends State<AdminSupportChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;

  String get _ticketId => '${widget.ticket['id']}';
  String get _userId => '${widget.ticket['user_id'] ?? ''}';
  String get _userName {
    final n = '${_profile?['full_name'] ?? ''}'.trim();
    return n.isNotEmpty ? n : 'Remedoo User';
  }

  String get _status => '${widget.ticket['status'] ?? 'open'}';

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _loadProfile();
    _loadMessages(markRead: true);
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadMessages(markRead: true, silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_userId.isEmpty) return;
    final p = await SupabaseRepository.instance
        .fetchProfileByUserId(_userId);
    if (mounted && p != null) setState(() => _profile = p);
  }

  Future<void> _loadMessages({
    bool markRead = false,
    bool silent = false,
  }) async {
    final repo = SupabaseRepository.instance;
    final msgs = await repo.fetchTicketMessages(_ticketId);
    if (markRead) {
      await repo.markTicketMessagesRead(
          ticketId: _ticketId, readerRole: 'admin');
    }
    if (!mounted) return;
    final changed = msgs.length != _messages.length ||
        (msgs.isNotEmpty &&
            _messages.isNotEmpty &&
            '${msgs.last['id']}' != '${_messages.last['id']}') ||
        (msgs.isNotEmpty && _messages.isEmpty);
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    if (!silent || changed) _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final repo = SupabaseRepository.instance;
    final ok = await repo.sendTicketMessage(
      ticketId: _ticketId,
      message: text,
      senderRole: 'admin',
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _controller.clear();
      // Notify the user in-app (persistent notification + bell badge).
      if (_userId.isNotEmpty) {
        unawaited(repo.sendNotificationToUser(
          userId: _userId,
          title: 'Support Team',
          message:
              'You have a new reply on "${widget.ticket['subject'] ?? 'your query'}". Tap Support to read it.',
          type: 'support',
        ));
      }
      // First admin reply moves the ticket to in_progress.
      if (_status == 'open') {
        await AppStateScope.of(context)
            .updateSupportTicket(_ticketId, {'status': 'in_progress'});
        widget.ticket['status'] = 'in_progress';
      }
      _loadMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  List<Map<String, dynamic>> get _displayMessages {
    if (_messages.isNotEmpty) return _messages;
    final desc = '${widget.ticket['description'] ?? ''}'.trim();
    if (desc.isEmpty) return const [];
    return [
      {
        'sender_role': 'user',
        'message': desc,
        'created_at': '${widget.ticket['created_at'] ?? ''}',
      }
    ];
  }

  void _showDetails() {
    final scheme = Theme.of(context).colorScheme;
    final p = _profile;
    String fmtDate(String? iso) {
      if (iso == null || iso.isEmpty) return '—';
      final d = DateTime.tryParse(iso);
      if (d == null) return iso;
      final l = d.toLocal();
      return '${l.day}/${l.month}/${l.year}';
    }

    Widget row(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 19, color: scheme.primary),
            const SizedBox(width: 12),
            SizedBox(
              width: 105,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(value.isEmpty ? '—' : value,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ChatAvatar(name: _userName, radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      Text('Sent this query',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            row(Icons.email_outlined, 'Email', '${p?['email'] ?? ''}'),
            row(Icons.phone_outlined, 'Phone', '${p?['phone'] ?? ''}'),
            row(Icons.badge_outlined, 'Role',
                '${p?['role'] ?? 'user'}'),
            row(Icons.calendar_month_outlined, 'Member since',
                fmtDate('${p?['created_at'] ?? ''}')),
            const Divider(),
            const Text('Query details',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 4),
            row(Icons.subject_outlined, 'Subject',
                '${widget.ticket['subject'] ?? ''}'),
            row(Icons.category_outlined, 'Category',
                '${widget.ticket['category'] ?? 'general'}'),
            row(Icons.flag_outlined, 'Priority',
                '${widget.ticket['priority'] ?? 'medium'}'),
            row(Icons.schedule_outlined, 'Raised on',
                fmtDate('${widget.ticket['created_at'] ?? ''}')),
            const SizedBox(height: 10),
            const Text('Status',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in const [
                  'open',
                  'in_progress',
                  'resolved'
                ])
                  ChoiceChip(
                    label: Text(s.replaceAll('_', ' ')),
                    selected: _status == s,
                    onSelected: (_) async {
                      Navigator.pop(ctx);
                      await AppStateScope.of(context)
                          .updateSupportTicket(
                              _ticketId, {'status': s});
                      if (s == 'resolved' && _userId.isNotEmpty) {
                        unawaited(SupabaseRepository.instance
                            .sendNotificationToUser(
                          userId: _userId,
                          title: 'Support Team',
                          message:
                              'Your query "${widget.ticket['subject'] ?? ''}" was marked as resolved. Thank you!',
                          type: 'support',
                        ));
                      }
                      if (mounted) {
                        setState(
                            () => widget.ticket['status'] = s);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 6),
            const Text('Media uploads (this chat only)',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'Allow this user to attach photos & files in this query only.',
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            StatefulBuilder(
              builder: (ctx2, setSheet) {
                final enabled =
                    widget.ticket['media_enabled'] == true;
                final limit =
                    (widget.ticket['media_limit'] as num?)?.toInt() ??
                        5;
                Future<void> save(Map<String, dynamic> patch) async {
                  await AppStateScope.of(context)
                      .updateSupportTicket(_ticketId, patch);
                  if (mounted) {
                    setState(() => widget.ticket.addAll(patch));
                    setSheet(() {});
                  }
                }

                return Column(
                  children: [
                    SwitchListTile(
                      value: enabled,
                      onChanged: (v) =>
                          save({'media_enabled': v}),
                      title: const Text('Allow media uploads',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          enabled
                              ? 'User sees the attach button in this chat'
                              : 'Text-only for this chat',
                          style: const TextStyle(fontSize: 12)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.attach_file, size: 19),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Max files in this chat',
                              style: TextStyle(fontSize: 13.5)),
                        ),
                        IconButton(
                          icon: const Icon(
                              Icons.remove_circle_outline),
                          onPressed: limit > 1
                              ? () => save(
                                  {'media_limit': limit - 1})
                              : null,
                        ),
                        Text('$limit',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        IconButton(
                          icon:
                              const Icon(Icons.add_circle_outline),
                          onPressed: limit < 50
                              ? () => save(
                                  {'media_limit': limit + 1})
                              : null,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _showDetails,
          child: Row(
            children: [
              ChatAvatar(name: _userName, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    Text(
                      '${widget.ticket['subject'] ?? ''} • tap for details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'User & query details',
            onPressed: _showDetails,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              children: [
                StatusChip(status: _status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.ticket['category'] ?? 'general'} • '
                    '${widget.ticket['priority'] ?? 'medium'} priority',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const RLoading()
                : _displayMessages.isEmpty
                    ? const Center(child: Text('No messages yet.'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _displayMessages.length,
                        itemBuilder: (ctx, i) {
                          final m = _displayMessages[i];
                          final isAdmin = m['sender_role'] == 'admin';
                          final when =
                              DateTime.tryParse('${m['created_at'] ?? ''}');
                          return Align(
                            alignment: isAdmin
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width *
                                        0.78,
                              ),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(
                                      isAdmin ? 16 : 4),
                                  bottomRight: Radius.circular(
                                      isAdmin ? 4 : 16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (!isAdmin)
                                    Text(
                                      _userName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: RemedooTheme.success,
                                      ),
                                    ),
                                  if (m['attachment_url'] != null) ...[
                                    ChatAttachment(
                                      url: '${m['attachment_url']}',
                                      name: m['attachment_name'] as String?,
                                      type: m['attachment_type'] as String?,
                                      isMine: isAdmin,
                                    ),
                                    if ('${m['message'] ?? ''}'
                                        .trim()
                                        .isNotEmpty)
                                      const SizedBox(height: 6),
                                  ],
                                  if ('${m['message'] ?? ''}'
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      '${m['message'] ?? ''}',
                                      style: TextStyle(
                                        color: isAdmin
                                            ? Colors.white
                                            : scheme.onSurface,
                                      ),
                                    ),
                                  if (when != null) ...[
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        chatBubbleTime(when.toLocal()),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isAdmin
                                              ? Colors.white70
                                              : scheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Type a reply...',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.primary,
                    child: IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.send,
                              size: 19, color: Colors.white),
                      onPressed: _sending ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/supabase_repository.dart';
import '../state/app_state.dart';
import '../widgets/support_chat_widgets.dart';
import '../widgets/widgets.dart';

/// WhatsApp-style chat for one support query.
/// The user chats here; the admin replies from the admin panel.
/// Opening the chat marks the support team's messages as read
/// (clears the badge on the support button).
class SupportChatScreen extends StatefulWidget {
  final SupportTicket ticket;

  const SupportChatScreen({super.key, required this.ticket});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadMessages(markRead: true);
    // Near-live refresh while the chat is open.
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

  String get _shortId => widget.ticket.id.length > 8
      ? widget.ticket.id.substring(0, 8)
      : widget.ticket.id;

  Future<void> _loadMessages({
    bool markRead = false,
    bool silent = false,
  }) async {
    final repo = SupabaseRepository.instance;
    final msgs = await repo.fetchTicketMessages(widget.ticket.id);
    if (markRead) {
      await repo.markTicketMessagesRead(
          ticketId: widget.ticket.id, readerRole: 'user');
      if (mounted) {
        unawaited(AppStateScope.of(context).refreshSupportUnread());
      }
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
      ticketId: widget.ticket.id,
      message: text,
      senderRole: 'user',
    );

    if (mounted) {
      setState(() => _sending = false);
      if (ok) {
        _controller.clear();
        _loadMessages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = widget.ticket;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              child: Icon(Icons.support_agent,
                  color: scheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Remedoo Support',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    '${t.subject} • #$_shortId • ${t.status.replaceAll('_', ' ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const RLoading()
                : _displayMessages.isEmpty
                    ? const Center(
                        child: Text(
                            'No messages yet. Start the conversation!'),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _displayMessages.length,
                        itemBuilder: (ctx, i) {
                          final m = _displayMessages[i];
                          final isUser = m['sender_role'] == 'user';
                          final when =
                              DateTime.tryParse('${m['created_at'] ?? ''}');
                          return Align(
                            alignment: isUser
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
                                color: isUser
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft:
                                      Radius.circular(isUser ? 16 : 4),
                                  bottomRight:
                                      Radius.circular(isUser ? 4 : 16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (!isUser)
                                    Text(
                                      'Support Team',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  Text(
                                    '${m['message'] ?? ''}',
                                    style: TextStyle(
                                      color: isUser
                                          ? Colors.white
                                          : scheme.onSurface,
                                    ),
                                  ),
                                  if (when != null) ...[
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        chatBubbleTime(
                                            when.toLocal()),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isUser
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
                        hintText: 'Type a message...',
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

  /// Real messages; when the thread has none yet, the query's own
  /// description is shown as the first message (older queries were
  /// created before descriptions were saved as messages).
  List<Map<String, dynamic>> get _displayMessages {
    if (_messages.isNotEmpty) return _messages;
    final desc = widget.ticket.description.trim();
    if (desc.isEmpty) return const [];
    return [
      {
        'sender_role': 'user',
        'message': desc,
        'created_at': widget.ticket.date.toIso8601String(),
      }
    ];
  }
}

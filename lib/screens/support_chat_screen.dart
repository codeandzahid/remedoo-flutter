import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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

  // Pending attachment (picked, not yet sent).
  Uint8List? _pendingBytes;
  String? _pendingName;
  String? _pendingType; // 'image' | 'file'
  bool _uploading = false;

  // Per-query media permission, set by the admin for THIS chat
  // (support_tickets.media_enabled / media_limit).
  bool _mediaEnabled = false;
  int _mediaLimit = 5;

  /// Latest ticket status from the server (refreshed on the poll),
  /// so admin changes — Opened / Pending / Solved — show live here.
  String? _liveStatus;

  String get _status => _liveStatus ?? widget.ticket.status;

  /// Solved or Closed chats are finished: the user can read them
  /// but can no longer send messages in them.
  bool get _isFinished => _status == 'resolved' || _status == 'closed';

  Future<void> _loadMediaSettings() async {
    final row = await SupabaseRepository.instance
        .fetchTicketById(widget.ticket.id);
    if (!mounted || row == null) return;
    final enabled = row['media_enabled'] == true;
    final limit = (row['media_limit'] as num?)?.toInt() ?? 5;
    final status = row['status'] as String?;
    if (enabled != _mediaEnabled ||
        limit != _mediaLimit ||
        status != _liveStatus) {
      setState(() {
        _mediaEnabled = enabled;
        _mediaLimit = limit;
        if (status != null) _liveStatus = status;
      });
    }
  }

  /// How many media files I have already attached in this chat.
  int get _myMediaCount => _messages
      .where((m) =>
          m['sender_role'] == 'user' && m['attachment_url'] != null)
      .length;

  @override
  void initState() {
    super.initState();
    _loadMessages(markRead: true);
    _loadMediaSettings();
    // Near-live refresh while the chat is open.
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadMessages(markRead: true, silent: true);
      _loadMediaSettings();
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

  Future<void> _pickMedia() async {
    if (_myMediaCount >= _mediaLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'You can attach up to $_mediaLimit files in this chat.'),
        ),
      );
      return;
    }
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (files.isEmpty || !mounted) return;
    final f = files.single;
    Uint8List? bytes;
    try {
      bytes = await f.readAsBytes();
    } catch (_) {
      bytes = null;
    }
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read that file.')),
        );
      }
      return;
    }
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('File is too large — max 10 MB.')),
        );
      }
      return;
    }
    final ext = (f.extension ?? '').toLowerCase();
    setState(() {
      _pendingBytes = bytes;
      _pendingName = f.name;
      _pendingType = ext == 'pdf' ? 'file' : 'image';
    });
  }

  /// Preview strip for a picked-but-unsent attachment, with the
  /// remaining-quota hint.
  /// Shown instead of the composer once the chat is Solved/Closed:
  /// the conversation stays readable but is locked for new messages.
  Widget _finishedBanner(ColorScheme scheme) {
    final solved = _status == 'resolved';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            solved ? Icons.check_circle : Icons.lock_outline,
            size: 20,
            color: solved
                ? const Color(0xFF1FA855)
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              solved
                  ? 'This query was marked as Solved — this chat is now closed. For more help, start a new query.'
                  : 'This chat was closed by the support team. For more help, start a new query.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingPreview(ColorScheme scheme) {
    final remaining = _mediaLimit - _myMediaCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (_pendingType == 'image' && _pendingBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(_pendingBytes!,
                  width: 44, height: 44, fit: BoxFit.cover),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.picture_as_pdf,
                  color: Color(0xFFD64545)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pendingName ?? 'Attachment',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  _uploading
                      ? 'Uploading…'
                      : '$remaining of $_mediaLimit attachments left in this chat',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _uploading
                ? null
                : () => setState(() {
                      _pendingBytes = null;
                      _pendingName = null;
                      _pendingType = null;
                    }),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (_isFinished) return; // Solved/Closed chats are locked.
    final text = _controller.text.trim();
    if ((text.isEmpty && _pendingBytes == null) || _sending) return;
    setState(() => _sending = true);

    final repo = SupabaseRepository.instance;
    String? attachmentUrl;
    if (_pendingBytes != null) {
      setState(() => _uploading = true);
      String? uploadError;
      (attachmentUrl, uploadError) = await repo.uploadChatMediaData(
          _pendingBytes!, _pendingName ?? 'file', widget.ticket.id);
      if (mounted) setState(() => _uploading = false);
      if (attachmentUrl == null) {
        if (mounted) {
          setState(() => _sending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Upload failed: ${uploadError ?? 'unknown error'}')),
          );
        }
        return;
      }
    }
    final ok = await repo.sendTicketMessage(
      ticketId: widget.ticket.id,
      message: text,
      senderRole: 'user',
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentUrl != null ? _pendingName : null,
      attachmentType: attachmentUrl != null ? _pendingType : null,
    );

    if (mounted) {
      setState(() => _sending = false);
      if (ok) {
        _controller.clear();
        setState(() {
          _pendingBytes = null;
          _pendingName = null;
          _pendingType = null;
        });
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
                    '${t.subject} • #$_shortId • ${ticketStatusLabel(_status)}',
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
                                  if (m['attachment_url'] != null) ...[
                                    ChatAttachment(
                                      url: '${m['attachment_url']}',
                                      name: m['attachment_name'] as String?,
                                      type: m['attachment_type'] as String?,
                                      isMine: isUser,
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
              child: _isFinished
                  ? _finishedBanner(scheme)
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pendingBytes != null) _pendingPreview(scheme),
                  Row(
                    children: [
                      if (_mediaEnabled)
                        IconButton(
                          icon: Icon(
                            Icons.attach_file,
                            color: _myMediaCount >= _mediaLimit
                                ? scheme.onSurfaceVariant
                                    .withValues(alpha: 0.4)
                                : scheme.primary,
                          ),
                          tooltip: 'Attach photo or file',
                          onPressed: _pickMedia,
                        ),
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

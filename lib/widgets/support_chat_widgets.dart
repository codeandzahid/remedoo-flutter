import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Short label for a chat attachment, used in list previews.
String attachmentPreviewLabel(Map<String, dynamic> m) =>
    m['attachment_type'] == 'image' ? '📷 Photo' : '📄 File';

/// Attachment inside a chat bubble: image preview (tap = full
/// view) or a file chip (tap = open/download).
class ChatAttachment extends StatelessWidget {
  final String url;
  final String? name;
  final String? type;
  final bool isMine;

  const ChatAttachment({
    super.key,
    required this.url,
    this.name,
    this.type,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    if (type == 'image') {
      return GestureDetector(
        onTap: () => _viewImage(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 220,
            height: 160,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(
                    width: 220,
                    height: 160,
                    color: Colors.black12,
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
            errorBuilder: (_, __, ___) => Container(
              width: 220,
              height: 90,
              color: Colors.black12,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf,
                size: 22, color: Color(0xFFD64545)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name ?? 'Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const Text('Tap to open',
                      style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// WhatsApp-style time label for chat lists: '10:24 AM' today,
/// 'Yesterday', or '09/10/2026'.
String chatListTime(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return chatBubbleTime(t);
  if (diff == 1) return 'Yesterday';
  return '${t.day.toString().padLeft(2, '0')}/'
      '${t.month.toString().padLeft(2, '0')}/${t.year}';
}

/// 'h:mm AM/PM' label used inside chat bubbles.
String chatBubbleTime(DateTime t) {
  var h = t.hour % 12;
  if (h == 0) h = 12;
  final m = t.minute.toString().padLeft(2, '0');
  final ap = t.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ap';
}

/// Green unread-count badge, WhatsApp style.
class UnreadBadge extends StatelessWidget {
  final int count;
  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF25D366),
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Round avatar with a person's initial (chat lists + headers).
class ChatAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color? background;

  const ChatAvatar({
    super.key,
    required this.name,
    this.radius = 24,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial =
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: background ?? scheme.primary,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}

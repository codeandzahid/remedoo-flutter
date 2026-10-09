import 'package:flutter/material.dart';

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

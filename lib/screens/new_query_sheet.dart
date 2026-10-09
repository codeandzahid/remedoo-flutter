import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Professional "Submit a New Query" bottom sheet.
///
/// Guided form: visual category picker → subject → detailed message →
/// urgency. Validates inline, then shows an in-sheet success state.
/// The query opens a WhatsApp-style chat with the support team.
class NewQuerySheet extends StatefulWidget {
  /// Called after a query is successfully submitted (parent refreshes).
  final VoidCallback? onSubmitted;

  const NewQuerySheet({super.key, this.onSubmitted});

  static Future<void> show(BuildContext context,
      {VoidCallback? onSubmitted}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewQuerySheet(onSubmitted: onSubmitted),
    );
  }

  @override
  State<NewQuerySheet> createState() => _NewQuerySheetState();
}

class _NewQuerySheetState extends State<NewQuerySheet> {
  static const _categories = <(String, IconData)>[
    ('Appointment', Icons.calendar_month_outlined),
    ('Order', Icons.shopping_bag_outlined),
    ('Payment', Icons.payments_outlined),
    ('Refund', Icons.replay_outlined),
    ('Account', Icons.person_outline),
    ('Other', Icons.help_outline),
  ];
  static const _priorities = <(String, String, Color)>[
    ('low', 'Low', Color(0xFF2E9E5B)),
    ('medium', 'Medium', Color(0xFFE8912D)),
    ('high', 'High', Color(0xFFD64545)),
  ];

  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'Appointment';
  String _priority = 'medium';
  String? _subjectError;
  String? _messageError;
  bool _submitting = false;
  bool _done = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    setState(() {
      _subjectError =
          subject.isEmpty ? 'Please enter a subject' : null;
      _messageError = message.isEmpty
          ? 'Please describe your issue'
          : message.length < 10
              ? 'Add a few more details so we can help faster'
              : null;
    });
    if (_subjectError != null || _messageError != null) return;

    setState(() => _submitting = true);
    AppStateScope.of(context).addTicket(
      subject: subject,
      category: _category,
      description: message,
      priority: _priority,
    );
    // Brief pause so the button state reads as "sending".
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _done = true;
    });
    widget.onSubmitted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, 20 + bottomInset),
              child: _done ? _successView() : _formView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formView() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Header ----
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.support_agent,
                  color: scheme.primary, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Submit a New Query',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text(
                    'Our team usually replies within a few hours.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // ---- Category ----
        const Text('What is this about?',
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            for (final c in _categories) _categoryCard(c.$1, c.$2),
          ],
        ),
        const SizedBox(height: 20),

        // ---- Subject ----
        const Text('Subject',
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _subject,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'e.g. Payment deducted but booking failed',
            errorText: _subjectError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
          ),
          onChanged: (_) {
            if (_subjectError != null) {
              setState(() => _subjectError = null);
            }
          },
        ),
        const SizedBox(height: 16),

        // ---- Message ----
        const Text('Describe your issue',
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _message,
          minLines: 4,
          maxLines: 6,
          decoration: InputDecoration(
            hintText:
                'Tell us what happened, step by step. Include dates, '
                'order or appointment details if relevant…',
            errorText: _messageError,
            alignLabelWithHint: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
          ),
          onChanged: (_) {
            if (_messageError != null) {
              setState(() => _messageError = null);
            }
          },
        ),
        const SizedBox(height: 20),

        // ---- Priority ----
        const Text('How urgent is this?',
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final p in _priorities) ...[
              Expanded(child: _priorityChip(p.$1, p.$2, p.$3)),
              if (p.$1 != 'high') const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // ---- Reassurance note ----
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: RemedooTheme.success.withValues(alpha: 0.07),
            border: Border.all(
                color: RemedooTheme.success.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 18, color: Color(0xFF1FA855)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This opens a chat with our support team. You will '
                  'get a notification here whenever they reply.',
                  style: TextStyle(fontSize: 12.5, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ---- Submit ----
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, size: 18),
            label: Text(_submitting ? 'Sending…' : 'Submit Query',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _categoryCard(String label, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _category == label;
    return InkWell(
      onTap: () => setState(() => _category = label),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.10)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          border: Border.all(
            color: selected
                ? scheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 21,
                color: selected
                    ? scheme.primary
                    : scheme.onSurfaceVariant),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? scheme.primary
                        : scheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _priorityChip(String value, String label, Color color) {
    final selected = _priority == value;
    return InkWell(
      onTap: () => setState(() => _priority = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.13)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? color
                : Theme.of(context).dividerColor,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? color : null)),
          ],
        ),
      ),
    );
  }

  Widget _successView() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: RemedooTheme.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle,
              size: 46, color: Color(0xFF1FA855)),
        ),
        const SizedBox(height: 16),
        const Text('Query submitted!',
            style:
                TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Your query is now a chat with our support team.\n'
          'We will notify you here as soon as they reply.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Done',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

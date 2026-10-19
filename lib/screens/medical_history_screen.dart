import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../app_navigator.dart';

/// Medical History: unified expandable timeline with type filters.
class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  State<MedicalHistoryScreen> createState() =>
      _MedicalHistoryScreenState();
}

class _TimelineItem {
  final String id;
  final String type; // appointment | prescription | lab_report
  final String title;
  final String subtitle;
  final String status;
  final DateTime date;
  final String details;

  _TimelineItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.date,
    this.details = '',
  });
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

String _fmtDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  String _filter = 'all';
  String? _expandedId;

  static const _filters = [
    ('all', 'All'),
    ('appointment', 'Appointments'),
    ('prescription', 'Prescriptions'),
    ('lab_report', 'Lab Reports'),
    ('health_fact', 'Health Facts'),
  ];

  List<_TimelineItem> _timeline(AppState state) {
    final items = <_TimelineItem>[];
    for (final a in state.appointments) {
      items.add(_TimelineItem(
        id: 'apt-${a.id}',
        type: 'appointment',
        title: a.doctorName,
        subtitle: '${a.specialty} • ${a.timeLabel}',
        status: a.status,
        date: a.date,
        details:
            '${a.place}\nFee: ${inr(a.fee)}\nPayment: ${a.payment}${a.notes.isNotEmpty ? '\nNotes: ${a.notes}' : ''}',
      ));
    }
    for (final r in state.reports) {
      items.add(_TimelineItem(
        id: 'lab-${r.id}',
        type: 'lab_report',
        title: r.labName,
        subtitle: '${r.tests.length} tests',
        status: r.status,
        date: r.date,
      ));
    }
    for (var i = 0; i < state.prescriptions.length; i++) {
      items.add(_TimelineItem(
        id: 'rx-$i',
        type: 'prescription',
        title: state.prescriptions[i],
        subtitle: 'Prescription • PDF',
        status: 'completed',
        date: DateTime(2000),
      ));
    }
    for (final e in state.historyEntries) {
      items.add(_TimelineItem(
        id: 'fact-${e.id}',
        type: 'health_fact',
        title: e.title,
        subtitle: e.kind,
        status: 'Added by you',
        date: e.date,
        details: e.notes,
      ));
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.isSignedIn) {
      return const GuestGate();
    }
    final items = _timeline(state)
        .where((t) => _filter == 'all' || t.type == _filter)
        .toList();
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                      onPressed: () =>
                          goBack(context),
                    ),
                    const SizedBox(width: 4),
                    const Text('Medical History',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Material(
                      color: Colors.white,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        onTap: () => _addEntry(state),
                        customBorder: const StadiumBorder(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  size: 16, color: RemedooTheme.primary),
                              const SizedBox(width: 4),
                              Text('Add',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: RemedooTheme.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (key, label) in _filters)
                        Padding(
                          padding:
                              const EdgeInsets.only(right: 8),
                          child: _filterChip(key, label),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? MaxWidthBox(
                    child: REmptyState(
                      icon: Icons.history,
                      title: 'No medical history yet',
                      subtitle:
                          'Your visits, prescriptions and reports will build your history here. You can also add your own health facts.',
                      actionLabel: 'Add Health Fact',
                      onAction: () => _addEntry(state),
                    ),
                  )
                : MaxWidthBox(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          20, 16, 20, 24),
                      itemCount: items.length,
                      itemBuilder: (_, i) => StaggerItem(
                        index: i % 6,
                        child: _card(items[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? RemedooTheme.primary
                    : Colors.white)),
      ),
    );
  }

  /// Add a health fact (2026-10-19): allergy, condition, surgery,
  /// medication or anything else a doctor should know.
  Future<void> _addEntry(AppState state) async {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var kind = 'Allergy';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add Health Fact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    'Allergy',
                    'Condition',
                    'Surgery',
                    'Medication',
                    'Other',
                  ]
                      .map((k) =>
                          DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => setD(() => kind = v ?? 'Other'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Allergic to penicillin'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a title.')));
      return;
    }
    state.addHistoryEntry(HistoryEntry(
      id: 'H${DateTime.now().millisecondsSinceEpoch}',
      kind: kind,
      title: title,
      date: DateTime.now(),
      notes: notesCtrl.text.trim(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to your medical history.')));
  }

  Widget _card(_TimelineItem t) {
    final scheme = Theme.of(context).colorScheme;
    final Color tileBg;
    final Color tileFg;
    final IconData icon;
    final String typeLabel;
    switch (t.type) {
      case 'appointment':
        tileBg = scheme.primary.withValues(alpha: 0.12);
        tileFg = scheme.primary;
        icon = Icons.calendar_month_outlined;
        typeLabel = 'Appointment';
      case 'prescription':
        tileBg =
            RemedooTheme.success.withValues(alpha: 0.12);
        tileFg = RemedooTheme.success;
        icon = Icons.medication_outlined;
        typeLabel = 'Prescription';
      case 'health_fact':
        tileBg =
            RemedooTheme.emergency.withValues(alpha: 0.12);
        tileFg = RemedooTheme.emergency;
        icon = Icons.favorite_outline;
        typeLabel = 'Health Fact';
      default:
        tileBg =
            RemedooTheme.warning.withValues(alpha: 0.14);
        tileFg = RemedooTheme.warning;
        icon = Icons.science_outlined;
        typeLabel = 'Lab Report';
    }
    final expanded = _expandedId == t.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: RCard(
        onTap: () => setState(
            () => _expandedId = expanded ? null : t.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child:
                      Icon(icon, color: tileFg, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(t.title,
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(t.subtitle,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: scheme
                                            .onSurfaceVariant)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              StatusChip(status: t.status),
                              const SizedBox(height: 4),
                              Icon(
                                expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color:
                                    scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 13,
                              color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                              t.date.year == 2000
                                  ? '—'
                                  : _fmtDate(t.date),
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      scheme.onSurfaceVariant)),
                          const SizedBox(width: 8),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3),
                            decoration: BoxDecoration(
                              color: tileBg,
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: Text(typeLabel,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: tileFg)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (expanded && t.details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor),
              const SizedBox(height: 12),
              Text(t.details,
                  style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                      height: 1.5)),
            ],
            if (expanded && t.type == 'health_fact') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => AppStateScope.of(context)
                      .removeHistoryEntry(t.id.replaceFirst('fact-', '')),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete entry'),
                  style: TextButton.styleFrom(
                      foregroundColor: RemedooTheme.destructive),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

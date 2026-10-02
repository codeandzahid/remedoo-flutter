import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'booking_screen.dart';

/// Lab detail: info, test list with ADD, Book Tests (lab mode booking).
class LabDetailScreen extends StatefulWidget {
  final Lab lab;

  const LabDetailScreen({super.key, required this.lab});

  @override
  State<LabDetailScreen> createState() => _LabDetailScreenState();
}

class _LabDetailScreenState extends State<LabDetailScreen> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final l = widget.lab;
    final tests = labTests.take(10).toList();
    final selectedTests =
        tests.where((t) => _selected.contains(t.id)).toList();
    final total = selectedTests.fold<double>(0, (s, t) => s + t.price);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Details'),
        actions: [FavoriteButton(favKey: 'lab:${l.id}')],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: RemedooTheme.teal
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.science,
                            color: RemedooTheme.teal, size: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(l.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                            Text(l.location,
                                style: const TextStyle(
                                    color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      RatingPill(rating: l.rating),
                      if (l.nabl)
                        const StatusChip(status: 'NABL Accredited'),
                      Chip(
                          label: Text(
                              'Report in ${l.turnaround}')),
                      Chip(
                          label:
                              Text('${l.testCount} tests')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const InfoRow(
                    icon: Icons.home,
                    label: 'Home collection',
                    value: 'Available',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Available Tests',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...tests.map((t) {
            final sel = _selected.contains(t.id);
            return Card(
              child: ListTile(
                title: Text(t.name,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'Report in ${t.turnaround} • ${t.category}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(inr(t.price),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: RemedooTheme.primary)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(sel ? 'ADDED' : 'ADD'),
                      selected: sel,
                      onSelected: (_) =>
                          setState(() => sel
                              ? _selected.remove(t.id)
                              : _selected.add(t.id)),
                      selectedColor: RemedooTheme.primary,
                      labelStyle: TextStyle(
                          color: sel
                              ? Colors.white
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 90),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: FilledButton(
            onPressed: selectedTests.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingScreen(
                          kind: 'lab',
                          refId: l.id,
                          title: l.name,
                          subtitle:
                              '${selectedTests.length} tests • Home collection',
                          place: l.location,
                          fee: total,
                          tests: selectedTests,
                        ),
                      ),
                    ),
            child: Text(selectedTests.isEmpty
                ? 'Select tests to book'
                : 'Book ${selectedTests.length} Tests • ${inr(total)}'),
          ),
        ),
      ),
    );
  }
}

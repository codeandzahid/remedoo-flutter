import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/widgets.dart';

/// Compose a broadcast → pushes a patient notification.
class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState
    extends State<AdminBroadcastScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RSectionHeader(
                    title: 'New Broadcast',
                    subtitle:
                        'Sent as a push notification to all patients.'),
                const SizedBox(height: 16),
                RTextField(
                  label: 'Title',
                  hint: 'e.g. Monsoon health camp',
                  controller: _title,
                ),
                const SizedBox(height: 12),
                RTextField(
                  label: 'Message',
                  hint: 'Write your message…',
                  controller: _message,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                RButton(
                  label: 'Send Broadcast',
                  icon: Icons.send,
                  fullWidth: true,
                  onPressed: () {
                    if (_title.text.trim().isEmpty ||
                        _message.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Title and message are required')),
                      );
                      return;
                    }
                    AppStateScope.of(context).addNotification(
                      title: _title.text.trim(),
                      message: _message.text.trim(),
                      category: 'system',
                    );
                    _title.clear();
                    _message.clear();
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                          content:
                              Text('Broadcast sent!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const RSectionHeader(
              title: 'Recent broadcasts',
              subtitle: 'Last 5 system notifications'),
          const SizedBox(height: 12),
          ...AppStateScope.of(context)
              .notifications
              .where((n) => n.category == 'system')
              .take(5)
              .map((n) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: 10),
                    child: RCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: ListTile(
                        leading: Icon(Icons.campaign,
                            color: scheme.primary),
                        title: Text(n.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(n.body,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis),
                      ),
                    ),
                  )),
        ],
      ),
    );
  }
}

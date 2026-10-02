import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
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
    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Broadcast',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                    'Sent as a push notification to all patients.',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                        labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _message,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Message'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
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
                    icon: const Icon(Icons.send),
                    label: const Text('Send Broadcast'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Recent broadcasts',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...AppStateScope.of(context)
              .notifications
              .where((n) => n.category == 'system')
              .take(5)
              .map((n) => Card(
                    margin:
                        const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.campaign,
                          color: RemedooTheme.primary),
                      title: Text(n.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(n.body,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis),
                    ),
                  )),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/widgets.dart';

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

/// Announcements manager (Supabase `announcements` table).
/// Announcements appear in-app for patients/providers.
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
  String _audience = 'all';
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppStateScope.of(context).loadAnnouncements();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final message = _message.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Title and message are required')),
      );
      return;
    }
    setState(() => _sending = true);
    final ok = await AppStateScope.of(context)
        .createAnnouncement(title, message, _audience);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _title.clear();
      _message.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Announcement published!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Publish failed. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = AppStateScope.of(context);
    return ResponsiveBody(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const RSectionHeader(
                      title: 'New Announcement',
                      subtitle:
                          'Published in-app to the selected audience.'),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _audience,
                    decoration: const InputDecoration(
                      labelText: 'Audience',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'all',
                          child: Text('Everyone')),
                      DropdownMenuItem(
                          value: 'users',
                          child: Text('Patients only')),
                      DropdownMenuItem(
                          value: 'providers',
                          child: Text('Providers only')),
                    ],
                    onChanged: (v) => setState(
                        () => _audience = v ?? 'all'),
                  ),
                  const SizedBox(height: 16),
                  RButton(
                    label:
                        _sending ? 'Publishing…' : 'Publish',
                    icon: Icons.send,
                    fullWidth: true,
                    onPressed:
                        _sending ? null : () => _send(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            RSectionHeader(
                title: 'Published',
                subtitle:
                    '${state.announcements.length} announcements'),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (state.announcements.isEmpty)
              const REmptyState(
                icon: Icons.campaign_outlined,
                title: 'No announcements',
                subtitle:
                    'Published announcements appear here.',
              )
            else
              ...state.announcements.map((a) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: 10),
                    child: RCard(
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                      child: ListTile(
                        leading: Icon(Icons.campaign,
                            color: scheme.primary),
                        title: Text('${a['title']}',
                            style: const TextStyle(
                                fontWeight:
                                    FontWeight.w600)),
                        subtitle: Text(
                          '${a['message'] ?? ''}\n${a['audience'] ?? 'all'} • ${_fmtDate(a['created_at']?.toString())}',
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () =>
                              _confirmDelete(state, a),
                        ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(AppState state,
      Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete announcement?',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        content:
            Text('“${a['title']}” will be removed from the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          RButton(
            label: 'Delete',
            small: true,
            variant: RButtonVariant.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final deleted =
        await state.deleteAnnouncement('${a['id']}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(deleted
                ? 'Announcement deleted.'
                : 'Delete failed. Try again.')),
      );
    }
  }
}

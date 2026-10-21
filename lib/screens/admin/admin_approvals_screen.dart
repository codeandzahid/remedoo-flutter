import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';
import '../../widgets/widgets.dart';

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day}/${d.month}/${d.year}';
  } catch (_) {
    return iso;
  }
}

/// One-line summary of a registration's details JSONB.
String _detailsSummary(Map details) {
  final parts = <String>[];
  if ('${details['specialization'] ?? ''}'.isNotEmpty) {
    parts.add('${details['specialization']}');
  }
  if (details['consultation_fee'] != null) {
    parts.add('Fee ₹${details['consultation_fee']}');
  }
  if (details['experience_years'] != null) {
    parts.add('${details['experience_years']} yrs exp');
  }
  if (details['beds'] != null) {
    parts.add('${details['beds']} beds');
  }
  if (details['icu_available'] == true) parts.add('ICU');
  final services = details['services'];
  if (services is List && services.isNotEmpty) {
    parts.add(services.join(', '));
  }
  return parts.join(' • ');
}

/// Opens one uploaded registration document via a signed URL
/// into the private certificates bucket. Rows submitted before
/// real uploads existed have no storage path — say so plainly.
Future<void> _viewDoc(BuildContext context, AppState state,
    Map<dynamic, dynamic> doc) async {
  final messenger = ScaffoldMessenger.of(context);
  final path = '${doc['path'] ?? ''}';
  if (path.isEmpty) {
    messenger.showSnackBar(const SnackBar(
        content: Text(
            'This application was submitted before document uploads were stored — ask the provider to re-upload.')));
    return;
  }
  final url = await state.supabaseRepository
      .signedStorageUrl('certificates', path);
  if (url == null) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Could not open the document. Try again.')));
    return;
  }
  await launchUrl(Uri.parse(url),
      mode: LaunchMode.externalApplication);
}

/// Provider applications from Supabase with Approve / Reject.
/// Approving also creates the provider's catalog record.
class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() =>
      _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState
    extends State<AdminApprovalsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppStateScope.of(context)
        .loadAdminProviderApplications();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final apps = state.adminProviderApplications.toList()
      ..sort((a, b) {
        final pa = a['status'] == 'pending' ? 0 : 1;
        final pb = b['status'] == 'pending' ? 0 : 1;
        return pa.compareTo(pb);
      });
    final pending =
        apps.where((a) => a['status'] == 'pending').toList();
    final done =
        apps.where((a) => a['status'] != 'pending').toList();

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RSectionHeader(
              title: 'Pending Review',
              subtitle:
                  '${pending.length} applications waiting'),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            const REmptyState(
              icon: Icons.check_circle_outline,
              title: 'All caught up',
              subtitle:
                  'No pending applications to review.',
            )
          else
            ...pending.map((a) => _card(context, state, a)),
          const SizedBox(height: 24),
          RSectionHeader(
              title: 'Decided',
              subtitle:
                  '${done.length} reviewed applications'),
          const SizedBox(height: 12),
          if (done.isEmpty)
            const REmptyState(
              icon: Icons.history,
              title: 'Nothing decided yet',
              subtitle:
                  'Approved and rejected applications appear here.',
            )
          else
            ...done.map((a) => _card(context, state, a)),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, AppState state,
      Map<String, dynamic> a) {
    final scheme = Theme.of(context).colorScheme;
    final pending = a['status'] == 'pending';
    final docs = a['documents'];
    final docCount = docs is List ? docs.length : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(
                    name: '${a['name'] ?? '?'}', radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('${a['name'] ?? '—'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                          '${a['provider_type'] ?? ''} • ${a['email'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                StatusChip(status: '${a['status'] ?? ''}'),
              ],
            ),
            const SizedBox(height: 10),
            if (!pending && a['decided_at'] != null)
              Text(
                  'Decided ${_fmtDate(a['decided_at']?.toString())}'
                  '${a['decided_by'] != null ? ' • by ${a['decided_by']}' : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant)),
            Text(
                'Phone: ${a['phone'] ?? '—'} • License: ${a['license_no'] ?? '—'}',
                style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Address: ${a['address'] ?? '—'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
                '$docCount document${docCount == 1 ? '' : 's'} • Applied ${_fmtDate(a['created_at']?.toString())}',
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant)),
            // Registration details + viewable documents (audit
            // M5 / Panelist 18: reviewers used to see only a
            // document COUNT — the files themselves were never
            // uploaded, and approval dropped every detail).
            if (a['details'] is Map &&
                (a['details'] as Map).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _detailsSummary(a['details'] as Map),
                style: TextStyle(
                    fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ],
            if (docs is List && docs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in docs)
                    if (d is Map)
                      ActionChip(
                        avatar: const Icon(Icons.description_outlined,
                            size: 16),
                        label: Text(
                            '${d['kind'] ?? d['name'] ?? 'Document'}'),
                        onPressed: () =>
                            _viewDoc(context, state, d),
                      ),
                ],
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RButton(
                      label: 'Reject',
                      small: true,
                      variant: RButtonVariant.danger,
                      onPressed: () => _confirm(
                          context, state, a, 'rejected'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RButton(
                      label: 'Approve',
                      small: true,
                      onPressed: () => _confirm(
                          context, state, a, 'approved'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, AppState state,
      Map<String, dynamic> a, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            status == 'approved'
                ? 'Approve application?'
                : 'Reject application?',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
        content: Text(status == 'approved'
            ? 'This will create a ${a['provider_type']} catalog record for ${a['name']} and link it to their account.'
            : 'The applicant will be marked as rejected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          RButton(
            label: status == 'approved'
                ? 'Approve'
                : 'Reject',
            small: true,
            variant: status == 'approved'
                ? RButtonVariant.primary
                : RButtonVariant.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success = await state.decideProviderApplication(
        '${a['id']}', status, a);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
          content: Text(success
              ? 'Application ${status == 'approved' ? 'approved — provider record created' : 'rejected'}.'
              : 'Failed to update application. Try again.')),
    );
  }
}

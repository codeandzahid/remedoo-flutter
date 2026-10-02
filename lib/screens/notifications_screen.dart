import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Notifications with Read all + category tabs.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: state.markAllNotificationsRead,
            child: const Text('Read all',
                style: TextStyle(color: RemedooTheme.primary)),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: RemedooTheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: RemedooTheme.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Appointments'),
            Tab(text: 'Orders'),
            Tab(text: 'System'),
          ],
        ),
      ),
      body: MaxWidthBox(
        child: TabBarView(
          controller: _tabs,
          children: [
            _list(state.notifications),
            _list(state.notifications
                .where((n) => n.category == 'appointments')
                .toList()),
            _list(state.notifications
                .where((n) => n.category == 'orders')
                .toList()),
            _list(state.notifications
                .where((n) => n.category == 'system')
                .toList()),
          ],
        ),
      ),
    );
  }

  Widget _list(List<AppNotification> list) {
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none,
        title: 'No notifications',
        subtitle: 'You are all caught up!',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final n = list[i];
        return StaggerItem(
          index: i % 6,
          child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Stack(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: RemedooTheme.primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(n.icon,
                      color: RemedooTheme.primary),
                ),
                if (!n.read)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: RemedooTheme.emergency,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(n.title,
                style: TextStyle(
                    fontWeight: n.read
                        ? FontWeight.w500
                        : FontWeight.w800)),
            subtitle: Text(n.body),
            trailing: Text(
              '${n.time.day}/${n.time.month}',
              style:
                  const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            onTap: () {
              n.read = true;
              AppStateScope.of(context).refresh();
            },
          ),
          ),
        );
      },
    );
  }
}

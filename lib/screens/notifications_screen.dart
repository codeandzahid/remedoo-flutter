import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../app_navigator.dart';

/// Notifications: orange gradient header, segmented tabs, read/unread cards.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index != _index) {
        setState(() => _index = _tabs.index);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final unread = state.unreadCount;
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                    onPressed: () => goBack(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text('Notifications',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      if (unread > 0)
                        Text('$unread unread',
                            style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.75),
                                fontSize: 13)),
                    ],
                  ),
                ),
                if (state.notifications.isNotEmpty)
                  TextButton.icon(
                    onPressed: state.markAllNotificationsRead,
                    icon: const Icon(Icons.check,
                        size: 16, color: Colors.white),
                    label: const Text('Read all',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                // Segmented tabs in a white card.
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: RCard(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _tab('All', 0),
                        _tab('Appointments', 1),
                        _tab('Orders', 2),
                        _tab('System', 3),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: MaxWidthBox(
                    maxWidth: 760,
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _list(state.notifications),
                        _list(state.notifications
                            .where((n) =>
                                n.category == 'appointments')
                            .toList()),
                        _list(state.notifications
                            .where(
                                (n) => n.category == 'orders')
                            .toList()),
                        _list(state.notifications
                            .where(
                                (n) => n.category == 'system')
                            .toList()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, int i) {
    final selected = _index == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabs.animateTo(i),
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? RemedooTheme.ink
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? Colors.white
                  : Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(List<AppNotification> list) {
    if (list.isEmpty) {
      return const REmptyState(
        icon: Icons.notifications_none,
        title: 'No notifications',
        subtitle: 'You are all caught up!',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final n = list[i];
        return StaggerItem(
          index: i % 6,
          child: _card(n),
        );
      },
    );
  }

  Widget _card(AppNotification n) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color tileBg;
    final Color tileFg;
    switch (n.category) {
      case 'appointments':
        tileBg = scheme.primary.withValues(alpha: 0.12);
        tileFg = scheme.primary;
      case 'orders':
        tileBg =
            RemedooTheme.success.withValues(alpha: 0.12);
        tileFg = RemedooTheme.success;
      default:
        tileBg =
            RemedooTheme.warning.withValues(alpha: 0.14);
        tileFg = RemedooTheme.warning;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: n.read
            ? (dark
                ? RemedooTheme.darkMutedSurface
                : RemedooTheme.mutedSurface)
            : Theme.of(context).cardColor,
        borderRadius:
            BorderRadius.circular(RemedooRadius.card),
        border:
            Border.all(color: Theme.of(context).dividerColor),
        boxShadow: (!n.read && !dark)
            ? RemedooTheme.softShadow
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(RemedooRadius.card),
          onTap: () {
            n.read = true;
            AppStateScope.of(context).refresh();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(n.icon, color: tileFg, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: n.read
                                        ? FontWeight.w600
                                        : FontWeight.w800,
                                    color: n.read
                                        ? scheme.onSurfaceVariant
                                        : scheme.onSurface)),
                          ),
                          if (!n.read)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(
                                  left: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(n.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                        '${n.time.day}/${n.time.month}',
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

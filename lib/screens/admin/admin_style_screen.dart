import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/admin_style.dart';
import '../../widgets/widgets.dart';

/// Admin > Panel Style (owner order 2026-10-18: "try everyone one
/// by one"). A grid of every admin UI style with a live miniature
/// preview; tapping one applies it to the whole admin panel
/// instantly and persists it on this device.
class AdminStyleScreen extends StatelessWidget {
  final AppState state;

  const AdminStyleScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = state.adminStyle;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const RSectionHeader(
          title: 'Panel Style',
          subtitle:
              'Tap a style to apply it to the whole admin panel instantly. Your pick is saved on this device.',
        ),
        const SizedBox(height: 6),
        Text(
          'Trying them one by one? They are in order — Dark Command Center is style #1.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cols = w > 980 ? 3 : (w > 600 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.32,
              ),
              itemCount: AdminStyle.values.length,
              itemBuilder: (context, i) {
                final style = AdminStyle.values[i];
                return _StyleCard(
                  style: style,
                  index: i,
                  active: style == active,
                  onTap: () {
                    state.setAdminStyle(style);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Panel style: ${style.label}'),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _StyleCard extends StatelessWidget {
  final AdminStyle style;
  final int index;
  final bool active;
  final VoidCallback onTap;

  const _StyleCard({
    required this.style,
    required this.index,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? scheme.primary : scheme.outlineVariant,
            width: active ? 2.4 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live miniature: the style's own backdrop + surfaces.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 86,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AdminBackdrop(style),
                    Positioned(
                      left: 10,
                      top: 10,
                      bottom: 10,
                      width: 40,
                      child: Container(
                        decoration: adminDecoration(context, style,
                            radius: 8, depth: 2),
                      ),
                    ),
                    Positioned(
                      left: 60,
                      right: 10,
                      top: 10,
                      bottom: 10,
                      child: Container(
                        decoration: adminDecoration(context, style,
                            radius: 8, depth: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${index + 1}. ${style.label}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'ON',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                style.tagline,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

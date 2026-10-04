import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'lab_detail_screen.dart';
import 'pharmacy_detail_screen.dart';
import 'doctors_screen.dart';

/// Saved favorites across doctors, hospitals, labs, pharmacies.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.isSignedIn) {
      return const GuestGate();
    }
    final favs = state.favorites.toList();
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 4),
                const Text('Favorites',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                if (favs.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${favs.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: favs.isEmpty
                ? MaxWidthBox(
                    child: REmptyState(
                      icon: Icons.favorite_border,
                      title: 'No favorites yet',
                      subtitle:
                          'Tap the heart on any doctor, hospital, lab or pharmacy to save it here.',
                      actionLabel: 'Explore',
                      onAction: () =>
                          pushPage(context, const DoctorsScreen()),
                    ),
                  )
                : MaxWidthBox(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          20, 16, 20, 24),
                      itemCount: favs.length,
                      itemBuilder: (_, i) {
                        final key = favs[i];
                        final parts = key.split(':');
                        final kind = parts[0];
                        final id = parts.sublist(1).join(':');
                        return StaggerItem(
                          index: i % 6,
                          child: _tile(
                              context, state, kind, id, key),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, AppState state, String kind,
      String id, String key) {
    String title = id;
    String sub = kind;
    double? rating;
    VoidCallback? onTap;
    try {
      switch (kind) {
        case 'doctor':
          final d = doctorById(id);
          title = d.name;
          sub = d.specialty;
          rating = d.rating;
          onTap = () =>
              pushPage(context, DoctorDetailScreen(doctor: d));
        case 'hospital':
          final h = hospitalById(id);
          title = h.name;
          sub = h.location;
          rating = h.rating;
          onTap = () => pushPage(
              context, HospitalDetailScreen(hospital: h));
        case 'lab':
          final l = labById(id);
          title = l.name;
          sub = l.location;
          rating = l.rating;
          onTap =
              () => pushPage(context, LabDetailScreen(lab: l));
        case 'pharmacy':
          final p = pharmacyById(id);
          title = p.name;
          sub = p.location;
          rating = p.rating;
          onTap = () => pushPage(
              context, PharmacyDetailScreen(pharmacy: p));
      }
    } catch (_) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final Color tileBg;
    final Color tileFg;
    final IconData tileIcon;
    switch (kind) {
      case 'doctor':
        tileBg = scheme.primary.withValues(alpha: 0.12);
        tileFg = scheme.primary;
        tileIcon = Icons.medical_services_outlined;
      case 'hospital':
        tileBg =
            RemedooTheme.success.withValues(alpha: 0.12);
        tileFg = RemedooTheme.success;
        tileIcon = Icons.local_hospital_outlined;
      case 'lab':
        tileBg =
            RemedooTheme.warning.withValues(alpha: 0.14);
        tileFg = RemedooTheme.warning;
        tileIcon = Icons.science_outlined;
      default:
        tileBg =
            RemedooTheme.emergency.withValues(alpha: 0.1);
        tileFg = RemedooTheme.emergency;
        tileIcon = Icons.medication_outlined;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: RCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(tileIcon, color: tileFg, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(kind,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (rating != null) ...[
                        Icon(Icons.star,
                            size: 13,
                            color: RemedooTheme.warning),
                        const SizedBox(width: 3),
                        Text(rating.toStringAsFixed(1),
                            style:
                                const TextStyle(fontSize: 12)),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    scheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => state.toggleFavorite(key),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: RemedooTheme.destructive
                          .withValues(alpha: 0.1),
                    ),
                    child: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: RemedooTheme.destructive),
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

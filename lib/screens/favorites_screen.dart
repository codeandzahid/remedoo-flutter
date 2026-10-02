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
    final favs = state.favorites.toList();
    if (favs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: MaxWidthBox(
          child: EmptyState(
            icon: Icons.favorite_border,
            title: 'No favorites yet',
            subtitle:
                'Tap the heart on any doctor, hospital, lab or pharmacy to save it here.',
            actionLabel: 'Explore',
            onAction: () => pushPage(context, const DoctorsScreen()),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Favorites (${favs.length})')),
      body: MaxWidthBox(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: favs.length,
          itemBuilder: (_, i) {
            final key = favs[i];
            final parts = key.split(':');
            final kind = parts[0];
            final id = parts.sublist(1).join(':');
            return StaggerItem(
              index: i % 6,
              child: _tile(context, state, kind, id, key),
            );
          },
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, AppState state, String kind,
      String id, String key) {
    String title = id;
    String sub = kind;
    VoidCallback? onTap;
    try {
      switch (kind) {
        case 'doctor':
          final d = doctorById(id);
          title = d.name;
          sub = d.specialty;
          onTap = () => pushPage(context, DoctorDetailScreen(doctor: d));
        case 'hospital':
          final h = hospitalById(id);
          title = h.name;
          sub = h.location;
          onTap =
              () => pushPage(context, HospitalDetailScreen(hospital: h));
        case 'lab':
          final l = labById(id);
          title = l.name;
          sub = l.location;
          onTap = () => pushPage(context, LabDetailScreen(lab: l));
        case 'pharmacy':
          final p = pharmacyById(id);
          title = p.name;
          sub = p.location;
          onTap = () =>
              pushPage(context, PharmacyDetailScreen(pharmacy: p));
      }
    } catch (_) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: InitialsAvatar(name: title, radius: 22),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub),
        trailing: IconButton(
          icon: const Icon(Icons.favorite,
              color: RemedooTheme.emergency),
          onPressed: () => state.toggleFavorite(key),
        ),
        onTap: onTap,
      ),
    );
  }
}

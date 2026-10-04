import 'package:flutter/material.dart';

import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'profile_screen.dart';
import 'appointments_screen.dart';
import 'family_screen.dart';
import 'reminders_screen.dart';
import 'orders_screen.dart';
import 'medical_history_screen.dart';
import 'favorites_screen.dart';
import 'refund_tracking_screen.dart';

/// Settings: profile card, quick links, preferences, about, logout.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 4),
                const Text('Settings',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Expanded(
            child: MaxWidthBox(
              maxWidth: 720,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // User info card.
                  RCard(
                    onTap: () {
                      if (!checkLogin(context)) return;
                      pushPage(context, const ProfileScreen());
                    },
                    child: Row(
                      children: [
                        InitialsAvatar(
                            name: state.displayName, radius: 26),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(state.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(state.userEmail ?? 'Guest',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quick links.
                  _groupCard(context, [
                    _linkData(context, Icons.person_outline,
                        'Edit Profile',
                        () => pushPage(
                            context, const ProfileScreen())),
                    _linkData(context, Icons.calendar_month,
                        'My Appointments',
                        () => _go(
                            context, const AppointmentsScreen())),
                    _linkData(context, Icons.shopping_bag, 'My Orders',
                        () => _go(context, const OrdersScreen())),
                    _linkData(context, Icons.history,
                        'Medical History',
                        () => _go(context,
                            const MedicalHistoryScreen())),
                    _linkData(context, Icons.favorite_outline,
                        'My Favorites',
                        () => _go(context,
                            const FavoritesScreen())),
                    _linkData(context, Icons.replay,
                        'Refund Status',
                        () => _go(context,
                            const RefundTrackingScreen())),
                  ]),
                  const SizedBox(height: 20),
                  const Text('Preferences',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  RCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        _prefRow(
                          context,
                          icon: Icons.dark_mode_outlined,
                          label: 'Dark Mode',
                          trailing: Switch(
                            value: state.darkMode,
                            activeThumbColor: scheme.primary,
                            onChanged: state.setDarkMode,
                          ),
                        ),
                        _prefRow(
                          context,
                          icon: Icons.notifications_outlined,
                          label: 'Email Notifications',
                          trailing: Switch(
                            value: state.emailNotif,
                            activeThumbColor: scheme.primary,
                            onChanged: (_) =>
                                state.toggleEmailNotif(),
                          ),
                        ),
                        _prefRow(
                          context,
                          icon: Icons.notifications_outlined,
                          label: 'Push Notifications',
                          trailing: Switch(
                            value: state.pushNotif,
                            activeThumbColor: scheme.primary,
                            onChanged: (_) =>
                                state.togglePushNotif(),
                          ),
                        ),
                        _prefRow(
                          context,
                          icon: Icons.language,
                          label: 'Language',
                          last: true,
                          trailing: DropdownButton<String>(
                            value: state.language,
                            underline: const SizedBox.shrink(),
                            style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 14),
                            items: const [
                              'English',
                              'Hindi',
                              'Urdu'
                            ]
                                .map((l) => DropdownMenuItem(
                                    value: l,
                                    child: Text(l)))
                                .toList(),
                            onChanged: (v) =>
                                state.setLanguage(v ?? 'English'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Appearance',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  RCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Theme',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface)),
                        const SizedBox(height: 12),
                        Builder(builder: (c) {
                          final packs = state.availablePacks;
                          final rows = (packs.length / 3).ceil();
                          return Column(
                            children: [
                              for (var row = 0; row < rows; row++)
                                Padding(
                                  padding: EdgeInsets.only(
                                      bottom:
                                          row == rows - 1 ? 0 : 10),
                                  child: Row(
                                    children: [
                                      for (var col = 0; col < 3; col++)
                                        if (row * 3 + col <
                                            packs.length)
                                          Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right:
                                                    col == 2 ? 0 : 10,
                                              ),
                                              child: _themeTile(
                                                  context,
                                                  state,
                                                  packs[row * 3 + col],
                                                  scheme),
                                            ),
                                          )
                                        else
                                          const Expanded(
                                              child: SizedBox.shrink()),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _groupCard(context, [
                    _linkData(
                        context,
                        Icons.privacy_tip_outlined,
                        'Privacy Policy',
                        () => _infoDialog(
                            context,
                            'Privacy Policy',
                            'Your health data is encrypted and never shared without your consent. (demo policy text)')),
                    _linkData(
                        context,
                        Icons.info_outline,
                        'About Remedoo',
                        () => _infoDialog(
                            context,
                            'About Remedoo',
                            'Remedoo v1.0.0 (build 2026-10-03)\nYour Health, Our Priority.\n\nBook doctors, hospitals, labs and medicines in one app.'),
                        last: true),
                  ]),
                  const SizedBox(height: 20),
                  // Log out: red outline pill.
                  _logoutButton(context, state),
                  const SizedBox(height: 20),
                  Center(
                    child: Text('Remedoo v1.0.0 (build 2026-10-03)',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _go(BuildContext context, Widget page) {
    if (page is ProfileScreen ||
        page is AppointmentsScreen ||
        page is OrdersScreen ||
        page is FamilyScreen ||
        page is RemindersScreen) {
      if (!checkLogin(context)) return;
    }
    pushPage(context, page);
  }

  /// One row of a grouped link card.
  _LinkData _linkData(
      BuildContext context, IconData icon, String label,
      VoidCallback onTap,
      {bool last = false}) {
    return _LinkData(icon, label, onTap, last);
  }

  Widget _groupCard(BuildContext context, List<_LinkData> rows) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            InkWell(
              onTap: rows[i].onTap,
              borderRadius: i == 0
                  ? const BorderRadius.vertical(
                      top: Radius.circular(RemedooRadius.card))
                  : i == rows.length - 1
                      ? const BorderRadius.vertical(
                          bottom:
                              Radius.circular(RemedooRadius.card))
                      : BorderRadius.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: RemedooTheme.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(rows[i].icon,
                          size: 18,
                          color: RemedooTheme.accentForeground),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(rows[i].label,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right,
                        size: 20, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            if (i < rows.length - 1)
              Divider(
                  height: 1,
                  indent: 64,
                  color: Theme.of(context).dividerColor),
          ],
        ],
      ),
    );
  }

  Widget _themeTile(BuildContext context, AppState state, ThemePack pack,
      ColorScheme scheme) {
    final selected = state.themePack.id == pack.id;
    return GestureDetector(
      onTap: () => state.setThemePack(pack),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: pack.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? pack.primary : scheme.outline,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [pack.primary, pack.primaryDark],
                ),
              ),
              child: selected
                  ? const Icon(Icons.check,
                      size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(pack.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: pack.ink)),
          ],
        ),
      ),
    );
  }

  Widget _prefRow(BuildContext context,
      {required IconData icon,
      required String label,
      required Widget trailing,
      bool last = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: RemedooTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    size: 18,
                    color: RemedooTheme.accentForeground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
              trailing,
            ],
          ),
        ),
        if (!last)
          Divider(
              height: 1,
              indent: 48,
              color: Theme.of(context).dividerColor),
      ],
    );
  }

  Widget _logoutButton(BuildContext context, AppState state) {
    return Material(
      color: RemedooTheme.destructive.withValues(alpha: 0.06),
      shape: StadiumBorder(
        side: BorderSide(
            color:
                RemedooTheme.destructive.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: () async {
          final ok = await confirmDialog(
            context,
            title: 'Log out?',
            message: 'You will be signed out of Remedoo.',
            confirmLabel: 'Log Out',
          );
          if (ok) state.logout();
        },
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.logout,
                  size: 18, color: RemedooTheme.destructive),
              SizedBox(width: 8),
              Text('Log Out',
                  style: TextStyle(
                      color: RemedooTheme.destructive,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  void _infoDialog(
      BuildContext context, String title, String body) {
    showResponsiveDialog(
      context,
      (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          RButton(
            label: 'OK',
            small: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

}

class _LinkData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  _LinkData(this.icon, this.label, this.onTap, [this.last = false]);
}

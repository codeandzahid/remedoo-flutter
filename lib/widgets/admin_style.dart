import 'package:flutter/material.dart';

/// Admin panel style system (owner order 2026-10-18: "try everyone
/// one by one"). The admin shell, the admin login and shared cards
/// render in whichever [AdminStyle] is active; the super admin
/// flips styles live in Admin > Panel Style and the choice persists
/// on the device (AppState.adminStyle).
///
/// Each style defines: a backdrop (the environment behind the
/// shell), a surface decoration (cards / slabs), a component theme,
/// and a chrome layout — floating (detached sidebar + top-bar pill
/// + workspace slab) or attached (flush sidebar + full-width bar).
enum AdminStyle {
  darkCommand('dark', 'Dark Command Center',
      'Deep slate surfaces, one bright accent — the pro SaaS look, easy on the eyes for long sessions.'),
  materialYou('material', 'Material You',
      'Google\'s newest: soft tonal colors, big rounded shapes, calm and finished.'),
  brutal('brutal', 'Neo-Brutalism',
      'White cards, thick black borders, hard shadows, one loud accent. Bold but very readable.'),
  clay('clay', 'Claymorphism',
      'Soft puffy clay cards in pastels. Friendly and playful.'),
  bento('bento', 'Bento Grid',
      'Everything in neat white tiles on light gray — clean, airy, Apple-style.'),
  neu('neu', 'Neumorphism',
      'Surfaces pressed out of the background with soft twin shadows. Subtle and quiet.'),
  spatial('spatial', 'Spatial',
      'Deep-space environment with floating light slabs at different depths.'),
  glass('glass', 'Glassmorphism',
      'Pastel aurora with frosted see-through panels.'),
  maximal('maximal', 'Maximalism',
      'Loud saturated gradient, warm paper cards, chunky ink outlines and hard shadows.');

  final String id;
  final String label;
  final String tagline;
  const AdminStyle(this.id, this.label, this.tagline);

  static AdminStyle byId(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return AdminStyle.darkCommand;
  }

  bool get floating =>
      this == AdminStyle.spatial ||
      this == AdminStyle.clay ||
      this == AdminStyle.bento;

  bool get isDark => this == AdminStyle.darkCommand;
}

/// Carries the active style down the admin subtree so shared
/// widgets (RCard) render the matching surface.
class AdminScope extends InheritedWidget {
  final AdminStyle style;

  const AdminScope({
    super.key,
    required this.style,
    required super.child,
  });

  static AdminStyle of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AdminScope>();
    return scope?.style ?? AdminStyle.darkCommand;
  }

  /// Null when there is no admin scope above — shared widgets use
  /// this to keep their standard look outside the admin panel.
  static AdminStyle? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AdminScope>();
    return scope?.style;
  }

  @override
  bool updateShouldNotify(AdminScope oldWidget) =>
      style != oldWidget.style;
}

const Color _ink = Color(0xFF232038);
const Color _paper = Color(0xFFFFFBEB);
const Color _darkSurface = Color(0xFF111A2E);
const Color _darkEdge = Color(0xFF26334D);
const Color _neuBase = Color(0xFFE0E5EC);

/// The surface decoration for cards and slabs in [style]. [depth]
/// only matters for Spatial (0 card, 1 workspace, 2 top chrome).
BoxDecoration adminDecoration(
  BuildContext context,
  AdminStyle style, {
  double radius = 24,
  int depth = 0,
}) {
  final scheme = Theme.of(context).colorScheme;
  BoxShadow soft(Color c, double blur, double dx, double dy) =>
      BoxShadow(color: c, blurRadius: blur, offset: Offset(dx, dy));
  switch (style) {
    case AdminStyle.spatial:
      final shadows = switch (depth) {
        2 => [
            soft(const Color(0x4D000000), 48, 0, 24),
            soft(const Color(0x26000000), 10, 0, 4),
          ],
        1 => [
            soft(const Color(0x38000000), 36, 0, 18),
            soft(const Color(0x1F000000), 8, 0, 3),
          ],
        _ => [
            soft(const Color(0x1F000000), 20, 0, 8),
            soft(const Color(0x14000000), 3, 0, 1),
          ],
      };
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.98),
            Colors.white.withValues(alpha: 0.93),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.65), width: 1),
        boxShadow: shadows,
      );
    case AdminStyle.glass:
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.62),
            Colors.white.withValues(alpha: 0.38),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.75), width: 1.2),
        boxShadow: [
          soft(const Color(0xFF7C3AED).withValues(alpha: 0.18), 24, 0, 10),
        ],
      );
    case AdminStyle.maximal:
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_paper, Color(0xFFFFF1C9)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _ink, width: 2),
        boxShadow: [
          soft(const Color(0xE6232038), 0, 6, 6),
          soft(const Color(0x407C3AED), 28, 0, 14),
        ],
      );
    case AdminStyle.darkCommand:
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF131E33), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _darkEdge, width: 1),
        boxShadow: [soft(Colors.black.withValues(alpha: 0.45), 18, 0, 8)],
      );
    case AdminStyle.materialYou:
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerLowest,
            scheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outlineVariant, width: 1),
        boxShadow: [soft(Colors.black.withValues(alpha: 0.05), 16, 0, 6)],
      );
    case AdminStyle.clay:
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF5F3FF)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          soft(Colors.white.withValues(alpha: 0.9), 12, -6, -6),
          soft(const Color(0xFF7C3AED).withValues(alpha: 0.18), 18, 8, 8),
        ],
      );
    case AdminStyle.brutal:
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: [soft(Colors.black.withValues(alpha: 0.9), 0, 5, 5)],
      );
    case AdminStyle.bento:
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
        boxShadow: [soft(Colors.black.withValues(alpha: 0.06), 24, 0, 10)],
      );
    case AdminStyle.neu:
      return BoxDecoration(
        color: _neuBase,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          soft(Colors.white.withValues(alpha: 0.95), 12, -6, -6),
          soft(const Color(0xFFA3B1C6).withValues(alpha: 0.5), 12, 6, 6),
        ],
      );
  }
}

/// The environment painted behind the admin shell for [style].
class AdminBackdrop extends StatelessWidget {
  final AdminStyle style;
  const AdminBackdrop(this.style, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (style) {
      case AdminStyle.spatial:
        return const _SpatialBackdrop();
      case AdminStyle.glass:
        return const _GlassBackdrop();
      case AdminStyle.maximal:
        return const _MaxBackdrop();
      case AdminStyle.darkCommand:
        return const ColoredBox(color: Color(0xFF070D1A));
      case AdminStyle.materialYou:
        return ColoredBox(color: scheme.surfaceContainerLow);
      case AdminStyle.brutal:
        return const ColoredBox(color: _paper);
      case AdminStyle.clay:
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEDE9FE),
                Color(0xFFFDF2F8),
                Color(0xFFECFDF5),
              ],
            ),
          ),
        );
      case AdminStyle.bento:
        return const ColoredBox(color: Color(0xFFF4F4F5));
      case AdminStyle.neu:
        return const ColoredBox(color: _neuBase);
    }
  }
}

/// Flexible-space decoration for the attached (flush) top bar.
BoxDecoration adminBarDecoration(BuildContext context, AdminStyle style) {
  final scheme = Theme.of(context).colorScheme;
  BorderSide side(Color c, double w) => BorderSide(color: c, width: w);
  switch (style) {
    case AdminStyle.glass:
      return BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        border: Border(
            bottom: side(Colors.white.withValues(alpha: 0.6), 1)),
      );
    case AdminStyle.maximal:
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFFF97316)],
        ),
        border: Border(bottom: side(_ink, 2)),
      );
    case AdminStyle.darkCommand:
      return BoxDecoration(
        color: const Color(0xFF0D1526),
        border: Border(bottom: side(_darkEdge, 1)),
      );
    case AdminStyle.materialYou:
      return BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: side(scheme.outlineVariant, 1)),
      );
    case AdminStyle.brutal:
      return BoxDecoration(
        color: Colors.white,
        border: Border(bottom: side(Colors.black, 2.5)),
      );
    case AdminStyle.neu:
      return BoxDecoration(
        color: _neuBase,
        border: Border(bottom: side(const Color(0xFFC2CAD6), 1)),
      );
    case AdminStyle.spatial:
    case AdminStyle.clay:
    case AdminStyle.bento:
      return const BoxDecoration(color: Colors.transparent);
  }
}

/// Sidebar surface for the attached chrome (floating chrome uses
/// [adminDecoration] at depth 2 instead).
BoxDecoration adminSidebarDecoration(
    BuildContext context, AdminStyle style) {
  final scheme = Theme.of(context).colorScheme;
  BorderSide side(Color c, double w) => BorderSide(color: c, width: w);
  switch (style) {
    case AdminStyle.glass:
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.40),
          ],
        ),
        border: Border(
            right: side(Colors.white.withValues(alpha: 0.6), 1)),
      );
    case AdminStyle.maximal:
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_paper, Color(0xFFFFF1C9)],
        ),
        border: Border(right: side(_ink, 2)),
      );
    case AdminStyle.darkCommand:
      return BoxDecoration(
        color: const Color(0xFF0D1526),
        border: Border(right: side(_darkEdge, 1)),
      );
    case AdminStyle.materialYou:
      return BoxDecoration(color: scheme.surfaceContainerLow);
    case AdminStyle.brutal:
      return BoxDecoration(
        color: Colors.white,
        border: Border(right: side(Colors.black, 2.5)),
      );
    case AdminStyle.neu:
      return const BoxDecoration(color: _neuBase);
    case AdminStyle.spatial:
    case AdminStyle.clay:
    case AdminStyle.bento:
      return const BoxDecoration(color: Colors.transparent);
  }
}

/// Foreground color for content sitting directly on the backdrop
/// (e.g. the admin login's back button).
Color adminOnBackdropColor(AdminStyle style) {
  switch (style) {
    case AdminStyle.spatial:
    case AdminStyle.darkCommand:
    case AdminStyle.maximal:
      return Colors.white;
    case AdminStyle.glass:
    case AdminStyle.materialYou:
    case AdminStyle.clay:
    case AdminStyle.bento:
    case AdminStyle.neu:
    case AdminStyle.brutal:
      return const Color(0xFF1E293B);
  }
}

/// The component theme for [style], layered over the app theme.
ThemeData adminTheme(BuildContext context, AdminStyle style) {
  final base = Theme.of(context);
  final scheme = base.colorScheme;
  OutlineInputBorder fb(Color c, double w, [double r = 14]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: BorderSide(color: c, width: w),
      );
  RoundedRectangleBorder shape(double r, [BorderSide? side]) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r),
        side: side ?? BorderSide.none,
      );

  switch (style) {
    case AdminStyle.spatial:
      return base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: const Color(0xFF0F172A),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        ),
        cardTheme: base.cardTheme.copyWith(
          color: Colors.white.withValues(alpha: 0.95),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          surfaceTintColor: Colors.transparent,
          shape: shape(
              24, BorderSide(color: Colors.white.withValues(alpha: 0.65))),
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: shape(26),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
        ),
        popupMenuTheme: base.popupMenuTheme.copyWith(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: shape(18),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: const Color(0xFFF1F5F9),
          selectedColor: scheme.primary.withValues(alpha: 0.18),
          side: BorderSide.none,
        ),
        dividerTheme: base.dividerTheme.copyWith(
          color: const Color(0xFF0F172A).withValues(alpha: 0.10),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.92),
          border: fb(const Color(0xFFCBD5E1), 1.2),
          enabledBorder: fb(const Color(0xFFCBD5E1), 1.2),
          focusedBorder: fb(scheme.primary, 1.8),
        ),
        dataTableTheme: base.dataTableTheme.copyWith(
          headingRowColor:
              const WidgetStatePropertyAll(Color(0xFFF1F5F9)),
          dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
          dividerThickness: 1,
        ),
        expansionTileTheme: base.expansionTileTheme.copyWith(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
        ),
      );
    case AdminStyle.glass:
      final white = Colors.white;
      return base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: base.cardTheme.copyWith(
          color: white.withValues(alpha: 0.55),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: shape(20,
              BorderSide(color: white.withValues(alpha: 0.65))),
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: white.withValues(alpha: 0.94),
          surfaceTintColor: Colors.transparent,
          shape: shape(24),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: white.withValues(alpha: 0.96),
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        popupMenuTheme: base.popupMenuTheme.copyWith(
          color: white.withValues(alpha: 0.95),
          surfaceTintColor: Colors.transparent,
          shape: shape(16),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: white.withValues(alpha: 0.45),
          selectedColor: scheme.primary.withValues(alpha: 0.22),
          side: BorderSide(color: white.withValues(alpha: 0.6)),
        ),
        dividerTheme: base.dividerTheme.copyWith(
          color: white.withValues(alpha: 0.55),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: white.withValues(alpha: 0.45),
          border: fb(white.withValues(alpha: 0.7), 1),
          enabledBorder: fb(white.withValues(alpha: 0.7), 1),
          focusedBorder: fb(scheme.primary, 1.6),
        ),
        dataTableTheme: base.dataTableTheme.copyWith(
          headingRowColor:
              WidgetStatePropertyAll(white.withValues(alpha: 0.35)),
          dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
          dividerThickness: 0.6,
        ),
        expansionTileTheme: base.expansionTileTheme.copyWith(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
        ),
      );
    case AdminStyle.maximal:
      RoundedRectangleBorder inkShape(double r) =>
          shape(r, const BorderSide(color: _ink, width: 2));
      return base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        cardTheme: base.cardTheme.copyWith(
          color: _paper,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: inkShape(20),
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: _paper,
          surfaceTintColor: Colors.transparent,
          shape: inkShape(24),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: _paper,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        popupMenuTheme: base.popupMenuTheme.copyWith(
          color: _paper,
          surfaceTintColor: Colors.transparent,
          shape: inkShape(16),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: const Color(0xFFFDE68A),
          selectedColor: const Color(0xFFDB2777).withValues(alpha: 0.35),
          side: const BorderSide(color: _ink, width: 1.5),
        ),
        dividerTheme: base.dividerTheme.copyWith(
          color: _ink.withValues(alpha: 0.35),
          thickness: 1.2,
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: _paper,
          border: fb(_ink, 2),
          enabledBorder: fb(_ink, 2),
          focusedBorder: fb(const Color(0xFFDB2777), 2.5),
        ),
        dataTableTheme: base.dataTableTheme.copyWith(
          headingRowColor:
              const WidgetStatePropertyAll(Color(0xFFDDD6FE)),
          dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
          dividerThickness: 1,
        ),
        expansionTileTheme: base.expansionTileTheme.copyWith(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
        ),
      );
    case AdminStyle.darkCommand:
      final darkScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C3AED),
        brightness: Brightness.dark,
      ).copyWith(
        surface: _darkSurface,
        onSurface: const Color(0xFFE2E8F0),
        primary: const Color(0xFFA78BFA),
        secondary: const Color(0xFF38BDF8),
      );
      final dark = base.copyWith(
        brightness: Brightness.dark,
        colorScheme: darkScheme,
      );
      return dark.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: dark.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: const Color(0xFFE2E8F0),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: const IconThemeData(color: Color(0xFFE2E8F0)),
        ),
        cardTheme: dark.cardTheme.copyWith(
          color: _darkSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: shape(16, const BorderSide(color: _darkEdge)),
        ),
        dialogTheme: dark.dialogTheme.copyWith(
          backgroundColor: _darkSurface,
          surfaceTintColor: Colors.transparent,
          shape: shape(20, const BorderSide(color: _darkEdge)),
        ),
        bottomSheetTheme: dark.bottomSheetTheme.copyWith(
          backgroundColor: _darkSurface,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        popupMenuTheme: dark.popupMenuTheme.copyWith(
          color: const Color(0xFF16223C),
          surfaceTintColor: Colors.transparent,
          shape: shape(14, const BorderSide(color: _darkEdge)),
        ),
        chipTheme: dark.chipTheme.copyWith(
          backgroundColor: const Color(0xFF1E293B),
          selectedColor: const Color(0xFFA78BFA).withValues(alpha: 0.30),
          side: const BorderSide(color: Color(0xFF334155)),
          labelStyle: const TextStyle(color: Color(0xFFE2E8F0)),
        ),
        dividerTheme: dark.dividerTheme.copyWith(
          color: _darkEdge,
          thickness: 1,
        ),
        inputDecorationTheme: dark.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: const Color(0xFF0B1220),
          border: fb(_darkEdge, 1.2),
          enabledBorder: fb(_darkEdge, 1.2),
          focusedBorder: fb(const Color(0xFF38BDF8), 1.6),
        ),
        dataTableTheme: dark.dataTableTheme.copyWith(
          headingRowColor:
              const WidgetStatePropertyAll(Color(0xFF1E293B)),
          dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
          dividerThickness: 1,
        ),
        expansionTileTheme: dark.expansionTileTheme.copyWith(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
        ),
      );
    case AdminStyle.materialYou:
      return base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: base.cardTheme.copyWith(
          color: scheme.surfaceContainerLowest,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: shape(28, BorderSide(color: scheme.outlineVariant)),
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: scheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          shape: shape(28),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: scheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        popupMenuTheme: base.popupMenuTheme.copyWith(
          color: scheme.surfaceContainerLowest,
          surfaceTintColor: Colors.transparent,
          shape: shape(16),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: scheme.secondaryContainer,
          selectedColor: scheme.primaryContainer,
          side: BorderSide.none,
        ),
        dividerTheme: base.dividerTheme.copyWith(
          color: scheme.outlineVariant,
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
          border: fb(Colors.transparent, 0, 16),
          enabledBorder: fb(Colors.transparent, 0, 16),
          focusedBorder: fb(scheme.primary, 2, 16),
        ),
        dataTableTheme: base.dataTableTheme.copyWith(
          headingRowColor:
              WidgetStatePropertyAll(scheme.surfaceContainerLow),
          dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
          dividerThickness: 1,
        ),
        expansionTileTheme: base.expansionTileTheme.copyWith(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
        ),
      );
    case AdminStyle.clay:
      return base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: const Color(0xFF3B0764),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: Color(0xFF3B0764),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF3B0764)),
        ),
        cardTheme: base.cardTheme.copyWith(
          color: const Color(0xFFF5F3FF),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: shape(32),
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: const Color(0xFFFDFBFF),
          surfaceTintColor: Colors.transparent,
          shape: shape(28),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: const Color(0xFFFDFBFF),
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        popupMenuTheme: base.popupMenuTheme.copyWith(
          color: const Color(0xFFFDFBFF),
          surfaceTintColor: Colors.transparent,
          shape: shape(20),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: const Color(0xFFEDE9FE),
          selectedColor: const Color(0xFFDDD6FE),
          side: BorderSide.none,
        ),
        dividerTheme: base.dividerTheme.copyWith(
          color: const Color(0xFFE9D5FF).withValues(alpha: 0.7),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: Colors.white,
          border: fb(const Color(0xFFDDD6FE), 1.5, 18),
          enabledBorder: fb(const Color(0xFFDDD6FE), 1.5, 18),
          focusedBorder: fb(const Color(0xFFA78BFA), 2, 18),
        ),
        dataTableTheme: base.dataTableTheme.copyWith(
          headingRowColor:
              const WidgetStatePropertyAll(Color(0xFFEDE9FE)),
          dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
          dividerThickness: 1,
        ),
        expansionTileTheme: base.expansionTileTheme.copyWith(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
        ),
      );
    case AdminStyle.brutal:
      RoundedRectangleBorder inkShape(double r) =>
          shape(r, const BorderSide(color: Colors.black, width: 2.5));
      return base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        cardTheme: base.cardTheme.copyWith(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: inkShape(14),
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: inkShape(18),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
        ),
        popupMenuTheme: base.popupMenuTheme.copyWith(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: inkShape(12),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: const Color(0xFFFDE047),
          selectedColor: const Color(0xFFF9A8D4),
          side: const BorderSide(color: Colors.black, width: 1.5),
          labelStyle: const TextStyle(color: Colors.black),
        ),
        dividerTheme: base.dividerTheme.copyWith(
          color: Colors.black.withValues(alpha: 0.55),
          thickness: 1.5,
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: Colors.white,
          border: fb(Colors.black, 2),
          enabledBorder: fb(Colors.black, 2),
          focusedBorder: fb(Colors.black, 2.5),
        ),
        dataTableTheme: base.dataTableTheme.copyWith(
          headingRowColor:
              const WidgetStatePropertyAll(Color(0xFFFDE047)),
          dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
          dividerThickness: 1,
        ),
        expansionTileTheme: base.expansionTileTheme.copyWith(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
        ),
      );
    case AdminStyle.bento:
      return base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: base.cardTheme.copyWith(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: shape(28, const BorderSide(color: Color(0xFFE4E4E7))),
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: shape(28),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        popupMenuTheme: base.popupMenuTheme.copyWith(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: shape(18),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: const Color(0xFFF4F4F5),
          selectedColor: scheme.primary.withValues(alpha: 0.16),
          side: BorderSide.none,
        ),
        dividerTheme: base.dividerTheme.copyWith(
          color: const Color(0xFFE4E4E7),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          border: fb(const Color(0xFFE4E4E7), 1.2),
          enabledBorder: fb(const Color(0xFFE4E4E7), 1.2),
          focusedBorder: fb(scheme.primary, 1.8),
        ),
        dataTableTheme: base.dataTableTheme.copyWith(
          headingRowColor:
              const WidgetStatePropertyAll(Color(0xFFFAFAFA)),
          dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
          dividerThickness: 1,
        ),
        expansionTileTheme: base.expansionTileTheme.copyWith(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
        ),
      );
    case AdminStyle.neu:
      return base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: const Color(0xFF334155),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF334155)),
        ),
        cardTheme: base.cardTheme.copyWith(
          color: _neuBase,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: shape(24),
        ),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: _neuBase,
          surfaceTintColor: Colors.transparent,
          shape: shape(24),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: _neuBase,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        popupMenuTheme: base.popupMenuTheme.copyWith(
          color: _neuBase,
          surfaceTintColor: Colors.transparent,
          shape: shape(18),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: _neuBase,
          selectedColor: scheme.primary.withValues(alpha: 0.20),
          side: const BorderSide(color: Color(0xFFB8C2D0)),
        ),
        dividerTheme: base.dividerTheme.copyWith(
          color: const Color(0xFFB8C2D0).withValues(alpha: 0.7),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: _neuBase,
          border: fb(const Color(0xFFC2CAD6), 1.2),
          enabledBorder: fb(const Color(0xFFC2CAD6), 1.2),
          focusedBorder: fb(scheme.primary, 1.8),
        ),
        dataTableTheme: base.dataTableTheme.copyWith(
          headingRowColor:
              const WidgetStatePropertyAll(Color(0xFFD3DBE6)),
          dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
          dividerThickness: 1,
        ),
        expansionTileTheme: base.expansionTileTheme.copyWith(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
        ),
      );
  }
}

/// Spatial environment: deep indigo space + ambient glows + dust.
class _SpatialBackdrop extends StatelessWidget {
  const _SpatialBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B1026),
                Color(0xFF17203A),
                Color(0xFF1E293B),
              ],
            ),
          ),
        ),
        Positioned(top: -160, left: -120, child: _glow(460, const Color(0xFF7C3AED), 0.40)),
        Positioned(bottom: -180, right: -100, child: _glow(520, const Color(0xFF0D9488), 0.32)),
        Positioned(top: 120, right: 180, child: _glow(220, const Color(0xFFF59E0B), 0.14)),
        CustomPaint(painter: _DotsPainter(0.05, 34, 1.4)),
      ],
    );
  }

  Widget _glow(double size, Color color, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Glass environment: pastel aurora + soft blurred color blobs.
class _GlassBackdrop extends StatelessWidget {
  const _GlassBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF3EFFF),
                Color(0xFFEAF4FF),
                Color(0xFFEAFBF3),
                Color(0xFFFFEEF6),
              ],
            ),
          ),
        ),
        Positioned(top: -90, left: -70, child: _blob(300, const Color(0xFF7C3AED), 0.30)),
        Positioned(top: 60, right: -90, child: _blob(280, const Color(0xFF38BDF8), 0.30)),
        Positioned(bottom: -110, left: 130, child: _blob(320, const Color(0xFF34D399), 0.26)),
        Positioned(bottom: 30, right: 90, child: _blob(210, const Color(0xFFF472B6), 0.26)),
      ],
    );
  }

  Widget _blob(double size, Color color, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Maximal environment: loud saturated gradient + dot pattern +
/// bold outlined shapes.
class _MaxBackdrop extends StatelessWidget {
  const _MaxBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2E1065),
                Color(0xFF7C3AED),
                Color(0xFFDB2777),
                Color(0xFFF97316),
              ],
              stops: [0.0, 0.38, 0.72, 1.0],
            ),
          ),
        ),
        CustomPaint(painter: _DotsPainter(0.10, 26, 2.2)),
        Positioned(
          top: -70,
          right: -50,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20), width: 10),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: -60,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFFDE68A).withValues(alpha: 0.35),
                  width: 10),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          right: 140,
          child: Icon(Icons.star,
              size: 120, color: Colors.white.withValues(alpha: 0.10)),
        ),
      ],
    );
  }
}

class _DotsPainter extends CustomPainter {
  final double alpha;
  final double gap;
  final double radius;
  const _DotsPainter(this.alpha, this.gap, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
    for (double x = gap / 2; x < size.width; x += gap) {
      for (double y = gap / 2; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

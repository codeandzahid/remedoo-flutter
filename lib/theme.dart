import 'package:flutter/material.dart';

/// A named UI theme pack: the full set of brand tokens for one visual theme.
///
/// The app ships six user-facing themes (the user's hand-picked favorites):
/// Sky Pulse, Ocean Sand, Lavender Mist, Blush Rose, Honey Glow, Emerald Heal.
/// The active pack is held by [RemedooTheme] and switched at runtime; every
/// `RemedooTheme.<token>` getter below reads from it, so all call sites
/// follow the selected theme with no per-screen changes.
/// Decorative header artwork style, one per theme. Each theme paints its
/// own subtle motif behind gradient headers (see ThemeBackdrop).
enum ThemeBackdrop { clouds, wash, mist, petals, glow, leaves }

class ThemePack {
  final String id;
  final String name;
  final Color primary;
  final Color primaryDark;
  final Color background;
  final Color card;
  final Color ink;
  final Color mutedText;
  final Color border;
  final Color secondary;
  final Color mutedSurface;
  final Color accent;
  final Color accentForeground;
  final Color shadowTint;

  /// Design personality (beyond color): corner roundness of cards,
  /// whether buttons are fully pill-shaped, shadow softness/strength,
  /// and the header artwork motif.
  final double cardRadius;
  final bool pillButtons;
  final double shadowBlur;
  final double shadowOpacity;
  final ThemeBackdrop backdrop;

  const ThemePack({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryDark,
    required this.background,
    required this.card,
    required this.ink,
    required this.mutedText,
    required this.border,
    required this.secondary,
    required this.mutedSurface,
    required this.accent,
    required this.accentForeground,
    required this.shadowTint,
    required this.cardRadius,
    required this.pillButtons,
    required this.shadowBlur,
    required this.shadowOpacity,
    required this.backdrop,
  });

  /// Airy sky-blue on near-white. Breezy, optimistic, fresh.
  /// Playful claymorphism: puffy ultra-round cards, pill buttons,
  /// soft cloud shadows, cloud artwork.
  static const skyPulse = ThemePack(
    id: 'sky_pulse',
    name: 'Sky Pulse',
    primary: Color(0xFF0284C7),
    primaryDark: Color(0xFF0369A1),
    background: Color(0xFFF0F9FF),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF0C2D48),
    mutedText: Color(0xFF5B7A93),
    border: Color(0xFFDCEBF5),
    secondary: Color(0xFFE8F4FC),
    mutedSurface: Color(0xFFE4F1FA),
    accent: Color(0xFFDFF1FB),
    accentForeground: Color(0xFF075985),
    shadowTint: Color(0xFF0284C7),
    cardRadius: 28,
    pillButtons: true,
    shadowBlur: 24,
    shadowOpacity: 0.12,
    backdrop: ThemeBackdrop.clouds,
  );

  /// Warm sand background, ocean-teal brand. Coastal calm.
  static const oceanSand = ThemePack(
    id: 'ocean_sand',
    name: 'Ocean Sand',
    primary: Color(0xFF0E9AA7),
    primaryDark: Color(0xFF0B7E88),
    background: Color(0xFFFAF6EE),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1F2E33),
    mutedText: Color(0xFF7A8A8C),
    border: Color(0xFFE8E0D0),
    secondary: Color(0xFFF0EBDD),
    mutedSurface: Color(0xFFECE5D3),
    accent: Color(0xFFDFF5F6),
    accentForeground: Color(0xFF0B6E78),
    shadowTint: Color(0xFF0E9AA7),
    cardRadius: 22,
    pillButtons: true,
    shadowBlur: 14,
    shadowOpacity: 0.08,
    backdrop: ThemeBackdrop.wash,
  );

  /// Lavender-cream background, lilac brand. Dreamy serenity.
  static const lavenderMist = ThemePack(
    id: 'lavender_mist',
    name: 'Lavender Mist',
    primary: Color(0xFF8B5CF6),
    primaryDark: Color(0xFF7C3AED),
    background: Color(0xFFF5F1FA),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF2E2440),
    mutedText: Color(0xFF8A7FA3),
    border: Color(0xFFE4DCF2),
    secondary: Color(0xFFECE6F7),
    mutedSurface: Color(0xFFE2D9F3),
    accent: Color(0xFFE9E2FA),
    accentForeground: Color(0xFF6D28D9),
    shadowTint: Color(0xFF8B5CF6),
    cardRadius: 20,
    pillButtons: false,
    shadowBlur: 8,
    shadowOpacity: 0.05,
    backdrop: ThemeBackdrop.mist,
  );

  /// Blush-pink cream, rose brand. Soft and caring.
  static const blushRose = ThemePack(
    id: 'blush_rose',
    name: 'Blush Rose',
    primary: Color(0xFFE84A6F),
    primaryDark: Color(0xFFD13A5E),
    background: Color(0xFFFDF2F4),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF3D1F26),
    mutedText: Color(0xFFA07E88),
    border: Color(0xFFF3DDE3),
    secondary: Color(0xFFF9E8EC),
    mutedSurface: Color(0xFFF5DDE4),
    accent: Color(0xFFFADCE4),
    accentForeground: Color(0xFFB91C4A),
    shadowTint: Color(0xFFE84A6F),
    cardRadius: 24,
    pillButtons: true,
    shadowBlur: 16,
    shadowOpacity: 0.1,
    backdrop: ThemeBackdrop.petals,
  );

  /// Warm cream background, honey-amber brand. Cozy glow.
  static const honeyGlow = ThemePack(
    id: 'honey_glow',
    name: 'Honey Glow',
    primary: Color(0xFFD97706),
    primaryDark: Color(0xFFB45309),
    background: Color(0xFFFDF6EC),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF3B2A18),
    mutedText: Color(0xFFA08A6D),
    border: Color(0xFFF0E4CE),
    secondary: Color(0xFFF8EFDD),
    mutedSurface: Color(0xFFF3E7CF),
    accent: Color(0xFFFBEFD8),
    accentForeground: Color(0xFF92400E),
    shadowTint: Color(0xFFD97706),
    cardRadius: 22,
    pillButtons: false,
    shadowBlur: 18,
    shadowOpacity: 0.1,
    backdrop: ThemeBackdrop.glow,
  );

  /// Mint-white background, emerald brand. Fresh healing.
  static const emeraldHeal = ThemePack(
    id: 'emerald_heal',
    name: 'Emerald Heal',
    primary: Color(0xFF059669),
    primaryDark: Color(0xFF047857),
    background: Color(0xFFF2FBF6),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF0C2E23),
    mutedText: Color(0xFF6B8A7D),
    border: Color(0xFFD9EDE2),
    secondary: Color(0xFFE6F5EC),
    mutedSurface: Color(0xFFD9EFE2),
    accent: Color(0xFFD7F2E2),
    accentForeground: Color(0xFF065F46),
    shadowTint: Color(0xFF059669),
    cardRadius: 16,
    pillButtons: false,
    shadowBlur: 10,
    shadowOpacity: 0.07,
    backdrop: ThemeBackdrop.leaves,
  );

  static const List<ThemePack> all = [
    skyPulse,
    oceanSand,
    lavenderMist,
    blushRose,
    honeyGlow,
    emeraldHeal,
  ];

  static ThemePack? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Remedoo design system — theme tokens now come from the active [ThemePack]
/// (see above); pick from Sky Pulse, Ocean Sand, Lavender Mist, Blush Rose,
/// Honey Glow, Emerald Heal in Settings > Appearance.
///
/// Everything renders in Plus Jakarta Sans (bundled in assets/fonts).
class RemedooTheme {
  // ------------------------------------------------------------------
  // Active theme pack (switched at runtime via [setPack]).
  // ------------------------------------------------------------------
  static ThemePack _pack = ThemePack.skyPulse;

  /// The currently active theme pack.
  static ThemePack get pack => _pack;

  /// Switches the active theme pack. Call sites reading the getters below
  /// pick up the new tokens on the next rebuild.
  static void setPack(ThemePack p) {
    _pack = p;
  }

  // ------------------------------------------------------------------
  // Light-theme tokens (from the active pack).
  // ------------------------------------------------------------------
  static Color get primary => _pack.primary;
  static Color get primaryDark => _pack.primaryDark;
  static Color get background => _pack.background;
  static Color get cardWhite => _pack.card;
  static Color get ink => _pack.ink;
  static Color get mutedText => _pack.mutedText;
  static Color get cardBorder => _pack.border;
  static Color get secondary => _pack.secondary;
  static Color get mutedSurface => _pack.mutedSurface;
  static Color get accent => _pack.accent;
  static Color get accentForeground => _pack.accentForeground;
  static const Color success = Color(0xFF2BAD6E);
  static const Color warning = Color(0xFFF5A623);
  static const Color destructive = Color(0xFFDE3F3F);
  static const Color emergency = Color(0xFFEE2B2B);

  /// Dark-mode sidebar accents (from the design spec's dark tokens):
  /// --accent 24 30% 18%, --accent-foreground 24 50% 80%.
  static const Color darkAccent = Color(0xFF3C2B20);
  static const Color darkAccentForeground = Color(0xFFE6C7B3);

  /// Sidebar surface: near-white in light mode, tinted from the active pack.
  static Color get sidebarLight => _pack.background;

  /// Legacy aliases kept for screens written before the reskin.
  static Color get pageBg => background;
  static const Color ratingGreen = success;
  static const Color purple = Color(0xFF6B4FA0);
  static const Color teal = Color(0xFF2E9E6B);

  // ------------------------------------------------------------------
  // Dark-theme tokens (exact, from the design spec)
  // ------------------------------------------------------------------
  static const Color darkBg = Color(0xFF181210);
  static const Color darkCard = Color(0xFF241B18);
  static const Color darkText = Color(0xFFF7F4F1);
  static const Color darkMutedText = Color(0xFFA89A90);
  static const Color darkBorder = Color(0xFF3B2F2A);
  static const Color darkSecondary = Color(0xFF352B27);
  static const Color darkMutedSurface = Color(0xFF2F2722);

  /// Legacy dark aliases kept for screens written before the reskin.
  static const Color darkSurface = darkCard;
  static const Color darkSurface2 = darkSecondary;

  static const String fontFamily = 'PlusJakartaSans';

  /// Soft card shadow (light mode): tinted from the active pack's brand color.
  /// Blur and strength follow the pack's design personality — puffy for
  /// Sky Pulse, barely-there for Lavender Mist.
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: _pack.shadowTint.withValues(alpha: _pack.shadowOpacity),
          blurRadius: _pack.shadowBlur,
          offset: Offset(0, _pack.shadowBlur / 2.2),
        ),
      ];

  /// Corner radius for cards — each theme has its own shape language.
  static double get cardRadius => _pack.cardRadius;

  /// Corner radius for buttons: full pill for some themes, soft
  /// rectangle for others.
  static double get buttonRadius => _pack.pillButtons ? 999 : 16;

  /// Whether the active theme uses fully pill-shaped buttons.
  static bool get pillButtons => _pack.pillButtons;

  /// The active theme's header artwork motif.
  static ThemeBackdrop get backdrop => _pack.backdrop;

  /// Fade + slide page transition used on every platform.
  static const PageTransitionsTheme pageTransitions =
      PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _FadeSlideBuilder(),
      TargetPlatform.iOS: _FadeSlideBuilder(),
      TargetPlatform.macOS: _FadeSlideBuilder(),
      TargetPlatform.windows: _FadeSlideBuilder(),
      TargetPlatform.linux: _FadeSlideBuilder(),
      TargetPlatform.fuchsia: _FadeSlideBuilder(),
    },
  );

  static TextTheme _textTheme(Color text, Color muted) {
    TextStyle s(TextStyle base, Color c) =>
        base.copyWith(fontFamily: fontFamily, color: c);
    return TextTheme(
      displayLarge: s(RemedooType.displayLarge, text),
      displayMedium: s(RemedooType.displayMedium, text),
      headlineLarge: s(RemedooType.headlineLarge, text),
      headlineMedium: s(RemedooType.headlineMedium, text),
      headlineSmall: s(RemedooType.headlineSmall, text),
      titleLarge: s(RemedooType.titleLarge, text),
      titleMedium: s(RemedooType.titleMedium, text),
      titleSmall: s(RemedooType.titleSmall, text),
      bodyLarge: s(RemedooType.bodyLarge, text),
      bodyMedium: s(RemedooType.bodyMedium, text),
      bodySmall: s(RemedooType.bodySmall, muted),
      labelLarge: s(RemedooType.labelLarge, text),
      labelMedium: s(RemedooType.labelMedium, muted),
      labelSmall: s(RemedooType.labelSmall, muted),
    );
  }

  static ButtonStyle _pillButtonStyle(Color bg, Color fg) =>
      ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return bg.withValues(alpha: 0.4);
          }
          return bg;
        }),
        foregroundColor: WidgetStateProperty.all(fg),
        shape: WidgetStateProperty.all(const StadiumBorder()),
        textStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      );

  static ThemeData light([Color? brand]) {
    final p = brand ?? primary;
    final text = ink;
    final muted = mutedText;
    final border = cardBorder;
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: p,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: ink,
      tertiary: accent,
      onTertiary: accentForeground,
      error: destructive,
      onError: Colors.white,
      surface: cardWhite,
      onSurface: ink,
      surfaceContainerHighest: mutedSurface,
      onSurfaceVariant: muted,
      outline: border,
      outlineVariant: border,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: _textTheme(text, muted),
      pageTransitionsTheme: RemedooTheme.pageTransitions,
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardWhite,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardWhite,
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          color: muted,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: destructive),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme:
          FilledButtonThemeData(style: _pillButtonStyle(p, Colors.white)),
      elevatedButtonTheme:
          ElevatedButtonThemeData(style: _pillButtonStyle(p, Colors.white)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _pillButtonStyle(cardWhite, p).copyWith(
          side: WidgetStateProperty.all(
            BorderSide(color: p, width: 1.4),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardWhite,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardWhite,
        indicatorColor: p.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconTheme: IconThemeData(color: ink),
    );
  }

  static ThemeData dark([Color? brand]) {
    final p = brand ?? primaryDark;
    const text = darkText;
    const muted = darkMutedText;
    const border = darkBorder;
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: p,
      onPrimary: Colors.white,
      secondary: darkSecondary,
      onSecondary: darkText,
      tertiary: accent,
      onTertiary: darkText,
      error: destructive,
      onError: Colors.white,
      surface: darkCard,
      onSurface: darkText,
      surfaceContainerHighest: darkMutedSurface,
      onSurfaceVariant: muted,
      outline: border,
      outlineVariant: border,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBg,
      textTheme: _textTheme(text, muted),
      pageTransitionsTheme: RemedooTheme.pageTransitions,
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkCard,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkMutedSurface,
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          color: muted,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: destructive),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme:
          FilledButtonThemeData(style: _pillButtonStyle(p, Colors.white)),
      elevatedButtonTheme:
          ElevatedButtonThemeData(style: _pillButtonStyle(p, Colors.white)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _pillButtonStyle(darkCard, p).copyWith(
          side: WidgetStateProperty.all(
            BorderSide(color: p, width: 1.4),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: darkText,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkCard,
        indicatorColor: p.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: darkText),
    );
  }

  /// Brand gradient used for headers — derived from the active pack's primary.
  static LinearGradient get headerGradient {
    final p = _pack.primary;
    final d = _pack.primaryDark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(p, Colors.white, 0.15)!,
        p,
        d,
      ],
    );
  }

  /// Teal-green gradient for health promo banners.
  static const LinearGradient promoTealGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF14B8A6), Color(0xFF059669)],
  );

  /// Red-orange gradient for emergency promo banners / headers.
  static const LinearGradient promoEmergencyGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFF04438), Color(0xFFEE2B2B)],
  );

  /// Red gradient for the emergency screen.
  static const LinearGradient emergencyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF04438), Color(0xFFEE2B2B), Color(0xFFC81E1E)],
  );

  /// Pastel tile backgrounds for the dashboard service grid
  /// (bg + icon color pairs).
  static const List<List<Color>> serviceTileColors = [
    [Color(0xFFE0F2FE), Color(0xFF0284C7)], // blue
    [Color(0xFFDCFCE7), Color(0xFF16A34A)], // green
    [Color(0xFFF3E8FF), Color(0xFF9333EA)], // purple
    [Color(0xFFFFEDD5), Color(0xFFEA580C)], // orange
    [Color(0xFFFEE2E2), Color(0xFFDC2626)], // red
    [Color(0xFFFCE7F3), Color(0xFFDB2777)], // pink
    [Color(0xFFFEF9C3), Color(0xFFCA8A04)], // yellow
    [Color(0xFFCCFBF1), Color(0xFF0D9488)], // teal
  ];
}

/// 8pt spacing scale.
class RemedooSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Page padding used across the React app.
  static const double page = 16;

  /// Gap between sections.
  static const double section = 22;
}

/// Corner radius scale (matches `--radius` language of the React app).
class RemedooRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double card = 18;
}

/// Type scale, always rendered in Plus Jakarta Sans via the ThemeData.
class RemedooType {
  static const TextStyle displayLarge = TextStyle(
      fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5);
  static const TextStyle displayMedium = TextStyle(
      fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.25);
  static const TextStyle headlineLarge =
      TextStyle(fontSize: 24, fontWeight: FontWeight.w800);
  static const TextStyle headlineMedium =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
  static const TextStyle headlineSmall =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const TextStyle titleLarge =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  static const TextStyle titleMedium =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  static const TextStyle titleSmall =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static const TextStyle bodyLarge =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45);
  static const TextStyle bodyMedium =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45);
  static const TextStyle bodySmall =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4);
  static const TextStyle labelLarge =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
  static const TextStyle labelMedium =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
  static const TextStyle labelSmall =
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
}

/// Global fade + slide page transition.
class _FadeSlideBuilder extends PageTransitionsBuilder {
  const _FadeSlideBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Formats a number as Indian rupees with Indian digit grouping.
String inr(num value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final dec = parts[1];
  String grouped;
  if (intPart.length > 3) {
    final last3 = intPart.substring(intPart.length - 3);
    String rest = intPart.substring(0, intPart.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    grouped = '${groups.join(',')},$last3';
  } else {
    grouped = intPart;
  }
  final decStr = dec == '00' ? '' : '.$dec';
  return '₹$grouped$decStr';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// "Mon 5 Oct"
String shortDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// "Today", "Tomorrow" or "Mon 5 Oct"
String friendlyDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return shortDate(d);
}

/// "4:16 PM"
String shortTime(DateTime d) {
  var h = d.hour % 12;
  if (h == 0) h = 12;
  final m = d.minute.toString().padLeft(2, '0');
  final suffix = d.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $suffix';
}

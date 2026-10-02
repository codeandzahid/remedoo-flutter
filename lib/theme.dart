import 'package:flutter/material.dart';

/// Remedoo design system — rebuilt 1:1 from the React reference app
/// (`remedoo-reskin/DESIGN_SPEC.md`, tokens from `src/index.css`).
///
/// Light theme: warm off-white `#F9F7F5` background, white cards, orange
/// `#EC6A13` primary. Dark theme: warm charcoal surfaces, `#DC6A18` primary.
/// Everything renders in Plus Jakarta Sans (bundled in assets/fonts).
class RemedooTheme {
  // ------------------------------------------------------------------
  // Light-theme tokens (exact, from the design spec)
  // ------------------------------------------------------------------
  static const Color primary = Color(0xFFEC6A13);
  static const Color primaryDark = Color(0xFFDC6A18);
  static const Color background = Color(0xFFF9F7F5);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF201410);
  static const Color mutedText = Color(0xFF8C7F76);
  static const Color cardBorder = Color(0xFFE9E2DB);
  static const Color success = Color(0xFF2BAD6E);
  static const Color warning = Color(0xFFF5A623);
  static const Color destructive = Color(0xFFDE3F3F);
  static const Color emergency = Color(0xFFEE2B2B);
  static const Color secondary = Color(0xFFF5F0EC);
  static const Color mutedSurface = Color(0xFFF7F4F1);
  static const Color accent = Color(0xFFF4E7DA);
  static const Color accentForeground = Color(0xFF93490F);

  /// Dark-mode sidebar accents (from the design spec's dark tokens):
  /// --accent 24 30% 18%, --accent-foreground 24 50% 80%.
  static const Color darkAccent = Color(0xFF3C2B20);
  static const Color darkAccentForeground = Color(0xFFE6C7B3);

  /// Sidebar surface: near-white in light mode (React `--sidebar-background`
  /// 0 0% 98%), warm charcoal card in dark mode.
  static const Color sidebarLight = Color(0xFFFAFAFA);

  /// Legacy aliases kept for screens written before the reskin.
  static const Color pageBg = background;
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

  /// Soft card shadow (light mode): thin warm-gray, very subtle.
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF3A2410).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

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
    const text = ink;
    const muted = mutedText;
    const border = cardBorder;
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
      dividerTheme: const DividerThemeData(
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
      bottomSheetTheme: const BottomSheetThemeData(
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
      appBarTheme: const AppBarTheme(
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
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardWhite,
        hintStyle: const TextStyle(
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
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: const TextStyle(
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
      iconTheme: const IconThemeData(color: ink),
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
      dividerTheme: const DividerThemeData(
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
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkMutedSurface,
        hintStyle: const TextStyle(
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
        side: const BorderSide(color: border),
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

  /// Orange gradient used for headers (matches the React app's hero/header).
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF2790F), Color(0xFFEC6A13), Color(0xFFD95F10)],
  );

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

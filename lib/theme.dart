import 'package:flutter/material.dart';

/// Remedoo design system: warm orange health super-app.
class RemedooTheme {
  static const Color primary = Color(0xFFE86A1C);
  static const Color primaryDark = Color(0xFFC85A12);
  static const Color emergency = Color(0xFFD43D3D);
  static const Color purple = Color(0xFF6B4FA0);
  static const Color teal = Color(0xFF2E9E6B);
  static const Color ratingGreen = Color(0xFF1FA855);
  static const Color pageBg = Color(0xFFFFF8F2);
  static const Color ink = Color(0xFF1A2332);
  static const Color cardBorder = Color(0xFFF0E4D8);

  // Dark-mode surfaces.
  static const Color darkBg = Color(0xFF14100C);
  static const Color darkSurface = Color(0xFF1F1A14);
  static const Color darkSurface2 = Color(0xFF2A221A);
  static const Color darkBorder = Color(0xFF3A2E22);

  /// Soft card shadow (light mode).
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

  static ThemeData light([Color? brand]) {
    final p = brand ?? primary;
    final scheme = ColorScheme.fromSeed(
      seedColor: p,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: p),
      scaffoldBackgroundColor: pageBg,
      pageTransitionsTheme: RemedooTheme.pageTransitions,
      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
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
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          borderSide: BorderSide(color: p, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: p.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData dark([Color? brand]) {
    final p = brand ?? primary;
    final scheme = ColorScheme.fromSeed(
      seedColor: p,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: p),
      scaffoldBackgroundColor: darkBg,
      pageTransitionsTheme: RemedooTheme.pageTransitions,
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          borderSide: BorderSide(color: p, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1F1A14),
        indicatorColor: p.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Orange gradient used for headers.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF07B1D), Color(0xFFE86A1C), Color(0xFFD95F10)],
  );

  /// Red gradient for the emergency screen.
  static const LinearGradient emergencyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE05353), Color(0xFFD43D3D), Color(0xFFB92F2F)],
  );
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
}

/// Corner radius scale.
class RemedooRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
}

/// Elevated type scale with proper weights.
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

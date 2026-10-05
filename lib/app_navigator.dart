import 'package:flutter/material.dart';

import 'screens/main_shell.dart';

/// Global navigator key for the app's root [MaterialApp].
///
/// Lives in its own file (instead of main.dart) so state helpers and widgets
/// can drive navigation — e.g. popping pushed pages on logout — without
/// creating import cycles.
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

/// Robust back navigation for in-app back buttons: pops the current route
/// when possible, otherwise returns to the dashboard. A plain
/// `Navigator.maybePop` silently does nothing on root routes (e.g. deep
/// links), leaving the back button dead — this never does.
void goBack(BuildContext context) {
  if (Navigator.canPop(context)) {
    Navigator.pop(context);
  } else {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (r) => false,
    );
  }
}

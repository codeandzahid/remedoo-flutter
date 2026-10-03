import 'package:flutter/material.dart';

/// Global navigator key for the app's root [MaterialApp].
///
/// Lives in its own file (instead of main.dart) so state helpers and widgets
/// can drive navigation — e.g. popping pushed pages on logout — without
/// creating import cycles.
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

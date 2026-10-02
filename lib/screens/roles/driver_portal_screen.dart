import 'package:flutter/material.dart';

import '../driver_dashboard_screen.dart';

/// Role portal entry for drivers (wraps the driver dashboard).
class DriverPortalScreen extends StatelessWidget {
  const DriverPortalScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const DriverDashboardScreen();
}

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'hospitals_screen.dart';
import 'labs_screen.dart';
import 'pharmacies_screen.dart';
import 'orders_screen.dart';
import 'emergency_screen.dart';

/// Bottom-navigation shell: Home, Hospitals, Labs, Pharmacy, Orders.
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final tabs = const [
      DashboardScreen(),
      HospitalsScreen(),
      LabsScreen(),
      PharmaciesScreen(),
      OrdersScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_hospital_outlined),
            selectedIcon: Icon(Icons.local_hospital),
            label: 'Hospitals',
          ),
          const NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Labs',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: state.cartCount > 0,
              label: Text('${state.cartCount}'),
              child: const Icon(Icons.medication_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: state.cartCount > 0,
              label: Text('${state.cartCount}'),
              child: const Icon(Icons.medication),
            ),
            label: 'Pharmacy',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              backgroundColor: RemedooTheme.primary,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EmergencyScreen())),
              child: const Icon(Icons.sos),
            )
          : null,
    );
  }
}

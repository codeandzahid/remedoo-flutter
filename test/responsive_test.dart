import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/responsive/responsive.dart';

/// Builds a minimal two-destination ResponsiveScaffold for nav-type tests.
Widget _testScaffold() {
  return MaterialApp(
    home: ResponsiveScaffold(
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      sections: const [
        NavSection('Main', [
          NavDestinationItem(icon: Icons.home, label: 'Home'),
          NavDestinationItem(icon: Icons.person, label: 'Doctors'),
        ]),
      ],
      pages: const [
        Center(child: Text('Home page')),
        Center(child: Text('Doctors page')),
      ],
    ),
  );
}

void main() {
  testWidgets('compact width shows bottom NavigationBar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_testScaffold());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const ValueKey('nav-drawer')), findsNothing);
    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('desktop width shows permanent navigation drawer',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_testScaffold());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nav-drawer')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('tablet width shows NavigationRail', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_testScaffold());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('nav-drawer')), findsNothing);
  });
}

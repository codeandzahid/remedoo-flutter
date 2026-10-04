import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/data/mock_data.dart';
import 'package:remedoo_app/screens/lab_detail_screen.dart';
import 'package:remedoo_app/screens/pharmacy_detail_screen.dart';
import 'package:remedoo_app/state/app_state.dart';

Widget _wrap(Widget child, AppState state) {
  return MaterialApp(
    home: AppStateScope(state: state, child: child),
  );
}

void main() {
  testWidgets('pharmacy detail: clean top bar, name visible, no hero blocking',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    final state = AppState();
    state.login(name: 'Test', email: 'test@example.com');
    await tester.pumpWidget(
        _wrap(PharmacyDetailScreen(pharmacy: pharmacies.first), state));
    await tester.pump(const Duration(seconds: 1));
    while (tester.takeException() != null) {}

    // Top bar with title and working back button (no giant hero).
    expect(find.text('Pharmacy Details'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    // No oversized hero illustration: the only pill emoji left is the
    // small 40px info-card icon.
    final bigEmoji = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == '💊' &&
          (w.style?.fontSize ?? 0) >= 48,
    );
    expect(bigEmoji, findsNothing);
    // Pharmacy name is visible near the top inside the info card.
    expect(find.text(pharmacies.first.name), findsOneWidget);
  });

  testWidgets('lab detail: clean top bar, name visible, no hero blocking',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    final state = AppState();
    state.login(name: 'Test', email: 'test@example.com');
    await tester.pumpWidget(
        _wrap(LabDetailScreen(lab: labs.first), state));
    await tester.pump(const Duration(seconds: 1));
    while (tester.takeException() != null) {}

    expect(find.text('Lab Details'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    // No oversized hero illustration: the only microscope emoji left is the
    // small 40px info-card icon.
    final bigEmoji = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == '🔬' &&
          (w.style?.fontSize ?? 0) >= 48,
    );
    expect(bigEmoji, findsNothing);
    // Lab name is visible near the top inside the info card.
    expect(find.text(labs.first.name), findsOneWidget);
  });

  testWidgets('pharmacy back button pops the detail screen', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    final state = AppState();
    state.login(name: 'Test', email: 'test@example.com');
    await tester.pumpWidget(AppStateScope(
      state: state,
      child: MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AppStateScope(
                  state: state,
                  child:
                      PharmacyDetailScreen(pharmacy: pharmacies.first),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    while (tester.takeException() != null) {}
    expect(find.text('Pharmacy Details'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    // Popped back to the opener — detail screen is gone.
    expect(find.text('Pharmacy Details'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}

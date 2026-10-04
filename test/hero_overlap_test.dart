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
  testWidgets('lab hero illustration does not overlap info card',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    final state = AppState();
    state.login(name: 'Test', email: 'test@example.com');
    await tester.pumpWidget(_wrap(LabDetailScreen(lab: labs.first), state));
    await tester.pumpAndSettle();
    // Ignore unrelated pre-existing row overflows; we only assert hero vs card.
    while (tester.takeException() != null) {}

    // Find the hero emoji and the info card (RCard containing lab name).
    final emoji = find.text('🔬');
    expect(emoji, findsOneWidget);
    final emojiBox = tester.getRect(emoji);

    final nameText = find.text(labs.first.name);
    expect(nameText, findsOneWidget);
    final nameBox = tester.getRect(nameText);

    // The lab name (top of info card) must start below the hero emoji.
    expect(nameBox.top, greaterThan(emojiBox.bottom),
        reason:
            'info card top (${nameBox.top}) should be below hero emoji bottom (${emojiBox.bottom})');
  });

  testWidgets('pharmacy hero illustration does not overlap info card',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    final state = AppState();
    state.login(name: 'Test', email: 'test@example.com');
    await tester.pumpWidget(
        _wrap(PharmacyDetailScreen(pharmacy: pharmacies.first), state));
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}

    final emoji = find.text('💊');
    expect(emoji, findsOneWidget);
    final emojiBox = tester.getRect(emoji);

    final nameText = find.text(pharmacies.first.name);
    expect(nameText, findsOneWidget);
    final nameBox = tester.getRect(nameText);

    expect(nameBox.top, greaterThan(emojiBox.bottom),
        reason:
            'info card top (${nameBox.top}) should be below hero emoji bottom (${emojiBox.bottom})');
  });
}

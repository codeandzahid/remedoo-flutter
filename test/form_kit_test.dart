import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/widgets/form_kit.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('Form kit (UI redesign)', () {
    test('rTime12 converts 24h labels to 12-hour display', () {
      expect(rTime12('09:30'), '9:30 AM');
      expect(rTime12('9:05'), '9:05 AM');
      expect(rTime12('12:00'), '12:00 PM');
      expect(rTime12('00:15'), '12:15 AM');
      expect(rTime12('21:05'), '9:05 PM');
      expect(rTime12('13:45:00'), '1:45 PM');
      // Non HH:MM values pass through untouched.
      expect(rTime12('Any time'), 'Any time');
    });

    testWidgets('RKitField renders its stacked label above the input',
        (tester) async {
      final c = TextEditingController();
      await tester.pumpWidget(_wrap(RKitField(
        label: 'Phone Number',
        labelIcon: Icons.phone_outlined,
        icon: Icons.phone_outlined,
        hint: 'Enter your phone number',
        controller: c,
      )));
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Enter your phone number'), findsOneWidget);
      // Stacked: the label sits ABOVE the field, not floating in it.
      final labelY = tester.getTopLeft(find.text('Phone Number')).dy;
      final fieldY = tester.getTopLeft(find.byType(TextField)).dy;
      expect(labelY < fieldY, isTrue);
    });

    testWidgets('RKitDropdown renders a stacked label, not a floating one',
        (tester) async {
      await tester.pumpWidget(_wrap(RKitDropdown<String>(
        label: 'Preferred Language',
        value: 'English',
        items: const [
          DropdownMenuItem(value: 'English', child: Text('English')),
          DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
        ],
        onChanged: (_) {},
      )));
      expect(find.text('Preferred Language'), findsOneWidget);
      final labelY =
          tester.getTopLeft(find.text('Preferred Language')).dy;
      final fieldY =
          tester.getTopLeft(find.byType(DropdownButtonFormField<String>)).dy;
      expect(labelY < fieldY, isTrue);
    });

    testWidgets('RFormActions is an outlined Cancel + filled primary pair, '
        'both at least 48px tall', (tester) async {
      var cancelled = false;
      var saved = false;
      await tester.pumpWidget(_wrap(RFormActions(
        onCancel: () => cancelled = true,
        onPrimary: () => saved = true,
        primaryLabel: 'Save',
      )));
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(tester.getSize(find.byType(OutlinedButton)).height >= 48,
          isTrue);
      expect(tester.getSize(find.byType(FilledButton)).height >= 48,
          isTrue);
      await tester.tap(find.text('Cancel'));
      await tester.tap(find.text('Save'));
      expect(cancelled, isTrue);
      expect(saved, isTrue);
    });

    testWidgets('RFormHeaderBand shows the title on the brand band',
        (tester) async {
      await tester.pumpWidget(
          _wrap(const RFormHeaderBand(title: 'Add Doctor', icon: Icons.add)));
      expect(find.text('Add Doctor'), findsOneWidget);
    });

    testWidgets('RStickyActionBar hosts its action row', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: RStickyActionBar(
            child: RFormActions(
              onCancel: () {},
              onPrimary: () {},
              primaryLabel: 'Save',
            ),
          ),
          body: const SizedBox.shrink(),
        ),
      ));
      expect(find.byType(RStickyActionBar), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('RLabelChips reports the tapped chip', (tester) async {
      String? picked;
      await tester.pumpWidget(_wrap(RLabelChips(
        options: const ['Home', 'Office', 'Other'],
        selected: 'Home',
        onSelected: (v) => picked = v,
      )));
      await tester.tap(find.text('Office'));
      expect(picked, 'Office');
    });

    testWidgets('RFormSection groups children under its heading',
        (tester) async {
      await tester.pumpWidget(_wrap(const RFormSection(
        title: 'Contact',
        icon: Icons.person_outline,
        children: [Text('one'), Text('two')],
      )));
      expect(find.text('Contact'), findsOneWidget);
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/onboarding_view.dart';
import 'package:vitail/onboarding_screen.dart'; 

void main() {
  testWidgets('onboarding layout and optional field actions', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    final name = TextEditingController(), weight = TextEditingController(), colour = TextEditingController();
    addTearDown(name.dispose); addTearDown(weight.dispose); addTearDown(colour.dispose);
    var next = 0, dates = 0, photos = 0;
    String? sex;
    String? breed;
    await tester.runAsync(() async {
      final loader = FontLoader('PlusJakartaSans')..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
      await loader.load();
    });
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, setState) => OnboardingView(
      nameController: name, weightController: weight, sex: sex,
      ownerActivityLevel: 'moderate',
      onOwnerActivityChanged: (val) {},
      deSexed: null, onDeSexed: (value) {},
      colourController: colour,
      healthImpact: null, onHealthImpact: (value) {},
      onSex: (value) => setState(() => sex = value), birthdayLabel: 'Select date of birth',
      onBirthday: () => dates++, breeds: const ['Beagle', 'Poodle'], onBreed: (value) => breed = value,
      onPhoto: () => photos++, onNext: () => next++, loading: false))));
    await tester.pumpAndSettle();
    await expectLater(find.byType(OnboardingView), matchesGoldenFile('goldens/onboarding.png'));
    await tester.enterText(find.byType(TextField).first, 'Milo');
    expect(sex, isNull);
    await tester.tap(find.text('FEMALE')); await tester.pump();
    expect(sex, 'Female');
    await tester.ensureVisible(find.widgetWithText(TextField, 'Select date of birth'));
    await tester.tap(find.widgetWithText(TextField, 'Select date of birth')); expect(dates, 1);
    await tester.ensureVisible(find.byType(InkWell).first);
    await tester.tap(find.byType(InkWell).first); expect(photos, 1);
    await tester.ensureVisible(find.text('Next')); await tester.tap(find.text('Next'));
    expect(next, 1); expect(weight.text, isEmpty); expect(breed, isNull);
    await tester.ensureVisible(find.widgetWithText(TextField, 'Select breed'));
    await tester.enterText(find.widgetWithText(TextField, 'Select breed'), 'Bea');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beagle')); await tester.pumpAndSettle();
    expect(breed, 'Beagle');
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next')); expect(tester.takeException(), isNull);
  });
  test('weight accepts only numbers from 0 to 100', () {
    final formatter = DogWeightInputFormatter();
    const previous = TextEditingValue(text: '12');
    for (final value in ['', '0', '0.5', '12.', '12.75', '100', '100.0']) {
      expect(formatter.formatEditUpdate(previous, TextEditingValue(text: value)).text, value);
    }
    for (final value in ['-1', '101', '100.01', 'abc', '1e2', '12kg', '1.2.3']) {
      expect(formatter.formatEditUpdate(previous, TextEditingValue(text: value)).text, '12');
    }
  });
  testWidgets('name alone still requires sex selection', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.enterText(find.byType(TextField).first, 'Milo');
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next')); await tester.pump();
    expect(find.textContaining('Please fill in'), findsOneWidget);
  });
  testWidgets('blank name is rejected before any database call', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next')); await tester.pump();
    expect(find.textContaining('Please fill in'), findsOneWidget);
  });
}

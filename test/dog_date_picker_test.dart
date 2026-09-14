import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/dog_date_picker.dart';

void main() {
  testWidgets('calendar confirms selection and blocks future days', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360,800);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final font = FontLoader('PlusJakartaSans')..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
      await font.load();
    });
    DateTime? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () async { result = await showModalBottomSheet<DateTime>(context: context, isScrollControlled: true,
        builder: (_) => DogDatePicker(today: DateTime(2024,2,20))); }, child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    expect(tester.widget<TextButton>(find.byKey(const ValueKey('day-21'))).onPressed, isNull);
    expect(find.byKey(const ValueKey('day-29')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('day-14'))); await tester.pump();
    await expectLater(find.byType(DogDatePicker), matchesGoldenFile('goldens/date_picker.png'));
    await tester.tap(find.text('Confirm date')); await tester.pumpAndSettle();
    expect(result, DateTime(2024,2,14));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
    expect(result, isNull);
  });
  testWidgets('reopens with existing selection', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DogDatePicker(initialDate: DateTime(2023,3,14), today: DateTime(2024,2,20)))));
    expect(find.text('Selected: 14 March 2023'), findsOneWidget);
    expect(tester.widget<DropdownButton<int>>(find.byKey(const ValueKey('year-selector'))).value, 2023);
    expect(tester.widget<DropdownButton<int>>(find.byKey(const ValueKey('month-selector'))).value, 3);
  });
}

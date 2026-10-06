import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/activity_history_data.dart';
import 'package:vitail/activity_history_widgets.dart';
import 'package:vitail/walk_history_screen.dart';
import 'package:vitail/walk_summary.dart';

class FakeHistory extends ActivityHistoryRepository {
  @override
  Future<List<ActivityWalk>> loadWalks() async => [
    ActivityWalk({
      'id': 'one',
      'walk_date': '2026-10-05',
      'title': 'Morning loop',
      'distance_meters': 1900,
      'duration_seconds': 1560,
      'points_earned': 19,
      'note': 'Park loop',
    }),
    ActivityWalk({
      'id': 'two',
      'walk_date': '2026-10-04',
      'title': 'Night walk',
      'distance_meters': 2400,
      'duration_seconds': 1920,
      'points_earned': 24,
    }),
  ];
  @override
  Future<List<ActivityCoupon>> loadCoupons() async => [
    ActivityCoupon({
      'reward_title': 'Free long black',
      'created_at': '2026-10-05T09:00:00',
      'partner_name': 'Partner café',
      'points_cost': 250,
      'is_collected': true,
    }),
  ];
}

void main() {
  test('periods handle week, month and year boundaries', () {
    expect(
      inActivityPeriod(
        DateTime(2025, 12, 29),
        DateTime(2026, 1, 1),
        HistoryPeriod.weeks,
      ),
      isTrue,
    );
    expect(
      inActivityPeriod(
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 1),
        HistoryPeriod.weeks,
      ),
      isFalse,
    );
    expect(
      inActivityPeriod(
        DateTime(2025, 1, 1),
        DateTime(2026, 1, 1),
        HistoryPeriod.months,
      ),
      isFalse,
    );
    expect(
      inActivityPeriod(
        DateTime(2026, 1, 31, 23),
        DateTime(2026, 1, 1),
        HistoryPeriod.months,
      ),
      isTrue,
    );
  });
  testWidgets('calendar filters daily walks and weeks include adjacent days', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WalkHistoryScreen(
          initialDate: DateTime(2026, 10, 5),
          repository: FakeHistory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Morning loop'), findsOneWidget);
    expect(find.text('Night walk'), findsNothing);
    expect(find.text('Free long black'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity-day-2026-10-04')));
    await tester.pumpAndSettle();
    expect(find.text('Night walk'), findsOneWidget);
    expect(find.text('Morning loop'), findsNothing);
    await tester.tap(find.text('MONTHS'));
    await tester.pumpAndSettle();
    expect(find.text('Morning loop'), findsOneWidget);
    expect(find.text('Night walk'), findsOneWidget);
  });
  testWidgets(
    'walk card opens the specific saved summary without editable photo actions',
    (tester) async {
      final walk = (await FakeHistory().loadWalks()).first;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ActivityWalkCard(walk: walk)),
        ),
      );
      await tester.tap(find.text('Morning loop'));
      await tester.pumpAndSettle();
      final summary = tester.widget<WalkSummary>(find.byType(WalkSummary));
      expect(summary.savedWalk?['id'], 'one');
      expect(summary.distanceMeters, 1900);
      expect(summary.elapsedSeconds, 1560);
      expect(find.text('+19 points earned'), findsOneWidget);
      expect(find.text('+ Add photo'), findsNothing);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.scrollUntilVisible(
        find.text('Done'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Morning loop'), findsOneWidget);
    },
  );
  testWidgets(
    'date boxes scroll, select older days and keep Figma dimensions',
    (tester) async {
      tester.view.physicalSize = const Size(360, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final today = activityDay(DateTime.now());
      final older = DateTime(today.year, today.month, today.day - 7);
      Key dayKey(DateTime date) =>
          ValueKey('activity-day-${date.toIso8601String().split('T').first}');
      for (final compact in [false, true]) {
        var selected = today;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: StatefulBuilder(
                  builder: (context, setState) => ActivityDateStrip(
                    key: ValueKey(compact),
                    selected: selected,
                    compact: compact,
                    onChanged: (date) => setState(() => selected = date),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(dayKey(today))),
          compact ? const Size(50, 64) : const Size(56, 68),
        );
        final strip = find.byKey(const ValueKey('activity-date-scroll'));
        await tester.drag(
          strip,
          const Offset(380, 0),
          kind: compact ? PointerDeviceKind.mouse : PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(dayKey(older)), findsOneWidget);
        await tester.tap(find.byKey(dayKey(older)));
        await tester.pumpAndSettle();
        expect(selected, older);
        expect(
          tester
              .widget<Semantics>(find.byKey(dayKey(older)))
              .properties
              .selected,
          isTrue,
        );
        // A date chosen externally (e.g. from the popup) is brought into view.
        final distant = DateTime(today.year, today.month - 2, today.day);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: ActivityDateStrip(
                  selected: distant,
                  compact: compact,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(dayKey(distant)), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('history screen at design width has no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final loader = FontLoader('PlusJakartaSans')
        ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'PlusJakartaSans'),
        home: WalkHistoryScreen(
          initialDate: DateTime(2026, 10, 5),
          repository: FakeHistory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(WalkHistoryScreen),
      matchesGoldenFile('goldens/history.png'),
    );
  });
}

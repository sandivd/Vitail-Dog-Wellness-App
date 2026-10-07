import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/rewards_data.dart';
import 'package:vitail/reward_details_screen.dart';

void main() {
  Map<String, dynamic> row() => {
    'id': 'coffee',
    'title': 'Coffee reward',
    'partner_name': 'Cafe',
    'points_cost': 250,
    'category': 'Partner Vouchers',
  };
  test('missing and null descriptions remain compatible with older rows', () {
    expect(RewardOffer.fromJson(row()).description, isEmpty);
    expect(
      RewardOffer.fromJson({...row(), 'description': null}).description,
      isEmpty,
    );
    expect(
      RewardOffer.fromJson({
        ...row(),
        'description': ' Coffee for your walk. ',
      }).description,
      'Coffee for your walk.',
    );
  });
  testWidgets(
    'description replaces category beneath offer title and wraps at large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      const description =
          'Take a coffee break with your dog after your next walk.';
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: RewardDetailsScreen(
            offer: RewardOffer.fromJson({...row(), 'description': description}),
            canRedeem: true,
            onRedeem: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(description), 200);
      expect(find.text(description), findsOneWidget);
      expect(find.text('Partner Vouchers'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vitail/reward_flow.dart';
import 'package:vitail/reward_details_screen.dart';
import 'rewards_screen_test.dart' show FakeRewardsRepository;
import 'package:vitail/reward_venues.dart';
import 'package:vitail/rewards_data.dart';
import 'package:vitail/venue_detail.dart';

VenueInfo venue(String id, String name) => VenueInfo(
  partnerId: id,
  name: name,
  closingTime: '17:00',
  location: null,
  details: 'Dog friendly',
  venueType: 'other',
);
RewardOffer offer({String? id, String name = 'Other'}) => RewardOffer(
  id: 'reward',
  title: 'Treat',
  partnerName: name,
  pointsCost: 10,
  category: '',
  partnerId: id,
);

void main() {
  testWidgets('venue points estimate uses each venue distance', (tester) async {
    Future<void> openVenue(double longitude) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VenueDetailScreen(
            venue: VenueInfo.fromJson({
              'partner_id': 'a',
              'venue_name': 'Cafe',
              'latitude': 0,
              'longitude': longitude,
              'points': 999,
            }),
            userLocation: const LatLng(0, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await openVenue(0.01);
    expect(find.text('+ 11 pts'), findsOneWidget);
    expect(find.text('+ 999 pts'), findsNothing);
    expect(
      find.text('Estimated from your distance to this venue.'),
      findsOneWidget,
    );

    await openVenue(0.02);
    expect(find.text('+ 22 pts'), findsOneWidget);
  });

  testWidgets('Explore opens all venue offers and Back returns to venue', (
    tester,
  ) async {
    final repository = FakeRewardsRepository()
      ..catalogue = [
        const RewardOffer(
          id: 'expensive',
          title: 'Expensive offer',
          partnerName: 'Cafe',
          pointsCost: 900,
          category: '',
          partnerId: 'a',
        ),
        offer(id: 'a'),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: VenueDetailScreen(
          venue: venue('a', 'Cafe'),
          rewardsRepository: repository,
          venueLoader: () async => [venue('a', 'Cafe'), venue('b', 'Park')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CHECK REWARDS'));
    await tester.tap(find.text('CHECK REWARDS'));
    await tester.pumpAndSettle();
    expect(find.byType(RewardDetailsScreen), findsOneWidget);
    expect(find.text('Treat'), findsOneWidget);
    expect(find.text('Expensive offer'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(VenueDetailScreen), findsOneWidget);
  });

  testWidgets('venue without rewards stays on details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VenueDetailScreen(
          venue: venue('a', 'Cafe'),
          rewardsRepository: FakeRewardsRepository()..catalogue = [],
          venueLoader: () async => [venue('a', 'Cafe')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CHECK REWARDS'));
    await tester.tap(find.text('CHECK REWARDS'));
    await tester.pumpAndSettle();
    expect(find.byType(RewardDetailsScreen), findsNothing);
    expect(
      find.text('No rewards are available for this venue yet.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Go here opens the resolved venue and Check rewards returns to the same reward',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RewardFlow(
            offer: offer(),
            repository: FakeRewardsRepository(),
            canRedeem: true,
            onChanged: (_) {},
            venueLoader: () async => [venue('a', 'Demo cafe')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Demo cafe'), findsOneWidget);
      expect(find.text('Closes 5:00pm'), findsOneWidget);
      await tester.tap(find.text('GO HERE'));
      await tester.pumpAndSettle();
      expect(find.byType(VenueDetailScreen), findsOneWidget);
      await tester.ensureVisible(find.text('CHECK REWARDS'));
      await tester.tap(find.text('CHECK REWARDS'));
      await tester.pumpAndSettle();
      expect(find.byType(RewardDetailsScreen), findsOneWidget);
      expect(find.byType(VenueDetailScreen), findsNothing);
      expect(find.text('Treat'), findsOneWidget);
    },
  );

  final first = venue('a', 'Cafe');
  final second = venue('b', 'Park');
  test('partner ID selects the corresponding venue as catalogue grows', () {
    expect(venueForReward(offer(id: 'b'), [first, second]), same(second));
  });
  test('single venue fallback stops when more venues are added', () {
    expect(venueForReward(offer(id: 'missing'), [first]), same(first));
    expect(venueForReward(offer(id: 'missing'), [first, second]), isNull);
    expect(venueForReward(offer(), []), isNull);
  });
  test(
    'legacy name matching is normalized and does not override explicit ID',
    () {
      expect(
        venueForReward(offer(name: ' cafe '), [first, second]),
        same(first),
      );
      expect(
        venueForReward(offer(id: 'missing', name: 'Cafe'), [first, second]),
        isNull,
      );
      expect(
        venueForReward(offer(id: 'a'), [first, venue('a', 'Branch')]),
        isNull,
      );
    },
  );
}

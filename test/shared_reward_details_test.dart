import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/rewards_data.dart';
import 'package:vitail/rewards_screen.dart';
import 'package:vitail/reward_details_screen.dart';
import 'package:vitail/venue_detail.dart';
import 'package:vitail/detail_image_header.dart';
import 'package:vitail/venue_reward_thumbnail.dart';
import 'rewards_screen_test.dart' show FakeRewardsRepository;

const first = RewardOffer(
  id: 'a',
  title: 'Biscuit',
  partnerName: 'Cafe',
  partnerId: 'venue',
  pointsCost: 150,
  category: 'Treats',
);
const second = RewardOffer(
  id: 'b',
  title: 'Coffee',
  partnerName: 'Cafe',
  partnerId: 'venue',
  pointsCost: 200,
  category: 'Treats',
);
const other = RewardOffer(
  id: 'c',
  title: 'Grooming',
  partnerName: 'Salon',
  partnerId: 'salon',
  pointsCost: 250,
  category: 'Care',
);
final venues = [
  const VenueInfo(
    partnerId: 'venue',
    name: 'Cafe',
    closingTime: '17:00',
    location: null,
    details: 'Dog friendly',
    photoUrl: 'https://example.com/cafe.jpg',
  ),
  const VenueInfo(
    partnerId: 'salon',
    name: 'Salon',
    closingTime: null,
    location: null,
    details: '',
  ),
];
Future<void> open(WidgetTester tester, FakeRewardsRepository repo) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RewardsScreen(repository: repo, venueLoader: () async => venues),
    ),
  );
  await tester.pumpAndSettle();
}

Finder card(String id) => find.byKey(ValueKey('offer-$id'));
Finder action(String id, String text) =>
    find.descendant(of: card(id), matching: find.text(text));

void main() {
  testWidgets('shared details layout at narrow widths and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1100);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await (FontLoader(
        'PlusJakartaSans',
      )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
    });
    Widget page(double scale) => MaterialApp(
      theme: ThemeData(
        fontFamily: 'PlusJakartaSans',
        colorScheme: const ColorScheme.light(
          surface: Color(0xFFF4F0E9),
          primary: Color(0xFFDC755C),
          tertiary: Color(0xFFAEC568),
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('shared-preview'),
        child: RewardDetailsScreen(
          offer: first,
          canRedeem: true,
          onRedeem: () {},
          venue: venues.first,
          offerCards: [
            for (final offer in [first, second])
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: RewardOfferCard(
                  offer: offer,
                  canRedeem: true,
                  onRedeem: () {},
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(page(1));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/brand/reward-details-dog.png'),
        tester.element(find.byType(RewardDetailsScreen)),
      ),
    );
    await tester.pumpAndSettle();
    const preview = String.fromEnvironment('SHARED_REWARD_PREVIEW');
    if (preview.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('shared-preview')),
        );
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(preview).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(page(2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Coffee'));
    expect(tester.takeException(), isNull);
  });

  for (final title in ['Biscuit', 'Coffee']) {
    testWidgets('opening $title shows the same venue offers and photo', (
      tester,
    ) async {
      final repo = FakeRewardsRepository()..catalogue = [first, second, other];
      await open(tester, repo);
      final thumbs = tester
          .widgetList<VenueRewardThumbnail>(find.byType(VenueRewardThumbnail))
          .toList();
      expect(
        thumbs
            .take(2)
            .every((thumb) => thumb.photoUrl == venues.first.photoUrl),
        isTrue,
      );
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(RewardOfferCard), findsNWidgets(2));
      expect(find.text('Biscuit'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Grooming'), findsNothing);
      expect(
        tester
            .widget<DetailImageHeader>(find.byType(DetailImageHeader))
            .photoUrl,
        venues.first.photoUrl,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'direct catalogue redeem confirms only selected reward and updates sibling affordability',
    (tester) async {
      final repo = FakeRewardsRepository()
        ..catalogue = [first, second]
        ..points = 300;
      await open(tester, repo);
      // The second catalogue action belongs to Coffee, not the first offer.
      await tester.ensureVisible(find.text('REDEEM').at(1));
      await tester.tap(find.text('REDEEM').at(1));
      await tester.pumpAndSettle();
      expect(find.text('200 points'), findsOneWidget);
      await tester.tap(find.text('Redeem Offer'));
      await tester.pumpAndSettle();
      expect(repo.history.first.rewardId, 'b');
      expect(repo.redeemCalls, 1);
      await tester.tap(find.text('View reward'));
      await tester.pumpAndSettle();
      expect(action('b', 'CHECK IN'), findsOneWidget);
      expect(action('a', 'LOCKED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('each offer uses its own retry ID', (tester) async {
    final repo = FakeRewardsRepository()
      ..catalogue = [first, second]
      ..failRedemption = true;
    await open(tester, repo);
    await tester.tap(find.text('Biscuit'));
    await tester.pumpAndSettle();
    for (final id in ['a', 'a', 'b']) {
      await tester.ensureVisible(action(id, 'REDEEM'));
      await tester.tap(action(id, 'REDEEM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Redeem Offer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
    expect(repo.requestIds[0], repo.requestIds[1]);
    expect(repo.requestIds[2], isNot(repo.requestIds[0]));
  });
}

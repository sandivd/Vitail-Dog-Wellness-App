import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/check_in_screen.dart';
import 'package:vitail/rewards_data.dart';
import 'package:vitail/reward_details_screen.dart';
import 'package:vitail/rewards_screen.dart';

const offers = [
  RewardOffer(
    id: 'cafe',
    title: 'Free long black + puppuccino',
    partnerName: 'Partner café',
    pointsCost: 250,
    category: 'Partner Vouchers',
  ),
  RewardOffer(
    id: 'groom',
    title: '15% off grooming',
    partnerName: 'Doggie discount',
    pointsCost: 400,
    category: 'Partner Vouchers',
  ),
  RewardOffer(
    id: 'vet',
    title: 'Free vet wellness check',
    partnerName: 'Paws Vet Clinic',
    pointsCost: 800,
    category: 'Premium Perks',
  ),
  RewardOffer(
    id: 'park',
    title: 'Council park pass',
    partnerName: 'City of Melbourne',
    pointsCost: 1000,
    category: 'Premium Perks',
  ),
];

class FakeRewardsRepository implements RewardsRepository {
  int points = 500;
  int historyCalls = 0;
  bool failCatalogue = false;
  bool failHistory = false;
  Completer<List<RedeemedReward>>? pendingHistory;
  List<RewardOffer> catalogue = offers;
  List<RedeemedReward> history = [
    const RedeemedReward(title: 'An old partner offer', promoCode: 'ABC123'),
  ];

  @override
  Future<RewardsCatalogue> loadCatalogue() async {
    if (failCatalogue) throw Exception('offline');
    return RewardsCatalogue(points: points, offers: catalogue);
  }

  @override
  Future<List<RedeemedReward>> loadRedeemed() async {
    historyCalls++;
    if (failHistory) throw Exception('offline');
    return pendingHistory?.future ?? history;
  }

  int redeemCalls = 0;
  int collectCalls = 0;
  bool failRedemption = false;
  bool failCollection = false;
  Completer<RedeemedReward>? pendingRedemption;
  final requestIds = <String>[];

  @override
  Future<RedeemedReward> redeem(RewardOffer offer, String requestId) async {
    redeemCalls++;
    requestIds.add(requestId);
    if (failRedemption) throw Exception('offline');
    if (pendingRedemption != null) return pendingRedemption!.future;
    final reward = RedeemedReward(
      title: offer.title,
      promoCode: 'NEW123',
      rewardId: offer.id,
      partnerName: offer.partnerName,
      pointsCost: offer.pointsCost,
      category: offer.category,
    );
    points -= offer.pointsCost;
    history = [reward, ...history];
    return reward;
  }

  @override
  Future<RedeemedReward> collect(RedeemedReward reward) async {
    collectCalls++;
    if (failCollection) throw Exception('offline');
    final collected = RedeemedReward(
      title: reward.title,
      promoCode: reward.promoCode,
      rewardId: reward.rewardId,
      partnerName: reward.partnerName,
      pointsCost: reward.pointsCost,
      category: reward.category,
      isCollected: true,
    );
    history = [
      collected,
      ...history.where((r) => r.promoCode != reward.promoCode),
    ];
    return collected;
  }
}

Widget app(
  FakeRewardsRepository repository, {
  bool active = true,
  double scale = 1,
}) => RepaintBoundary(
  key: const ValueKey('app-preview'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      colorScheme: const ColorScheme.light(
        surface: Color(0xFFF4F0E9),
        primary: Color(0xFFDC755C),
        secondary: Color(0xFF5F98BD),
        tertiary: Color(0xFFAEC568),
        onSurface: Color(0xFF211F1D),
        onSurfaceVariant: Color(0xFF6E6A63),
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: RepaintBoundary(
      key: const ValueKey('preview'),
      child: RewardsScreen(repository: repository, isActive: active),
    ),
  ),
);

Future<void> captureFlow(WidgetTester tester, String name) async {
  const prefix = String.fromEnvironment('REWARD_FLOW_PREVIEW');
  if (prefix.isEmpty) return;
  ScaffoldMessenger.of(
    tester.element(find.byType(Scaffold).last),
  ).clearSnackBars();
  await tester.pumpAndSettle();
  final original = debugDisableShadows;
  debugDisableShadows = false;
  try {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('app-preview')),
    );
    boundary.markNeedsPaint();
    await tester.pump();
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$prefix-$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = original;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'PlusJakartaSans',
    )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
  });
  testWidgets(
    'All uses live affordability and preserves categories and tier preview',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 900);
      addTearDown(tester.view.reset);
      final repo = FakeRewardsRepository();
      repo.catalogue = offers.reversed.toList();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.text('300 pts to your next reward'), findsOneWidget);
      expect(find.text('REDEEM'), findsNWidgets(2));
      expect(find.text('LOCKED'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text(offers.first.title)).dy,
        lessThan(tester.getTopLeft(find.text(offers.last.title)).dy),
      );
      final locked = tester
          .widgetList<TextButton>(find.byType(TextButton))
          .where((button) => (button.child as Text).data == 'LOCKED');
      expect(locked.every((button) => button.onPressed == null), isTrue);
      await tester.tap(find.text('Free vet wellness check'));
      await tester.pumpAndSettle();
      expect(find.text('Premium Perks'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Back'));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('POINTS WALLET'));
      await tester.pumpAndSettle();
      expect(find.text('Active Adventurer'), findsOneWidget);
      expect(find.text('1,500 pts to Gold Tier'), findsOneWidget);
    },
  );

  testWidgets(
    'My rewards loads persistent history and reopens and copies a code without redeeming',
    (tester) async {
      final repo = FakeRewardsRepository();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(repo.historyCalls, 1);
      await tester.tap(find.text('MY REWARDS'));
      await tester.pumpAndSettle();
      expect(find.text('An old partner offer'), findsOneWidget);
      expect(find.text('Free long black + puppuccino'), findsNothing);
      await tester.tap(find.text('VIEW REWARD'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View code'));
      await tester.tap(find.text('View code'));
      await tester.pumpAndSettle();
      expect(find.text('ABC123'), findsOneWidget);
      expect(find.byType(CheckInScreen), findsNothing);
      await tester.tap(find.text('Copy code'));
      await tester.pumpAndSettle();
      expect(copied, 'ABC123');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Back'));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALL'));
      await tester.pumpAndSettle();
      expect(find.text('Free long black + puppuccino'), findsOneWidget);
    },
  );

  testWidgets(
    'history failures stay distinct from empty history and retry succeeds',
    (tester) async {
      final repo = FakeRewardsRepository()..failHistory = true;
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MY REWARDS'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('couldn’t load your redeemed'),
        findsOneWidget,
      );
      repo.failHistory = false;
      repo.history = [];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No redeemed rewards yet'), findsOneWidget);
      await tester.tap(find.text('Browse rewards'));
      await tester.pumpAndSettle();
      expect(find.text('REDEEM'), findsNWidgets(2));
    },
  );

  testWidgets(
    'wallet refreshes on tab re-entry and catalogue failures can retry',
    (tester) async {
      final repo = FakeRewardsRepository()..failCatalogue = true;
      await tester.pumpWidget(app(repo, active: false));
      await tester.pumpAndSettle();
      expect(
        find.text('We couldn’t load your points and rewards.'),
        findsOneWidget,
      );
      repo.failCatalogue = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      repo.points = 1100;
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.text('LOCKED'), findsNothing);
      expect(
        find.text('You have enough points for every reward'),
        findsOneWidget,
      );
    },
  );

  testWidgets('redemption popup is dismissible without spending points', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.reset);
    final repo = FakeRewardsRepository();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REDEEM').first);
    await tester.pumpAndSettle();
    expect(find.text('Redeem Offer'), findsOneWidget);
    await captureFlow(tester, 'confirmation');
    expect(find.textContaining('Expires'), findsNothing);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Redeem Offer'), findsNothing);
    expect(find.byType(RewardDetailsScreen), findsOneWidget);
    await tester.tap(find.text('REDEEM'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 80));
    await tester.pumpAndSettle();
    expect(find.text('Redeem Offer'), findsNothing);
    expect(repo.redeemCalls, 0);
    expect(repo.points, 500);
  });

  testWidgets(
    'redeem once then check in and restore collected status without a time',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 900);
      addTearDown(tester.view.reset);
      final repo = FakeRewardsRepository();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free long black + puppuccino'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GO HERE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not load the venue'), findsOneWidget);
      await tester.tap(find.text('REDEEM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Redeem Offer'));
      await tester.pumpAndSettle();
      expect(find.text('Redeemed!'), findsOneWidget);
      expect(repo.redeemCalls, 1);
      expect(repo.points, 250);
      expect(repo.collectCalls, 0);
      await tester.tap(find.text('View reward'));
      await tester.pumpAndSettle();
      expect(find.text('CHECK IN'), findsOneWidget);
      await captureFlow(tester, 'redeemed');
      expect(find.text('250 pts'), findsNothing);
      await tester.tap(find.text('CHECK IN'));
      await tester.pumpAndSettle();
      expect(find.text('Please show to staff'), findsOneWidget);
      await captureFlow(tester, 'swipe');
      await tester.drag(
        find.byKey(const ValueKey('collect-swipe-knob')),
        const Offset(280, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Collected!'), findsOneWidget);
      await captureFlow(tester, 'collected');
      expect(find.text('Time'), findsNothing);
      expect(find.text('Place'), findsOneWidget);
      expect(repo.history.first.isCollected, isTrue);
      expect(repo.redeemCalls, 1);
      expect(repo.collectCalls, 1);
      expect(repo.points, 250);
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      expect(find.text('VIEW COLLECTION'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Back'));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MY REWARDS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free long black + puppuccino'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VIEW COLLECTION'));
      await tester.pumpAndSettle();
      expect(find.text('Time'), findsNothing);
      expect(find.text('Place'), findsOneWidget);
      expect(repo.history.first.isCollected, isTrue);
      expect(repo.collectCalls, 1);
    },
  );

  testWidgets(
    'redemption retry reuses its request ID and collection failures do not show success',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 900);
      addTearDown(tester.view.reset);
      final repo = FakeRewardsRepository()..failRedemption = true;
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REDEEM').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Redeem Offer'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('couldn’t confirm redemption'),
        findsOneWidget,
      );
      expect(find.text('Redeemed!'), findsNothing);
      repo.failRedemption = false;
      await tester.tap(find.text('Redeem Offer'));
      await tester.pumpAndSettle();
      expect(repo.requestIds.toSet().length, 1);
      await tester.tap(find.text('View reward'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHECK IN'));
      await tester.pumpAndSettle();
      repo.failCollection = true;
      await tester.drag(
        find.byKey(const ValueKey('collect-swipe-knob')),
        const Offset(280, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Collection couldn’t be confirmed'),
        findsOneWidget,
      );
      expect(find.text('Collected!'), findsNothing);
      repo.failCollection = false;
      await tester.drag(
        find.byKey(const ValueKey('collect-swipe-knob')),
        const Offset(280, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Collected!'), findsOneWidget);
      expect(repo.points, 250);
    },
  );

  testWidgets(
    'closing the popup while redemption is pending preserves the result',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 900);
      addTearDown(tester.view.reset);
      final repo = FakeRewardsRepository()
        ..pendingRedemption = Completer<RedeemedReward>();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REDEEM').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Redeem Offer'));
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      repo.pendingRedemption!.complete(
        RedeemedReward(
          title: offers.first.title,
          promoCode: 'NEW123',
          rewardId: 'cafe',
          partnerName: 'Partner café',
          pointsCost: 250,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CHECK IN'), findsOneWidget);
      expect(repo.redeemCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late history responses after leaving the page are safe', (
    tester,
  ) async {
    final repo = FakeRewardsRepository()
      ..pendingHistory = Completer<List<RedeemedReward>>();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MY REWARDS'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    repo.pendingHistory!.complete(repo.history);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Figma layout renders at 360px and adapts to small screens and large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 848);
      addTearDown(tester.view.reset);
      final originalShadows = debugDisableShadows;
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = originalShadows);
      await tester.runAsync(() async {
        final loader = FontLoader('PlusJakartaSans')
          ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'))
          ..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-SemiBold.ttf'),
          )
          ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'))
          ..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-ExtraBold.ttf'),
          );
        await loader.load();
      });
      final repo = FakeRewardsRepository();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Optional local visual QA artifact; no generated snapshots committed.
      const previewPath = String.fromEnvironment('REWARDS_PREVIEW');
      if (previewPath.isNotEmpty) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(previewPath).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(app(repo, scale: 2));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Council park pass'), 200);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('MY REWARDS'), -200);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('MY REWARDS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MY REWARDS'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      debugDisableShadows = originalShadows;
    },
  );
}

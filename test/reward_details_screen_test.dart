import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/reward_details_screen.dart';
import 'package:vitail/rewards_data.dart';

const offer = RewardOffer(
  id: 'cafe',
  title: 'Free long black + puppuccino',
  partnerName: 'The Local Hound Café',
  pointsCost: 250,
  category: 'Partner Vouchers',
);

void main() {
  testWidgets(
    'details renders Figma layout, locked state and large-text layout',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      var redemptions = 0;
      Widget screen({bool canRedeem = true, double scale = 1}) => MaterialApp(
        theme: ThemeData(
          fontFamily: 'PlusJakartaSans',
          colorScheme: const ColorScheme.light(
            surface: Color(0xFFF4F0E9),
            primary: Color(0xFFDC755C),
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
          key: const ValueKey('details-preview'),
          child: RewardDetailsScreen(
            offer: offer,
            canRedeem: canRedeem,
            onRedeem: () => redemptions++,
          ),
        ),
      );
      await tester.runAsync(() async {
        await (FontLoader(
          'PlusJakartaSans',
        )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
      });
      await tester.pumpWidget(screen());
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/brand/reward-details-dog.png'),
          tester.element(find.byType(RewardDetailsScreen)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The Local Hound Café'), findsOneWidget);
      expect(find.text('Not confirmed'), findsOneWidget);
      expect(tester.takeException(), isNull);
      const previewPath = String.fromEnvironment('REWARD_DETAILS_PREVIEW');
      if (previewPath.isNotEmpty) {
        final originalShadows = debugDisableShadows;
        debugDisableShadows = false;
        await tester.pumpWidget(screen());
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('details-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(previewPath).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        debugDisableShadows = originalShadows;
      }
      await tester.tap(find.text('REDEEM'));
      expect(redemptions, 1);
      await tester.pumpWidget(screen(canRedeem: false));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('LOCKED'));
      expect(redemptions, 1);
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(screen(canRedeem: false, scale: 2));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('LOCKED'), 200);
      expect(tester.takeException(), isNull);
    },
  );
}

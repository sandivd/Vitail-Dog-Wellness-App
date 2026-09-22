import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/vitail_launch.dart';
import 'package:vitail/vitail_loading.dart';

void main() {
  testWidgets('reduced motion reveals title then enters the app', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: VitailLaunch(child: Scaffold(body: Text('Destination'))),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    expect(find.text('Destination'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Destination'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'startup fallback releases destination and timers dispose safely',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VitailLaunch(child: Scaffold(body: Text('Destination'))),
        ),
      );
      expect(find.text('Destination'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Destination'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loader respects reduced motion and exposes its status', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: VitailLoading(size: 22, semanticsLabel: 'Signing in'),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/brand/vitail-mark.png',
    );
    expect(find.bySemanticsLabel('Signing in'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

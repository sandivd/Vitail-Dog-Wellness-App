import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:vitail/walk_summary.dart';

class FakeImagePickerPlatform extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return XFile('assets/brand/app-icon.png');
  }
}

void main() {
  testWidgets('walk summary accepts mood, hygiene, note and photo details', (
    tester,
  ) async {
    final originalImagePicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = FakeImagePickerPlatform();
    addTearDown(() {
      ImagePickerPlatform.instance = originalImagePicker;
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: WalkSummary(
          distanceMeters: 1250,
          elapsedSeconds: 900,
          goalMinutes: 15,
          dog: {'dog_name': 'Milo'},
          hygiene: {'pee': false, 'poo': false},
          routePoints: [LatLng(-37.81, 144.96)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Walk summary'), findsOneWidget);
    expect(find.text('Nice loop — that\'s the goal done.'), findsOneWidget);
    expect(find.text('1.25 km'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('+12 points earned'), findsOneWidget);

    await tester.tap(find.text('Adventure'));
    var moodTile = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Adventure'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (moodTile.decoration! as BoxDecoration).color,
      const Color(0xFF5F98BD),
    );
    await tester.tap(find.text('Active'));
    moodTile = tester.widget<Container>(
      find
          .ancestor(of: find.text('Active'), matching: find.byType(Container))
          .first,
    );
    expect(
      (moodTile.decoration! as BoxDecoration).color,
      const Color(0xFF5F98BD),
    );

    expect(find.text('Not yet'), findsOneWidget);
    await tester.ensureVisible(find.text('PEE').last);
    await tester.tap(find.text('PEE').last);
    await tester.pump();
    expect(find.text('Done 1/2'), findsOneWidget);
    await tester.tap(find.text('POO').last);
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);

    await tester.scrollUntilVisible(find.byType(TextField), 300);
    await tester.enterText(find.byType(TextField), 'Park loop');
    expect(find.text('Park loop'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('+ Add photo'), 300);
    await tester.tap(find.text('+ Add photo'));
    await tester.pumpAndSettle();
    expect(find.text('+ Add photo'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}

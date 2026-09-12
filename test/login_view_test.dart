import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/login_view.dart';

void main() {
  testWidgets('login actions and keyboard layouts remain usable', (tester) async {
    final email = TextEditingController();
    final password = TextEditingController();
    addTearDown(email.dispose);
    addTearDown(password.dispose);
    var emailCalls = 0;
    var googleCalls = 0;
    var signupCalls = 0;
    tester.view.resetPhysicalSize();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    Widget screen({bool loading = false, double keyboard = 0}) => MaterialApp(
      home: MediaQuery(data: MediaQueryData(size: const Size(360, 800),
        viewInsets: EdgeInsets.only(bottom: keyboard)), child: LoginView(
        emailController: email, passwordController: password, isLoading: loading,
        onEmailLogin: () => emailCalls++, onGoogleLogin: () => googleCalls++,
        onSignUp: () => signupCalls++)));
    await tester.runAsync(() async {
      final loader = FontLoader('PlusJakartaSans')
        ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    await tester.pumpWidget(screen());
    await tester.runAsync(() => precacheImage(const AssetImage('assets/brand/vitail-logo.png'), tester.element(find.byType(LoginView))));
    await tester.pumpAndSettle();
    await expectLater(find.byType(LoginView), matchesGoldenFile('goldens/login.png'));
    await tester.enterText(find.byType(TextField).first, 'owner@example.com');
    await tester.enterText(find.byType(TextField).last, 'password');
    await tester.tap(find.text('Continue with email'));
    await tester.tap(find.text('Continue with Google'));
    await tester.tap(find.text("Don't have an account? Sign up", findRichText: true));
    expect([emailCalls, googleCalls, signupCalls], [1, 1, 1]);
    expect(find.byKey(const ValueKey('lucide-mail')), findsOneWidget);
    expect(find.byKey(const ValueKey('lucide-lock-keyhole')), findsOneWidget);
    expect(find.byKey(const ValueKey('google-logo')), findsOneWidget);
    expect(email.text, 'owner@example.com');
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText, isTrue);
    await tester.pumpWidget(screen(loading: true));
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
    await tester.pumpWidget(screen(keyboard: 300));
    await tester.ensureVisible(find.text("Don't have an account? Sign up", findRichText: true));
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

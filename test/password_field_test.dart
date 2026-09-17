import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/password_field.dart';

void main() {
  test('signup allows passwords of at least six characters', () {
    for (final value in ['012345', 'abcdef', 'abc123', 'longerPassword!', '123 45']) {
      expect(PasswordField.isValid(value), isTrue);
    }
    expect(PasswordField.isValid('a' * 64), isTrue);
    expect(PasswordField.isValid('a' * 65), isFalse);
    for (final value in ['', '12345', 'abc', '      ']) {
      expect(PasswordField.isValid(value), isFalse);
    }
  });
  testWidgets('visibility is independent and preserves password and submission', (tester) async {
    final password = TextEditingController(text: '123456');
    final confirm = TextEditingController(text: '123456');
    addTearDown(password.dispose); addTearDown(confirm.dispose);
    String? submitted;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      PasswordField(controller: password, decoration: const InputDecoration(hintText: 'Password'),
        autofillHints: const [AutofillHints.newPassword], textInputAction: TextInputAction.next),
      PasswordField(controller: confirm, decoration: const InputDecoration(hintText: 'Confirm Password'),
        autofillHints: const [AutofillHints.newPassword], textInputAction: TextInputAction.done,
        onSubmitted: (value) => submitted = value),
    ]))));
    expect(tester.widgetList<TextField>(find.byType(TextField)).every((f) => f.obscureText), isTrue);
    await tester.tap(find.byTooltip('Show password')); await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText, isFalse);
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText, isTrue);
    expect(password.text, '123456');
    await tester.enterText(find.byType(TextField).first, 'ab12 345678!');
    expect(password.text, 'ab12 345678!');
    await tester.enterText(find.byType(TextField).first, 'a' * 65);
    expect(password.text, 'a' * 64);
    await tester.tap(find.byTooltip('Hide password')); await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show confirm password')); await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText, isFalse);
    await tester.showKeyboard(find.byType(TextField).last);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, '123456');
  });
}

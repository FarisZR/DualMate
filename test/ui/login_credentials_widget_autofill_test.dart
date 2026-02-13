import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/ui/login_credentials_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('exposes Dualis autofill hints for username and password',
      (tester) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    await tester.pumpWidget(
      _wrapWithApp(
        LoginCredentialsWidget(
          usernameEditingController: usernameController,
          passwordEditingController: passwordController,
          onSubmitted: () {},
        ),
      ),
    );

    expect(find.byType(AutofillGroup), findsOneWidget);

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.length, 2);

    expect(fields[0].autofillHints, contains(AutofillHints.username));
    expect(fields[0].autofillHints, contains('dualis.dhbw.de'));
    expect(fields[0].autofillHints, contains('https://dualis.dhbw.de/'));

    expect(fields[1].autofillHints, contains(AutofillHints.password));
    expect(fields[1].autofillHints, contains('dualis.dhbw.de'));
    expect(fields[1].autofillHints, contains('https://dualis.dhbw.de/'));
  });

  testWidgets('keeps submit behavior for focus handoff and password submit',
      (tester) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    var submitted = 0;

    await tester.pumpWidget(
      _wrapWithApp(
        LoginCredentialsWidget(
          usernameEditingController: usernameController,
          passwordEditingController: passwordController,
          onSubmitted: () {
            submitted++;
          },
        ),
      ),
    );

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    await tester.tap(textFields.first);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final editableStates =
        tester.stateList<EditableTextState>(find.byType(EditableText)).toList();
    expect(editableStates[1].widget.focusNode.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, 1);
  });
}

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      LocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('de')],
    home: Scaffold(body: child),
  );
}

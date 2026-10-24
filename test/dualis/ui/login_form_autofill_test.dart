import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/dualis/model/credentials.dart';
import 'package:dualmate/dualis/ui/widgets/login_form_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Dualis login exposes both credentials to Android autofill', (
    tester,
  ) async {
    Credentials? submitted;
    await tester.pumpWidget(
      _app(
        onLogin: (credentials) async {
          submitted = credentials;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.tap(fields.first);
    await tester.pump();

    final configuration = tester.testTextInput.setClientArgs!;
    final autofillFields = configuration['fields'] as List<dynamic>;
    expect(autofillFields, hasLength(2));
    final autofillValues = <String, dynamic>{};
    for (final field in autofillFields) {
      final autofill = field['autofill'] as Map<String, dynamic>;
      final hints = autofill['hints'] as List<dynamic>;
      expect(hints, containsAll(['dualis.dhbw.de', 'https://dualis.dhbw.de/']));
      final isPassword = hints.contains(AutofillHints.password);
      expect(
        hints.first,
        isPassword ? AutofillHints.password : AutofillHints.username,
      );
      autofillValues[autofill['uniqueIdentifier'] as String] = TextEditingValue(
        text: isPassword ? 'filled-password' : 'filled-user',
      ).toJSON();
    }

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.updateEditingStateWithTag', [
          -1,
          autofillValues,
        ]),
      ),
      (_) {},
    );
    await tester.pump();

    final textFields = tester.widgetList<TextField>(fields).toList();
    expect(textFields[0].controller!.text, 'filled-user');
    expect(textFields[1].controller!.text, 'filled-password');
    expect(textFields[1].obscureText, isTrue);

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(submitted!.username, 'filled-user');
    expect(submitted!.password, 'filled-password');
  });

  for (final success in [true, false]) {
    for (final remember in [true, false]) {
      testWidgets(
        'autofill save follows login success=$success with remember=$remember',
        (tester) async {
          Credentials? saved;
          var cleared = false;
          await tester.pumpWidget(
            _app(
              onLogin: (_) async => success,
              remember: remember,
              onSave: (credentials) async => saved = credentials,
              onClear: () async => cleared = true,
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).first, 'user');
          await tester.enterText(find.byType(TextField).last, 'password');
          tester.testTextInput.log.clear();

          await tester.tap(find.byType(TextButton));
          await tester.pumpAndSettle();

          final finishes = tester.testTextInput.log.where(
            (call) => call.method == 'TextInput.finishAutofillContext',
          );
          if (success) {
            expect(finishes, hasLength(1));
            expect(finishes.single.arguments, isTrue);
          } else {
            expect(finishes, isEmpty);
            expect(find.text('Login failed'), findsOneWidget);
          }
          expect(saved?.username, success && remember ? 'user' : null);
          expect(saved?.password, success && remember ? 'password' : null);
          expect(cleared, !remember);
        },
      );
    }
  }

  for (final submit in [true, false]) {
    testWidgets(
      'leaving an unsuccessful login cancels autofill (submit=$submit)',
      (tester) async {
        await tester.pumpWidget(_app(onLogin: (_) async => false));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'unverified-user');
        if (submit) {
          await tester.enterText(find.byType(TextField).last, 'wrong-password');
          await tester.tap(find.byType(TextButton));
          await tester.pumpAndSettle();
        }
        tester.testTextInput.log.clear();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        final finishes = tester.testTextInput.log.where(
          (call) => call.method == 'TextInput.finishAutofillContext',
        );
        expect(finishes, hasLength(1));
        expect(finishes.single.arguments, isFalse);
      },
    );
  }
}

Widget _app({
  required OnLogin onLogin,
  bool remember = false,
  OnSaveCredentials? onSave,
  OnClearCredentials? onClear,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      LocalizationDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('de')],
    home: Scaffold(
      body: LoginForm(
        title: const Text('Dualis login'),
        loginFailedText: 'Login failed',
        onLogin: onLogin,
        onLoadCredentials: () async => Credentials('', ''),
        getDoSaveCredentials: () async => remember,
        onSaveCredentials: onSave ?? (_) async {},
        onClearCredentials: onClear ?? () async {},
      ),
    ),
  );
}

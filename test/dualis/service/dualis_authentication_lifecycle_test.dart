import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/service/dualis_authentication.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'authenticatedGet rejects requests before login with a clear state error',
    () async {
      final authentication = DualisAuthentication();

      await expectLater(
        authentication.authenticatedGet(
          'https://dualis.dhbw.de/test',
          CancellationToken(),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('authenticated session'),
          ),
        ),
      );
    },
  );

  test('logout before login is safe and remains logged out', () async {
    final authentication = DualisAuthentication();

    await authentication.logout(CancellationToken());

    expect(authentication.loginState, LoginResult.LoggedOut);
  });

  test(
    'previous-credentials login fails cleanly when none were configured',
    () async {
      final authentication = DualisAuthentication();

      final result = await authentication.loginWithPreviousCredentials(
        CancellationToken(),
      );

      expect(result, LoginResult.LoginFailed);
    },
  );
}

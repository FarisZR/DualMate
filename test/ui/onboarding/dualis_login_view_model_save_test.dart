import 'dart:async';

import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/dualis/model/credentials.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/ui/onboarding/viewmodels/dualis_login_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'save does not complete until credential persistence finishes',
    () async {
      final storeCompleter = Completer<void>();
      final preferencesProvider = _DelayedCredentialsPreferencesProvider(
        storeCompleter,
      );
      final viewModel = DualisLoginViewModel(
        preferencesProvider,
        _FakeDualisService(),
      );
      viewModel.username = 'testuser';
      viewModel.password = 'testpass';

      var saveCompleted = false;
      final saveFuture = viewModel.save().then((_) {
        saveCompleted = true;
      });

      // Let any pending microtasks drain. If save() had not awaited
      // storeDualisCredentials, it would complete before the completer fires.
      await Future.microtask(() {});
      expect(saveCompleted, isFalse);

      storeCompleter.complete();
      await saveFuture;

      expect(saveCompleted, isTrue);
      expect(preferencesProvider.storeCredentialsCalls, 1);
    },
  );
}

class _DelayedCredentialsPreferencesProvider implements PreferencesProvider {
  final Completer<void> _storeCompleter;
  int storeCredentialsCalls = 0;

  _DelayedCredentialsPreferencesProvider(this._storeCompleter);

  @override
  Future<void> setStoreDualisCredentials(bool value) async {}

  @override
  Future<void> storeDualisCredentials(Credentials credentials) async {
    storeCredentialsCalls += 1;
    await _storeCompleter.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeDualisService implements DualisService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

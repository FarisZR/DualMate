import 'package:dualmate/common/application_constants.dart';
import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/logging/analytics.dart';
import 'package:dualmate/common/util/platform_util.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

///
/// Dialog which asks the user to rate the app in the store
///
class RateInStoreDialog {
  final PreferencesProvider _preferencesProvider;
  final int _appLaunchCounter;

  RateInStoreDialog(this._preferencesProvider, this._appLaunchCounter);

  Future<void> showIfNeeded(BuildContext context) async {
    if (!PlatformUtil.isAndroid()) return;
    if (await _preferencesProvider.getDontShowRateNowDialog()) return;

    if (_appLaunchCounter >=
        await _preferencesProvider.getNextRateInStoreLaunchCount()) {
      await _showRateDialog(context);
    }
  }

  Future<void> _showRateDialog(BuildContext context) async {
    await analytics.logEvent(name: "rateRequestShown");

    return await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          buttonPadding: const EdgeInsets.all(0),
          actionsPadding: const EdgeInsets.all(0),
          contentPadding: const EdgeInsets.all(0),
          title: Text(L.of(context).rateDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(L.of(context).rateDialogMessage),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: _buildButtonBar(context),
              )
            ],
          ),
        );
      },
    );
  }

  OverflowBar _buildButtonBar(BuildContext context) {
    return OverflowBar(
      spacing: 8,
      overflowSpacing: 8,
      children: <Widget>[
        TextButton(
          child: Text(L.of(context).rateDialogDoNotRateButton.toUpperCase()),
          onPressed: () {
            _rateNever();
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text(L.of(context).rateDialogRateLaterButton.toUpperCase()),
          onPressed: () {
            _rateLater();
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text(L.of(context).rateDialogRateNowButton.toUpperCase()),
          onPressed: () {
            _rateNow();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Future<void> _rateLater() async {
    await analytics.logEvent(name: "rateLater");

    await _preferencesProvider.setNextRateInStoreLaunchCount(
        RateInStoreLaunchAfter + _appLaunchCounter);
  }

  Future<void> _rateNow() async {
    final inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await inAppReview.openStoreListing();
    }
    await analytics.logEvent(name: "rateNow");
    await _preferencesProvider.setDontShowRateNowDialog(true);
  }

  Future<void> _rateNever() async {
    await analytics.logEvent(name: "rateNever");
    await _preferencesProvider.setDontShowRateNowDialog(true);
  }
}

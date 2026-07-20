import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/service/rapla/rapla_schedule_source.dart';
import 'package:dualmate/schedule/ui/widgets/enter_url_dialog.dart';
import 'package:flutter/material.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_source_change_confirmation.dart';

///
/// Shows a dialog to enter and validate the url for rapla
///
class EnterRaplaUrlDialog extends EnterUrlDialog {
  final PreferencesProvider _preferencesProvider;
  final ScheduleSourceProvider _scheduleSource;
  String _previousSourceIdentity = 'none';

  EnterRaplaUrlDialog(this._preferencesProvider, this._scheduleSource);

  @override
  Future saveUrl(String url) async {
    await _scheduleSource.setupForRapla(url);
    await ScheduleSourceChangeConfirmation.finishCommittedChange(
      sourceProvider: _scheduleSource,
      previousSourceIdentity: _previousSourceIdentity,
    );
  }

  @override
  Future<bool> confirmSave(BuildContext context, String url) {
    _previousSourceIdentity = _scheduleSource.currentSourceIdentity;
    return ScheduleSourceChangeConfirmation.confirmIfNeeded(
      context: context,
      sourceProvider: _scheduleSource,
      nextType: ScheduleSourceType.Rapla,
      nextIdentityValue: url,
    );
  }

  @override
  Future<String> loadUrl() async {
    return await _preferencesProvider.getRaplaUrl();
  }

  @override
  bool isValidUrl(String url) {
    return RaplaScheduleSource.isValidUrl(url);
  }

  @override
  String hint(BuildContext context) {
    return L.of(context).onboardingRaplaUrlHint;
  }

  @override
  String message(BuildContext context) {
    return L.of(context).onboardingRaplaPageDescription;
  }

  @override
  String title(BuildContext context) {
    return L.of(context).dialogSetRaplaUrlTitle;
  }

  @override
  String invalidUrl(BuildContext context) {
    return L.of(context).onboardingRaplaUrlInvalid;
  }
}

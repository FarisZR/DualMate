import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/ui/widgets/enter_dualis_credentials_dialog.dart';
import 'package:dualmate/schedule/ui/widgets/enter_ical_url.dart';
import 'package:dualmate/schedule/ui/widgets/enter_rapla_url_dialog.dart';
import 'package:dualmate/schedule/ui/widgets/select_mannheim_course_dialog.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';

class SelectSourceDialog {
  final PreferencesProvider _preferencesProvider;
  final ScheduleSourceProvider _scheduleSourceProvider;

  late ScheduleSourceType _currentScheduleSource;

  SelectSourceDialog(this._preferencesProvider, this._scheduleSourceProvider);

  Future show(BuildContext context) async {
    var type = await _preferencesProvider.getScheduleSourceType();
    _currentScheduleSource = ScheduleSourceType.values[type];

    await showDialog(
      context: context,
      builder: (context) => _buildDialog(context),
    );
  }

  SimpleDialog _buildDialog(BuildContext context) {
    final radioGroup = RadioGroup<ScheduleSourceType>(
      groupValue: _currentScheduleSource,
      onChanged: (value) {
        if (value != null) {
          sourceSelected(value, context);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          RadioListTile<ScheduleSourceType>(
            value: ScheduleSourceType.Rapla,
            toggleable: true,
            title: Text(L.of(context).scheduleSourceTypeRapla),
          ),
          RadioListTile<ScheduleSourceType>(
            value: ScheduleSourceType.Dualis,
            title: Text(L.of(context).scheduleSourceTypeDualis),
          ),
          RadioListTile<ScheduleSourceType>(
            value: ScheduleSourceType.Mannheim,
            title: Text(L.of(context).scheduleSourceTypeMannheim),
          ),
          RadioListTile<ScheduleSourceType>(
            value: ScheduleSourceType.Ical,
            title: Text(L.of(context).scheduleSourceTypeIcal),
          ),
          RadioListTile<ScheduleSourceType>(
            value: ScheduleSourceType.None,
            title: Text(L.of(context).scheduleSourceTypeNone),
          ),
        ],
      ),
    );

    return SimpleDialog(
      title: Text(L.of(context).onboardingScheduleSourceTitle),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Text(
            L.of(context).onboardingScheduleSourceDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        radioGroup,
      ],
    );
  }

  Future<void> sourceSelected(
    ScheduleSourceType type,
    BuildContext context,
  ) async {
    _preferencesProvider.setScheduleSourceType(type.index);

    Navigator.of(context).pop();

    switch (type) {
      case ScheduleSourceType.None:
        await _scheduleSourceProvider.setupScheduleSource();
        break;
      case ScheduleSourceType.Rapla:
        await EnterRaplaUrlDialog(
          _preferencesProvider,
          KiwiContainer().resolve(),
        ).show(context);
        break;
      case ScheduleSourceType.Dualis:
        await EnterDualisCredentialsDialog(
          _preferencesProvider,
          KiwiContainer().resolve(),
        ).show(context);
        break;
      case ScheduleSourceType.Ical:
        await EnterIcalDialog(
          _preferencesProvider,
          KiwiContainer().resolve(),
        ).show(context);
        break;
      case ScheduleSourceType.Mannheim:
        await SelectMannheimCourseDialog(
          KiwiContainer().resolve(),
        ).show(context);
        break;
    }
  }
}

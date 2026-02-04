import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/ui/onboarding/viewmodels/onboarding_view_model_base.dart';
import 'package:dualmate/ui/onboarding/viewmodels/select_source_view_model.dart';
import 'package:flutter/material.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

class SelectSourcePage extends StatelessWidget {
  const SelectSourcePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PropertyChangeConsumer<OnboardingStepViewModel, String>(
      builder: (
        BuildContext context,
        OnboardingStepViewModel? model,
        Set<String>? _,
      ) {
        if (model == null) return Container();
        var viewModel = model as SelectSourceViewModel;
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
              child: Center(
                child: Text(
                  L.of(context).onboardingScheduleSourceTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
              child: Divider(),
            ),
            Text(
              L.of(context).onboardingScheduleSourceDescription,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    buildScheduleTypeRadio(
                      viewModel,
                      context,
                      ScheduleSourceType.Rapla,
                      L.of(context).scheduleSourceTypeRapla,
                    ),
                    buildScheduleTypeRadio(
                      viewModel,
                      context,
                      ScheduleSourceType.Dualis,
                      L.of(context).scheduleSourceTypeDualis,
                    ),
                    buildScheduleTypeRadio(
                      viewModel,
                      context,
                      ScheduleSourceType.Mannheim,
                      "DHBW Mannheim",
                    ),
                    buildScheduleTypeRadio(
                      viewModel,
                      context,
                      ScheduleSourceType.Ical,
                      L.of(context).scheduleSourceTypeIcal,
                    ),
                    buildScheduleTypeRadio(
                      viewModel,
                      context,
                      ScheduleSourceType.None,
                      L.of(context).scheduleSourceTypeNone,
                    )
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
              child: Text(
                L.of(context).disclaimer,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        );
      },
    );
  }

  RadioListTile<ScheduleSourceType> buildScheduleTypeRadio(
      SelectSourceViewModel viewModel,
      BuildContext context,
      ScheduleSourceType type,
      String title) {
    return RadioListTile(
      tileColor: Theme.of(context).scaffoldBackgroundColor,
      selectedTileColor: Theme.of(context).scaffoldBackgroundColor,
      overlayColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.hovered)) {
            return Theme.of(context).colorScheme.onSurface.withOpacity(0.08);
          }
          return Colors.transparent;
        },
      ),
      value: type, //model.useDualis,
      onChanged: (value) {
        if (value == null) return;
        viewModel.setScheduleSourceType(value);
      },
      title: Text(title),
      groupValue: viewModel.scheduleSourceType,
    );
  }
}

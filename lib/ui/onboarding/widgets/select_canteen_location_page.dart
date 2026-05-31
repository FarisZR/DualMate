import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/ui/onboarding/viewmodels/onboarding_view_model_base.dart';
import 'package:dualmate/ui/onboarding/viewmodels/select_canteen_location_view_model.dart';
import 'package:flutter/material.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

class SelectCanteenLocationPage extends StatelessWidget {
  const SelectCanteenLocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PropertyChangeConsumer<OnboardingStepViewModel, String>(
      builder: (
        BuildContext context,
        OnboardingStepViewModel? model,
        Set<String>? _,
      ) {
        if (model == null) return Container();

        final viewModel = model as SelectCanteenLocationViewModel;
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
              child: Center(
                child: Text(
                  L.of(context).onboardingCanteenLocationTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Text(
                L.of(context).onboardingCanteenLocationDescription,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: RadioGroup<CanteenLocation>(
                  groupValue: viewModel.selectedLocation,
                  onChanged: (value) {
                    if (value != null) {
                      viewModel.setSelectedLocation(value);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: viewModel.locations
                        .map((location) => RadioListTile<CanteenLocation>(
                              value: location,
                              title: Text(location.name),
                              subtitle: location.subtitle == null
                                  ? null
                                  : Text(location.subtitle!),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
              child: Text(
                L.of(context).onboardingCanteenLocationRequired,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }
}

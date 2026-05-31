import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/ui/onboarding/viewmodels/dualis_login_view_model.dart';
import 'package:dualmate/ui/onboarding/viewmodels/ical_url_view_model.dart';
import 'package:dualmate/ui/onboarding/viewmodels/mannheim_view_model.dart';
import 'package:dualmate/ui/onboarding/viewmodels/rapla_url_view_model.dart';
import 'package:dualmate/ui/onboarding/viewmodels/onboarding_view_model_base.dart';
import 'package:dualmate/ui/onboarding/viewmodels/select_canteen_location_view_model.dart';
import 'package:dualmate/ui/onboarding/viewmodels/select_source_view_model.dart';
import 'package:dualmate/ui/onboarding/widgets/dualis_login_page.dart';
import 'package:dualmate/ui/onboarding/widgets/ical_url_page.dart';
import 'package:dualmate/ui/onboarding/widgets/mannheim_page.dart';
import 'package:dualmate/ui/onboarding/widgets/rapla_url_page.dart';
import 'package:dualmate/ui/onboarding/widgets/select_canteen_location_page.dart';
import 'package:dualmate/ui/onboarding/widgets/select_source_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:kiwi/kiwi.dart';

abstract class OnboardingStep {
  Widget buildContent(BuildContext context);

  OnboardingStepViewModel viewModel();

  String? nextStep();
}

class SelectSourceOnboardingStep extends OnboardingStep {
  final SelectSourceViewModel _viewModel = SelectSourceViewModel(
    KiwiContainer().resolve(),
  );

  @override
  Widget buildContent(BuildContext context) {
    return SelectSourcePage();
  }

  @override
  String? nextStep() {
    return _viewModel.nextStep();
  }

  @override
  OnboardingStepViewModel viewModel() {
    return _viewModel;
  }
}

class DualisCredentialsOnboardingStep extends OnboardingStep {
  final DualisLoginViewModel _viewModel = DualisLoginViewModel(
    KiwiContainer().resolve(),
    KiwiContainer().resolve(),
  );

  @override
  Widget buildContent(BuildContext context) {
    return DualisLoginCredentialsPage();
  }

  @override
  String? nextStep() {
    return "canteenLocation";
  }

  @override
  OnboardingStepViewModel viewModel() {
    return _viewModel;
  }
}

class SelectCanteenLocationOnboardingStep extends OnboardingStep {
  final SelectCanteenLocationViewModel _viewModel =
      SelectCanteenLocationViewModel(
    CanteenLocationService(
      KiwiContainer().resolve(),
    ),
  );

  @override
  Widget buildContent(BuildContext context) {
    return const SelectCanteenLocationPage();
  }

  @override
  String? nextStep() {
    return null;
  }

  @override
  OnboardingStepViewModel viewModel() {
    return _viewModel;
  }
}

class RaplaOnboardingStep extends OnboardingStep {
  final RaplaUrlViewModel _viewModel = RaplaUrlViewModel(
    KiwiContainer().resolve(),
    KiwiContainer().resolve(),
  );

  @override
  Widget buildContent(BuildContext context) {
    return RaplaUrlPage();
  }

  @override
  String? nextStep() {
    return "dualis";
  }

  @override
  OnboardingStepViewModel viewModel() {
    return _viewModel;
  }
}

class IcalOnboardingStep extends OnboardingStep {
  final IcalUrlViewModel _viewModel = IcalUrlViewModel(
    KiwiContainer().resolve(),
    KiwiContainer().resolve(),
  );

  @override
  Widget buildContent(BuildContext context) {
    return IcalUrlPage();
  }

  @override
  String? nextStep() {
    return "dualis";
  }

  @override
  OnboardingStepViewModel viewModel() {
    return _viewModel;
  }
}

class MannheimOnboardingStep extends OnboardingStep {
  final MannheimViewModel _viewModel = MannheimViewModel(
    KiwiContainer().resolve(),
  );

  @override
  Widget buildContent(BuildContext context) {
    return MannheimPage();
  }

  @override
  String? nextStep() {
    return "dualis";
  }

  @override
  OnboardingStepViewModel viewModel() {
    return _viewModel;
  }
}

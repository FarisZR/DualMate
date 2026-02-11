import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/ui/schedule_page.dart';
import 'package:dualmate/schedule/ui/viewmodels/schedule_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/schedule_filter_page.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_help_dialog.dart';
import 'package:dualmate/ui/navigation/navigation_entry.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

class ScheduleNavigationEntry extends NavigationEntry<ScheduleViewModel> {
  late ScheduleViewModel _viewModel;

  @override
  Widget icon(BuildContext context) {
    return Icon(Icons.calendar_today);
  }

  @override
  ScheduleViewModel initViewModel() {
    _viewModel = ScheduleViewModel(
      KiwiContainer().resolve(),
    );
    return _viewModel;
  }

  @override
  String title(BuildContext context) {
    return L.of(context).screenScheduleTitle;
  }

  @override
  Widget build(BuildContext context) {
    return SchedulePage();
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    final viewModel = this.viewModel();
    return [
      PropertyChangeProvider<ScheduleViewModel, String>(
        value: viewModel,
        child: PropertyChangeConsumer<ScheduleViewModel, String>(
          properties: const ["didSetupProperly"],
          builder: (
            BuildContext _,
            ScheduleViewModel? __,
            Set<String>? ___,
          ) =>
              viewModel.didSetupProperly
                  ? Container()
                  : IconButton(
                      icon: Icon(Icons.help_outline),
                      onPressed: () async {
                        await ScheduleHelpDialog().show(context);
                      },
                      tooltip: L.of(context).helpButtonTooltip,
                    ),
        ),
      ),
      PropertyChangeProvider<ScheduleViewModel, String>(
        value: viewModel,
        child: PropertyChangeConsumer<ScheduleViewModel, String>(
          properties: const ["didSetupProperly"],
          builder: (
            BuildContext _,
            ScheduleViewModel? __,
            Set<String>? ___,
          ) =>
              viewModel.didSetupProperly
                  ? IconButton(
                      icon: Icon(Icons.filter_alt),
                      onPressed: () async {
                        try {
                          await FilterViewModel.preloadStates(
                            KiwiContainer().resolve<ScheduleEntryRepository>(),
                            KiwiContainer().resolve<ScheduleFilterRepository>(),
                          ).timeout(const Duration(milliseconds: 900));
                        } catch (_) {}
                        await Navigator.of(context).push(
                          PageRouteBuilder<void>(
                            transitionDuration:
                                const Duration(milliseconds: 240),
                            reverseTransitionDuration:
                                const Duration(milliseconds: 200),
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const ScheduleFilterPage(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              final offsetTween = Tween<Offset>(
                                begin: const Offset(0.18, 0),
                                end: Offset.zero,
                              ).chain(
                                CurveTween(curve: Curves.easeOutCubic),
                              );
                              final fadeTween = Tween<double>(
                                begin: 0.7,
                                end: 1,
                              ).chain(
                                CurveTween(curve: Curves.easeOut),
                              );

                              return SlideTransition(
                                position: animation.drive(offsetTween),
                                child: FadeTransition(
                                  opacity: animation.drive(fadeTween),
                                  child: child,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    )
                  : Container(),
        ),
      )
    ];
  }

  @override
  String get route => "schedule";
}

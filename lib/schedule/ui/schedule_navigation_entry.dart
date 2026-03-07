import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
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
                        final scheduleEntryRepository =
                            KiwiContainer().resolve<ScheduleEntryRepository>();
                        final scheduleFilterRepository =
                            KiwiContainer().resolve<ScheduleFilterRepository>();
                        final preloadFuture = FilterViewModel.preloadStates(
                          scheduleEntryRepository,
                          scheduleFilterRepository,
                        );
                        final didChangeFilters =
                            await Navigator.of(context).push<bool>(
                          PageRouteBuilder<bool>(
                            transitionDuration:
                                const Duration(milliseconds: 180),
                            reverseTransitionDuration:
                                const Duration(milliseconds: 160),
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    ScheduleFilterPage(
                              preloadFuture: preloadFuture,
                            ),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              final opacityTween = Tween<double>(
                                begin: 0,
                                end: 1,
                              ).chain(
                                CurveTween(curve: Curves.easeOutCubic),
                              );

                              return FadeTransition(
                                opacity: animation.drive(opacityTween),
                                child: child,
                              );
                            },
                          ),
                        );
                        if (didChangeFilters == true) {
                          final scheduleProvider =
                              KiwiContainer().resolve<ScheduleProvider>();
                          final scheduleSourceProvider =
                              KiwiContainer().resolve<ScheduleSourceProvider>();
                          scheduleProvider.invalidateScheduleCache();
                          scheduleSourceProvider.fireScheduleSourceChanged();
                        }
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

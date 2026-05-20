import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/custom_icons_icons.dart';
import 'package:dualmate/dualis/ui/dualis_page.dart';
import 'package:dualmate/dualis/ui/viewmodels/study_grades_view_model.dart';
import 'package:dualmate/dualis/ui/widgets/dualis_help_dialog.dart';
import 'package:dualmate/schedule/ui/schedule_page.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:dualmate/ui/navigation/navigation_entry.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

class DualisNavigationEntry extends NavigationEntry<StudyGradesViewModel> {
  static const int sectionIndex = 2;

  @override
  Widget icon(BuildContext context) {
    return Icon(Icons.data_usage);
  }

  @override
  String title(BuildContext context) {
    return L.of(context).screenDualisTitle;
  }

  @override
  StudyGradesViewModel initViewModel() {
    return StudyGradesViewModel(
      KiwiContainer().resolve(),
      KiwiContainer().resolve(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const DualisPage(sectionIndex: sectionIndex);
  }

  @override
  List<Widget> appBarActions(BuildContext context) {
    final model = viewModel();
    return [
      PropertyChangeProvider<StudyGradesViewModel, String>(
        value: model,
        child: PropertyChangeConsumer<StudyGradesViewModel, String>(
          builder: (
            BuildContext _,
            StudyGradesViewModel? model,
            Set<String>? __,
          ) {
            if (model == null) return Container();
            return model.loginState != LoginState.LoggedIn
                ? IconButton(
                    icon: Icon(Icons.help_outline),
                    onPressed: () async {
                      await DualisHelpDialog().show(context);
                    },
                    tooltip: L.of(context).helpButtonTooltip,
                  )
                : IconButton(
                    icon: const Icon(CustomIcons.logout),
                    onPressed: () async {
                      SchedulePage.resetSharedState();
                      FilterViewModel.invalidateCache();
                      await model.logout();
                    },
                    tooltip: L.of(context).logoutButtonTooltip,
                  );
          },
        ),
      ),
    ];
  }

  @override
  String get route => "dualis";
}

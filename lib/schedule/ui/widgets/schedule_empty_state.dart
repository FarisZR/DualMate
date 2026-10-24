import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_page.dart';
import 'package:dualmate/schedule/ui/widgets/schedule_empty_state_placeholder.dart';
import 'package:dualmate/ui/banner_widget.dart';
import 'package:flutter/material.dart';

class ScheduleEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          child: BannerWidget(
            message: L.of(context).scheduleEmptyStateBannerMessage,
            onButtonTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TimetableCustomizationPage(),
                ),
              );
            },
            buttonText: L.of(context).scheduleEmptyStateSetUrl.toUpperCase(),
          ),
        ),
        Expanded(
          child: ClipRRect(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ScheduleEmptyStatePlaceholder(
                showLessonPlaceholders: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

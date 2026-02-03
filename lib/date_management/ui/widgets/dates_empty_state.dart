import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/date_management/ui/widgets/dates_empty_state_placeholder.dart';
import 'package:dualmate/schedule/ui/widgets/select_source_dialog.dart';
import 'package:dualmate/ui/banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';

class DatesEmptyState extends StatelessWidget {
  final Future<void> Function()? onSetupCompleted;

  const DatesEmptyState({
    Key? key,
    this.onSetupCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          child: BannerWidget(
            message: L.of(context).dateManagementEmptyStateBannerMessage,
            onButtonTap: () async {
              await SelectSourceDialog(
                KiwiContainer().resolve(),
                KiwiContainer().resolve(),
              ).show(context);
              if (onSetupCompleted != null) {
                await onSetupCompleted!();
              }
            },
            buttonText: L.of(context).scheduleEmptyStateSetUrl.toUpperCase(),
          ),
        ),
        Expanded(
          child: ClipRRect(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: DatesEmptyStatePlaceholder(),
            ),
          ),
        ),
      ],
    );
  }
}

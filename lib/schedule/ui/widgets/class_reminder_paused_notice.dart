import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/ui/banner_widget.dart';
import 'package:flutter/material.dart';

class ClassReminderPausedNotice extends StatelessWidget {
  final VoidCallback onFixPermissions;

  const ClassReminderPausedNotice({super.key, required this.onFixPermissions});

  @override
  Widget build(BuildContext context) {
    final strings = L.of(context);
    return BannerWidget(
      title: strings.classReminderPausedTitle,
      message: strings.classReminderPausedMessage,
      buttonText: strings.classReminderFixPermissions.toUpperCase(),
      onButtonTap: onFixPermissions,
    );
  }
}

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

class ClassReminderLikelyMissedNotice extends StatelessWidget {
  final VoidCallback onOpenBatterySettings;
  final VoidCallback onDismiss;

  const ClassReminderLikelyMissedNotice({
    super.key,
    required this.onOpenBatterySettings,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final strings = L.of(context);
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 0,
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.notifications_paused_outlined,
                color: colors.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.classReminderMissedTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.classReminderMissedMessage,
                    style: TextStyle(color: colors.onTertiaryContainer),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onOpenBatterySettings,
                      child: Text(strings.classReminderBatterySettings),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: strings.classReminderDismiss,
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              color: colors.onTertiaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

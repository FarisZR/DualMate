import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/common/ui/schedule_entry_type_mappings.dart';
import 'package:dualmate/common/ui/text_styles.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/reminder_configuration_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kiwi/kiwi.dart';

/// Expandable detail sheet for a schedule entry.
///
/// The sheet has exactly two settle states: standard and fully expanded. The
/// built-in [DraggableScrollableSheet] snap is disabled because it animates
/// with a constant velocity (linear) and emits no haptic. Instead snapping is
/// driven manually via [DraggableScrollableController.animateTo] using a snappy
/// Material 3 decelerate ([Curves.easeOutCubic]).
///
/// A selection haptic fires every time the sheet *arrives* at either state,
/// whether the user snapped it there or dragged it there themselves, per
/// https://m3.material.io/styles/motion/transitions/transition-patterns
class ScheduleEntryDetailBottomSheet extends StatefulWidget {
  final ScheduleEntry scheduleEntry;
  final ClassReminderController? reminderController;

  const ScheduleEntryDetailBottomSheet({
    Key? key,
    required this.scheduleEntry,
    this.reminderController,
  }) : super(key: key);

  @override
  State<ScheduleEntryDetailBottomSheet> createState() =>
      _ScheduleEntryDetailBottomSheetState();
}

class _ScheduleEntryDetailBottomSheetState
    extends State<ScheduleEntryDetailBottomSheet> {
  static const double _minChildSize = 0.25;
  static const double _initialChildSize = 0.4; // standard state
  static const double _maxChildSize = 0.9; // fully expanded state

  // A release below this snaps back to standard; above it snaps to expanded.
  static const double _expandThreshold =
      (_initialChildSize + _maxChildSize) / 2;

  // Snappy Material 3 decelerate so the sheet locks into place quickly rather
  // than slowly easing across (see m3.material.io/styles/motion).
  static const Duration _snapDuration = Duration(milliseconds: 200);
  static const Curve _snapCurve = Curves.easeOutCubic;

  static const double _stateTolerance = 0.01;

  final DraggableScrollableController _controller =
      DraggableScrollableController();
  bool _isSnapping = false;
  ClassReminderController? _reminderController;

  // The state the sheet currently sits within tolerance of, so a haptic fires
  // exactly once each time it *arrives* at a state — by snap or by manual drag.
  // Initialized to the standard state since the sheet opens there.
  double? _reachedState = _initialChildSize;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSizeChanged);
    _reminderController = widget.reminderController;
    final container = KiwiContainer();
    if (_reminderController == null &&
        container.isRegistered<ClassReminderController>()) {
      _reminderController = container.resolve<ClassReminderController>();
    }
    _reminderController?.addListener(_onReminderStateChanged);
  }

  @override
  void dispose() {
    _reminderController?.removeListener(_onReminderStateChanged);
    _controller.removeListener(_onSizeChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onReminderStateChanged() {
    if (mounted) setState(() {});
  }

  /// Fires a selection haptic whenever the sheet arrives at a settle state and
  /// clears the snap guard on normal completion.
  void _onSizeChanged() {
    if (!mounted || !_controller.isAttached) return;
    final size = _controller.size;
    if ((size - _maxChildSize).abs() <= _stateTolerance) {
      if (_reachedState != _maxChildSize) {
        _reachedState = _maxChildSize;
        _triggerHaptic();
      }
      _isSnapping = false; // snap completed: arrived at expanded
    } else if ((size - _initialChildSize).abs() <= _stateTolerance) {
      if (_reachedState != _initialChildSize) {
        _reachedState = _initialChildSize;
        _triggerHaptic();
      }
      _isSnapping = false; // snap completed: arrived at standard
    } else {
      _reachedState = null;
    }
  }

  /// Target settle state for a released [size]: standard or fully expanded.
  double _targetForSize(double size) {
    return size < _expandThreshold ? _initialChildSize : _maxChildSize;
  }

  bool _isAtSnap(double size) {
    return (size - _minChildSize).abs() <= _stateTolerance ||
        (size - _initialChildSize).abs() <= _stateTolerance ||
        (size - _maxChildSize).abs() <= _stateTolerance;
  }

  void _onScrollEnd() {
    if (!mounted || !_controller.isAttached || _isSnapping) return;
    final size = _controller.size;
    if (_isAtSnap(size)) return;
    _snapTo(_targetForSize(size));
  }

  void _snapTo(double target) {
    if (!mounted || !_controller.isAttached || _isSnapping) return;
    _isSnapping = true;
    // Fire-and-forget: animateTo's returned future never completes when the
    // user interrupts the snap (AnimationController.stop() cancels the ticker,
    // leaving the primary TickerFuture pending), so we cannot rely on awaiting
    // it to clear the guard. The guard is cleared from cancellation-safe
    // paths instead: when the sheet arrives at a state (_onSizeChanged) or
    // when a new drag starts (ScrollStartNotification in build).
    _controller.animateTo(target, duration: _snapDuration, curve: _snapCurve);
  }

  // Fire-and-forget: haptics are a best-effort enhancement and must never
  // block or break the snap animation (e.g. when the platform call fails or
  // no handler is available, such as in tests without a mock channel).
  void _triggerHaptic() {
    HapticFeedback.selectionClick().catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // When the user takes over mid-snap, Flutter cancels the running
        // animateTo, so clear the guard here — otherwise the (never-completing)
        // snap would leave it stuck and block all later snaps.
        if (notification is ScrollStartNotification &&
            notification.depth == 0) {
          _isSnapping = false;
        }
        // ScrollEndNotification fires when the user lifts their finger. Defer
        // the snap to a post-frame callback so it runs after the scrollable's
        // own ballistic activity has started; animateTo() then cancels it.
        if (notification is ScrollEndNotification &&
            notification.depth == 0 &&
            !_isSnapping) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onScrollEnd());
        }
        return false;
      },
      child: DraggableScrollableSheet(
        expand: false,
        controller: _controller,
        initialChildSize: _initialChildSize,
        minChildSize: _minChildSize,
        maxChildSize: _maxChildSize,
        snap: false,
        builder: (context, scrollController) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: _buildContent(context),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    var formatter = DateFormat.Hm(L.of(context).locale.languageCode);
    var timeStart = formatter.format(widget.scheduleEntry.start);
    var timeEnd = formatter.format(widget.scheduleEntry.end);

    var typeString = scheduleEntryTypeToReadableString(
      context,
      widget.scheduleEntry.type,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Center(
            child: Container(
              height: 8,
              width: 30,
              decoration: BoxDecoration(
                color: colorSeparator(),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16.0),
          child: ScheduleEntryDetailHeaderLayout(
            leading: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      L.of(context).scheduleEntryDetailFrom,
                      style: textStyleScheduleEntryBottomPageTimeFromTo(
                        context,
                      ),
                    ),
                    Text(
                      timeStart,
                      style: textStyleScheduleEntryBottomPageTime(context),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      L.of(context).scheduleEntryDetailTo,
                      style: textStyleScheduleEntryBottomPageTimeFromTo(
                        context,
                      ),
                    ),
                    Text(
                      timeEnd,
                      style: textStyleScheduleEntryBottomPageTime(context),
                    ),
                  ],
                ),
              ],
            ),
            title: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
              child: Text(
                widget.scheduleEntry.title,
                softWrap: true,
                style: textStyleScheduleEntryBottomPageTitle(context),
              ),
            ),
            trailing: _reminderController == null
                ? null
                : _buildReminderButton(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(child: Text(widget.scheduleEntry.professor)),
              Text(
                typeString,
                style: textStyleScheduleEntryBottomPageType(context),
              ),
            ],
          ),
        ),
        widget.scheduleEntry.room.isEmpty
            ? Container()
            : Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                child: Text(widget.scheduleEntry.room.replaceAll(",", "\n")),
              ),
        widget.scheduleEntry.details.isEmpty
            ? Container()
            : Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                child: Container(color: colorSeparator(), height: 1),
              ),
        widget.scheduleEntry.details.isEmpty
            ? Container()
            : Text(widget.scheduleEntry.details),
      ],
    );
  }

  Widget _buildReminderButton(BuildContext context) {
    final controller = _reminderController!;
    final rule = controller.ruleFor(widget.scheduleEntry);
    final paused = rule != null && controller.remindersPaused;
    final icon = paused
        ? Icons.notifications_off_outlined
        : rule == null
        ? Icons.notifications_none_outlined
        : Icons.notifications;
    return IconButton(
      key: const ValueKey('class-reminder-button'),
      onPressed: controller.isInitialized
          ? () => _openReminderConfiguration(context, rule)
          : null,
      icon: Icon(icon),
      color: paused ? Theme.of(context).colorScheme.tertiary : null,
      tooltip: rule == null
          ? L.of(context).classReminderTooltipAdd
          : L.of(context).classReminderTooltipEdit,
    );
  }

  Future<void> _openReminderConfiguration(
    BuildContext context,
    ClassReminderRule? existingRule,
  ) async {
    final controller = _reminderController!;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (sheetContext) => ReminderConfigurationSheet(
        existingRule: existingRule,
        onSave: (offset, scope) async {
          final result = await controller.saveReminder(
            entry: widget.scheduleEntry,
            offset: offset,
            scope: scope,
          );
          if (!sheetContext.mounted) return;
          switch (result) {
            case ReminderActivationResult.active:
              return;
            case ReminderActivationResult.ignoredPastEvent:
              // The configuration sheet closes after this callback. Past
              // events intentionally need no additional message.
              return;
            case ReminderActivationResult.permissionsRequired:
              break;
          }
          final openSettings = await showDialog<bool>(
            context: sheetContext,
            builder: (dialogContext) => AlertDialog(
              title: Text(L.of(dialogContext).classReminderPermissionTitle),
              content: Text(L.of(dialogContext).classReminderPermissionMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    L.of(dialogContext).classReminderPermissionCancel,
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    L.of(dialogContext).classReminderPermissionOpenSettings,
                  ),
                ),
              ],
            ),
          );
          if (openSettings != true) return;
          await controller.openReliablePermissionSettings();
          if (controller.permissionsGranted) {
            await controller.saveReminder(
              entry: widget.scheduleEntry,
              offset: offset,
              scope: scope,
            );
          }
        },
        onRemove: existingRule == null
            ? null
            : () => controller.removeReminder(widget.scheduleEntry),
      ),
    );
  }
}

/// Keeps the detail action independent from the title's intrinsic width.
///
/// The trailing action is overlaid at the header's top-right edge while the
/// content reserves one Material touch-target width for it.
class ScheduleEntryDetailHeaderLayout extends StatelessWidget {
  static const double _trailingExtent = 48;

  final Widget leading;
  final Widget title;
  final Widget? trailing;

  const ScheduleEntryDetailHeaderLayout({
    super.key,
    required this.leading,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            right: trailing == null ? 0 : _trailingExtent,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading,
              Expanded(child: title),
            ],
          ),
        ),
        if (trailing != null) Positioned(top: 0, right: 0, child: trailing!),
      ],
    );
  }
}

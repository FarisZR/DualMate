import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/colors.dart';
import 'package:dualmate/common/ui/schedule_entry_type_mappings.dart';
import 'package:dualmate/common/ui/text_styles.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Expandable detail sheet for a schedule entry.
///
/// The built-in [DraggableScrollableSheet] snap is disabled because it animates
/// with a constant velocity (linear), which does not match Material 3 motion.
/// Instead snapping is driven manually via [DraggableScrollableController.animateTo]
/// using the Material 3 emphasized curve ([Curves.easeInOutCubicEmphasized]) and
/// a selection haptic, per
/// https://m3.material.io/styles/motion/transitions/transition-patterns
class ScheduleEntryDetailBottomSheet extends StatefulWidget {
  final ScheduleEntry scheduleEntry;

  const ScheduleEntryDetailBottomSheet({Key? key, required this.scheduleEntry})
    : super(key: key);

  @override
  State<ScheduleEntryDetailBottomSheet> createState() =>
      _ScheduleEntryDetailBottomSheetState();
}

class _ScheduleEntryDetailBottomSheetState
    extends State<ScheduleEntryDetailBottomSheet> {
  static const double _minChildSize = 0.25;
  static const double _initialChildSize = 0.4;
  static const double _maxChildSize = 0.9;

  // Snap stops: dismiss (min), medium, large. A release between two stops snaps
  // to the nearest stop, decided at the midpoint between adjacent stops.
  static const double _lowerThreshold = (_minChildSize + _initialChildSize) / 2;
  static const double _upperThreshold = (_initialChildSize + _maxChildSize) / 2;

  // Material 3 emphasized motion (see m3.material.io/styles/motion).
  static const Duration _snapDuration = Duration(milliseconds: 300);
  static const Curve _snapCurve = Curves.easeInOutCubicEmphasized;

  static const double _snapTolerance = 0.005;

  final DraggableScrollableController _controller =
      DraggableScrollableController();
  bool _isSnapping = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Target snap stop for a released [size]: min (dismiss), medium or large.
  double _targetForSize(double size) {
    if (size < _lowerThreshold) return _minChildSize;
    if (size < _upperThreshold) return _initialChildSize;
    return _maxChildSize;
  }

  bool _isAtSnap(double size) {
    return (size - _minChildSize).abs() <= _snapTolerance ||
        (size - _initialChildSize).abs() <= _snapTolerance ||
        (size - _maxChildSize).abs() <= _snapTolerance;
  }

  void _onScrollEnd() {
    if (!mounted || !_controller.isAttached || _isSnapping) return;
    final size = _controller.size;
    if (_isAtSnap(size)) return;
    _snapTo(_targetForSize(size));
  }

  Future<void> _snapTo(double target) async {
    if (!mounted || !_controller.isAttached || _isSnapping) return;
    _isSnapping = true;
    _triggerHaptic();
    try {
      await _controller.animateTo(
        target,
        duration: _snapDuration,
        curve: _snapCurve,
      );
    } finally {
      _isSnapping = false;
    }
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Column(
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
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                  child: Text(
                    widget.scheduleEntry.title,
                    softWrap: true,
                    style: textStyleScheduleEntryBottomPageTitle(context),
                  ),
                ),
              ),
            ],
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
}

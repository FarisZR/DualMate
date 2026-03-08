import 'dart:async';

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/date_management/model/important_event.dart';
import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ImportantEventTile extends StatelessWidget {
  static final Map<String, DateFormat> _dateFormats = <String, DateFormat>{};
  static final Map<String, DateFormat> _timeFormats = <String, DateFormat>{};

  final ImportantEvent event;
  final EdgeInsets contentPadding;
  final VisualDensity? visualDensity;
  final double dotSize;
  final TextStyle? titleStyle;
  final Color? dotColor;
  final bool showProfessor;

  const ImportantEventTile({
    Key? key,
    required this.event,
    required this.contentPadding,
    this.visualDensity,
    this.dotSize = 12,
    this.titleStyle,
    this.dotColor,
    this.showProfessor = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final resolvedTitleStyle = titleStyle ??
        (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
          decoration: event.end.isBefore(DateTime.now())
              ? TextDecoration.lineThrough
              : null,
        );

    return ListTile(
      contentPadding: contentPadding,
      visualDensity: visualDensity,
      leading: _EventDot(
        color: dotColor ?? _eventColor(context, event),
        size: dotSize,
      ),
      isThreeLine: _showsProfessor,
      title: Text(event.title, style: resolvedTitleStyle),
      subtitle: _buildSubtitle(context),
    );
  }

  bool get _showsProfessor {
    return showProfessor &&
        event.type == ScheduleEntryType.Exam &&
        event.professor.trim().isNotEmpty;
  }

  Widget _buildSubtitle(BuildContext context) {
    if (!_showsProfessor) {
      return Text(_formatEventDate(context, event));
    }

    final professorStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatEventDate(context, event)),
        _AutoScrollingProfessorText(
          text: event.professor,
          style: professorStyle,
        ),
      ],
    );
  }

  Color _eventColor(BuildContext context, ImportantEvent event) {
    switch (event.type) {
      case ScheduleEntryType.Exam:
        return const Color(0xffff0000);
      case ScheduleEntryType.SpecialEvent:
        return const Color(0xffc0e2ff);
      case ScheduleEntryType.PublicHoliday:
        return const Color(0xffcbcbcb);
      default:
        return Theme.of(context).disabledColor;
    }
  }

  String _formatEventDate(BuildContext context, ImportantEvent event) {
    final locale = L.of(context).locale.languageCode;
    final dateFormat = _dateFormats.putIfAbsent(
      locale,
      () => DateFormat('dd/MM/yyyy', locale),
    );
    if (event.isSingleDay) {
      final dateText = dateFormat.format(event.start);
      if (event.hasTime) {
        final timeText = _timeFormats
            .putIfAbsent(locale, () => DateFormat.Hm(locale))
            .format(event.start);
        return "$dateText · $timeText";
      }
      return dateText;
    }

    final startDate = dateFormat.format(event.start);
    final endDate = dateFormat.format(event.end);
    return "$startDate - $endDate";
  }
}

class _AutoScrollingProfessorText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _AutoScrollingProfessorText({required this.text, this.style});

  @override
  State<_AutoScrollingProfessorText> createState() =>
      _AutoScrollingProfessorTextState();
}

class _AutoScrollingProfessorTextState
    extends State<_AutoScrollingProfessorText> {
  static const _initialPause = Duration(milliseconds: 900);
  static const _edgePause = Duration(milliseconds: 700);
  static const _resumePause = Duration(milliseconds: 1400);

  final ScrollController _scrollController = ScrollController();
  int _animationToken = 0;
  Timer? _pendingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleAutoScroll();
    });
  }

  @override
  void didUpdateWidget(covariant _AutoScrollingProfessorText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _scrollController.jumpTo(0);
      _scheduleAutoScroll();
    }
  }

  @override
  void dispose() {
    _animationToken++;
    _pendingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _animationToken++;
    } else if (notification is ScrollEndNotification) {
      _scheduleAutoScroll(delay: _resumePause);
    }
    return false;
  }

  void _scheduleAutoScroll({Duration delay = _initialPause}) {
    final token = ++_animationToken;
    _pendingTimer?.cancel();
    _pendingTimer = Timer(delay, () {
      _autoScrollLoop(token, forward: true);
    });
  }

  Future<void> _autoScrollLoop(int token, {required bool forward}) async {
    if (!mounted || token != _animationToken || !_scrollController.hasClients) {
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      return;
    }

    final targetOffset = forward ? maxExtent : 0.0;
    final currentOffset = _scrollController.offset;
    final distance = (targetOffset - currentOffset).abs();
    if (distance <= 0.5) {
      _scheduleNextPass(token, forward: !forward);
      return;
    }

    final duration = Duration(
      milliseconds: (distance * 12).round().clamp(1200, 6000),
    );

    try {
      await _scrollController.animateTo(
        targetOffset,
        duration: duration,
        curve: Curves.linear,
      );
    } catch (_) {
      return;
    }

    if (!mounted || token != _animationToken) return;
    _scheduleNextPass(token, forward: !forward);
  }

  void _scheduleNextPass(int token, {required bool forward}) {
    if (!mounted || token != _animationToken) return;
    _pendingTimer?.cancel();
    _pendingTimer = Timer(_edgePause, () {
      _autoScrollLoop(token, forward: forward);
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: SingleChildScrollView(
        key: const Key('important_event_professor_scroll'),
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Text(
          widget.text,
          softWrap: false,
          style: widget.style,
        ),
      ),
    );
  }
}

class _EventDot extends StatelessWidget {
  final Color color;
  final double size;

  const _EventDot({Key? key, required this.color, required this.size})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

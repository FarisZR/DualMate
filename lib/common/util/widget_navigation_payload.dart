import 'package:dualmate/schedule/model/schedule_entry.dart';
import 'package:flutter/foundation.dart';

const String widgetScheduleEntryId = "schedule_entry_id";
const String widgetScheduleEntryStart = "schedule_entry_start";
const String widgetScheduleEntryEnd = "schedule_entry_end";
const String widgetScheduleEntryTitle = "schedule_entry_title";
const String widgetScheduleEntryDetails = "schedule_entry_details";
const String widgetScheduleEntryProfessor = "schedule_entry_professor";
const String widgetScheduleEntryRoom = "schedule_entry_room";
const String widgetScheduleEntryType = "schedule_entry_type";
const String widgetScheduleDayStart = "schedule_day_start";
const String widgetCanteenDayStart = "canteen_day_start";

class WidgetScheduleEntryPayload {
  final int? id;
  final DateTime? start;
  final DateTime? end;
  final String? title;
  final String? details;
  final String? professor;
  final String? room;
  final int? type;
  final DateTime? dayStart;

  const WidgetScheduleEntryPayload({
    this.id,
    this.start,
    this.end,
    this.title,
    this.details,
    this.professor,
    this.room,
    this.type,
    this.dayStart,
  });

  bool get hasEntry => id != null || start != null || end != null;

  bool get isEmpty =>
      id == null &&
      start == null &&
      end == null &&
      title == null &&
      details == null &&
      professor == null &&
      room == null &&
      type == null &&
      dayStart == null;

  factory WidgetScheduleEntryPayload.fromMap(Map<dynamic, dynamic> map) {
    return WidgetScheduleEntryPayload(
      id: _intFrom(map[widgetScheduleEntryId]),
      start: _dateFromMillis(map[widgetScheduleEntryStart]),
      end: _dateFromMillis(map[widgetScheduleEntryEnd]),
      title: _stringFrom(map[widgetScheduleEntryTitle]),
      details: _stringFrom(map[widgetScheduleEntryDetails]),
      professor: _stringFrom(map[widgetScheduleEntryProfessor]),
      room: _stringFrom(map[widgetScheduleEntryRoom]),
      type: _intFrom(map[widgetScheduleEntryType]),
      dayStart: _dateFromMillis(map[widgetScheduleDayStart]),
    );
  }
}

class WidgetNavigationPayloadStore extends ChangeNotifier {
  WidgetNavigationPayloadStore._();

  static final WidgetNavigationPayloadStore instance =
      WidgetNavigationPayloadStore._();

  WidgetScheduleEntryPayload? _schedulePayload;
  WidgetCanteenDayPayload? _canteenPayload;

  WidgetScheduleEntryPayload? takeSchedulePayload() {
    final payload = _schedulePayload;
    _schedulePayload = null;
    return payload;
  }

  WidgetScheduleEntryPayload? peekSchedulePayload() {
    return _schedulePayload;
  }

  WidgetCanteenDayPayload? takeCanteenPayload() {
    final payload = _canteenPayload;
    _canteenPayload = null;
    return payload;
  }

  WidgetCanteenDayPayload? peekCanteenPayload() {
    return _canteenPayload;
  }

  void setSchedulePayload(WidgetScheduleEntryPayload payload) {
    _schedulePayload = payload;
    notifyListeners();
  }

  void setCanteenPayload(WidgetCanteenDayPayload payload) {
    _canteenPayload = payload;
    notifyListeners();
  }
}

class WidgetCanteenDayPayload {
  final DateTime? dayStart;

  const WidgetCanteenDayPayload({this.dayStart});

  bool get isEmpty => dayStart == null;

  factory WidgetCanteenDayPayload.fromMap(Map<dynamic, dynamic> map) {
    return WidgetCanteenDayPayload(
      dayStart: _dateFromMillis(map[widgetCanteenDayStart]),
    );
  }
}

ScheduleEntry? resolveScheduleEntry(
  List<ScheduleEntry> entries,
  WidgetScheduleEntryPayload payload,
) {
  if (entries.isEmpty) return null;

  if (payload.id != null) {
    final match = entries.where((entry) => entry.id == payload.id).toList();
    if (match.isNotEmpty) return match.first;
  }

  bool hasFallbackData = payload.start != null ||
      payload.end != null ||
      payload.title != null ||
      payload.details != null ||
      payload.professor != null ||
      payload.room != null ||
      payload.type != null;

  if (!hasFallbackData) return null;

  for (final entry in entries) {
    if (payload.start != null && entry.start != payload.start) continue;
    if (payload.end != null && entry.end != payload.end) continue;
    if (payload.title != null && entry.title != payload.title) continue;
    if (payload.details != null && entry.details != payload.details) continue;
    if (payload.professor != null && entry.professor != payload.professor) {
      continue;
    }
    if (payload.room != null && entry.room != payload.room) continue;
    if (payload.type != null && entry.type.index != payload.type) continue;
    return entry;
  }

  return null;
}

int? _intFrom(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

String? _stringFrom(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

DateTime? _dateFromMillis(dynamic value) {
  final millis = _intFrom(value);
  if (millis == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

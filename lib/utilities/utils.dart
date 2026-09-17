import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mvskoke_language_app/utilities/timestamp.dart';

class Utils {
  static Timestamp getFormattedDate(dynamic date) {
    if (date is String) {
      if (date.startsWith('Timestamp')) {
        var tempString = int.parse(date.split('=')[1].split(',')[0]);
        return Timestamp.fromMillisecondsSinceEpoch(tempString * 1000);
      }
      if (date.toLowerCase() == 'null') return Timestamp(1644393087, 0);
      return Timestamp.fromDate(DateTime.parse(date));
    }
    if (date is DateTime) {
      return Timestamp.fromDate(date);
    }
    if (date is Map) {
      return Timestamp.fromMillisecondsSinceEpoch(date['_seconds'] * 1000);
    }

    return Timestamp(1644393087, 0);
  }

  static String? getChordTabs(String chord) {
    if (_chordTabs.keys.contains(chord)) {
      return _chordTabs[chord];
    }
    return null;
  }

  static final Map<String, String> _chordTabs = {
    "A": "x 0 2 2 2 0",
    "B": "x 0 4 4 4 2",
    "C": "x 3 2 0 1 0",
    "D": "x x 0 2 3 2",
    "E": "0 2 2 1 0 0",
    "F": "1 3 3 2 1 1",
    "G": "3 2 0 0 0 3",
    "Am": "x 0 2 2 1 0",
    "Bm": "x 2 4 4 3 2",
    "Cm": "x 3 5 5 4 3",
    "Dm": "x x 0 2 3 1",
    "Em": "0 2 2 0 0 0",
    "Fm": "1 3 3 1 1 1",
    "Gm": "3 5 5 3 3 3",
    "A#": "x 1 3 3 3 1",
    "C#": "x 4 3 1 2 1",
    "D#": "x x 1 3 4 3",
    "F#": "2 4 4 3 2 2",
    "G#": "4 6 6 5 4 4",
    "A#m": "x 1 3 3 2 1",
    "C#m": "x 4 6 6 5 4",
    "D#m": "x x 1 3 4 2",
    "F#m": "2 4 4 2 2 2",
    "G#m": "4 6 6 4 4 4",
    "A7": "x 0 2 0 2 0",
    "B7": "x 2 1 2 0 x",
    "C7": "x 3 2 3 1 x",
    "D7": "x x 0 2 1 2",
    "E7": "0 2 0 1 0 0",
    "F7": "1 3 1 2 1 1",
    "G7": "3 2 x x x 1",
  };

  static List<Alignment> alignments = [
    Alignment.centerLeft,
    Alignment.center,
    Alignment.centerRight,
    Alignment.bottomLeft,
    Alignment.bottomCenter,
    Alignment.bottomRight,
    Alignment.topLeft,
    Alignment.topCenter,
    Alignment.topRight,
  ];

  /// Formats provided [date] to a fuzzy time like 'a moment ago'
  ///
  /// - If [clock] is passed this will be the point of reference for calculating
  ///   the elapsed time. Defaults to DateTime.now()
  /// - If [allowFromNow] is passed, format will use the From prefix, ie. a date
  ///   5 minutes from now in 'en' locale will display as "5 minutes from now"
  static String humanize(
    DateTime date, {
    DateTime? clock,
    bool allowFromNow = false,
  }) {
    final shouldAllowFromNow = allowFromNow;
    final messages = EnMessages();
    final currentClock = clock ?? DateTime.now();
    var elapsed =
        currentClock.millisecondsSinceEpoch - date.millisecondsSinceEpoch;

    String prefix, suffix;

    if (shouldAllowFromNow && elapsed < 0) {
      elapsed = date.isBefore(currentClock) ? elapsed : elapsed.abs();
      prefix = messages.prefixFromNow();
      suffix = messages.suffixFromNow();
    } else {
      prefix = messages.prefixAgo();
      suffix = messages.suffixAgo();
    }

    final num seconds = elapsed / 1000;
    final num minutes = seconds / 60;
    final num hours = minutes / 60;
    final num days = hours / 24;

    late String result;
    if (seconds < 45) {
      result = messages.lessThanOneMinute(seconds.round());
    } else if (seconds < 90) {
      result = messages.aboutAMinute(minutes.round());
    } else if (minutes < 45) {
      result = messages.minutes(minutes.round());
    } else if (minutes < 90) {
      result = messages.aboutAnHour(minutes.round());
    } else if (hours < 24) {
      result = messages.hours(hours.round());
    } else if (hours < 48) {
      result = messages.aDay(hours.round());
    } else if (days < 7) {
      return DateFormat.EEEE().format(date);
    } else if (days < 365) {
      return DateFormat.MMMd().format(date);
    } else {
      return DateFormat.yMMMd().format(date);
    }

    return [
      prefix,
      result,
      suffix,
    ].where((str) => str.isNotEmpty).join(messages.wordSeparator());
  }
}

class EnMessages {
  String prefixAgo() => '';
  String prefixFromNow() => '';
  String suffixAgo() => 'ago';
  String suffixFromNow() => 'from now';
  String lessThanOneMinute(int seconds) => 'a moment';
  String aboutAMinute(int minutes) => 'a minute';
  String minutes(int minutes) => '$minutes minutes';
  String aboutAnHour(int minutes) => 'about an hour';
  String hours(int hours) => '$hours hours';
  String aDay(int hours) => 'a day';
  String days(int days) => '$days days';
  String aboutAMonth(int days) => 'about a month';
  String months(int months) => '$months months';
  String aboutAYear(int year) => 'about a year';
  String years(int years) => '$years years';
  String wordSeparator() => ' ';
}

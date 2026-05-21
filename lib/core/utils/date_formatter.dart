import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final _fullDate = DateFormat('MMM d, yyyy');
  static final _shortDate = DateFormat('MMM d');
  static final _dayMonth = DateFormat('E, MMM d');
  static final _time = DateFormat('h:mm a');
  static final _dateTime = DateFormat('MMM d, yyyy h:mm a');

  static String fullDate(DateTime date) => _fullDate.format(date);
  static String shortDate(DateTime date) => _shortDate.format(date);
  static String dayMonth(DateTime date) => _dayMonth.format(date);
  static String time(DateTime date) => _time.format(date);
  static String dateTime(DateTime date) => _dateTime.format(date);

  static String dateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${DateFormat('MMM d').format(start)} - ${DateFormat('d, yyyy').format(end)}';
    }
    if (start.year == end.year) {
      return '${shortDate(start)} - ${shortDate(end)}, ${end.year}';
    }
    return '${fullDate(start)} - ${fullDate(end)}';
  }

  static String daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 0) return '${-diff} days ago';
    if (diff < 7) return 'In $diff days';
    if (diff < 30) return 'In ${diff ~/ 7} weeks';
    return fullDate(date);
  }

  static String tripDuration(DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;
    if (days == 1) return '1 day';
    return '$days days';
  }
}

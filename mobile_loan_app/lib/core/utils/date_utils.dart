import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');
  static final DateFormat _slashFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _monthYearFormat = DateFormat('MM/yyyy');

  static String format(DateTime? date) {
    if (date == null) return '';
    return _dateFormat.format(date);
  }

  static String formatSlash(DateTime? date) {
    if (date == null) return '';
    return _slashFormat.format(date);
  }

  static String formatMonthYear(DateTime? date) {
    if (date == null) return '';
    return _monthYearFormat.format(date);
  }

  static DateTime parse(String str) {
    try {
      if (str.contains('/')) {
        return _slashFormat.parse(str);
      }
      return _dateFormat.parse(str);
    } catch (_) {
      return DateTime.now();
    }
  }
}

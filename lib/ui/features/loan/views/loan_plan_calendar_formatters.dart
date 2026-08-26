import 'package:lunar/lunar.dart';

/// Formats the lunar month represented by a repayment row.
///
/// Repayment rows currently only store a Gregorian year-month, so the first
/// day of that month is used as the representative date for the lunar label.
String formatLoanLunarMonth(String month) {
  final match = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(month);
  if (match == null) return '—';

  final year = int.tryParse(match.group(1)!);
  final monthNumber = int.tryParse(match.group(2)!);
  if (year == null ||
      monthNumber == null ||
      monthNumber < 1 ||
      monthNumber > 12) {
    return '—';
  }

  try {
    final lunar = Solar.fromYmd(year, monthNumber, 1).getLunar();
    final lunarMonth = lunar.getMonth();
    final leapPrefix = lunarMonth < 0 ? '闰' : '';
    return '${lunar.getYear()}-$leapPrefix${lunarMonth.abs()}月';
  } catch (_) {
    return '—';
  }
}

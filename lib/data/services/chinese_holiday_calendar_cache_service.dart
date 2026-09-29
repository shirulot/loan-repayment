import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/chinese_holiday_calendar_snapshot.dart';

class ChineseHolidayCalendarCacheService {
  const ChineseHolidayCalendarCacheService();

  static const _fileName = 'chinese-holiday-calendar.json';

  Future<ChineseHolidayCalendarSnapshot> load() async {
    try {
      final file = await _snapshotFile();
      if (!await file.exists()) return const ChineseHolidayCalendarSnapshot();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const ChineseHolidayCalendarSnapshot();
      return ChineseHolidayCalendarSnapshot.fromJson(decoded);
    } on FileSystemException {
      return const ChineseHolidayCalendarSnapshot();
    } on FormatException {
      return const ChineseHolidayCalendarSnapshot();
    } on TypeError {
      return const ChineseHolidayCalendarSnapshot();
    }
  }

  Future<void> save(ChineseHolidayCalendarSnapshot snapshot) async {
    final file = await _snapshotFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );
  }

  Future<File> _snapshotFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDirectory = Directory('${directory.path}/loan-repayment-plans');
    if (!await cacheDirectory.exists()) {
      await cacheDirectory.create(recursive: true);
    }
    return File('${cacheDirectory.path}/$_fileName');
  }
}

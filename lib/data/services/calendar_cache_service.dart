import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/calendar_models.dart';

class CalendarCacheService {
  const CalendarCacheService();

  static const _directoryName = 'loan-repayment-plans';
  static const _fileName = 'calendar-state.json';

  Future<CalendarData> load() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) return const CalendarData();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const CalendarData();
      return CalendarData.fromJson(decoded);
    } on FileSystemException {
      return const CalendarData();
    } on FormatException {
      return const CalendarData();
    } on TypeError {
      return const CalendarData();
    }
  }

  Future<void> save(CalendarData data) async {
    final file = await _stateFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
    );
  }

  Future<File> _stateFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDirectory = Directory('${directory.path}/$_directoryName');
    if (!await cacheDirectory.exists()) {
      await cacheDirectory.create(recursive: true);
    }
    return File('${cacheDirectory.path}/$_fileName');
  }
}

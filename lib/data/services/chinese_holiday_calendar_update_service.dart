// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/chinese_holiday_calendar_snapshot.dart';
import 'chinese_holiday_calendar_cache_service.dart';

typedef HolidayCalendarGet = Future<http.Response> Function(Uri uri);
typedef _HolidayYearData = ({Map<int, bool> workdays, Map<int, String> names});

class ChineseHolidayCalendarUpdateService {
  ChineseHolidayCalendarUpdateService({
    required ChineseHolidayCalendarCacheService cacheService,
    HolidayCalendarGet? get,
  }) : _cacheService = cacheService,
       _get = get ?? http.get;

  final ChineseHolidayCalendarCacheService _cacheService;
  final HolidayCalendarGet _get;

  Future<ChineseHolidayCalendarSnapshot> load() => _cacheService.load();

  /// Tries once per calendar month when the app is opened, retaining old data
  /// whenever the network response is unavailable or fails validation.
  Future<ChineseHolidayCalendarSnapshot> refreshIfDue({DateTime? now}) async {
    final current = await _cacheService.load();
    final date = now ?? DateTime.now();
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    if (current.lastAttemptedMonth == monthKey) return current;

    var snapshot = current.copyWith(lastAttemptedMonth: monthKey);
    try {
      await _cacheService.save(snapshot);
    } on Exception {
      // Continue with the request; the app remains usable if storage is read-only.
    }

    final fetched = await Future.wait(<Future<_HolidayYearData?>>[
      _fetchYear(date.year),
      _fetchYear(date.year + 1),
    ]);
    final overrides = Map<int, bool>.from(snapshot.workdayOverrides);
    final names = Map<int, String>.from(snapshot.holidayNames);
    for (final yearData in fetched) {
      if (yearData == null) continue;
      final year = yearData.workdays.keys.first ~/ 10000;
      overrides.removeWhere((key, _) => key ~/ 10000 == year);
      names.removeWhere((key, _) => key ~/ 10000 == year);
      for (final entry in yearData.workdays.entries) {
        overrides[entry.key] = entry.value;
      }
      names.addAll(yearData.names);
    }
    if (fetched.any((yearData) => yearData != null)) {
      snapshot = snapshot.copyWith(
        workdayOverrides: overrides,
        holidayNames: names,
        lastSuccessfulAt: date,
      );
    }
    try {
      await _cacheService.save(snapshot);
    } on Exception {
      // Keep the in-memory result even if the cache cannot be updated.
    }
    return snapshot;
  }

  Future<_HolidayYearData?> _fetchYear(int year) async {
    try {
      final uri = Uri.https('timor.tech', '/api/holiday/year/$year/');
      final response = await _get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['code'] != 0) return null;
      final holidays = decoded['holiday'];
      if (holidays is! Map || holidays.isEmpty) return null;

      final overrides = <int, bool>{};
      final names = <int, String>{};
      for (final value in holidays.values) {
        if (value is! Map || value['holiday'] is! bool) return null;
        final day = DateTime.tryParse(value['date']?.toString() ?? '');
        if (day == null || day.year != year) return null;
        final key = day.year * 10000 + day.month * 100 + day.day;
        overrides[key] = !(value['holiday'] as bool);
        final name = value['name']?.toString().trim();
        if (name != null && name.isNotEmpty) names[key] = name;
      }
      return overrides.isEmpty ? null : (workdays: overrides, names: names);
    } on Exception {
      return null;
    }
  }
}

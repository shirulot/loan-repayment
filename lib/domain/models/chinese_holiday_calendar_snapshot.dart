class ChineseHolidayCalendarSnapshot {
  const ChineseHolidayCalendarSnapshot({
    this.workdayOverrides = const <int, bool>{},
    this.holidayNames = const <int, String>{},
    this.lastAttemptedMonth,
    this.lastSuccessfulAt,
  });

  final Map<int, bool> workdayOverrides;
  final Map<int, String> holidayNames;
  final String? lastAttemptedMonth;
  final DateTime? lastSuccessfulAt;

  factory ChineseHolidayCalendarSnapshot.fromJson(Map<dynamic, dynamic> json) {
    final rawOverrides = json['workdayOverrides'];
    final overrides = <int, bool>{};
    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries) {
        final dateKey = int.tryParse(entry.key.toString());
        if (dateKey != null && entry.value is bool) {
          overrides[dateKey] = entry.value as bool;
        }
      }
    }
    final rawNames = json['holidayNames'];
    final names = <int, String>{};
    if (rawNames is Map) {
      for (final entry in rawNames.entries) {
        final dateKey = int.tryParse(entry.key.toString());
        final name = entry.value?.toString().trim();
        if (dateKey != null && name != null && name.isNotEmpty) {
          names[dateKey] = name;
        }
      }
    }
    final lastAttemptedMonth = json['lastAttemptedMonth']?.toString();
    final lastSuccessfulAt = DateTime.tryParse(
      json['lastSuccessfulAt']?.toString() ?? '',
    );
    return ChineseHolidayCalendarSnapshot(
      workdayOverrides: overrides,
      holidayNames: names,
      lastAttemptedMonth: lastAttemptedMonth,
      lastSuccessfulAt: lastSuccessfulAt,
    );
  }

  ChineseHolidayCalendarSnapshot copyWith({
    Map<int, bool>? workdayOverrides,
    Map<int, String>? holidayNames,
    String? lastAttemptedMonth,
    DateTime? lastSuccessfulAt,
    bool clearLastSuccessfulAt = false,
  }) {
    return ChineseHolidayCalendarSnapshot(
      workdayOverrides: workdayOverrides ?? this.workdayOverrides,
      holidayNames: holidayNames ?? this.holidayNames,
      lastAttemptedMonth: lastAttemptedMonth ?? this.lastAttemptedMonth,
      lastSuccessfulAt: clearLastSuccessfulAt
          ? null
          : lastSuccessfulAt ?? this.lastSuccessfulAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'workdayOverrides': <String, bool>{
      for (final entry in workdayOverrides.entries)
        entry.key.toString(): entry.value,
    },
    'holidayNames': <String, String>{
      for (final entry in holidayNames.entries)
        entry.key.toString(): entry.value,
    },
    if (lastAttemptedMonth != null) 'lastAttemptedMonth': lastAttemptedMonth,
    if (lastSuccessfulAt != null)
      'lastSuccessfulAt': lastSuccessfulAt!.toIso8601String(),
  };
}

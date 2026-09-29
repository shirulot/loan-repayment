enum CalendarNodeSource { note, prepayment }

enum CalendarMonthlyRuleType { commercialPayment, providentFirstWorkday, note }

enum CalendarMonthlyScheduleType {
  fixedDay,
  firstWorkdayAfterDay,
  nthWorkdayOfMonth,
  nthWorkdayAfterDay,
}

class CalendarNode {
  const CalendarNode({
    required this.id,
    required this.title,
    required this.dateTime,
    this.note = '',
    this.notificationsEnabled = true,
    this.source = CalendarNodeSource.note,
    this.prepaymentId,
    this.amount,
  });

  final String id;
  final String title;
  final DateTime dateTime;
  final String note;
  final bool notificationsEnabled;
  final CalendarNodeSource source;
  final String? prepaymentId;
  final double? amount;

  factory CalendarNode.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    return CalendarNode(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      dateTime: DateTime.parse(json['dateTime'].toString()),
      note: json['note']?.toString() ?? '',
      notificationsEnabled: json['notificationsEnabled'] != false,
      source: CalendarNodeSource.values.firstWhere(
        (source) => source.name == json['source'],
        orElse: () => CalendarNodeSource.note,
      ),
      prepaymentId: json['prepaymentId']?.toString(),
      amount: amount is num ? amount.toDouble() : null,
    );
  }

  CalendarNode copyWith({
    String? title,
    DateTime? dateTime,
    String? note,
    bool clearNote = false,
    bool? notificationsEnabled,
    double? amount,
  }) {
    return CalendarNode(
      id: id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      note: clearNote ? '' : note ?? this.note,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      source: source,
      prepaymentId: prepaymentId,
      amount: amount ?? this.amount,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'dateTime': dateTime.toIso8601String(),
    'note': note,
    'notificationsEnabled': notificationsEnabled,
    'source': source.name,
    if (prepaymentId != null) 'prepaymentId': prepaymentId,
    if (amount != null) 'amount': amount,
  };
}

class CalendarMonthlyRule {
  const CalendarMonthlyRule({
    required this.id,
    required this.type,
    required this.createdAt,
    CalendarMonthlyScheduleType? scheduleType,
    int? dayOfMonth,
    this.workdayOrdinal = 1,
    this.hour = 10,
    this.minute = 0,
    this.notificationsEnabled = true,
    this.customTitle,
    this.note = '',
  }) : scheduleType =
           scheduleType ??
           (type == CalendarMonthlyRuleType.providentFirstWorkday
               ? CalendarMonthlyScheduleType.firstWorkdayAfterDay
               : CalendarMonthlyScheduleType.fixedDay),
       dayOfMonth =
           dayOfMonth ??
           (type == CalendarMonthlyRuleType.providentFirstWorkday ? 0 : 1);

  final String id;
  final CalendarMonthlyRuleType type;
  final DateTime createdAt;
  final CalendarMonthlyScheduleType scheduleType;
  final int dayOfMonth;
  final int workdayOrdinal;
  final int hour;
  final int minute;
  final bool notificationsEnabled;
  final String? customTitle;
  final String note;

  factory CalendarMonthlyRule.fromJson(Map<String, dynamic> json) {
    int value(String key, int fallback) {
      final raw = json[key];
      return raw is num ? raw.toInt() : int.tryParse('$raw') ?? fallback;
    }

    final type = CalendarMonthlyRuleType.values.firstWhere(
      (type) => type.name == json['type'],
      orElse: () => CalendarMonthlyRuleType.commercialPayment,
    );
    final hasSchedule = json['scheduleType'] != null;
    final scheduleType = CalendarMonthlyScheduleType.values.firstWhere(
      (schedule) => schedule.name == json['scheduleType'],
      orElse: () => type == CalendarMonthlyRuleType.providentFirstWorkday
          ? CalendarMonthlyScheduleType.firstWorkdayAfterDay
          : CalendarMonthlyScheduleType.fixedDay,
    );
    return CalendarMonthlyRule(
      id: json['id']?.toString() ?? '',
      type: type,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      scheduleType: scheduleType,
      // Older provident rules represented "first workday" without a base day.
      dayOfMonth:
          !hasSchedule && type == CalendarMonthlyRuleType.providentFirstWorkday
          ? 0
          : value(
              'dayOfMonth',
              scheduleType == CalendarMonthlyScheduleType.fixedDay ? 1 : 0,
            ).clamp(
              scheduleType == CalendarMonthlyScheduleType.fixedDay ? 1 : 0,
              31,
            ),
      workdayOrdinal: value('workdayOrdinal', 1).clamp(1, 22),
      hour: value('hour', 10).clamp(0, 23),
      minute: value('minute', 0).clamp(0, 59),
      notificationsEnabled: json['notificationsEnabled'] != false,
      customTitle: json['customTitle']?.toString(),
      note: json['note']?.toString() ?? '',
    );
  }

  CalendarMonthlyRule copyWith({
    CalendarMonthlyScheduleType? scheduleType,
    int? dayOfMonth,
    int? workdayOrdinal,
    int? hour,
    int? minute,
    bool? notificationsEnabled,
    String? customTitle,
    String? note,
  }) {
    return CalendarMonthlyRule(
      id: id,
      type: type,
      createdAt: createdAt,
      scheduleType: scheduleType ?? this.scheduleType,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      workdayOrdinal: workdayOrdinal ?? this.workdayOrdinal,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      customTitle: customTitle ?? this.customTitle,
      note: note ?? this.note,
    );
  }

  String get title => switch (type) {
    CalendarMonthlyRuleType.commercialPayment => '商贷扣款',
    CalendarMonthlyRuleType.providentFirstWorkday => '公积金扣款',
    CalendarMonthlyRuleType.note => customTitle ?? '每月备注',
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
    'scheduleType': scheduleType.name,
    'dayOfMonth': dayOfMonth,
    'workdayOrdinal': workdayOrdinal,
    'hour': hour,
    'minute': minute,
    'notificationsEnabled': notificationsEnabled,
    if (customTitle != null) 'customTitle': customTitle,
    'note': note,
  };
}

class CalendarData {
  const CalendarData({
    this.nodes = const <CalendarNode>[],
    this.monthlyRules = const <CalendarMonthlyRule>[],
    this.readReminderKeys = const <String>{},
    this.defaultReminderHour = 10,
    this.defaultReminderMinute = 0,
  });

  final List<CalendarNode> nodes;
  final List<CalendarMonthlyRule> monthlyRules;
  final Set<String> readReminderKeys;
  final int defaultReminderHour;
  final int defaultReminderMinute;

  factory CalendarData.fromJson(Map<dynamic, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((item) => parse(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    int value(String key, int fallback, int max) {
      final raw = json[key];
      final parsed = raw is num ? raw.toInt() : int.tryParse('$raw');
      return (parsed ?? fallback).clamp(0, max);
    }

    return CalendarData(
      nodes: parseList('nodes', CalendarNode.fromJson),
      monthlyRules: parseList('monthlyRules', CalendarMonthlyRule.fromJson),
      readReminderKeys:
          (json['readReminderKeys'] is List
                  ? (json['readReminderKeys'] as List).whereType<String>()
                  : const <String>[])
              .toSet(),
      defaultReminderHour: value('defaultReminderHour', 10, 23),
      defaultReminderMinute: value('defaultReminderMinute', 0, 59),
    );
  }

  CalendarData copyWith({
    List<CalendarNode>? nodes,
    List<CalendarMonthlyRule>? monthlyRules,
    Set<String>? readReminderKeys,
    int? defaultReminderHour,
    int? defaultReminderMinute,
  }) {
    return CalendarData(
      nodes: nodes ?? this.nodes,
      monthlyRules: monthlyRules ?? this.monthlyRules,
      readReminderKeys: readReminderKeys ?? this.readReminderKeys,
      defaultReminderHour: defaultReminderHour ?? this.defaultReminderHour,
      defaultReminderMinute:
          defaultReminderMinute ?? this.defaultReminderMinute,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
    'monthlyRules': monthlyRules
        .map((rule) => rule.toJson())
        .toList(growable: false),
    'readReminderKeys': readReminderKeys.toList(growable: false),
    'defaultReminderHour': defaultReminderHour,
    'defaultReminderMinute': defaultReminderMinute,
  };
}

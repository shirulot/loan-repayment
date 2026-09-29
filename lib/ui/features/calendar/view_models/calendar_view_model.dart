import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../data/services/calendar_cache_service.dart';
import '../../../../data/services/calendar_notification_service.dart';
import '../../../../data/services/chinese_holiday_calendar_update_service.dart';
import '../../../../domain/models/chinese_holiday_calendar_snapshot.dart';
import '../../../../domain/models/calendar_models.dart';
import '../../../../domain/models/loan_models.dart';
import '../../../../domain/services/calendar_monthly_rule_scheduler.dart';
import '../../../../domain/services/chinese_workday_calendar.dart';
import '../../loan/view_models/loan_planner_view_model.dart';

class CalendarDayOccurrence {
  const CalendarDayOccurrence({
    required this.key,
    required this.title,
    required this.dateTime,
    required this.isUnread,
    this.note = '',
    this.amount,
    this.paymentDetails,
    this.prepaymentDetails,
    this.node,
    this.rule,
  });

  final String key;
  final String title;
  final DateTime dateTime;
  final bool isUnread;
  final String note;
  final double? amount;
  final CalendarPaymentDetails? paymentDetails;
  final LoanPrepaymentDetail? prepaymentDetails;
  final CalendarNode? node;
  final CalendarMonthlyRule? rule;
}

class CalendarPaymentDetails {
  const CalendarPaymentDetails({
    required this.payment,
    required this.principal,
    required this.interest,
    required this.annualRate,
    required this.openingBalance,
    required this.closingBalance,
    required this.remainingTerms,
    required this.repaymentMethod,
  });

  final double payment;
  final double principal;
  final double interest;
  final double annualRate;
  final double openingBalance;
  final double closingBalance;
  final int remainingTerms;
  final LoanRepaymentMethod repaymentMethod;
}

class CalendarViewModel extends ChangeNotifier {
  // Keep public dependency names descriptive while keeping service fields private.
  CalendarViewModel({
    required CalendarData initialData,
    required LoanPlannerViewModel loanPlanner,
    required CalendarCacheService cacheService,
    required CalendarNotificationService notificationService,
    required ChineseHolidayCalendarUpdateService holidayUpdateService,
    required ChineseHolidayCalendarSnapshot holidaySnapshot,
    required ChineseWorkdayCalendar workdayCalendar,
    DateTime Function()? now,
  }) : _data = initialData,
       // ignore: prefer_initializing_formals
       _loanPlanner = loanPlanner,
       // ignore: prefer_initializing_formals
       _cacheService = cacheService,
       // ignore: prefer_initializing_formals
       _notificationService = notificationService,
       // ignore: prefer_initializing_formals
       _holidayUpdateService = holidayUpdateService,
       // ignore: prefer_initializing_formals
       _holidaySnapshot = holidaySnapshot,
       // ignore: prefer_initializing_formals
       _workdayCalendar = workdayCalendar,
       _now = now ?? DateTime.now {
    _loanPlanner.addListener(_syncPrepaymentNodes);
    _syncPrepaymentNodes();
    _isInitializing = false;
    _refreshUnreadState();
    _queueNotificationRefresh();
  }

  static const _maxScheduledNotifications = 60;
  static const _notificationHorizonDays = 550;

  final LoanPlannerViewModel _loanPlanner;
  final CalendarCacheService _cacheService;
  final CalendarNotificationService _notificationService;
  final ChineseHolidayCalendarUpdateService _holidayUpdateService;
  final ChineseWorkdayCalendar _workdayCalendar;
  final DateTime Function() _now;
  CalendarData _data;
  ChineseHolidayCalendarSnapshot _holidaySnapshot;
  bool _isHolidayDataRefreshing = false;
  bool _isInitializing = true;
  final Set<String> _unreadReminderKeys = <String>{};
  Future<void> _pendingSave = Future<void>.value();
  Future<void> _pendingNotificationRefresh = Future<void>.value();
  Timer? _nextReminderTimer;
  DateTime? _pendingNotificationDate;

  CalendarData get data => _data;
  int get unreadCount => _unreadReminderKeys.length;
  bool get isHolidayDataRefreshing => _isHolidayDataRefreshing;
  DateTime? get holidayDataUpdatedAt => _holidaySnapshot.lastSuccessfulAt;
  TimeOfDayValue get defaultReminderTime =>
      TimeOfDayValue(_data.defaultReminderHour, _data.defaultReminderMinute);
  bool isWorkdayOn(DateTime date) => _workdayCalendar.isWorkday(date);
  String? holidayNameOn(DateTime date) => _workdayCalendar.holidayName(date);

  List<CalendarDayOccurrence> occurrencesOn(DateTime date) {
    final day = _dateOnly(date);
    final occurrences = <CalendarDayOccurrence>[];
    for (final node in _data.nodes) {
      if (!_isSameDay(node.dateTime, day)) continue;
      final key = _nodeReminderKey(node);
      occurrences.add(
        CalendarDayOccurrence(
          key: key,
          title: node.title,
          dateTime: node.dateTime,
          isUnread: _unreadReminderKeys.contains(key),
          note: node.note,
          amount: node.amount,
          prepaymentDetails: _prepaymentDetailsForNode(node),
          node: node,
        ),
      );
    }
    for (final rule in _data.monthlyRules) {
      // A date near month-end can settle in the following month.
      for (var offset = -2; offset <= 0; offset++) {
        final anchor = DateTime(day.year, day.month + offset, 1);
        final occurrence = _ruleOccurrence(rule, anchor.year, anchor.month);
        if (occurrence.isBefore(rule.createdAt) ||
            !_isSameDay(occurrence, day)) {
          continue;
        }
        final key = _ruleReminderKey(rule, occurrence);
        final details = _monthlyPaymentDetails(rule, anchor);
        occurrences.add(
          CalendarDayOccurrence(
            key: key,
            title: rule.title,
            dateTime: occurrence,
            isUnread: _unreadReminderKeys.contains(key),
            note:
                rule.type == CalendarMonthlyRuleType.note &&
                    rule.note.trim().isNotEmpty
                ? rule.note
                : _ruleScheduleDescription(rule),
            amount: details?.payment,
            paymentDetails: details,
            rule: rule,
          ),
        );
      }
    }
    occurrences.sort((left, right) => left.dateTime.compareTo(right.dateTime));
    return List.unmodifiable(occurrences);
  }

  bool hasOccurrencesOn(DateTime date) => occurrencesOn(date).isNotEmpty;

  bool hasUnreadOn(DateTime date) =>
      occurrencesOn(date).any((occurrence) => occurrence.isUnread);

  void addNote(CalendarNode node) {
    final readKeys = Set<String>.from(_data.readReminderKeys);
    if (!node.dateTime.isAfter(_now())) readKeys.add(_nodeReminderKey(node));
    _data = _data.copyWith(
      nodes: <CalendarNode>[..._data.nodes, node],
      readReminderKeys: readKeys,
    );
    _afterDataChanged();
    if (node.notificationsEnabled && node.dateTime.isAfter(_now())) {
      unawaited(_notificationService.requestPermission());
    }
  }

  void updateNode(CalendarNode updatedNode) {
    final index = _data.nodes.indexWhere((node) => node.id == updatedNode.id);
    if (index < 0) return;
    final nodes = List<CalendarNode>.from(_data.nodes);
    final original = nodes[index];
    nodes[index] = updatedNode;
    final readKeys = Set<String>.from(_data.readReminderKeys);
    if (!_isSameDay(original.dateTime, updatedNode.dateTime) ||
        original.dateTime.hour != updatedNode.dateTime.hour ||
        original.dateTime.minute != updatedNode.dateTime.minute) {
      readKeys.remove(_nodeReminderKey(original));
      if (!updatedNode.dateTime.isAfter(_now())) {
        readKeys.add(_nodeReminderKey(updatedNode));
      }
    }
    _data = _data.copyWith(nodes: nodes, readReminderKeys: readKeys);
    _afterDataChanged();
    if (updatedNode.notificationsEnabled &&
        updatedNode.dateTime.isAfter(_now())) {
      unawaited(_notificationService.requestPermission());
    }
  }

  void deleteNode(String id) {
    CalendarNode? node;
    for (final item in _data.nodes) {
      if (item.id == id) {
        node = item;
        break;
      }
    }
    if (node == null || node.source == CalendarNodeSource.prepayment) return;
    final nodes = _data.nodes.where((item) => item.id != id).toList();
    final readKeys = Set<String>.from(_data.readReminderKeys)
      ..remove(_nodeReminderKey(node));
    _data = _data.copyWith(nodes: nodes, readReminderKeys: readKeys);
    _afterDataChanged();
  }

  void removeLinkedPrepayment(String prepaymentId) {
    final removed = _data.nodes
        .where((node) => node.prepaymentId == prepaymentId)
        .toList(growable: false);
    final nodes = _data.nodes
        .where((node) => node.prepaymentId != prepaymentId)
        .toList(growable: false);
    if (nodes.length == _data.nodes.length) return;
    final readKeys = Set<String>.from(_data.readReminderKeys)
      ..removeAll(removed.map(_nodeReminderKey));
    _data = _data.copyWith(nodes: nodes, readReminderKeys: readKeys);
    _afterDataChanged();
  }

  void saveMonthlyRule(CalendarMonthlyRule rule) {
    final rules = _data.monthlyRules
        .where(
          (item) =>
              rule.type == CalendarMonthlyRuleType.note ||
              item.type != rule.type ||
              item.id == rule.id,
        )
        .toList();
    final existingIndex = rules.indexWhere((item) => item.id == rule.id);
    if (existingIndex < 0) {
      rules.add(rule);
    } else {
      rules[existingIndex] = rule;
    }
    _data = _data.copyWith(monthlyRules: rules);
    _afterDataChanged();
    if (rule.notificationsEnabled) {
      unawaited(_notificationService.requestPermission());
    }
  }

  void deleteMonthlyRule(String id) {
    final rules = _data.monthlyRules
        .where((item) => item.id != id)
        .toList(growable: false);
    if (rules.length == _data.monthlyRules.length) return;
    final readKeys = Set<String>.from(_data.readReminderKeys)
      ..removeWhere((key) => key.startsWith('rule:$id:'));
    _data = _data.copyWith(monthlyRules: rules, readReminderKeys: readKeys);
    _afterDataChanged();
  }

  void setDefaultReminderTime(TimeOfDayValue time) {
    _data = _data.copyWith(
      defaultReminderHour: time.hour,
      defaultReminderMinute: time.minute,
    );
    _afterDataChanged();
  }

  Future<bool> requestNotificationPermission() =>
      _notificationService.requestPermission();

  void markRead(String reminderKey) {
    if (!_unreadReminderKeys.contains(reminderKey)) return;
    final readKeys = Set<String>.from(_data.readReminderKeys)..add(reminderKey);
    _data = _data.copyWith(readReminderKeys: readKeys);
    _afterDataChanged();
  }

  void markAllRead() {
    if (_unreadReminderKeys.isEmpty) return;
    final readKeys = Set<String>.from(_data.readReminderKeys)
      ..addAll(_unreadReminderKeys);
    _data = _data.copyWith(readReminderKeys: readKeys);
    _afterDataChanged();
  }

  void handleNotificationTap(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final key = decoded['key']?.toString();
      final dateTime = DateTime.tryParse(decoded['dateTime']?.toString() ?? '');
      if (key == null || dateTime == null) return;
      _pendingNotificationDate = dateTime;
      final readKeys = Set<String>.from(_data.readReminderKeys)..add(key);
      _data = _data.copyWith(readReminderKeys: readKeys);
      _afterDataChanged();
    } on FormatException {
      return;
    }
  }

  DateTime? takePendingNotificationDate() {
    final date = _pendingNotificationDate;
    _pendingNotificationDate = null;
    return date;
  }

  void onAppResumed() {
    _refreshUnreadState();
    _queueNotificationRefresh();
    unawaited(refreshHolidayDataIfDue());
    notifyListeners();
  }

  Future<void> refreshHolidayDataIfDue() async {
    if (_isHolidayDataRefreshing) return;
    _isHolidayDataRefreshing = true;
    notifyListeners();
    try {
      final updated = await _holidayUpdateService.refreshIfDue(now: _now());
      final overridesChanged =
          !_sameOverrides(
            _holidaySnapshot.workdayOverrides,
            updated.workdayOverrides,
          ) ||
          !_sameNames(_holidaySnapshot.holidayNames, updated.holidayNames);
      _holidaySnapshot = updated;
      if (overridesChanged) {
        _workdayCalendar.updateData(
          updated.workdayOverrides,
          updated.holidayNames,
        );
        _refreshUnreadState();
        _queueNotificationRefresh();
      }
    } catch (_) {
      // A failed holiday sync leaves the cached and bundled calendars active.
    } finally {
      _isHolidayDataRefreshing = false;
      notifyListeners();
    }
  }

  void _syncPrepaymentNodes() {
    var changed = false;
    final nodes = List<CalendarNode>.from(_data.nodes);
    final readKeys = Set<String>.from(_data.readReminderKeys);
    for (final event in _loanPlanner.config.recentPrepayments) {
      final date = LoanPlanConfig.parseLoanStartDate(event.repaymentDate);
      final amount = event.actualPrepayment ?? event.amount;
      final index = nodes.indexWhere((node) => node.prepaymentId == event.id);
      final previous = index < 0 ? null : nodes[index];
      if (date == null || amount <= 0) {
        if (previous == null) continue;
        nodes.removeAt(index);
        readKeys.remove(_nodeReminderKey(previous));
        changed = true;
        continue;
      }
      final time =
          previous?.dateTime ??
          DateTime(
            date.year,
            date.month,
            date.day,
            _data.defaultReminderHour,
            _data.defaultReminderMinute,
          );
      final updated = CalendarNode(
        id: previous?.id ?? 'prepayment-${event.id}',
        title: '提前还款',
        dateTime: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
        note: '关联提前还款记录',
        notificationsEnabled: previous?.notificationsEnabled ?? true,
        source: CalendarNodeSource.prepayment,
        prepaymentId: event.id,
        amount: amount,
      );
      if (previous == null) {
        nodes.add(updated);
        changed = true;
        if (!updated.dateTime.isAfter(_now())) {
          // Imported history should not become a new unread reminder.
          readKeys.add(_nodeReminderKey(updated));
        } else if (!_isInitializing && updated.notificationsEnabled) {
          unawaited(_notificationService.requestPermission());
        }
      } else if (!_sameNode(previous, updated)) {
        nodes[index] = updated;
        if (!_isSameDay(previous.dateTime, updated.dateTime)) {
          readKeys.remove(_nodeReminderKey(previous));
        }
        changed = true;
      }
    }
    if (!changed) return;
    _data = _data.copyWith(nodes: nodes, readReminderKeys: readKeys);
    _afterDataChanged();
  }

  bool _sameNode(CalendarNode left, CalendarNode right) =>
      left.id == right.id &&
      left.title == right.title &&
      left.dateTime == right.dateTime &&
      left.note == right.note &&
      left.notificationsEnabled == right.notificationsEnabled &&
      left.source == right.source &&
      left.prepaymentId == right.prepaymentId &&
      left.amount == right.amount;

  void _afterDataChanged() {
    _refreshUnreadState();
    _persist();
    _queueNotificationRefresh();
    notifyListeners();
  }

  void _refreshUnreadState() {
    final now = _now();
    final unread = <String>{};
    for (final node in _data.nodes) {
      if (node.notificationsEnabled &&
          !node.dateTime.isAfter(now) &&
          !_data.readReminderKeys.contains(_nodeReminderKey(node))) {
        unread.add(_nodeReminderKey(node));
      }
    }
    for (final rule in _data.monthlyRules) {
      if (!rule.notificationsEnabled) continue;
      // Keep each elapsed monthly occurrence unread until that occurrence is opened.
      for (
        var month = DateTime(rule.createdAt.year, rule.createdAt.month, 1);
        !month.isAfter(now);
        month = DateTime(month.year, month.month + 1, 1)
      ) {
        final occurrence = _ruleOccurrence(rule, month.year, month.month);
        if (occurrence.isBefore(rule.createdAt) || occurrence.isAfter(now)) {
          continue;
        }
        final key = _ruleReminderKey(rule, occurrence);
        if (!_data.readReminderKeys.contains(key)) unread.add(key);
      }
    }
    _unreadReminderKeys
      ..clear()
      ..addAll(unread);
    _scheduleNextReminderRefresh(now);
  }

  void _scheduleNextReminderRefresh(DateTime now) {
    _nextReminderTimer?.cancel();
    DateTime? next;
    for (final node in _data.nodes) {
      if (!node.notificationsEnabled || !node.dateTime.isAfter(now)) continue;
      if (next == null || node.dateTime.isBefore(next)) next = node.dateTime;
    }
    for (final rule in _data.monthlyRules) {
      if (!rule.notificationsEnabled) continue;
      for (var offset = -2; offset < 14; offset++) {
        final month = DateTime(now.year, now.month + offset, 1);
        final occurrence = _ruleOccurrence(rule, month.year, month.month);
        if (occurrence.isBefore(rule.createdAt) || !occurrence.isAfter(now)) {
          continue;
        }
        if (next == null || occurrence.isBefore(next)) next = occurrence;
        break;
      }
    }
    if (next == null) return;
    final remaining = next.difference(now);
    final delay =
        (remaining > const Duration(days: 28)
            ? const Duration(days: 28)
            : remaining) +
        const Duration(milliseconds: 50);
    _nextReminderTimer = Timer(delay, () {
      _refreshUnreadState();
      _queueNotificationRefresh();
      notifyListeners();
    });
  }

  void _persist() {
    final data = _data;
    _pendingSave = _pendingSave.then((_) async {
      try {
        await _cacheService.save(data);
      } catch (_) {
        // A calendar cache failure must not block editing or loan calculations.
      }
    });
    unawaited(_pendingSave);
  }

  void _queueNotificationRefresh() {
    final now = _now();
    final reminders = _upcomingReminders(now);
    _pendingNotificationRefresh = _pendingNotificationRefresh.then((_) async {
      try {
        await _notificationService.reschedule(reminders);
      } catch (_) {
        // Notification access can be unavailable while the calendar remains usable.
      }
    });
    unawaited(_pendingNotificationRefresh);
  }

  List<CalendarReminderOccurrence> _upcomingReminders(DateTime now) {
    final end = now.add(const Duration(days: _notificationHorizonDays));
    final reminders = <CalendarReminderOccurrence>[];
    for (final node in _data.nodes) {
      if (!node.notificationsEnabled ||
          !node.dateTime.isAfter(now) ||
          node.dateTime.isAfter(end)) {
        continue;
      }
      final body = node.source == CalendarNodeSource.prepayment
          ? '提前还款 ¥${(node.amount ?? 0).toStringAsFixed(2)}'
          : node.note.trim();
      reminders.add(
        CalendarReminderOccurrence(
          key: _nodeReminderKey(node),
          title: node.title,
          body: body.isEmpty ? '日历提醒' : body,
          dateTime: node.dateTime,
        ),
      );
    }
    for (final rule in _data.monthlyRules) {
      if (!rule.notificationsEnabled) continue;
      for (var offset = -2; offset < 20; offset++) {
        final month = DateTime(now.year, now.month + offset, 1);
        final occurrence = _ruleOccurrence(rule, month.year, month.month);
        if (occurrence.isBefore(rule.createdAt) ||
            !occurrence.isAfter(now) ||
            occurrence.isAfter(end)) {
          continue;
        }
        final amount = _monthlyPaymentDetails(rule, month)?.payment;
        final body = rule.type == CalendarMonthlyRuleType.note
            ? (rule.note.trim().isEmpty ? '日历提醒' : rule.note.trim())
            : amount == null
            ? rule.title
            : '${rule.title} ¥${amount.toStringAsFixed(2)}';
        reminders.add(
          CalendarReminderOccurrence(
            key: _ruleReminderKey(rule, occurrence),
            title: rule.title,
            body: body,
            dateTime: occurrence,
          ),
        );
      }
    }
    reminders.sort((left, right) => left.dateTime.compareTo(right.dateTime));
    return reminders.take(_maxScheduledNotifications).toList(growable: false);
  }

  DateTime _ruleOccurrence(CalendarMonthlyRule rule, int year, int month) =>
      CalendarMonthlyRuleScheduler(
        _workdayCalendar,
      ).occurrenceForMonth(rule, year, month);

  String _ruleScheduleDescription(CalendarMonthlyRule rule) =>
      switch (rule.scheduleType) {
        CalendarMonthlyScheduleType.fixedDay => '每月${rule.dayOfMonth}日',
        CalendarMonthlyScheduleType.firstWorkdayAfterDay =>
          rule.dayOfMonth == 0 ? '每月第一个工作日' : '每月${rule.dayOfMonth}日后首个工作日',
        CalendarMonthlyScheduleType.nthWorkdayOfMonth =>
          '每月第${rule.workdayOrdinal}个工作日',
        CalendarMonthlyScheduleType.nthWorkdayAfterDay =>
          '每月${rule.dayOfMonth}日后第${rule.workdayOrdinal}个工作日',
      };

  CalendarPaymentDetails? _monthlyPaymentDetails(
    CalendarMonthlyRule rule,
    DateTime anchor,
  ) {
    final month = '${anchor.year}-${anchor.month.toString().padLeft(2, '0')}';
    for (final row in _loanPlanner.rows) {
      if (row.month != month) continue;
      final config = _loanPlanner.config;
      // In multi-prepayment months the first transaction owns the one applied
      // regular payment; the row's closing balances also include prepayments.
      final firstPrepayment = row.prepaymentDetails.length > 1
          ? row.prepaymentDetails.first
          : null;
      final commercialPrincipal =
          firstPrepayment?.hasNormalPaymentBefore == true
          ? firstPrepayment!.commercialPrincipalBefore
          : row.commercialPrincipal;
      final commercialInterest = firstPrepayment?.hasNormalPaymentBefore == true
          ? firstPrepayment!.commercialInterestBefore
          : row.commercialInterest;
      final providentPrincipal = firstPrepayment?.hasNormalPaymentBefore == true
          ? firstPrepayment!.providentPrincipalBefore
          : row.providentPrincipal;
      final providentInterest = firstPrepayment?.hasNormalPaymentBefore == true
          ? firstPrepayment!.providentInterestBefore
          : row.providentInterest;
      return switch (rule.type) {
        CalendarMonthlyRuleType.commercialPayment => CalendarPaymentDetails(
          payment: commercialPrincipal + commercialInterest,
          principal: commercialPrincipal,
          interest: commercialInterest,
          annualRate: config.commercialAnnualRate,
          openingBalance: row.commercialOpening,
          closingBalance: math.max(
            0,
            row.commercialOpening - commercialPrincipal,
          ),
          remainingTerms: row.remainingTerms,
          repaymentMethod: config.repaymentMethod,
        ),
        CalendarMonthlyRuleType.providentFirstWorkday => CalendarPaymentDetails(
          payment: providentPrincipal + providentInterest,
          principal: providentPrincipal,
          interest: providentInterest,
          annualRate: config.providentAnnualRate,
          openingBalance: row.providentOpening,
          closingBalance: math.max(
            0,
            row.providentOpening - providentPrincipal,
          ),
          remainingTerms: row.remainingTerms,
          repaymentMethod: config.repaymentMethod,
        ),
        CalendarMonthlyRuleType.note => null,
      };
    }
    return null;
  }

  LoanPrepaymentDetail? _prepaymentDetailsForNode(CalendarNode node) {
    final id = node.prepaymentId;
    if (id == null) return null;
    final month =
        '${node.dateTime.year}-${node.dateTime.month.toString().padLeft(2, '0')}';
    for (final row in _loanPlanner.rows) {
      if (row.month != month) continue;
      for (final detail in row.prepaymentDetails) {
        if (detail.eventId == id) return detail;
      }
    }
    return null;
  }

  String _nodeReminderKey(CalendarNode node) => 'node:${node.id}';

  String _ruleReminderKey(CalendarMonthlyRule rule, DateTime date) =>
      'rule:${rule.id}:${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  static bool _sameOverrides(Map<int, bool> left, Map<int, bool> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  static bool _sameNames(Map<int, String> left, Map<int, String> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _loanPlanner.removeListener(_syncPrepaymentNodes);
    _nextReminderTimer?.cancel();
    super.dispose();
  }
}

class TimeOfDayValue {
  const TimeOfDayValue(this.hour, this.minute);

  final int hour;
  final int minute;
}

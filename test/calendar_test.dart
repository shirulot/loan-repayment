import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:loan_repayment_manager/data/services/calendar_cache_service.dart';
import 'package:loan_repayment_manager/data/services/calendar_notification_service.dart';
import 'package:loan_repayment_manager/data/services/chinese_holiday_calendar_cache_service.dart';
import 'package:loan_repayment_manager/data/services/chinese_holiday_calendar_update_service.dart';
import 'package:loan_repayment_manager/domain/models/calendar_models.dart';
import 'package:loan_repayment_manager/domain/models/chinese_holiday_calendar_snapshot.dart';
import 'package:loan_repayment_manager/domain/models/loan_models.dart';
import 'package:loan_repayment_manager/domain/services/calendar_monthly_rule_scheduler.dart';
import 'package:loan_repayment_manager/domain/services/chinese_workday_calendar.dart';
import 'package:loan_repayment_manager/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:loan_repayment_manager/ui/features/calendar/views/calendar_month_grid.dart';
import 'package:loan_repayment_manager/ui/features/calendar/views/calendar_event_editor_sheet.dart';
import 'package:loan_repayment_manager/ui/features/calendar/views/calendar_monthly_rules_sheet.dart';
import 'package:loan_repayment_manager/ui/features/calendar/views/calendar_occurrence_detail_sheet.dart';
import 'package:loan_repayment_manager/ui/features/calendar/views/calendar_page.dart';
import 'package:loan_repayment_manager/ui/features/loan/view_models/loan_planner_view_model.dart';
import 'package:loan_repayment_manager/domain/services/loan_calculator.dart';

class _MemoryHolidayCache extends ChineseHolidayCalendarCacheService {
  _MemoryHolidayCache(this.snapshot);

  ChineseHolidayCalendarSnapshot snapshot;

  @override
  Future<ChineseHolidayCalendarSnapshot> load() async => snapshot;

  @override
  Future<void> save(ChineseHolidayCalendarSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}

class _MemoryCalendarCache extends CalendarCacheService {
  CalendarData? saved;

  @override
  Future<void> save(CalendarData data) async {
    saved = data;
  }
}

class _NoopNotifications extends CalendarNotificationService {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> reschedule(List<CalendarReminderOccurrence> reminders) async {}
}

void main() {
  test('applies downloaded workday overrides before bundled weekday rules', () {
    final overrides = <int, bool>{};
    for (var day = 1; day <= 7; day++) {
      overrides[20261000 + day] = false;
    }
    overrides[20261008] = true;
    final calendar = ChineseWorkdayCalendar(overrides: overrides);

    expect(calendar.firstWorkday(2026, 10), DateTime(2026, 10, 8));
    expect(calendar.isWorkday(DateTime(2026, 10, 4)), isFalse);
    expect(calendar.isWorkday(DateTime(2026, 10, 8)), isTrue);
  });

  test('old provident rules retain the first-workday schedule', () {
    final rule = CalendarMonthlyRule.fromJson(<String, dynamic>{
      'id': 'old-provident',
      'type': 'providentFirstWorkday',
      'createdAt': '2026-01-01T00:00:00',
      'dayOfMonth': 1,
    });

    expect(rule.scheduleType, CalendarMonthlyScheduleType.firstWorkdayAfterDay);
    expect(rule.dayOfMonth, 0);
    expect(CalendarMonthlyRule.fromJson(rule.toJson()).dayOfMonth, 0);
  });

  test('fixed day and first workday after a chosen day can cross months', () {
    final calendar = ChineseWorkdayCalendar(
      overrides: const <int, bool>{20260202: false, 20260203: true},
    );
    final scheduler = CalendarMonthlyRuleScheduler(calendar);
    final fixed = CalendarMonthlyRule(
      id: 'fixed',
      type: CalendarMonthlyRuleType.commercialPayment,
      createdAt: DateTime(2026, 1, 1),
      dayOfMonth: 31,
    );
    final workday = fixed.copyWith(
      scheduleType: CalendarMonthlyScheduleType.firstWorkdayAfterDay,
    );

    expect(
      scheduler.occurrenceForMonth(fixed, 2026, 2),
      DateTime(2026, 2, 28, 10),
    );
    expect(
      scheduler.occurrenceForMonth(workday, 2026, 1),
      DateTime(2026, 2, 3, 10),
    );
  });

  test('monthly note schedules honor adjusted workdays and cross months', () {
    final scheduler = CalendarMonthlyRuleScheduler(
      ChineseWorkdayCalendar(
        overrides: const <int, bool>{
          20261001: false,
          20261002: false,
          20261003: false,
          20261004: true,
          20261005: false,
          20261006: false,
          20261007: false,
          20261008: true,
          20261102: false,
          20261103: true,
        },
      ),
    );
    final note = CalendarMonthlyRule(
      id: 'note',
      type: CalendarMonthlyRuleType.note,
      createdAt: DateTime(2026, 9, 28),
      customTitle: '账单',
      scheduleType: CalendarMonthlyScheduleType.nthWorkdayOfMonth,
      workdayOrdinal: 2,
    );
    expect(
      scheduler.occurrenceForMonth(note, 2026, 10),
      DateTime(2026, 10, 8, 10),
    );
    final afterDay = note.copyWith(
      scheduleType: CalendarMonthlyScheduleType.nthWorkdayAfterDay,
      dayOfMonth: 31,
      workdayOrdinal: 2,
    );
    expect(
      scheduler.occurrenceForMonth(afterDay, 2026, 10),
      DateTime(2026, 11, 4, 10),
    );
    expect(CalendarMonthlyRule.fromJson(afterDay.toJson()).customTitle, '账单');
    expect(CalendarMonthlyRule.fromJson(afterDay.toJson()).workdayOrdinal, 2);
  });

  test(
    'multiple recurring notes coexist and deletion removes all occurrences',
    () {
      final loanPlanner = LoanPlannerViewModel();
      final calendarViewModel = CalendarViewModel(
        initialData: const CalendarData(),
        loanPlanner: loanPlanner,
        cacheService: _MemoryCalendarCache(),
        notificationService: _NoopNotifications(),
        holidayUpdateService: ChineseHolidayCalendarUpdateService(
          cacheService: _MemoryHolidayCache(
            const ChineseHolidayCalendarSnapshot(),
          ),
        ),
        holidaySnapshot: const ChineseHolidayCalendarSnapshot(),
        workdayCalendar: ChineseWorkdayCalendar(),
        now: () => DateTime(2026, 9, 28, 9),
      );
      final first = CalendarMonthlyRule(
        id: 'note-1',
        type: CalendarMonthlyRuleType.note,
        createdAt: DateTime(2026, 9, 28),
        dayOfMonth: 1,
        customTitle: '房租',
      );
      final second = CalendarMonthlyRule(
        id: 'note-2',
        type: CalendarMonthlyRuleType.note,
        createdAt: DateTime(2026, 9, 28),
        dayOfMonth: 1,
        customTitle: '对账',
      );
      calendarViewModel.saveMonthlyRule(first);
      calendarViewModel.saveMonthlyRule(second);
      expect(
        calendarViewModel
            .occurrencesOn(DateTime(2026, 10, 1))
            .map((e) => e.title),
        containsAll(<String>['房租', '对账']),
      );
      calendarViewModel.saveMonthlyRule(first.copyWith(customTitle: '新房租'));
      expect(
        calendarViewModel
            .occurrencesOn(DateTime(2026, 10, 1))
            .map((e) => e.title),
        containsAll(<String>['新房租', '对账']),
      );
      calendarViewModel.deleteMonthlyRule(first.id);
      expect(
        calendarViewModel
            .occurrencesOn(DateTime(2026, 10, 1))
            .map((e) => e.title),
        <String>['对账'],
      );
      calendarViewModel.dispose();
      loanPlanner.dispose();
    },
  );

  test('refreshes current and next year only once per month', () async {
    final cache = _MemoryHolidayCache(const ChineseHolidayCalendarSnapshot());
    final requests = <Uri>[];
    final service = ChineseHolidayCalendarUpdateService(
      cacheService: cache,
      get: (uri) async {
        requests.add(uri);
        final year = int.parse(
          uri.pathSegments.lastWhere((segment) => segment.isNotEmpty),
        );
        final body = year == 2026
            ? <String, Object?>{
                'code': 0,
                'holiday': <String, Object?>{
                  '01-01': <String, Object?>{
                    'date': '2026-01-01',
                    'holiday': true,
                    'name': '元旦',
                  },
                },
              }
            : <String, Object?>{'code': 0, 'holiday': <String, Object?>{}};
        return http.Response(
          jsonEncode(body),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      },
    );

    final first = await service.refreshIfDue(now: DateTime(2026, 6, 1));
    final second = await service.refreshIfDue(now: DateTime(2026, 6, 28));

    expect(requests, hasLength(2));
    expect(first.workdayOverrides, const <int, bool>{20260101: false});
    expect(first.holidayNames, const <int, String>{20260101: '元旦'});
    expect(first.lastAttemptedMonth, '2026-06');
    expect(first.lastSuccessfulAt, DateTime(2026, 6, 1));
    expect(second.workdayOverrides, first.workdayOverrides);
  });

  test(
    'keeps cached holiday overrides when the remote data is invalid',
    () async {
      final cache = _MemoryHolidayCache(
        const ChineseHolidayCalendarSnapshot(
          workdayOverrides: <int, bool>{20270101: false},
        ),
      );
      final service = ChineseHolidayCalendarUpdateService(
        cacheService: cache,
        get: (_) async => http.Response('{"code":0,"holiday":{}}', 200),
      );

      final updated = await service.refreshIfDue(now: DateTime(2026, 11, 1));

      expect(updated.workdayOverrides, const <int, bool>{20270101: false});
      expect(updated.lastSuccessfulAt, isNull);
      expect(updated.lastAttemptedMonth, '2026-11');
    },
  );

  test('creates and explicitly removes a node linked to prepayment', () async {
    const event = RecentPrepayment(
      id: 'prepayment-1',
      amount: 30000,
      repaymentDate: '2026-10-12',
    );
    final loanPlanner = LoanPlannerViewModel(
      initialConfig: const LoanPlanConfig(
        recentPrepayments: <RecentPrepayment>[event],
      ),
    );
    final holidayCache = _MemoryHolidayCache(
      const ChineseHolidayCalendarSnapshot(),
    );
    final calendarViewModel = CalendarViewModel(
      initialData: const CalendarData(),
      loanPlanner: loanPlanner,
      cacheService: _MemoryCalendarCache(),
      notificationService: _NoopNotifications(),
      holidayUpdateService: ChineseHolidayCalendarUpdateService(
        cacheService: holidayCache,
      ),
      holidaySnapshot: const ChineseHolidayCalendarSnapshot(),
      workdayCalendar: ChineseWorkdayCalendar(),
      now: () => DateTime(2026, 9, 28, 9),
    );

    final occurrence = calendarViewModel
        .occurrencesOn(DateTime(2026, 10, 12))
        .single;
    expect(occurrence.node?.prepaymentId, 'prepayment-1');
    expect(occurrence.amount, 30000);
    expect(occurrence.dateTime, DateTime(2026, 10, 12, 10));

    calendarViewModel.removeLinkedPrepayment('prepayment-1');
    expect(calendarViewModel.occurrencesOn(DateTime(2026, 10, 12)), isEmpty);

    calendarViewModel.dispose();
    loanPlanner.dispose();
  });

  test('imports past prepayments without creating unread reminders', () {
    final loanPlanner = LoanPlannerViewModel(
      initialConfig: const LoanPlanConfig(
        recentPrepayments: <RecentPrepayment>[
          RecentPrepayment(
            id: 'past-prepayment',
            amount: 10000,
            repaymentDate: '2026-08-12',
          ),
        ],
      ),
    );
    final calendarViewModel = CalendarViewModel(
      initialData: const CalendarData(),
      loanPlanner: loanPlanner,
      cacheService: _MemoryCalendarCache(),
      notificationService: _NoopNotifications(),
      holidayUpdateService: ChineseHolidayCalendarUpdateService(
        cacheService: _MemoryHolidayCache(
          const ChineseHolidayCalendarSnapshot(),
        ),
      ),
      holidaySnapshot: const ChineseHolidayCalendarSnapshot(),
      workdayCalendar: ChineseWorkdayCalendar(),
      now: () => DateTime(2026, 9, 28, 9),
    );

    expect(
      calendarViewModel.occurrencesOn(DateTime(2026, 8, 12)),
      hasLength(1),
    );
    expect(calendarViewModel.unreadCount, 0);

    calendarViewModel.dispose();
    loanPlanner.dispose();
  });

  test('builds monthly provident reminder on the first adjusted workday', () {
    final overrides = <int, bool>{};
    for (var day = 1; day <= 7; day++) {
      overrides[20261000 + day] = false;
    }
    overrides[20261008] = true;
    final loanPlanner = LoanPlannerViewModel();
    final holidayCache = _MemoryHolidayCache(
      const ChineseHolidayCalendarSnapshot(),
    );
    final calendarViewModel = CalendarViewModel(
      initialData: const CalendarData(),
      loanPlanner: loanPlanner,
      cacheService: _MemoryCalendarCache(),
      notificationService: _NoopNotifications(),
      holidayUpdateService: ChineseHolidayCalendarUpdateService(
        cacheService: holidayCache,
      ),
      holidaySnapshot: const ChineseHolidayCalendarSnapshot(),
      workdayCalendar: ChineseWorkdayCalendar(overrides: overrides),
      now: () => DateTime(2026, 9, 28, 9),
    );
    calendarViewModel.saveMonthlyRule(
      CalendarMonthlyRule(
        id: 'provident-rule',
        type: CalendarMonthlyRuleType.providentFirstWorkday,
        createdAt: DateTime(2026, 9, 28),
      ),
    );

    expect(
      calendarViewModel.occurrencesOn(DateTime(2026, 10, 8)).single.dateTime,
      DateTime(2026, 10, 8, 10),
    );

    calendarViewModel.dispose();
    loanPlanner.dispose();
  });

  test('monthly reminders stay unread until each occurrence is opened', () {
    var now = DateTime(2026, 3, 2, 11);
    final loanPlanner = LoanPlannerViewModel();
    final calendarViewModel = CalendarViewModel(
      initialData: CalendarData(
        monthlyRules: <CalendarMonthlyRule>[
          CalendarMonthlyRule(
            id: 'commercial-rule',
            type: CalendarMonthlyRuleType.commercialPayment,
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
      ),
      loanPlanner: loanPlanner,
      cacheService: _MemoryCalendarCache(),
      notificationService: _NoopNotifications(),
      holidayUpdateService: ChineseHolidayCalendarUpdateService(
        cacheService: _MemoryHolidayCache(
          const ChineseHolidayCalendarSnapshot(),
        ),
      ),
      holidaySnapshot: const ChineseHolidayCalendarSnapshot(),
      workdayCalendar: ChineseWorkdayCalendar(),
      now: () => now,
    );

    expect(calendarViewModel.unreadCount, 3);
    final january = calendarViewModel
        .occurrencesOn(DateTime(2026, 1, 1))
        .single;
    calendarViewModel.markRead(january.key);
    expect(calendarViewModel.unreadCount, 2);
    expect(
      calendarViewModel.occurrencesOn(DateTime(2026, 2, 1)).single.isUnread,
      isTrue,
    );

    now = DateTime(2026, 4, 1, 11);
    calendarViewModel.setDefaultReminderTime(const TimeOfDayValue(9, 30));
    expect(calendarViewModel.unreadCount, 3);

    calendarViewModel.dispose();
    loanPlanner.dispose();
  });

  test('cross-month payment detail uses the anchor month plan row', () {
    final loanPlanner = LoanPlannerViewModel(
      calculator: LoanCalculator(currentDate: DateTime(2026, 1, 15)),
      initialConfig: const LoanPlanConfig(
        commercialOpeningBalance: 120000,
        commercialAnnualRate: 0.036,
        remainingTerms: 120,
      ),
    );
    final january = loanPlanner.rows.firstWhere(
      (row) => row.month == '2026-01',
    );
    final calendarViewModel = CalendarViewModel(
      initialData: CalendarData(
        monthlyRules: <CalendarMonthlyRule>[
          CalendarMonthlyRule(
            id: 'after-month-end',
            type: CalendarMonthlyRuleType.commercialPayment,
            createdAt: DateTime(2026, 1, 1),
            scheduleType: CalendarMonthlyScheduleType.firstWorkdayAfterDay,
            dayOfMonth: 31,
          ),
        ],
      ),
      loanPlanner: loanPlanner,
      cacheService: _MemoryCalendarCache(),
      notificationService: _NoopNotifications(),
      holidayUpdateService: ChineseHolidayCalendarUpdateService(
        cacheService: _MemoryHolidayCache(
          const ChineseHolidayCalendarSnapshot(),
        ),
      ),
      holidaySnapshot: const ChineseHolidayCalendarSnapshot(),
      workdayCalendar: ChineseWorkdayCalendar(
        overrides: const <int, bool>{20260202: true},
      ),
      now: () => DateTime(2026, 1, 15),
    );

    final occurrence = calendarViewModel
        .occurrencesOn(DateTime(2026, 2, 2))
        .single;
    expect(occurrence.paymentDetails?.payment, january.commercialPayment);
    expect(occurrence.paymentDetails?.principal, january.commercialPrincipal);
    expect(occurrence.paymentDetails?.interest, january.commercialInterest);
    expect(occurrence.paymentDetails?.annualRate, 0.036);

    calendarViewModel.dispose();
    loanPlanner.dispose();
  });

  testWidgets(
    'monthly balance excludes prepayment and its node opens details',
    (tester) async {
      final loanPlanner = LoanPlannerViewModel(
        calculator: LoanCalculator(currentDate: DateTime(2026, 1, 15)),
        initialConfig: const LoanPlanConfig(
          commercialOpeningBalance: 120000,
          commercialAnnualRate: 0.036,
          remainingTerms: 120,
          isPlanRepaymentMode: true,
          recentPrepayments: <RecentPrepayment>[
            RecentPrepayment(
              id: 'feb-prepayment',
              amount: 30000,
              repaymentDate: '2026-02-12',
            ),
          ],
        ),
      );
      final february = loanPlanner.rows.firstWhere(
        (row) => row.month == '2026-02',
      );
      final calendarViewModel = CalendarViewModel(
        initialData: CalendarData(
          monthlyRules: <CalendarMonthlyRule>[
            CalendarMonthlyRule(
              id: 'commercial-rule',
              type: CalendarMonthlyRuleType.commercialPayment,
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
        loanPlanner: loanPlanner,
        cacheService: _MemoryCalendarCache(),
        notificationService: _NoopNotifications(),
        holidayUpdateService: ChineseHolidayCalendarUpdateService(
          cacheService: _MemoryHolidayCache(
            const ChineseHolidayCalendarSnapshot(),
          ),
        ),
        holidaySnapshot: const ChineseHolidayCalendarSnapshot(),
        workdayCalendar: ChineseWorkdayCalendar(),
        now: () => DateTime(2026, 1, 15),
      );

      final monthly = calendarViewModel
          .occurrencesOn(DateTime(2026, 2, 1))
          .single;
      final prepayment = calendarViewModel
          .occurrencesOn(DateTime(2026, 2, 12))
          .single;
      expect(monthly.paymentDetails?.payment, february.commercialPayment);
      expect(
        monthly.paymentDetails?.closingBalance,
        closeTo(
          february.commercialOpening - february.commercialPrincipal,
          0.001,
        ),
      );
      expect(
        monthly.paymentDetails!.closingBalance,
        greaterThan(february.commercialClosing),
      );
      expect(prepayment.prepaymentDetails?.eventId, 'feb-prepayment');
      expect(prepayment.prepaymentDetails?.amount, 30000);
      expect(
        prepayment.prepaymentDetails?.commercialClosing,
        february.commercialClosing,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CalendarPage(
            viewModel: calendarViewModel,
            initialSelectedDate: DateTime(2026, 2, 12),
          ),
        ),
      );
      await tester.ensureVisible(find.text('提前还款'));
      await tester.tap(find.text('提前还款'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarOccurrenceDetailSheet), findsOneWidget);
      expect(find.text('本次提前还贷'), findsOneWidget);
      expect(find.text('交易后商贷余额'), findsOneWidget);
      await tester.ensureVisible(find.text('编辑提醒'));
      await tester.tap(find.text('编辑提醒'));
      await tester.pumpAndSettle();
      expect(find.text('提前还款提醒'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      calendarViewModel.dispose();
      loanPlanner.dispose();
    },
  );

  testWidgets('monthly rule editor allows choosing the day-after schedule', (
    tester,
  ) async {
    CalendarMonthlyRule? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showModalBottomSheet<CalendarMonthlyRule>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CalendarMonthlyRuleEditorSheet(
                    type: CalendarMonthlyRuleType.commercialPayment,
                    defaultReminderTime: const TimeOfDayValue(10, 0),
                  ),
                );
              },
              child: const Text('设置扣款日'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('设置扣款日'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('顺延工作日'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每月5日后').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      saved?.scheduleType,
      CalendarMonthlyScheduleType.firstWorkdayAfterDay,
    );
    expect(saved?.dayOfMonth, 5);
  });

  testWidgets('new note editor creates an nth-workday recurring rule', (
    tester,
  ) async {
    Object? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showModalBottomSheet<Object>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CalendarEventEditorSheet(
                    initialDate: DateTime(2026, 10, 1),
                    defaultReminderTime: const TimeOfDay(hour: 10, minute: 0),
                  ),
                );
              },
              child: const Text('新建备注'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('新建备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '缴费提醒');
    await tester.tap(find.text('仅此一次'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每月某日后第几个工作日').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-month-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每月5日').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-workday-ordinal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第2个工作日').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(saved, isA<CalendarMonthlyRule>());
    final rule = saved! as CalendarMonthlyRule;
    expect(rule.title, '缴费提醒');
    expect(rule.scheduleType, CalendarMonthlyScheduleType.nthWorkdayAfterDay);
    expect(rule.dayOfMonth, 5);
    expect(rule.workdayOrdinal, 2);
    expect(rule.hour, 10);
  });

  testWidgets('calendar shows rest, adjusted workday, and holiday name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarMonthGrid(
            month: DateTime(2026, 10),
            selectedDate: DateTime(2026, 10, 8),
            today: DateTime(2026, 9, 28),
            hasEvents: (_) => false,
            hasUnread: (_) => false,
            isWorkday: (date) => date.month == 10 && date.day == 1
                ? false
                : date.day == 10 || date.weekday < DateTime.saturday,
            holidayName: (date) =>
                date.month == 10 && date.day == 1 ? '国庆节' : null,
            onDateSelected: (_) {},
            onPreviousMonth: () {},
            onNextMonth: () {},
            onToday: () {},
          ),
        ),
      ),
    );

    expect(find.text('国庆节'), findsOneWidget);
    expect(find.text('休'), findsWidgets);
    expect(find.text('班'), findsWidgets);
    final festival = tester.widget<Text>(find.text('国庆节'));
    expect(
      festival.style?.color,
      Theme.of(tester.element(find.text('国庆节'))).colorScheme.error,
    );
  });

  testWidgets('app bar shows month only after month heading scrolls away', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final loanPlanner = LoanPlannerViewModel();
    final calendarViewModel = CalendarViewModel(
      initialData: const CalendarData(),
      loanPlanner: loanPlanner,
      cacheService: _MemoryCalendarCache(),
      notificationService: _NoopNotifications(),
      holidayUpdateService: ChineseHolidayCalendarUpdateService(
        cacheService: _MemoryHolidayCache(
          const ChineseHolidayCalendarSnapshot(),
        ),
      ),
      holidaySnapshot: const ChineseHolidayCalendarSnapshot(),
      workdayCalendar: ChineseWorkdayCalendar(),
      now: () => DateTime(2026, 10, 8),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage(
          viewModel: calendarViewModel,
          initialSelectedDate: DateTime(2026, 10, 8),
        ),
      ),
    );
    final appBar = find.byType(AppBar);
    final scrollView = find.byType(SingleChildScrollView).first;
    expect(
      find.descendant(of: appBar, matching: find.text('日历')),
      findsOneWidget,
    );

    await tester.drag(scrollView, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: appBar, matching: find.text('2026年10月')),
      findsOneWidget,
    );

    await tester.drag(scrollView, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: appBar, matching: find.text('日历')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    calendarViewModel.dispose();
    loanPlanner.dispose();
  });
}

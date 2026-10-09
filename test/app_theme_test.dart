import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_repayment_manager/data/services/app_appearance_settings_service.dart';
import 'package:loan_repayment_manager/data/services/calendar_cache_service.dart';
import 'package:loan_repayment_manager/data/services/calendar_notification_service.dart';
import 'package:loan_repayment_manager/data/services/chinese_holiday_calendar_cache_service.dart';
import 'package:loan_repayment_manager/data/services/chinese_holiday_calendar_update_service.dart';
import 'package:loan_repayment_manager/domain/models/calendar_models.dart';
import 'package:loan_repayment_manager/domain/models/chinese_holiday_calendar_snapshot.dart';
import 'package:loan_repayment_manager/domain/services/chinese_workday_calendar.dart';
import 'package:loan_repayment_manager/main.dart';
import 'package:loan_repayment_manager/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:loan_repayment_manager/ui/features/loan/view_models/loan_planner_view_model.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_page.dart';

class _MemoryCalendarCache extends CalendarCacheService {
  @override
  Future<void> save(CalendarData data) async {}
}

class _MemoryHolidayCache extends ChineseHolidayCalendarCacheService {
  @override
  Future<ChineseHolidayCalendarSnapshot> load() async =>
      const ChineseHolidayCalendarSnapshot();

  @override
  Future<void> save(ChineseHolidayCalendarSnapshot snapshot) async {}
}

class _NoopNotifications extends CalendarNotificationService {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> reschedule(List<CalendarReminderOccurrence> reminders) async {}
}

class _MemoryAppearanceSettings extends AppAppearanceSettingsService {
  final savedModes = <String>[];

  @override
  Future<void> saveThemeMode(String themeMode) async {
    savedModes.add(themeMode);
  }
}

void main() {
  testWidgets('app theme follows system brightness changes', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final loanPlanner = LoanPlannerViewModel();
    final holidayCache = _MemoryHolidayCache();
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

    await tester.pumpWidget(
      LoanRepaymentApp(
        viewModel: loanPlanner,
        calendarViewModel: calendarViewModel,
      ),
    );
    final page = find.byType(LoanPlanPage);
    expect(Theme.of(tester.element(page)).brightness, Brightness.light);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(page)).brightness, Brightness.dark);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('appearance choice applies immediately and persists', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 32);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 32);
    tester.view.systemGestureInsets = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetSystemGestureInsets);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final loanPlanner = LoanPlannerViewModel();
    final holidayCache = _MemoryHolidayCache();
    final appearanceSettings = _MemoryAppearanceSettings();
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

    await tester.pumpWidget(
      LoanRepaymentApp(
        viewModel: loanPlanner,
        calendarViewModel: calendarViewModel,
        appearanceSettingsService: appearanceSettings,
      ),
    );
    final page = find.byType(LoanPlanPage);
    expect(Theme.of(tester.element(page)).brightness, Brightness.light);
    expect(
      tester.getTopLeft(find.text('提前还贷计算器')).dy,
      greaterThanOrEqualTo(24),
    );
    expect(
      tester.getBottomRight(find.byIcon(Icons.home)).dy,
      lessThanOrEqualTo(812),
    );

    await tester.tap(find.byTooltip('外观设置'));
    await tester.pumpAndSettle();
    final modeTiles = find.byType(RadioListTile<ThemeMode>);
    expect(modeTiles, findsNWidgets(3));
    expect(tester.getBottomRight(modeTiles.last).dy, lessThanOrEqualTo(812));
    await tester.tap(find.text('黑夜模式'));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(page)).brightness, Brightness.dark);
    expect(_systemUiOverlay(tester).statusBarIconBrightness, Brightness.light);
    expect(_systemUiOverlay(tester).statusBarColor, Colors.transparent);
    expect(
      _systemUiOverlay(tester).systemNavigationBarColor,
      Colors.transparent,
    );
    expect(_systemUiOverlay(tester).systemStatusBarContrastEnforced, isFalse);
    expect(
      _systemUiOverlay(tester).systemNavigationBarContrastEnforced,
      isFalse,
    );
    expect(appearanceSettings.savedModes, ['dark']);

    await tester.tap(find.text('白天模式'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(page)).brightness, Brightness.light);
    expect(_systemUiOverlay(tester).statusBarIconBrightness, Brightness.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(page)).brightness, Brightness.light);

    await tester.tap(find.text('跟随系统'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(page)).brightness, Brightness.dark);
    expect(_systemUiOverlay(tester).statusBarIconBrightness, Brightness.light);
    expect(appearanceSettings.savedModes, ['dark', 'light', 'system']);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

SystemUiOverlayStyle _systemUiOverlay(WidgetTester tester) => tester
    .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byKey(const ValueKey('app-system-ui-overlay')),
    )
    .value;

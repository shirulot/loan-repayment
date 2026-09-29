import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'data/services/calendar_cache_service.dart';
import 'data/services/calendar_notification_service.dart';
import 'data/services/chinese_holiday_calendar_cache_service.dart';
import 'data/services/chinese_holiday_calendar_update_service.dart';
import 'domain/services/chinese_workday_calendar.dart';
import 'ui/features/calendar/view_models/calendar_view_model.dart';
import 'ui/features/loan/view_models/loan_planner_view_model.dart';
import 'ui/features/loan/views/loan_plan_page.dart';
import 'ui/theme/loan_palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
  final viewModel = LoanPlannerViewModel();
  // Restore the last editable state before showing the first frame.
  await viewModel.loadCachedState();

  const calendarCache = CalendarCacheService();
  const holidayCache = ChineseHolidayCalendarCacheService();
  final notificationService = CalendarNotificationService();
  final holidayUpdateService = ChineseHolidayCalendarUpdateService(
    cacheService: holidayCache,
  );
  final holidaySnapshot = await holidayUpdateService.load();
  final workdayCalendar = ChineseWorkdayCalendar(
    overrides: holidaySnapshot.workdayOverrides,
    holidayNames: holidaySnapshot.holidayNames,
  );
  final calendarData = await calendarCache.load();
  CalendarViewModel? calendarViewModel;
  String? pendingNotificationPayload;
  try {
    await notificationService.initialize(
      onNotificationTap: (payload) {
        final currentViewModel = calendarViewModel;
        if (currentViewModel == null) {
          pendingNotificationPayload = payload;
        } else {
          currentViewModel.handleNotificationTap(payload);
        }
      },
    );
  } catch (_) {
    // Keep the calendar available if a platform notification plugin fails.
  }
  calendarViewModel = CalendarViewModel(
    initialData: calendarData,
    loanPlanner: viewModel,
    cacheService: calendarCache,
    notificationService: notificationService,
    holidayUpdateService: holidayUpdateService,
    holidaySnapshot: holidaySnapshot,
    workdayCalendar: workdayCalendar,
  );
  String? launchPayload;
  try {
    launchPayload = await notificationService.getLaunchPayload();
  } catch (_) {
    // A platform-specific notification error must not prevent app startup.
  }
  final initialPayload = launchPayload ?? pendingNotificationPayload;
  if (initialPayload != null) {
    calendarViewModel.handleNotificationTap(initialPayload);
  }

  runApp(
    LoanRepaymentApp(
      viewModel: viewModel,
      calendarViewModel: calendarViewModel,
    ),
  );
  unawaited(calendarViewModel.refreshHolidayDataIfDue());
}

class LoanRepaymentApp extends StatefulWidget {
  const LoanRepaymentApp({
    super.key,
    required this.viewModel,
    required this.calendarViewModel,
  });

  final LoanPlannerViewModel viewModel;
  final CalendarViewModel calendarViewModel;

  @override
  State<LoanRepaymentApp> createState() => _LoanRepaymentAppState();
}

class _LoanRepaymentAppState extends State<LoanRepaymentApp> {
  Timer? _holidayRefreshTimer;

  @override
  void initState() {
    super.initState();
    _scheduleNextHolidayRefresh();
  }

  void _scheduleNextHolidayRefresh() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1, 0, 5);
    _holidayRefreshTimer = Timer(nextMonth.difference(now), () {
      // Foreground apps refresh at month start; resumed apps also check on entry.
      unawaited(widget.calendarViewModel.refreshHolidayDataIfDue());
      _scheduleNextHolidayRefresh();
    });
  }

  @override
  void dispose() {
    _holidayRefreshTimer?.cancel();
    widget.calendarViewModel.dispose();
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: LoanPalette.primary,
      brightness: Brightness.light,
      error: LoanPalette.repaymentAccent,
    );
    return MaterialApp(
      title: '提前还贷计算器',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: colorScheme.surfaceContainerLowest,
          foregroundColor: colorScheme.onSurface,
          titleTextStyle: const TextStyle(
            fontSize: 19,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ).copyWith(color: colorScheme.onSurface),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: colorScheme.outlineVariant,
          space: 1,
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            // Size.fromHeight uses an infinite width, which is invalid for
            // buttons laid out as non-flex children inside a Row.
            minimumSize: const Size(0, 50),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: LoanPlanPage(
        viewModel: widget.viewModel,
        calendarViewModel: widget.calendarViewModel,
      ),
    );
  }
}

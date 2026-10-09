import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'data/services/app_appearance_settings_service.dart';
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
  }
  const appearanceSettingsService = AppAppearanceSettingsService();
  final initialThemeMode = _themeModeFromName(
    await appearanceSettingsService.loadThemeMode(),
  );
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
      initialThemeMode: initialThemeMode,
      appearanceSettingsService: appearanceSettingsService,
    ),
  );
  unawaited(calendarViewModel.refreshHolidayDataIfDue());
}

ThemeMode _themeModeFromName(String? name) => switch (name) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

class LoanRepaymentApp extends StatefulWidget {
  const LoanRepaymentApp({
    super.key,
    required this.viewModel,
    required this.calendarViewModel,
    this.initialThemeMode = ThemeMode.system,
    this.appearanceSettingsService = const AppAppearanceSettingsService(),
  });

  final LoanPlannerViewModel viewModel;
  final CalendarViewModel calendarViewModel;
  final ThemeMode initialThemeMode;
  final AppAppearanceSettingsService appearanceSettingsService;

  @override
  State<LoanRepaymentApp> createState() => _LoanRepaymentAppState();
}

class _LoanRepaymentAppState extends State<LoanRepaymentApp> {
  Timer? _holidayRefreshTimer;
  late ThemeMode _themeMode = widget.initialThemeMode;
  Future<void> _themeModeWriteQueue = Future<void>.value();

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

  void _updateThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    setState(() => _themeMode = mode);

    // Apply immediately while keeping rapid preference changes in write order.
    _themeModeWriteQueue = _themeModeWriteQueue
        .then((_) => widget.appearanceSettingsService.saveThemeMode(mode.name))
        .catchError((Object error) {
          debugPrint('Unable to save appearance preference: $error');
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
      theme: _buildLoanTheme(Brightness.light),
      darkTheme: _buildLoanTheme(Brightness.dark),
      themeMode: _themeMode,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        key: const ValueKey('app-system-ui-overlay'),
        value: _systemUiOverlayStyle(
          _resolvedBrightness(
            _themeMode,
            MediaQuery.platformBrightnessOf(context),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: LoanPlanPage(
        viewModel: widget.viewModel,
        calendarViewModel: widget.calendarViewModel,
        themeMode: _themeMode,
        onThemeModeChanged: _updateThemeMode,
      ),
    );
  }
}

Brightness _resolvedBrightness(ThemeMode mode, Brightness platformBrightness) =>
    switch (mode) {
      ThemeMode.system => platformBrightness,
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };

ThemeData _buildLoanTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: LoanPalette.primary,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colorScheme.surfaceContainerLowest,
      foregroundColor: colorScheme.onSurface,
      systemOverlayStyle: _systemUiOverlayStyle(brightness),
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
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

SystemUiOverlayStyle _systemUiOverlayStyle(Brightness brightness) {
  final iconBrightness = brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: brightness,
    statusBarIconBrightness: iconBrightness,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
    systemNavigationBarContrastEnforced: false,
  );
}

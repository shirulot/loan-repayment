import 'package:flutter/material.dart';

import '../../calendar/view_models/calendar_view_model.dart';
import '../../calendar/views/calendar_page.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_workspace.dart';
import 'loan_plan_retained_tab.dart';
import 'loan_calculator_page.dart';
import 'loan_plan_mobile_layout.dart';
import 'loan_plan_mobile_navigation.dart';
import 'loan_month_detail_page.dart';
import '../../settings/views/app_appearance_settings_sheet.dart';

class LoanPlanPage extends StatefulWidget {
  const LoanPlanPage({
    super.key,
    required this.viewModel,
    this.calendarViewModel,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
  });

  final LoanPlannerViewModel viewModel;
  final CalendarViewModel? calendarViewModel;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<LoanPlanPage> createState() => _LoanPlanPageState();
}

class _LoanPlanPageState extends State<LoanPlanPage>
    with WidgetsBindingObserver {
  var _selectedTabIndex = 0;
  final _tabController = PageController();
  String? _pendingDetailMonth;
  DateTime? _calendarInitialDate;

  LoanPlannerViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.calendarViewModel?.addListener(_onCalendarChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final date = widget.calendarViewModel?.takePendingNotificationDate();
      if (date != null) _openCalendarAt(date);
    });
  }

  @override
  void didUpdateWidget(covariant LoanPlanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calendarViewModel != widget.calendarViewModel) {
      oldWidget.calendarViewModel?.removeListener(_onCalendarChanged);
      widget.calendarViewModel?.addListener(_onCalendarChanged);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.calendarViewModel?.onAppResumed();
    }
  }

  void _onCalendarChanged() {
    final date = widget.calendarViewModel?.takePendingNotificationDate();
    if (date != null) {
      _openCalendarAt(date);
    } else if (mounted) {
      setState(() {});
    }
  }

  void _openCalendarAt(DateTime date) {
    final calendarViewModel = widget.calendarViewModel;
    if (!mounted || calendarViewModel == null) return;
    // All window sizes share the same destinations and calendar selection.
    setState(() {
      _selectedTabIndex = 3;
      _calendarInitialDate = date;
    });
    _tabController.jumpToPage(3);
  }

  void _openAppearanceSettings() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AppAppearanceSettingsSheet(
        selectedMode: widget.themeMode,
        onChanged: (mode) => widget.onThemeModeChanged?.call(mode),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.calendarViewModel?.removeListener(_onCalendarChanged);
    super.dispose();
  }

  Future<void> _openDetails() async {
    await _openDetailsAtMonth();
  }

  Future<void> _openDetailsForMonth(String month) async {
    // Preview rows reserve the first tap for highlighting; a second tap opens
    // the dedicated monthly detail page without changing the plan tab.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LoanMonthDetailPage(viewModel: viewModel, initialMonth: month),
      ),
    );
  }

  Future<void> _openDetailsAtMonth([String? month]) async {
    setState(() {
      _selectedTabIndex = 1;
      _pendingDetailMonth = month;
    });
    _tabController.jumpToPage(1);
  }

  void _selectTab(int index) {
    setState(() {
      _selectedTabIndex = index;
      _pendingDetailMonth = null;
    });
    _tabController.jumpToPage(index);
  }

  void _showMobileInfo() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('使用说明', style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('填写现金流和贷款参数后，计划会按实际还款记录自动滚动修正。'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          bottomNavigationBar: LoanPlanMobileNavigationBar(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: _selectTab,
            calendarUnreadCount: widget.calendarViewModel?.unreadCount,
          ),
          body: SafeArea(
            // 隐藏页保留状态但退出布局，避免键盘变化反复布局整张还款表。
            child: PageView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MobileLoanPlanLayout(
                  viewModel: viewModel,
                  config: viewModel.config,
                  onViewDetails: _openDetails,
                  onViewMonth: _openDetailsForMonth,
                  onShowInfo: _showMobileInfo,
                  onOpenAppearance: _openAppearanceSettings,
                  onPrepaymentDeleted:
                      widget.calendarViewModel?.removeLinkedPrepayment,
                ),
                LoanPlanWorkspace(
                  viewModel: viewModel,
                  initialMonth: _pendingDetailMonth,
                  active: _selectedTabIndex == 1,
                  onPrepaymentDeleted:
                      widget.calendarViewModel?.removeLinkedPrepayment,
                ),
                LoanCalculatorPage(viewModel: viewModel),
                if (widget.calendarViewModel != null)
                  CalendarPage(
                    viewModel: widget.calendarViewModel!,
                    initialSelectedDate: _calendarInitialDate,
                  ),
              ].map((page) => LoanPlanRetainedTab(child: page)).toList(),
            ),
          ),
        );
      },
    );
  }
}

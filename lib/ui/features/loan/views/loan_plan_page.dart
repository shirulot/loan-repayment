import 'package:flutter/material.dart';

import '../../calendar/view_models/calendar_view_model.dart';
import '../../calendar/views/calendar_page.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_detail_page.dart';
import 'loan_calculator_page.dart';
import 'loan_plan_card.dart';
import 'loan_plan_frequency_selector.dart';
import 'loan_plan_intro_banner.dart';
import 'loan_plan_mobile_layout.dart';
import 'loan_plan_mobile_navigation.dart';
import 'loan_plan_parameter_card.dart';
import 'loan_plan_summary_strip.dart';
import 'loan_month_detail_page.dart';
import 'loan_repayment_method_selector.dart';

class LoanPlanPage extends StatefulWidget {
  const LoanPlanPage({
    super.key,
    required this.viewModel,
    this.calendarViewModel,
  });

  final LoanPlannerViewModel viewModel;
  final CalendarViewModel? calendarViewModel;

  @override
  State<LoanPlanPage> createState() => _LoanPlanPageState();
}

class _LoanPlanPageState extends State<LoanPlanPage>
    with WidgetsBindingObserver {
  var _mobileTabIndex = 0;
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
    if (MediaQuery.sizeOf(context).width < 640) {
      setState(() {
        _mobileTabIndex = 3;
        _calendarInitialDate = date;
      });
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CalendarPage(
          viewModel: calendarViewModel,
          initialSelectedDate: date,
        ),
      ),
    );
  }

  void _openCalendar() => _openCalendarAt(DateTime.now());

  @override
  void dispose() {
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
    if (MediaQuery.sizeOf(context).width < 640) {
      setState(() {
        _mobileTabIndex = 1;
        _pendingDetailMonth = month;
      });
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LoanPlanDetailPage(viewModel: viewModel, initialMonth: month),
      ),
    );
  }

  void _selectMobileTab(int index) {
    setState(() {
      _mobileTabIndex = index;
      _pendingDetailMonth = null;
    });
  }

  void _updatePrepaymentFrequency(int months) {
    viewModel.updateConfig(
      viewModel.config.copyWith(
        prepaymentFrequencyMonths: months,
        isPlanRepaymentMode: false,
      ),
    );
  }

  void _selectPlanRepaymentMode() {
    viewModel.updateConfig(
      viewModel.config.copyWith(isPlanRepaymentMode: true),
    );
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
        final isMobile = MediaQuery.sizeOf(context).width < 640;
        return Scaffold(
          appBar: isMobile
              ? null
              : AppBar(
                  titleSpacing: 20,
                  title: const Text('提前还贷计算器'),
                  actions: [
                    if (widget.calendarViewModel != null)
                      IconButton(
                        tooltip: '日历',
                        onPressed: _openCalendar,
                        icon: Badge(
                          isLabelVisible:
                              widget.calendarViewModel!.unreadCount > 0,
                          smallSize: 8,
                          child: const Icon(Icons.calendar_month_outlined),
                        ),
                      ),
                    IconButton(
                      tooltip: viewModel.amountsMasked ? '显示金额' : '隐藏金额',
                      onPressed: viewModel.toggleAmountsMasked,
                      icon: Icon(
                        viewModel.amountsMasked
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
          bottomNavigationBar: isMobile
              ? LoanPlanMobileNavigationBar(
                  selectedIndex: _mobileTabIndex,
                  onDestinationSelected: _selectMobileTab,
                  calendarUnreadCount: widget.calendarViewModel?.unreadCount,
                )
              : null,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 640) {
                  // Keep each tab mounted so stateful surfaces (especially the
                  // calculator's expression controller) survive tab changes.
                  return IndexedStack(
                    index: _mobileTabIndex,
                    alignment: Alignment.topCenter,
                    children: [
                      MobileLoanPlanLayout(
                        viewModel: viewModel,
                        config: viewModel.config,
                        onViewDetails: _openDetails,
                        onViewMonth: _openDetailsForMonth,
                        onShowInfo: _showMobileInfo,
                        onPrepaymentDeleted:
                            widget.calendarViewModel?.removeLinkedPrepayment,
                      ),
                      LoanPlanDetailPage(
                        viewModel: viewModel,
                        embedded: true,
                        initialMonth: _pendingDetailMonth,
                      ),
                      LoanCalculatorPage(viewModel: viewModel),
                      if (widget.calendarViewModel != null)
                        CalendarPage(
                          viewModel: widget.calendarViewModel!,
                          initialSelectedDate: _calendarInitialDate,
                        ),
                    ],
                  );
                }
                final isWide = constraints.maxWidth >= 1080;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LoanPlanFrequencySelector(
                            frequencyMonths:
                                viewModel.config.prepaymentFrequencyMonths,
                            isPlanRepaymentMode:
                                viewModel.config.isPlanRepaymentMode,
                            onChanged: _updatePrepaymentFrequency,
                            onSelectPlanRepayment: _selectPlanRepaymentMode,
                          ),
                          const SizedBox(height: 12),
                          LoanRepaymentMethodSelector(
                            method: viewModel.config.repaymentMethod,
                            onChanged: (method) {
                              viewModel.updateConfig(
                                viewModel.config.copyWith(
                                  repaymentMethod: method,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          LoanPlanIntroBanner(viewModel: viewModel),
                          const SizedBox(height: 16),
                          LoanPlanSummaryStrip(viewModel: viewModel),
                          const SizedBox(height: 20),
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 350,
                                  child: LoanPlanParameterCard(
                                    viewModel: viewModel,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: LoanPlanCard(
                                    onViewDetails: _openDetails,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            LoanPlanParameterCard(viewModel: viewModel),
                            const SizedBox(height: 20),
                            LoanPlanCard(onViewDetails: _openDetails),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

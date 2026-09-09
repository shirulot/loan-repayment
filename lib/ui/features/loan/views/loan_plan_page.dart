import 'package:flutter/material.dart';

import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_detail_page.dart';
import 'loan_calculator_page.dart';
import 'loan_plan_card.dart';
import 'loan_plan_intro_banner.dart';
import 'loan_plan_mobile_layout.dart';
import 'loan_plan_mobile_navigation.dart';
import 'loan_plan_parameter_card.dart';
import 'loan_plan_summary_strip.dart';
import 'loan_month_detail_page.dart';

class LoanPlanPage extends StatefulWidget {
  const LoanPlanPage({super.key, required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  State<LoanPlanPage> createState() => _LoanPlanPageState();
}

class _LoanPlanPageState extends State<LoanPlanPage> {
  var _mobileTabIndex = 0;
  String? _pendingDetailMonth;

  LoanPlannerViewModel get viewModel => widget.viewModel;

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
                      ),
                      LoanPlanDetailPage(
                        viewModel: viewModel,
                        embedded: true,
                        initialMonth: _pendingDetailMonth,
                      ),
                      LoanCalculatorPage(viewModel: viewModel),
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

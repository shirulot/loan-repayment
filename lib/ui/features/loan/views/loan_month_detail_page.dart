import 'package:flutter/material.dart';

import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_month_detail_content.dart';

/// Shows one month's complete repayment data as vertically scrollable cards.
///
/// Pages keep the calculator's chronological order so the standard PageView
/// gesture moves left to the next month and right to the previous month.
class LoanMonthDetailPage extends StatefulWidget {
  const LoanMonthDetailPage({
    super.key,
    required this.viewModel,
    this.initialMonth,
  });

  final LoanPlannerViewModel viewModel;
  final String? initialMonth;

  @override
  State<LoanMonthDetailPage> createState() => _LoanMonthDetailPageState();
}

class _LoanMonthDetailPageState extends State<LoanMonthDetailPage> {
  late final PageController _pageController;
  late int _pageIndex;
  String? _currentMonth;

  @override
  void initState() {
    super.initState();
    final pages = _orderedRows();
    _currentMonth = widget.initialMonth;
    _pageIndex = _indexForMonth(pages, widget.initialMonth);
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<LoanPlanRow> _orderedRows() =>
      widget.viewModel.rows.toList(growable: false);

  int _indexForMonth(List<LoanPlanRow> rows, String? month) {
    if (rows.isEmpty || month == null) return 0;
    final index = rows.indexWhere((row) => row.month == month);
    return index < 0 ? 0 : index;
  }

  void _changePage(List<LoanPlanRow> pages, int index) {
    if (!mounted || index < 0 || index >= pages.length) return;
    setState(() {
      _pageIndex = index;
      _currentMonth = pages[index].month;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final pages = _orderedRows();
        if (pages.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('月详情')),
            body: const Center(child: Text('暂无还款计划数据。')),
          );
        }

        final currentIndex = _indexForMonth(
          pages,
          _currentMonth,
        ).clamp(0, pages.length - 1);
        final currentRow = pages[currentIndex];
        if (currentIndex != _pageIndex) {
          _pageIndex = currentIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_pageController.hasClients) return;
            final page = _pageController.page?.round();
            if (page != currentIndex) {
              _pageController.jumpToPage(currentIndex);
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('还款详情 · ${currentRow.month}'),
            actions: [
              IconButton(
                tooltip: widget.viewModel.amountsMasked ? '显示金额' : '隐藏金额',
                onPressed: widget.viewModel.toggleAmountsMasked,
                icon: Icon(
                  widget.viewModel.amountsMasked
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '左滑查看下个月 · 右滑查看上个月',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${currentIndex + 1}/${pages.length}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (index) => _changePage(pages, index),
                    itemBuilder: (context, index) {
                      final row = pages[index];
                      // The calculator stores this reduction on the row that
                      // follows the repayment month. The detail card describes
                      // the current month's upcoming change, so read the next
                      // row; that value already includes all same-month
                      // prepayments through the cumulative closing balance.
                      final nextMonthBasePaymentReduction =
                          index + 1 < pages.length
                          ? pages[index + 1].nextMonthBasePaymentReduction
                          : null;
                      return LoanMonthDetailContent(
                        key: ValueKey<String>('month-detail-${row.month}'),
                        row: row,
                        amountsMasked: widget.viewModel.amountsMasked,
                        nextMonthBasePaymentReduction:
                            nextMonthBasePaymentReduction,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

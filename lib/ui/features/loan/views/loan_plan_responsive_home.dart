import 'package:flutter/material.dart';

import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';
import 'loan_plan_layout_style.dart';

/// A 方案：宽窗口并排显示参数和预览，两栏独立滚动，操作按钮保持可见。
class LoanResponsiveHome extends StatelessWidget {
  const LoanResponsiveHome({
    super.key,
    required this.header,
    required this.frequency,
    required this.method,
    required this.settings,
    required this.cashFlow,
    required this.preview,
    required this.applyButton,
    required this.viewModel,
  });

  final Widget header;
  final Widget frequency;
  final Widget method;
  final Widget settings;
  final Widget cashFlow;
  final Widget preview;
  final Widget applyButton;
  final LoanPlannerViewModel viewModel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // 横屏键盘或极矮窗口下，让按钮随内容滚动，避免挤压编辑区域。
      final short = constraints.maxHeight < 170;
      final previewFirst = constraints.maxHeight < 420;
      if (constraints.maxWidth < LoanPlanLayoutStyle.twoColumnMinWidth) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: LoanPlanLayoutStyle.maxCompactWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                header,
                const SizedBox(height: 8),
                frequency,
                const SizedBox(height: 12),
                method,
                const SizedBox(height: 12),
                cashFlow,
                const SizedBox(height: 16),
                settings,
                const SizedBox(height: 12),
                preview,
                const SizedBox(height: 18),
                applyButton,
              ],
            ),
          ),
        );
      }
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: LoanPlanLayoutStyle.maxHomeWidth,
          ),
          child: Padding(
            key: const ValueKey('loan-home-two-column'),
            padding: LoanPlanLayoutStyle.panelPadding,
            child: Column(
              children: [
                if (!short) header,
                if (!short) const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          children: [
                            if (short) header,
                            frequency,
                            const SizedBox(height: 12),
                            method,
                            const SizedBox(height: 16),
                            settings,
                            const SizedBox(height: 12),
                            cashFlow,
                          ],
                        ),
                      ),
                      const SizedBox(width: LoanPlanLayoutStyle.gap),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView(
                                children: [
                                  // 矮横屏先看到三期预览，概况仍在同一栏内可滚动查看。
                                  if (previewFirst) preview,
                                  LoanWideOverview(viewModel: viewModel),
                                  const SizedBox(height: 12),
                                  if (!previewFirst) preview,
                                  if (short) const SizedBox(height: 12),
                                  if (short) applyButton,
                                ],
                              ),
                            ),
                            if (!short) const SizedBox(height: 12),
                            if (!short) applyButton,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 复用原有字段编辑和校验，只改变 C 方案参数区的滚动与操作按钮位置。
class LoanParameterEditorLayout extends StatelessWidget {
  const LoanParameterEditorLayout({
    super.key,
    required this.frequency,
    required this.method,
    required this.settings,
    required this.applyButton,
  });
  final Widget frequency;
  final Widget method;
  final Widget settings;
  final Widget applyButton;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final short = constraints.maxHeight < 150;
      return Padding(
        padding: LoanPlanLayoutStyle.panelPadding,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  frequency,
                  const SizedBox(height: 12),
                  method,
                  const SizedBox(height: 16),
                  settings,
                  if (short) const SizedBox(height: 12),
                  if (short) applyButton,
                ],
              ),
            ),
            if (!short) const SizedBox(height: 12),
            if (!short) applyButton,
          ],
        ),
      );
    },
  );
}

/// 概况只读取共享 ViewModel，避免横屏产生另一套月供或还款金额算法。
class LoanWideOverview extends StatelessWidget {
  const LoanWideOverview({
    super.key,
    required this.viewModel,
    this.columns = 2,
  });
  final LoanPlannerViewModel viewModel;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final latest = viewModel.latestPrepaymentOnOrBeforeToday;
    String money(double value) =>
        '¥${formatLoanMoneyProtected(value, masked: viewModel.amountsMasked)}';
    final cards = [
      _LoanOverviewMetric(
        label: '剩余本金',
        value: money(
          viewModel.currentCommercialBalance +
              viewModel.currentProvidentBalance,
        ),
        detail: '商贷与公积金合计',
        icon: Icons.savings_outlined,
      ),
      _LoanOverviewMetric(
        label: '次月月供',
        value: money(viewModel.nextMonthlyPayment),
        detail: '沿用当前还款计划',
        icon: Icons.calendar_month_outlined,
      ),
      _LoanOverviewMetric(
        label: '最近一笔还款',
        value: latest == null
            ? '—'
            : money(latest.actualPrepayment ?? latest.amount),
        detail: latest?.repaymentDate ?? '暂无已到期记录',
        icon: Icons.payments_outlined,
      ),
      _LoanOverviewMetric(
        label: '剩余期数',
        value: '${viewModel.calculatedRemainingTerms} 期',
        detail: '按贷款期限计算',
        icon: Icons.timelapse_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: cards
            .map(
              (card) => SizedBox(
                width: (constraints.maxWidth - 8 * (columns - 1)) / columns,
                child: card,
              ),
            )
            .toList(),
      ),
    );
  }
}

/// 紧凑概况卡片使用缩放保护完整金额，适合手机横屏的较窄半栏。
class _LoanOverviewMetric extends StatelessWidget {
  const _LoanOverviewMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });
  final String label;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: text.titleLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

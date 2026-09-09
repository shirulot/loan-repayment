import 'package:flutter/material.dart';

import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';
import 'loan_plan_mobile_fields.dart';

/// Groups the mobile loan, rate, and recent-repayment editors.
class LoanMobileSettingsGroup extends StatelessWidget {
  const LoanMobileSettingsGroup({
    super.key,
    required this.config,
    required this.viewModel,
    required this.recentPrepayments,
    required this.expandedSections,
    required this.controllerFor,
    required this.focusNodeFor,
    required this.onPickRepaymentDate,
    required this.onRecentPrepaymentChanged,
    required this.onAddRecentPrepayment,
    required this.onRemoveRecentPrepayment,
    required this.onSectionExpansionChanged,
  });

  final LoanPlanConfig config;
  final LoanPlannerViewModel viewModel;
  final List<RecentPrepayment> recentPrepayments;
  final Set<String> expandedSections;
  final TextEditingController Function(String key) controllerFor;
  final FocusNode Function(String key) focusNodeFor;
  final ValueChanged<String> onPickRepaymentDate;
  final VoidCallback onRecentPrepaymentChanged;
  final VoidCallback onAddRecentPrepayment;
  final ValueChanged<int> onRemoveRecentPrepayment;
  final void Function(String title, bool expanded) onSectionExpansionChanged;

  String _money(double value) =>
      formatLoanMoneyProtected(value, masked: viewModel.amountsMasked);

  String _termSummary() {
    final terms = viewModel.calculatedRemainingTerms;
    return config.loanTermYears > 0
        ? '$terms 期（${config.loanTermYears} 年）'
        : '$terms 期';
  }

  String _currentLoanSummary() {
    final balance =
        viewModel.currentCommercialBalance + viewModel.currentProvidentBalance;
    return '¥${_money(balance)}';
  }

  String _expectedPrepaymentSummary() {
    final latest = viewModel.latestPrepaymentOnOrBeforeToday;
    if (latest == null) return '暂无到期还款';
    return '¥${_money(latest.actualPrepayment ?? latest.amount)}';
  }

  Widget _inputField(
    String label,
    String key, {
    required String suffix,
    bool integer = false,
    bool date = false,
    bool enabled = true,
  }) {
    return LoanMobileInputField(
      label: label,
      controller: controllerFor(key),
      focusNode: focusNodeFor(key),
      suffix: suffix,
      integer: integer,
      date: date,
      enabled: enabled,
      amountsMasked: viewModel.amountsMasked,
      onChanged: key.startsWith('recentPrepayment-')
          ? (_) => onRecentPrepaymentChanged()
          : null,
      onPickDate: date ? () => onPickRepaymentDate(key) : null,
    );
  }

  Widget _readonlyField(
    String label,
    String value, {
    required String suffix,
    bool highlight = false,
  }) {
    return LoanMobileReadonlyField(
      label: label,
      value: value,
      suffix: suffix,
      highlight: highlight,
      amountsMasked: viewModel.amountsMasked,
    );
  }

  Widget _subsectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _recentPrepaymentFields(int index) {
    final event = recentPrepayments[index];
    final isSettled = event.isSettled || event.actualPrepayment != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _inputField(
          '第 ${index + 1} 笔金额',
          'recentPrepayment-${event.id}-amount',
          suffix: '元',
          enabled: !isSettled,
        ),
        _inputField(
          '第 ${index + 1} 笔还款日期',
          'recentPrepayment-${event.id}-date',
          suffix: isSettled ? '已结清' : '预定日期',
          date: true,
          enabled: !isSettled,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: isSettled ? null : () => onRemoveRecentPrepayment(index),
            icon: const Icon(Icons.delete_outline, size: 17),
            label: const Text('删除此笔'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.48),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          LoanMobileCompactSection(
            title: '贷款期限',
            icon: Icons.calendar_month_outlined,
            summary: _termSummary(),
            expanded: expandedSections.contains('贷款期限'),
            onExpansionChanged: (expanded) =>
                onSectionExpansionChanged('贷款期限', expanded),
            children: [
              _inputField(
                '贷款开始日期',
                'loanStartDate',
                suffix: 'YYYY-MM',
                date: true,
              ),
              _inputField('贷款总年限', 'loanTermYears', suffix: '年', integer: true),
              _readonlyField(
                '剩余期数（自动）',
                '${viewModel.calculatedRemainingTerms}',
                suffix: '月',
              ),
            ],
          ),
          Divider(color: colors.outlineVariant.withValues(alpha: 0.48)),
          LoanMobileCompactSection(
            title: '本金与利率',
            icon: Icons.percent_outlined,
            summary: _currentLoanSummary(),
            expanded: expandedSections.contains('本金与利率'),
            onExpansionChanged: (expanded) =>
                onSectionExpansionChanged('本金与利率', expanded),
            children: [
              _subsectionLabel(context, '当前贷款余额'),
              _readonlyField(
                '当前商贷余额',
                _money(viewModel.currentCommercialBalance),
                suffix: '元',
              ),
              _readonlyField(
                '当前公积金余额',
                _money(viewModel.currentProvidentBalance),
                suffix: '元',
              ),
              _subsectionLabel(context, '初期贷款本金与利率'),
              _inputField('初期商贷本金', 'commercialOpeningBalance', suffix: '元'),
              _inputField('初期公积金本金', 'providentOpeningBalance', suffix: '元'),
              _inputField('商贷年利率', 'commercialAnnualRate', suffix: '%'),
              _inputField('公积金年利率', 'providentAnnualRate', suffix: '%'),
            ],
          ),
          Divider(color: colors.outlineVariant.withValues(alpha: 0.48)),
          LoanMobileCompactSection(
            title: '最近三笔提前还款',
            icon: Icons.track_changes_outlined,
            summary: _expectedPrepaymentSummary(),
            expanded: expandedSections.contains('最近三笔提前还款'),
            onExpansionChanged: (expanded) =>
                onSectionExpansionChanged('最近三笔提前还款', expanded),
            children: [
              ...List<Widget>.generate(
                recentPrepayments.length,
                _recentPrepaymentFields,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onAddRecentPrepayment,
                icon: const Icon(Icons.add_outlined, size: 18),
                label: const Text('添加一笔（保留最近三笔）'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Expandable settings section with a compact summary.
class LoanMobileCompactSection extends StatelessWidget {
  const LoanMobileCompactSection({
    super.key,
    required this.title,
    required this.icon,
    required this.summary,
    required this.expanded,
    required this.onExpansionChanged,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String summary;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExpansionTile(
      onExpansionChanged: onExpansionChanged,
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      visualDensity: const VisualDensity(vertical: -1),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      collapsedShape: const RoundedRectangleBorder(),
      leading: Icon(icon, size: 21, color: colors.primary),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w400),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Icon(
              Icons.expand_more,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      children: children,
    );
  }
}

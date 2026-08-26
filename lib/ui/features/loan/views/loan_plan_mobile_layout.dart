import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/loan_models.dart';
import '../../../theme/loan_palette.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';

/// Compact phone layout that keeps the repayment preview above the fold.
class MobileLoanPlanLayout extends StatefulWidget {
  const MobileLoanPlanLayout({
    super.key,
    required this.viewModel,
    required this.config,
    required this.onViewDetails,
    required this.onViewMonth,
    required this.onShowInfo,
  });

  final LoanPlannerViewModel viewModel;
  final LoanPlanConfig config;
  final VoidCallback onViewDetails;
  final ValueChanged<String> onViewMonth;
  final VoidCallback onShowInfo;

  @override
  State<MobileLoanPlanLayout> createState() => _MobileLoanPlanLayoutState();
}

class _MobileLoanPlanLayoutState extends State<MobileLoanPlanLayout> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _syncFromConfig();
  }

  @override
  void didUpdateWidget(covariant MobileLoanPlanLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) _syncFromConfig();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncFromConfig() {
    for (final entry in _values(widget.config).entries) {
      final controller = _controllers.putIfAbsent(
        entry.key,
        TextEditingController.new,
      );
      controller.text = entry.value;
    }
  }

  Map<String, String> _values(LoanPlanConfig config) {
    String editableNumber(double value) =>
        value == 0 ? '' : value.toStringAsFixed(2);
    return {
      'commercialOpeningBalance': editableNumber(
        config.commercialOpeningBalance,
      ),
      'providentOpeningBalance': editableNumber(config.providentOpeningBalance),
      'commercialAnnualRate': editableNumber(config.commercialAnnualRate * 100),
      'providentAnnualRate': editableNumber(config.providentAnnualRate * 100),
      'loanStartDate': config.loanStartDate,
      'loanTermYears': config.loanTermYears > 0
          ? '${config.loanTermYears}'
          : '',
      'monthlySalary': editableNumber(config.monthlySalary),
      'monthlyExtraIncome': editableNumber(config.monthlyExtraIncome),
      'monthlyLivingCost': editableNumber(config.monthlyLivingCost),
      'fixedAugustPrepayment': editableNumber(config.fixedAugustPrepayment),
      'fixedSeptemberPrepayment': editableNumber(
        config.fixedSeptemberPrepayment,
      ),
      'fixedOctoberPrepayment': editableNumber(config.fixedOctoberPrepayment),
      'fixedAugustPrepaymentDate': config.fixedAugustPrepaymentDate,
      'fixedSeptemberPrepaymentDate': config.fixedSeptemberPrepaymentDate,
      'fixedOctoberPrepaymentDate': config.fixedOctoberPrepaymentDate,
    };
  }

  double _number(String key, double fallback) =>
      double.tryParse(_controllers[key]?.text ?? '') ?? fallback;

  double _zeroIfBlank(String key) =>
      double.tryParse(_controllers[key]?.text ?? '') ?? 0;

  void _apply() {
    final old = widget.viewModel.config;
    final loanStartDate = _controllers['loanStartDate']?.text.trim() ?? '';
    final loanTermYears =
        int.tryParse(_controllers['loanTermYears']?.text ?? '') ?? 0;
    final hasStartDate = loanStartDate.isNotEmpty;
    final hasTermYears = loanTermYears > 0;
    if (hasStartDate != hasTermYears ||
        (hasStartDate &&
            LoanPlanConfig.parseLoanStartDate(loanStartDate) == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请同时填写有效的贷款开始日期和总年限。')));
      return;
    }
    if (!_hasValidRecentPrepaymentDates()) return;

    widget.viewModel.updateConfig(
      old.copyWith(
        commercialOpeningBalance: _number(
          'commercialOpeningBalance',
          old.commercialOpeningBalance,
        ),
        providentOpeningBalance: _number(
          'providentOpeningBalance',
          old.providentOpeningBalance,
        ),
        commercialAnnualRate:
            _number('commercialAnnualRate', old.commercialAnnualRate * 100) /
            100,
        providentAnnualRate:
            _number('providentAnnualRate', old.providentAnnualRate * 100) / 100,
        loanStartDate: loanStartDate,
        loanTermYears: loanTermYears,
        monthlySalary: _number('monthlySalary', old.monthlySalary),
        monthlyExtraIncome: _number(
          'monthlyExtraIncome',
          old.monthlyExtraIncome,
        ),
        monthlyLivingCost: _number('monthlyLivingCost', old.monthlyLivingCost),
        // Blank recent expected amounts intentionally fall back to cash flow.
        fixedAugustPrepayment: _zeroIfBlank('fixedAugustPrepayment'),
        fixedSeptemberPrepayment: _zeroIfBlank('fixedSeptemberPrepayment'),
        fixedOctoberPrepayment: _zeroIfBlank('fixedOctoberPrepayment'),
        fixedAugustPrepaymentDate:
            _controllers['fixedAugustPrepaymentDate']?.text.trim() ?? '',
        fixedSeptemberPrepaymentDate:
            _controllers['fixedSeptemberPrepaymentDate']?.text.trim() ?? '',
        fixedOctoberPrepaymentDate:
            _controllers['fixedOctoberPrepaymentDate']?.text.trim() ?? '',
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('参数已应用，计划已重算。')));
  }

  bool _hasValidRecentPrepaymentDates() {
    final dateKeys = [
      'fixedAugustPrepaymentDate',
      'fixedSeptemberPrepaymentDate',
      'fixedOctoberPrepaymentDate',
    ];
    for (var index = 0; index < dateKeys.length; index++) {
      final value = _controllers[dateKeys[index]]?.text.trim() ?? '';
      if (value.isEmpty) continue;
      final date = LoanPlanConfig.parseLoanStartDate(value);
      final expectedMonth = widget.viewModel.fixedPrepaymentMonths[index];
      final actualMonth = date == null
          ? ''
          : '${date.year}-${date.month.toString().padLeft(2, '0')}';
      if (actualMonth != expectedMonth) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请填写 ${_displayMonth(expectedMonth)} 内有效的还贷日期。'),
          ),
        );
        return false;
      }
    }
    return true;
  }

  void _saveCashFlow() {
    final old = widget.viewModel.config;
    widget.viewModel.updateConfig(
      old.copyWith(
        monthlySalary: _number('monthlySalary', old.monthlySalary),
        monthlyExtraIncome: _number(
          'monthlyExtraIncome',
          old.monthlyExtraIncome,
        ),
        monthlyLivingCost: _number('monthlyLivingCost', old.monthlyLivingCost),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _openCashFlowEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '编辑每月现金流',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _inputField('本月收入', 'monthlySalary', suffix: '元'),
                _inputField('额外收入', 'monthlyExtraIncome', suffix: '元'),
                _readonlyField(
                  '当月月供',
                  _money(widget.viewModel.currentMonthlyPayment),
                  suffix: '元',
                ),
                _inputField('每月生活费', 'monthlyLivingCost', suffix: '元'),
                _readonlyField(
                  '可供提前还贷额',
                  _money(widget.viewModel.currentAvailablePrepayment),
                  suffix: '元',
                  highlight: true,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saveCashFlow,
                  child: const Text('保存现金流'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.viewModel.rows;
    final mediaQuery = MediaQuery.of(context);
    // Keep compact financial rows legible when the system font scale is large.
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.1,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _pageHeader(context),
          const SizedBox(height: 8),
          _cashFlowSummary(context),
          const SizedBox(height: 16),
          _settingsGroup(context),
          const SizedBox(height: 12),
          _previewHeader(context),
          const SizedBox(height: 8),
          _upcomingPreview(context, rows.take(3).toList()),
          const SizedBox(height: 18),
          _gradientApplyButton(),
        ],
      ),
    );
  }

  Widget _gradientApplyButton() {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          gradient: LinearGradient(
            colors: [LoanPalette.primary, LoanPalette.primaryGradientEnd],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            onTap: _apply,
            child: const Center(
              child: Text(
                '应用并重算',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, color: colors.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            '提前还贷计算器',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: widget.viewModel.amountsMasked ? '显示金额' : '隐藏金额',
            onPressed: widget.viewModel.toggleAmountsMasked,
            icon: Icon(
              widget.viewModel.amountsMasked
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          IconButton(
            tooltip: '使用说明',
            onPressed: widget.onShowInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
    );
  }

  Widget _settingsGroup(BuildContext context) {
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
          _compactSection(
            context,
            title: '贷款期限',
            icon: Icons.calendar_month_outlined,
            summary: _termSummary(),
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
                '${widget.viewModel.calculatedRemainingTerms}',
                suffix: '月',
              ),
            ],
          ),
          Divider(color: colors.outlineVariant.withValues(alpha: 0.48)),
          _compactSection(
            context,
            title: '本金与利率',
            icon: Icons.percent_outlined,
            summary: _currentLoanSummary(),
            children: [
              _subsectionLabel(context, '当前贷款余额'),
              _readonlyField(
                '当前商贷余额',
                _money(_currentCommercialBalance()),
                suffix: '元',
              ),
              _readonlyField(
                '当前公积金余额',
                _money(_currentProvidentBalance()),
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
          _compactSection(
            context,
            title: '近期期望还款额',
            icon: Icons.track_changes_outlined,
            summary: _expectedPrepaymentSummary(),
            children: [
              _inputField(
                _displayMonth(widget.viewModel.fixedPrepaymentMonths[0]),
                'fixedAugustPrepayment',
                suffix: '元',
              ),
              _inputField(
                '${_displayMonth(widget.viewModel.fixedPrepaymentMonths[0])} 还贷日期',
                'fixedAugustPrepaymentDate',
                suffix: _repaymentStatus(
                  widget.viewModel.fixedPrepaymentMonths[0],
                ),
                date: true,
                enabled: !_isSettled(widget.viewModel.fixedPrepaymentMonths[0]),
              ),
              _inputField(
                _displayMonth(widget.viewModel.fixedPrepaymentMonths[1]),
                'fixedSeptemberPrepayment',
                suffix: '元',
              ),
              _inputField(
                '${_displayMonth(widget.viewModel.fixedPrepaymentMonths[1])} 还贷日期',
                'fixedSeptemberPrepaymentDate',
                suffix: _repaymentStatus(
                  widget.viewModel.fixedPrepaymentMonths[1],
                ),
                date: true,
                enabled: !_isSettled(widget.viewModel.fixedPrepaymentMonths[1]),
              ),
              _inputField(
                _displayMonth(widget.viewModel.fixedPrepaymentMonths[2]),
                'fixedOctoberPrepayment',
                suffix: '元',
              ),
              _inputField(
                '${_displayMonth(widget.viewModel.fixedPrepaymentMonths[2])} 还贷日期',
                'fixedOctoberPrepaymentDate',
                suffix: _repaymentStatus(
                  widget.viewModel.fixedPrepaymentMonths[2],
                ),
                date: true,
                enabled: !_isSettled(widget.viewModel.fixedPrepaymentMonths[2]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _termSummary() {
    final years = widget.config.loanTermYears;
    final terms = widget.viewModel.calculatedRemainingTerms;
    return years > 0 ? '$terms 期（$years 年）' : '$terms 期';
  }

  // Current balances come from the generated plan, while opening principal stays editable.
  double _currentCommercialBalance() {
    final rows = widget.viewModel.rows;
    return rows.isEmpty
        ? widget.config.commercialOpeningBalance
        : rows.first.commercialClosing;
  }

  double _currentProvidentBalance() {
    final rows = widget.viewModel.rows;
    return rows.isEmpty
        ? widget.config.providentOpeningBalance
        : rows.first.providentClosing;
  }

  String _currentLoanSummary() {
    return '¥${_money(_currentCommercialBalance() + _currentProvidentBalance())}';
  }

  String _expectedPrepaymentSummary() {
    final rows = widget.viewModel.rows;
    final requested = rows.isEmpty ? 0.0 : rows.first.expectedPrepayment;
    return requested > 0 ? '¥${_money(requested)}' : '留空自动计算';
  }

  /// 仅替换界面文本，保持控制器和计算使用原始金额。
  String _money(double value) =>
      formatLoanMoneyProtected(value, masked: widget.viewModel.amountsMasked);

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

  Widget _cashFlowSummary(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final config = widget.config;
    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openCashFlowEditor,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.48),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 3.25,
                  children: [
                    _cashMetric(
                      context,
                      '本月收入',
                      config.monthlySalary,
                      Icons.account_balance_wallet_outlined,
                    ),
                    _cashMetric(
                      context,
                      '额外收入',
                      config.monthlyExtraIncome,
                      Icons.card_giftcard_outlined,
                    ),
                    _cashMetric(
                      context,
                      '当月月供',
                      widget.viewModel.currentMonthlyPayment,
                      Icons.credit_card_outlined,
                      accent: true,
                    ),
                    _cashMetric(
                      context,
                      '每月生活费',
                      config.monthlyLivingCost,
                      Icons.coffee_outlined,
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.48),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.currency_yen_rounded,
                      color: colors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '可供提前还贷额',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '¥${_money(widget.viewModel.currentAvailablePrepayment)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        color: colors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cashMetric(
    BuildContext context,
    String label,
    double value,
    IconData icon, {
    bool accent = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: accent ? colors.error : colors.primary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '¥${_money(value)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String summary,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ExpansionTile(
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
          Icon(Icons.expand_more, size: 20, color: colors.onSurfaceVariant),
        ],
      ),
      children: children,
    );
  }

  Widget _previewHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '未来三个月还款预览',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400),
          ),
        ),
        TextButton.icon(
          onPressed: widget.onViewDetails,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: const Text('查看详情'),
        ),
      ],
    );
  }

  Widget _upcomingPreview(BuildContext context, List<LoanPlanRow> rows) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.48),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _previewRow(
            context,
            month: '月份',
            expected: '预计提前还款额',
            balance: '剩余本金',
            header: true,
          ),
          ...rows.map(
            (row) => _previewRow(
              context,
              month: _displayPreviewMonth(row.month),
              expected: '¥${_money(row.expectedPrepayment)}',
              balance: '¥${_money(row.totalBalance)}',
              onTap: () => widget.onViewMonth(row.month),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '以上为预测结果，实际以还款后银行数据为准。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(
    BuildContext context, {
    required String month,
    required String expected,
    required String balance,
    bool header = false,
    VoidCallback? onTap,
  }) {
    final style = TextStyle(
      fontSize: header ? 12 : 12,
      color: header
          ? Theme.of(context).colorScheme.onSurfaceVariant
          : Theme.of(context).colorScheme.onSurface,
      fontWeight: header ? FontWeight.w500 : FontWeight.w400,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: header ? 34 : 44,
          decoration: BoxDecoration(
            color: header
                ? Theme.of(context).colorScheme.surfaceContainerHigh
                : null,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.48),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(month, textAlign: TextAlign.center, style: style),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  expected,
                  textAlign: TextAlign.center,
                  style: header
                      ? style
                      : style.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        balance,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                    ),
                    if (!header) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    String key, {
    required String suffix,
    bool integer = false,
    bool date = false,
    bool enabled = true,
  }) {
    final fieldEnabled =
        enabled && !(suffix == '元' && widget.viewModel.amountsMasked);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: _controllers[key],
        enabled: fieldEnabled,
        readOnly: date,
        onTap: date && fieldEnabled ? () => _pickRepaymentDate(key) : null,
        obscureText: suffix == '元' && widget.viewModel.amountsMasked,
        obscuringCharacter: '*',
        keyboardType: date
            ? TextInputType.datetime
            : TextInputType.numberWithOptions(decimal: !integer),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(
              date
                  ? r'[0-9-]'
                  : integer
                  ? r'[0-9]'
                  : r'[0-9.]',
            ),
          ),
        ],
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.primary,
        ),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          hintText: date ? 'YYYY-MM-DD' : null,
          suffixIcon: date
              ? IconButton(
                  tooltip: '选择还贷日期',
                  onPressed: fieldEnabled
                      ? () => _pickRepaymentDate(key)
                      : null,
                  icon: const Icon(Icons.calendar_month_outlined),
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
        ),
      ),
    );
  }

  /// 已录入实际提前金额的月份不再允许改动其还贷日期。
  bool _isSettled(String month) =>
      widget.viewModel.actualPrepayments[month] != null;

  String _repaymentStatus(String month) => _isSettled(month) ? '已结清' : '预定日期';

  /// 仅允许在当前近三期对应月份内选择，避免日期与计划行错位。
  Future<void> _pickRepaymentDate(String key) async {
    final month = _expectedMonthForDateKey(key);
    if (month == null) return;
    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final monthNumber = int.parse(parts[1]);
    final firstDate = DateTime(year, monthNumber);
    final lastDate = DateTime(year, monthNumber + 1, 0);
    final parsed = LoanPlanConfig.parseLoanStartDate(
      _controllers[key]?.text ?? '',
    );
    final initialDate =
        parsed != null &&
            !parsed.isBefore(firstDate) &&
            !parsed.isAfter(lastDate)
        ? parsed
        : firstDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: '选择还贷日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected == null || !mounted) return;
    _controllers[key]?.text =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
  }

  String? _expectedMonthForDateKey(String key) {
    return switch (key) {
      'fixedAugustPrepaymentDate' => widget.viewModel.fixedPrepaymentMonths[0],
      'fixedSeptemberPrepaymentDate' =>
        widget.viewModel.fixedPrepaymentMonths[1],
      'fixedOctoberPrepaymentDate' => widget.viewModel.fixedPrepaymentMonths[2],
      _ => null,
    };
  }

  Widget _readonlyField(
    String label,
    String value, {
    required String suffix,
    bool highlight = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
          filled: highlight,
          fillColor: highlight ? colors.primaryContainer : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
        ),
        child: Text(
          suffix == '元' && widget.viewModel.amountsMasked ? '****' : value,
          style: TextStyle(
            fontSize: 14,
            color: highlight ? colors.primary : colors.onSurfaceVariant,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  String _displayMonth(String month) {
    final parts = month.split('-');
    return '${parts[0]}/${int.parse(parts[1])}';
  }

  String _displayPreviewMonth(String month) {
    final parts = month.split('-');
    return '${parts[0]}年${int.parse(parts[1])}月';
  }
}

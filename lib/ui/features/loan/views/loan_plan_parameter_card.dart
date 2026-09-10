import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/extensions/string_extensions.dart';
import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';

/// Desktop parameter editor for the loan model.
class LoanPlanParameterCard extends StatefulWidget {
  const LoanPlanParameterCard({super.key, required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  State<LoanPlanParameterCard> createState() => _LoanPlanParameterCardState();
}

class _LoanPlanParameterCardState extends State<LoanPlanParameterCard> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  // Keeps any future config synchronization from disturbing active edits.
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};

  @override
  void initState() {
    super.initState();
    syncFromConfig();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  FocusNode _focusNodeFor(String key) =>
      _focusNodes.putIfAbsent(key, FocusNode.new);

  void syncFromConfig() {
    final values = _values(widget.viewModel.config);
    for (final entry in values.entries) {
      final controller = _controllers.putIfAbsent(
        entry.key,
        TextEditingController.new,
      );
      if (_focusNodeFor(entry.key).hasFocus || controller.text == entry.value) {
        continue;
      }
      controller.value = TextEditingValue(
        text: entry.value,
        selection: TextSelection.collapsed(offset: entry.value.length),
      );
    }
    if (mounted) setState(() {});
  }

  Map<String, String> _values(LoanPlanConfig config) {
    String editableNumber(double value) => formatLoanEditableNumber(value);
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
      'monthlyOtherExpense': editableNumber(config.monthlyOtherExpense),
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

  void _apply() {
    double number(String key, double fallback) =>
        (_controllers[key]?.text ?? '').toDoubleOr(fallback);
    double zeroIfBlank(String key) =>
        (_controllers[key]?.text ?? '').toDoubleOr(0);
    final old = widget.viewModel.config;
    final loanStartDate = _controllers['loanStartDate']?.text.trim() ?? '';
    final loanTermYears = (_controllers['loanTermYears']?.text ?? '').toIntOr(
      0,
    );
    final hasStartDate = !loanStartDate.isBlank;
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
        commercialOpeningBalance: number(
          'commercialOpeningBalance',
          old.commercialOpeningBalance,
        ),
        providentOpeningBalance: number(
          'providentOpeningBalance',
          old.providentOpeningBalance,
        ),
        commercialAnnualRate:
            number('commercialAnnualRate', old.commercialAnnualRate * 100) /
            100,
        providentAnnualRate:
            number('providentAnnualRate', old.providentAnnualRate * 100) / 100,
        loanStartDate: loanStartDate,
        loanTermYears: loanTermYears,
        monthlySalary: number('monthlySalary', old.monthlySalary),
        monthlyExtraIncome: number(
          'monthlyExtraIncome',
          old.monthlyExtraIncome,
        ),
        monthlyLivingCost: number('monthlyLivingCost', old.monthlyLivingCost),
        monthlyOtherExpense: zeroIfBlank('monthlyOtherExpense'),
        // Blank recent expected amounts intentionally fall back to cash flow.
        fixedAugustPrepayment: zeroIfBlank('fixedAugustPrepayment'),
        fixedSeptemberPrepayment: zeroIfBlank('fixedSeptemberPrepayment'),
        fixedOctoberPrepayment: zeroIfBlank('fixedOctoberPrepayment'),
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
      if (value.isBlank) continue;
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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '模型参数',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              '填写贷款开始日期和总年限后，剩余期数会按当前月份自动计算；蓝色字段可编辑。近三个月优先使用期望还款额，留空或填 0 时按可供提前还贷额计算；未被最近还款覆盖的月份按首页选择的频率规划，间隔月份的可用金额累计到下一次。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 13),
            _sectionLabel(context, '贷款期限'),
            _field('贷款开始日期', 'loanStartDate', suffix: 'YYYY-MM', date: true),
            _field('贷款总年限', 'loanTermYears', suffix: '年', integer: true),
            _calculatedTextField(
              '剩余期数（自动）',
              '${widget.viewModel.calculatedRemainingTerms}',
              suffix: '月',
            ),
            const SizedBox(height: 8),
            _sectionLabel(context, '本金与利率'),
            _field('商贷期初本金', 'commercialOpeningBalance', suffix: '元'),
            _field('公积金期初本金', 'providentOpeningBalance', suffix: '元'),
            _field('商贷年利率', 'commercialAnnualRate', suffix: '%'),
            _field('公积金年利率', 'providentAnnualRate', suffix: '%'),
            const SizedBox(height: 8),
            _sectionLabel(context, '每月现金流'),
            _field('本月收入', 'monthlySalary', suffix: '元'),
            _field('额外收入', 'monthlyExtraIncome', suffix: '元'),
            _calculatedField(
              '当月月供',
              widget.viewModel.currentMonthlyPayment,
              suffix: '元',
            ),
            _field('每月生活费（仅记录）', 'monthlyLivingCost', suffix: '元'),
            _field('其他消费', 'monthlyOtherExpense', suffix: '元'),
            _calculatedField(
              '可供提前还贷额',
              widget.viewModel.currentAvailablePrepayment,
              suffix: '元',
            ),
            const SizedBox(height: 8),
            _sectionLabel(context, '近期期望还款额'),
            _field(
              _displayMonth(widget.viewModel.fixedPrepaymentMonths[0]),
              'fixedAugustPrepayment',
              suffix: '元',
            ),
            _field(
              '${_displayMonth(widget.viewModel.fixedPrepaymentMonths[0])} 还贷日期',
              'fixedAugustPrepaymentDate',
              suffix: _repaymentStatus(
                widget.viewModel.fixedPrepaymentMonths[0],
              ),
              date: true,
              enabled: !_isSettled(widget.viewModel.fixedPrepaymentMonths[0]),
            ),
            _field(
              _displayMonth(widget.viewModel.fixedPrepaymentMonths[1]),
              'fixedSeptemberPrepayment',
              suffix: '元',
            ),
            _field(
              '${_displayMonth(widget.viewModel.fixedPrepaymentMonths[1])} 还贷日期',
              'fixedSeptemberPrepaymentDate',
              suffix: _repaymentStatus(
                widget.viewModel.fixedPrepaymentMonths[1],
              ),
              date: true,
              enabled: !_isSettled(widget.viewModel.fixedPrepaymentMonths[1]),
            ),
            _field(
              _displayMonth(widget.viewModel.fixedPrepaymentMonths[2]),
              'fixedOctoberPrepayment',
              suffix: '元',
            ),
            _field(
              '${_displayMonth(widget.viewModel.fixedPrepaymentMonths[2])} 还贷日期',
              'fixedOctoberPrepaymentDate',
              suffix: _repaymentStatus(
                widget.viewModel.fixedPrepaymentMonths[2],
              ),
              date: true,
              enabled: !_isSettled(widget.viewModel.fixedPrepaymentMonths[2]),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('应用参数并重算'),
            ),
            const SizedBox(height: 8),
            Text(
              '导出文件会保存到应用的 Documents/loan-repayment-plans 目录。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
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
        focusNode: _focusNodeFor(key),
        enabled: fieldEnabled,
        readOnly: date,
        onTap: date && fieldEnabled ? () => _pickRepaymentDate(key) : null,
        obscureText: suffix == '元' && widget.viewModel.amountsMasked,
        obscuringCharacter: '*',
        style: const TextStyle(color: Color(0xff0b5cad)),
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
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          hintText: date ? '例如 2020-01 或 2020-01-15' : null,
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

  Widget _calculatedField(
    String label,
    double value, {
    required String suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
        ),
        child: Text(
          formatLoanMoneyProtected(
            value,
            masked: widget.viewModel.amountsMasked,
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _calculatedTextField(
    String label,
    String value, {
    required String suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
        ),
        child: Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _displayMonth(String month) {
    final parts = month.split('-');
    return '${parts[0]}/${int.parse(parts[1])}';
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

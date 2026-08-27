import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_detail_page.dart';
import 'loan_plan_formatters.dart';
import 'loan_plan_mobile_layout.dart';

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
    await _openDetailsAtMonth(month);
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
    if (index <= 1) {
      setState(() {
        _mobileTabIndex = index;
        _pendingDetailMonth = null;
      });
      return;
    }
    const labels = ['首页', '还款计划', '记录', '我的'];
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${labels[index]}将在后续版本开放。')));
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
              ? _MobileNavigationBar(
                  selectedIndex: _mobileTabIndex,
                  onDestinationSelected: _selectMobileTab,
                )
              : null,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 640) {
                  if (_mobileTabIndex == 1) {
                    return LoanPlanDetailPage(
                      viewModel: viewModel,
                      embedded: true,
                      initialMonth: _pendingDetailMonth,
                    );
                  }
                  return MobileLoanPlanLayout(
                    viewModel: viewModel,
                    config: viewModel.config,
                    onViewDetails: _openDetails,
                    onViewMonth: _openDetailsForMonth,
                    onShowInfo: _showMobileInfo,
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
                          _IntroBanner(viewModel: viewModel),
                          const SizedBox(height: 16),
                          _SummaryStrip(viewModel: viewModel),
                          const SizedBox(height: 20),
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 350,
                                  child: _ParameterCard(viewModel: viewModel),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _PlanCard(onViewDetails: _openDetails),
                                ),
                              ],
                            )
                          else ...[
                            _ParameterCard(viewModel: viewModel),
                            const SizedBox(height: 20),
                            _PlanCard(onViewDetails: _openDetails),
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

class _MobileNavigationBar extends StatelessWidget {
  const _MobileNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 70,
        backgroundColor: colors.surfaceContainerLowest,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          return Theme.of(context).textTheme.labelSmall!.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            label: '还款计划',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            label: '记录',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
    );
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner({required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final rows = viewModel.rows;
    final fixedMonths = viewModel.fixedPrepaymentMonths;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '按当前模型滚动预测，实际扣款一经录入，后续自动补正',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_displayMonth(fixedMonths[0])} 为余额校准月；当前月供含银行结转息，转息前月供单独展示。预计结清：${_finishMonth(rows)}。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _finishMonth(List<LoanPlanRow> rows) {
    return rows
        .firstWhere((row) => row.totalBalance < 0.01, orElse: () => rows.last)
        .month;
  }

  String _displayMonth(String month) {
    final parts = month.split('-');
    return '${parts[0]}/${int.parse(parts[1])}';
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final rows = viewModel.rows;
    final current = rows.first;
    final next = rows.length > 1 ? rows[1] : current;
    String amount(double value) =>
        formatLoanMoneyProtected(value, masked: viewModel.amountsMasked);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final cards = [
          _MetricCard(
            label: '当前总余额',
            value: amount(current.totalBalance),
            detail:
                '商贷 ${amount(current.commercialClosing)} · 公积金 ${amount(current.providentClosing)}',
            icon: Icons.savings_outlined,
          ),
          _MetricCard(
            label: '下月正常月供',
            value: amount(next.totalPayment),
            detail: '${next.month} · 商贷 ${amount(next.commercialPayment)}',
            icon: Icons.calendar_month_outlined,
          ),
          _MetricCard(
            label: '预期结清',
            value: viewModel.expectedFinishMonth,
            detail: '当前模型共 ${rows.length} 个月',
            icon: Icons.flag_outlined,
          ),
          _MetricCard(
            label: '已录入实际扣款',
            value: '${viewModel.actualOverrideCount} 笔',
            detail: '修改淡黄色单元格即可补正',
            icon: Icons.edit_note_outlined,
          ),
        ];
        if (wide) {
          return Row(
            children: cards
                .map(
                  (card) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: card,
                    ),
                  ),
                )
                .toList(),
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: constraints.maxWidth < 300
                      ? constraints.maxWidth
                      : 300,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: colors.secondaryContainer,
              child: Icon(icon, size: 20, color: colors.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParameterCard extends StatefulWidget {
  const _ParameterCard({required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  State<_ParameterCard> createState() => _ParameterCardState();
}

class _ParameterCardState extends State<_ParameterCard> {
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
        double.tryParse(_controllers[key]?.text ?? '') ?? fallback;
    double zeroIfBlank(String key) =>
        double.tryParse(_controllers[key]?.text ?? '') ?? 0;
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
              '填写贷款开始日期和总年限后，剩余期数会按当前月份自动计算；蓝色字段可编辑。近三个月优先使用期望还款额，留空或填 0 时按可供提前还贷额计算；第四个月起也按可供提前还贷额计算，月供下降时金额会自动递增。',
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.onViewDetails});

  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final description = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '还款计划',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '详细数据已单独整理为横屏表格；可在对应月份录入实际提前还款，后续计划会自动补正。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
            final action = FilledButton.icon(
              onPressed: onViewDetails,
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('查看详情'),
            );
            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  description,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: description),
                const SizedBox(width: 16),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

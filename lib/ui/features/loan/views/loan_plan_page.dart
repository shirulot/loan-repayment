import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_detail_page.dart';
import 'loan_plan_formatters.dart';

class LoanPlanPage extends StatefulWidget {
  const LoanPlanPage({super.key, required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  State<LoanPlanPage> createState() => _LoanPlanPageState();
}

class _LoanPlanPageState extends State<LoanPlanPage> {
  final _parameterKey = GlobalKey<_ParameterCardState>();

  LoanPlannerViewModel get viewModel => widget.viewModel;

  Future<void> _openDetails() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoanPlanDetailPage(viewModel: viewModel),
      ),
    );
  }

  void _reset() {
    viewModel.reset();
    _parameterKey.currentState?.syncFromConfig();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已恢复当前模型的默认参数。')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('提前还贷计算器'),
            actions: [
              IconButton(
                tooltip: '恢复默认参数',
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
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
                                  child: _ParameterCard(
                                    key: _parameterKey,
                                    viewModel: viewModel,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _PlanCard(onViewDetails: _openDetails),
                                ),
                              ],
                            )
                          else ...[
                            _ParameterCard(
                              key: _parameterKey,
                              viewModel: viewModel,
                            ),
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
                    '${_displayMonth(fixedMonths[0])} 为余额校准月；商贷 ${_displayMonth(fixedMonths[1])} 使用银行账单校准值。预计结清：${_finishMonth(rows)}。实际提前还款输入框以淡黄色标出。',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final cards = [
          _MetricCard(
            label: '当前总余额',
            value: formatLoanMoney(current.totalBalance),
            detail:
                '商贷 ${formatLoanMoney(current.commercialClosing)} · 公积金 ${formatLoanMoney(current.providentClosing)}',
            icon: Icons.savings_outlined,
          ),
          _MetricCard(
            label: '下月正常月供',
            value: formatLoanMoney(next.totalPayment),
            detail:
                '${next.month} · 商贷 ${formatLoanMoney(next.commercialPayment)}',
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
  const _ParameterCard({super.key, required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  State<_ParameterCard> createState() => _ParameterCardState();
}

class _ParameterCardState extends State<_ParameterCard> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

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
    super.dispose();
  }

  void syncFromConfig() {
    final values = _values(widget.viewModel.config);
    for (final entry in values.entries) {
      final controller = _controllers.putIfAbsent(
        entry.key,
        TextEditingController.new,
      );
      controller.text = entry.value;
    }
    if (mounted) setState(() {});
  }

  Map<String, String> _values(LoanPlanConfig config) {
    return {
      'commercialOpeningBalance': config.commercialOpeningBalance
          .toStringAsFixed(2),
      'providentOpeningBalance': config.providentOpeningBalance.toStringAsFixed(
        2,
      ),
      'commercialAnnualRate': (config.commercialAnnualRate * 100)
          .toStringAsFixed(2),
      'providentAnnualRate': (config.providentAnnualRate * 100).toStringAsFixed(
        2,
      ),
      'loanStartDate': config.loanStartDate,
      'loanTermYears': config.loanTermYears > 0
          ? '${config.loanTermYears}'
          : '',
      'monthlySalary': config.monthlySalary.toStringAsFixed(2),
      'recurringPrepaymentStart': config.recurringPrepaymentStart
          .toStringAsFixed(2),
      'monthlyLivingCost': config.monthlyLivingCost.toStringAsFixed(2),
      'fixedAugustPrepayment': config.fixedAugustPrepayment.toStringAsFixed(2),
      'fixedSeptemberPrepayment': config.fixedSeptemberPrepayment
          .toStringAsFixed(2),
      'fixedOctoberPrepayment': config.fixedOctoberPrepayment.toStringAsFixed(
        2,
      ),
    };
  }

  void _apply() {
    double number(String key, double fallback) =>
        double.tryParse(_controllers[key]?.text ?? '') ?? fallback;
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
        recurringPrepaymentStart: number(
          'recurringPrepaymentStart',
          old.recurringPrepaymentStart,
        ),
        monthlyLivingCost: number('monthlyLivingCost', old.monthlyLivingCost),
        fixedAugustPrepayment: number(
          'fixedAugustPrepayment',
          old.fixedAugustPrepayment,
        ),
        fixedSeptemberPrepayment: number(
          'fixedSeptemberPrepayment',
          old.fixedSeptemberPrepayment,
        ),
        fixedOctoberPrepayment: number(
          'fixedOctoberPrepayment',
          old.fixedOctoberPrepayment,
        ),
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('参数已应用，计划已重算。')));
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
              '填写贷款开始日期和总年限后，剩余期数会按当前月份自动计算；蓝色字段可编辑。前三个计划月份使用固定提前还款，之后从“递增起始值”开始自动增加。',
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
            _field('月工资（记录）', 'monthlySalary', suffix: '元'),
            _field('递增起始值', 'recurringPrepaymentStart', suffix: '元'),
            _calculatedField(
              '当月月供',
              -widget.viewModel.currentMonthlyPayment,
              suffix: '元',
            ),
            _field('每月生活费（仅记录）', 'monthlyLivingCost', suffix: '元'),
            const SizedBox(height: 8),
            _sectionLabel(context, '固定提前还款'),
            _field(
              _displayMonth(widget.viewModel.fixedPrepaymentMonths[0]),
              'fixedAugustPrepayment',
              suffix: '元',
            ),
            _field(
              _displayMonth(widget.viewModel.fixedPrepaymentMonths[1]),
              'fixedSeptemberPrepayment',
              suffix: '元',
            ),
            _field(
              _displayMonth(widget.viewModel.fixedPrepaymentMonths[2]),
              'fixedOctoberPrepayment',
              suffix: '元',
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: _controllers[key],
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
          isDense: true,
        ),
      ),
    );
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
          formatLoanMoney(value),
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

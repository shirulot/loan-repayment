import 'package:flutter/material.dart';

import '../../../../domain/models/loan_models.dart';
import 'loan_plan_formatters.dart';
import 'loan_plan_mobile_fields.dart';

/// 首页提前还款设置；弹窗确认后才保存频率与手填定额。
class LoanPlanFrequencySelector extends StatelessWidget {
  const LoanPlanFrequencySelector({
    super.key,
    required this.config,
    required this.onChanged,
    this.amountsMasked = false,
  });

  final LoanPlanConfig config;
  final ValueChanged<LoanPlanConfig> onChanged;
  final bool amountsMasked;

  static String frequencyLabel(int months) => months == 1 ? '每月' : '每$months个月';

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<LoanPlanConfig>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) =>
          _LoanPlanFrequencySheet(config: config, amountsMasked: amountsMasked),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final frequency = frequencyLabel(config.prepaymentFrequencyMonths);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(Icons.event_repeat_outlined, color: colors.primary),
        title: const Text('还款频率'),
        subtitle: Text(
          config.isFixedPrepaymentMode
              ? '定额还款 · $frequency ${formatLoanMoneyProtected(config.fixedPrepaymentAmount, masked: amountsMasked)} 元'
              : config.isPlanRepaymentMode
              ? '仅按已录入还款记录安排'
              : '增量还款 · $frequency',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openPicker(context),
      ),
    );
  }
}

/// 模式、周期和金额共同确认，取消不会改变现有规划。
class _LoanPlanFrequencySheet extends StatefulWidget {
  const _LoanPlanFrequencySheet({
    required this.config,
    required this.amountsMasked,
  });

  final LoanPlanConfig config;
  final bool amountsMasked;

  @override
  State<_LoanPlanFrequencySheet> createState() =>
      _LoanPlanFrequencySheetState();
}

class _LoanPlanFrequencySheetState extends State<_LoanPlanFrequencySheet> {
  late bool _fixed =
      widget.config.isFixedPrepaymentMode || widget.config.isPlanRepaymentMode;
  late int _months = widget.config.prepaymentFrequencyMonths;
  late final _amount = TextEditingController(
    text: formatLoanEditableNumber(widget.config.fixedPrepaymentAmount),
  );
  final _amountFocus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _apply() {
    final amount = double.tryParse(_amount.text.trim());
    if (_fixed && (amount == null || !amount.isFinite || amount <= 0)) {
      setState(() => _error = '请输入大于 0 的固定还款金额');
      return;
    }
    Navigator.of(context).pop(
      widget.config.copyWith(
        isPlanRepaymentMode: false,
        isFixedPrepaymentMode: _fixed,
        prepaymentFrequencyMonths: _months,
        fixedPrepaymentAmount: _fixed
            ? amount
            : widget.config.fixedPrepaymentAmount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('提前还款方式', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('增量还款')),
                  ButtonSegment(value: true, label: Text('定额还款')),
                ],
                selected: {_fixed},
                onSelectionChanged: (values) => setState(() {
                  _fixed = values.single;
                  _error = null;
                }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _months,
                decoration: const InputDecoration(labelText: '还款频率'),
                items: [
                  for (final months
                      in LoanPlanConfig.prepaymentFrequencyOptions)
                    DropdownMenuItem(
                      value: months,
                      child: Text(
                        LoanPlanFrequencySelector.frequencyLabel(months),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _months = value);
                },
              ),
              if (_fixed) ...[
                const SizedBox(height: 8),
                LoanMobileInputField(
                  label: '固定还款金额',
                  controller: _amount,
                  focusNode: _amountFocus,
                  suffix: '元',
                  amountsMasked: widget.amountsMasked,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
              ],
              const SizedBox(height: 12),
              Text(
                _fixed
                    ? '每个周期按手填金额安排预计提前还款，正常月供另算；不会用计算出的可供还款额覆盖。已有还款记录优先，最后一笔以剩余本金为限。'
                    : '按所选频率累计可供还款额，已有还款记录优先。',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _apply, child: const Text('应用并重算')),
            ],
          ),
        ),
      ),
    );
  }
}

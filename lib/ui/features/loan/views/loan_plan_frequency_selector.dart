import 'package:flutter/material.dart';

import '../../../../domain/models/loan_models.dart';

/// Displays and edits the planning interval or the explicit-plan mode.
class LoanPlanFrequencySelector extends StatelessWidget {
  const LoanPlanFrequencySelector({
    super.key,
    required this.frequencyMonths,
    required this.isPlanRepaymentMode,
    required this.onChanged,
    required this.onSelectPlanRepayment,
  });

  static const _planRepaymentChoice = 'plan';
  static const _frequencyChoicePrefix = 'frequency:';

  final int frequencyMonths;
  final bool isPlanRepaymentMode;
  final ValueChanged<int> onChanged;
  final VoidCallback onSelectPlanRepayment;

  String _label(int months) => months == 1 ? '每月' : '每$months个月';

  String _frequencyChoice(int months) => '$_frequencyChoicePrefix$months';

  Future<void> _openPicker(BuildContext context) async {
    final selectedChoice = isPlanRepaymentMode
        ? _planRepaymentChoice
        : _frequencyChoice(frequencyMonths);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => _LoanPlanFrequencySheet(
        selectedChoice: selectedChoice,
        labelFor: _label,
        frequencyChoice: _frequencyChoice,
      ),
    );
    if (selected == null || selected == selectedChoice) return;
    if (selected == _planRepaymentChoice) {
      onSelectPlanRepayment();
      return;
    }
    if (selected.startsWith(_frequencyChoicePrefix)) {
      final months = int.tryParse(
        selected.substring(_frequencyChoicePrefix.length),
      );
      if (months != null) onChanged(months);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPicker(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          child: Row(
            children: [
              Icon(Icons.event_repeat_outlined, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '还款频率',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '仅影响规划表中的预计提前还款安排',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isPlanRepaymentMode ? '计划还款' : _label(frequencyMonths),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoanPlanFrequencySheet extends StatelessWidget {
  const _LoanPlanFrequencySheet({
    required this.selectedChoice,
    required this.labelFor,
    required this.frequencyChoice,
  });

  final String selectedChoice;
  final String Function(int months) labelFor;
  final String Function(int months) frequencyChoice;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 620),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Text(
                    '选择还款频率',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                RadioGroup<String>(
                  groupValue: selectedChoice,
                  onChanged: (value) {
                    if (value != null) Navigator.of(context).pop(value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: LoanPlanFrequencySelector._planRepaymentChoice,
                        selected:
                            selectedChoice ==
                            LoanPlanFrequencySelector._planRepaymentChoice,
                        title: const Text('计划还款'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        dense: true,
                        activeColor: colors.primary,
                      ),
                      for (final months
                          in LoanPlanConfig.prepaymentFrequencyOptions)
                        RadioListTile<String>(
                          value: frequencyChoice(months),
                          selected: selectedChoice == frequencyChoice(months),
                          title: Text(labelFor(months)),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          dense: true,
                          activeColor: colors.primary,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    selectedChoice ==
                            LoanPlanFrequencySelector._planRepaymentChoice
                        ? '计划还款只按最近三笔录入的金额和日期安排提前还款；未填写的月份只计算正常月供。'
                        : '最近三笔还款按填写的日期与金额纳入计划；其他月份按所选频率累计可供还款额。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

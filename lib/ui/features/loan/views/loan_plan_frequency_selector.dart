import 'package:flutter/material.dart';

import '../../../../domain/models/loan_models.dart';

/// Displays and edits the planning interval for future prepayments.
class LoanPlanFrequencySelector extends StatelessWidget {
  const LoanPlanFrequencySelector({
    super.key,
    required this.frequencyMonths,
    required this.onChanged,
  });

  final int frequencyMonths;
  final ValueChanged<int> onChanged;

  String _label(int months) => months == 1 ? '每月' : '每$months个月';

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => _LoanPlanFrequencySheet(
        selectedMonths: frequencyMonths,
        labelFor: _label,
      ),
    );
    if (selected != null && selected != frequencyMonths) onChanged(selected);
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
                _label(frequencyMonths),
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
    required this.selectedMonths,
    required this.labelFor,
  });

  final int selectedMonths;
  final String Function(int months) labelFor;

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
                RadioGroup<int>(
                  groupValue: selectedMonths,
                  onChanged: (value) {
                    if (value != null) Navigator.of(context).pop(value);
                  },
                  child: Column(
                    children: [
                      for (final months
                          in LoanPlanConfig.prepaymentFrequencyOptions)
                        RadioListTile<int>(
                          value: months,
                          selected: months == selectedMonths,
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
                    '只反映规划，实际按照最近${selectedMonths * LoanPlanConfig.recentPrepaymentPlanningCycles}个月进行；如果没有最近还款记录，则按照预期进行。',
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

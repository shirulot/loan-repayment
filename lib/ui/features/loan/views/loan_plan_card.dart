import 'package:flutter/material.dart';

/// Describes the full repayment-plan surface on the overview page.
class LoanPlanCard extends StatelessWidget {
  const LoanPlanCard({super.key, required this.onViewDetails});

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

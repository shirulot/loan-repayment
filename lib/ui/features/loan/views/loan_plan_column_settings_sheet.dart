import 'package:flutter/material.dart';

import 'loan_plan_table.dart';

/// Lets the user choose which repayment-plan columns are visible.
Future<Set<LoanPlanColumnKey>?> showLoanPlanColumnSettings({
  required BuildContext context,
  required Set<LoanPlanColumnKey> visibleColumns,
}) async {
  var selected = Set<LoanPlanColumnKey>.from(visibleColumns);
  final result = await showModalBottomSheet<Set<LoanPlanColumnKey>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final optionalColumns = LoanPlanColumnKey.values
              .where((column) => column != LoanPlanColumnKey.gregorianMonth)
              .toList();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '选择显示列',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '公历月份始终保留并固定，其他列可按需开关。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: true,
                          onChanged: null,
                          title: const Text('公历月份'),
                          subtitle: const Text('固定显示'),
                        ),
                        ...optionalColumns.map(
                          (column) => CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: selected.contains(column),
                            onChanged: (checked) {
                              setSheetState(() {
                                if (checked == true) {
                                  selected.add(column);
                                } else {
                                  selected.remove(column);
                                }
                              });
                            },
                            title: Text(column.label),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            selected = Set<LoanPlanColumnKey>.from(
                              defaultLoanPlanVisibleColumns,
                            );
                          });
                        },
                        child: const Text('恢复默认'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(
                          sheetContext,
                        ).pop(Set<LoanPlanColumnKey>.from(selected)),
                        child: const Text('应用'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return result;
}

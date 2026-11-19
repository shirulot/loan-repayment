import 'package:flutter/material.dart';

import 'loan_plan_display_row.dart';
import 'loan_plan_formatters.dart';

/// 对选中时的两行做只读比较。页面关闭时由导航栈释放这次比较。
class LoanPlanComparisonPage extends StatefulWidget {
  const LoanPlanComparisonPage({
    super.key,
    required this.first,
    required this.second,
    required this.amountsMasked,
  });

  final LoanPlanDisplayRow first;
  final LoanPlanDisplayRow second;
  final bool amountsMasked;

  @override
  State<LoanPlanComparisonPage> createState() => _LoanPlanComparisonPageState();
}

class _LoanPlanComparisonPageState extends State<LoanPlanComparisonPage> {
  // 高亮随本次比较页面释放，使用字段标识使滚动后仍能定位同一行。
  LoanPlanColumnKey? _highlighted;

  String _difference(
    LoanPlanColumnKey column,
    LoanPlanCellValue a,
    LoanPlanCellValue b,
  ) {
    if (widget.amountsMasked && (a.private || b.private)) return '****';
    if (a.amount case final firstAmount?) {
      final secondAmount = b.amount;
      if (secondAmount == null) return '—';
      final delta = loanDisplayedDifference(secondAmount, firstAmount);
      return '${delta > 0 ? '+' : ''}${formatLoanMoney(delta)}';
    }
    final left = a.text;
    final right = b.text;
    if (left == null || right == null || left == '—' || right == '—') {
      return '—';
    }
    if (column == LoanPlanColumnKey.repaymentDate) {
      final from = DateTime.tryParse('${left}T00:00:00Z');
      final to = DateTime.tryParse('${right}T00:00:00Z');
      if (from == null || to == null) return '—';
      final days = to.difference(from).inDays;
      return '${days > 0 ? '+' : ''}$days 天';
    }
    if (column == LoanPlanColumnKey.gregorianMonth) {
      final from = DateTime.parse('$left-01');
      final to = DateTime.parse('$right-01');
      final months = (to.year - from.year) * 12 + to.month - from.month;
      return '${months > 0 ? '+' : ''}$months 个月';
    }
    return left == right ? '相同' : '不同';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget line(List<String> fields, {bool header = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final (i, field) in fields.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                // 长金额在本格内等比缩小，负号、千分位和小数始终一起显示。
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: i == 0
                      ? AlignmentDirectional.centerStart
                      : AlignmentDirectional.centerEnd,
                  child: Text(
                    field,
                    softWrap: false,
                    maxLines: header ? 2 : 1,
                    textAlign: i == 0 ? TextAlign.start : TextAlign.end,
                    style: TextStyle(
                      fontWeight: header || i == 3 ? FontWeight.w600 : null,
                      color: i == 3 ? colors.primary : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('两行比差'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '第一行  ${widget.first.selectionLabel}\n第二行  ${widget.second.selectionLabel}',
              ),
            ),
            line(const ['字段', '第一行', '第二行', '差额'], header: true),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: LoanPlanColumnKey.values.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final column = LoanPlanColumnKey.values[index];
                  final a = widget.first.valueFor(column);
                  final b = widget.second.valueFor(column);
                  final selected = _highlighted == column;
                  return Semantics(
                    selected: selected,
                    child: Material(
                      color: selected
                          ? colors.secondaryContainer
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(
                          () => _highlighted = selected ? null : column,
                        ),
                        child: line([
                          column.label,
                          a.display(widget.amountsMasked),
                          b.display(widget.amountsMasked),
                          _difference(column, a, b),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

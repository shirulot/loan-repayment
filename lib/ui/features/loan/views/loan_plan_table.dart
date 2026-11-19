import 'package:flutter/material.dart';

import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_display_row.dart';
import 'loan_plan_gesture_detector.dart';

export 'loan_plan_display_row.dart';

/// Renders the horizontally scrollable repayment data table.
class LoanPlanTable extends StatelessWidget {
  const LoanPlanTable({
    super.key,
    required this.viewModel,
    required this.visibleColumns,
    required this.amountsMasked,
    this.targetMonth,
    this.targetRowKey,
    required this.isSelected,
    required this.onRowTap,
  });

  static const headerHeight = 36.0;
  static const bodyRowHeight = 40.0;

  final LoanPlannerViewModel viewModel;
  final Set<LoanPlanColumnKey> visibleColumns;
  final bool amountsMasked;
  final String? targetMonth;
  final GlobalKey? targetRowKey;
  final bool Function(LoanPlanDisplayRow) isSelected;
  final ValueChanged<LoanPlanDisplayRow> onRowTap;

  static List<LoanPlanColumnKey> columns({
    required Set<LoanPlanColumnKey> visibleColumns,
  }) {
    return LoanPlanColumnKey.values
        .where(
          (column) =>
              column == LoanPlanColumnKey.gregorianMonth ||
              visibleColumns.contains(column),
        )
        .toList();
  }

  static List<LoanPlanColumnKey> fixedColumns({
    required Set<LoanPlanColumnKey> visibleColumns,
  }) {
    return columns(visibleColumns: visibleColumns)
        .where(
          (column) =>
              column == LoanPlanColumnKey.gregorianMonth ||
              column == LoanPlanColumnKey.lunarMonth,
        )
        .toList();
  }

  static double minimumWidth({required Set<LoanPlanColumnKey> visibleColumns}) {
    return columns(
      visibleColumns: visibleColumns,
    ).fold<double>(0, (total, column) => total + column.width);
  }

  static double fixedColumnWidth({
    required Set<LoanPlanColumnKey> visibleColumns,
    double? tableWidth,
  }) {
    final growth = _columnGrowth(visibleColumns, tableWidth);
    return fixedColumns(
      visibleColumns: visibleColumns,
    ).fold<double>(0, (total, column) => total + column.width + growth);
  }

  // 无弹性列的 Table 会把宽窗口剩余空间均分给所有列；冻结层使用同样的增量。
  static double _columnGrowth(
    Set<LoanPlanColumnKey> visibleColumns,
    double? tableWidth,
  ) {
    if (tableWidth == null) return 0;
    final extra = tableWidth - minimumWidth(visibleColumns: visibleColumns);
    return extra > 0
        ? extra / columns(visibleColumns: visibleColumns).length
        : 0;
  }

  static Map<int, TableColumnWidth> fixedColumnWidthMap({
    required Set<LoanPlanColumnKey> visibleColumns,
    required double tableWidth,
  }) {
    final fixed = fixedColumns(visibleColumns: visibleColumns);
    final growth = _columnGrowth(visibleColumns, tableWidth);
    return {
      for (var index = 0; index < fixed.length; index++)
        index: FixedColumnWidth(fixed[index].width + growth),
    };
  }

  static Map<int, TableColumnWidth> columnWidthMap({
    required Set<LoanPlanColumnKey> visibleColumns,
  }) {
    final columnsToRender = columns(visibleColumns: visibleColumns);
    return <int, TableColumnWidth>{
      for (var index = 0; index < columnsToRender.length; index++)
        index: FixedColumnWidth(columnsToRender[index].width),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = LoanPlanDisplayRow.expand(viewModel.planRows);
    final columnsToRender = columns(visibleColumns: visibleColumns);

    return Table(
      columnWidths: columnWidthMap(visibleColumns: visibleColumns),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: tableBorder(colors),
      children: [
        TableRow(
          decoration: BoxDecoration(color: colors.primary),
          children: columnsToRender
              .map(
                (column) => headerCell(
                  column.header,
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                ),
              )
              .toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final displayRow = entry.value;
          final row = displayRow.row;
          void onTap() => onRowTap(displayRow);
          Widget cell(Widget child) => tapCell(child, onTap);
          final rowCells = <Widget>[];
          for (final column in columnsToRender) {
            Widget columnCell = bodyCell(
              dataCell(
                context: context,
                column: column,
                displayRow: displayRow,
                viewModel: viewModel,
                amountsMasked: amountsMasked,
              ),
            );
            if (column == LoanPlanColumnKey.gregorianMonth &&
                displayRow.isPrimary &&
                row.month == targetMonth &&
                targetRowKey != null) {
              columnCell = KeyedSubtree(key: targetRowKey, child: columnCell);
            }
            if (column == LoanPlanColumnKey.gregorianMonth) {
              columnCell = Semantics(
                container: true,
                key: ValueKey<String>(
                  displayRow.isPrimary
                      ? 'plan-row-${row.month}'
                      : 'plan-row-${row.month}-transaction-$rowIndex',
                ),
                label: '还款计划行 ${row.month}',
                selected: isSelected(displayRow),
                child: columnCell,
              );
            }
            rowCells.add(cell(columnCell));
          }

          return TableRow(
            decoration: BoxDecoration(
              color: isSelected(displayRow)
                  ? colors.secondaryContainer
                  : row.totalBalance < 0.01
                  ? colors.tertiaryContainer
                  : rowIndex.isEven
                  ? colors.surface
                  : colors.surfaceContainerLowest,
            ),
            children: rowCells,
          );
        }),
      ],
    );
  }

  static Widget dataCell({
    required BuildContext context,
    required LoanPlanColumnKey column,
    required LoanPlanDisplayRow displayRow,
    required LoanPlannerViewModel viewModel,
    required bool amountsMasked,
  }) {
    final value = displayRow.valueFor(column);
    final colors = Theme.of(context).colorScheme;
    final settled =
        column == LoanPlanColumnKey.repaymentStatus &&
        displayRow.valueFor(LoanPlanColumnKey.actualPrepayment).amount != null;
    final color = switch (column) {
      LoanPlanColumnKey.totalReduction ||
      LoanPlanColumnKey.expectedPrepayment ||
      LoanPlanColumnKey.nextMonthBasePayment => colors.primary,
      LoanPlanColumnKey.nextMonthBaseReduction =>
        value.amount == null ? colors.onSurfaceVariant : colors.primary,
      LoanPlanColumnKey.repaymentStatus =>
        settled ? colors.tertiary : colors.onSurfaceVariant,
      LoanPlanColumnKey.prepaymentInterest =>
        (value.amount ?? 0) > 0 ? colors.tertiary : colors.onSurfaceVariant,
      LoanPlanColumnKey.transferDifference =>
        value.amount == 0 ? colors.onSurfaceVariant : colors.tertiary,
      _ => null,
    };
    final cell = textCell(
      value.display(amountsMasked),
      align:
          column == LoanPlanColumnKey.gregorianMonth ||
              column == LoanPlanColumnKey.lunarMonth
          ? TextAlign.center
          : TextAlign.start,
      bold:
          settled ||
          column == LoanPlanColumnKey.gregorianMonth ||
          column == LoanPlanColumnKey.totalPayment ||
          column == LoanPlanColumnKey.nextMonthBasePayment ||
          column == LoanPlanColumnKey.totalReduction && value.amount != null,
      color: color,
    );
    if (column == LoanPlanColumnKey.expectedPrepayment) {
      return Tooltip(
        message: displayRow.row.expectedPrepaymentFromActual
            ? '缺历史原计划，按实还本金回填'
            : '',
        child: cell,
      );
    }
    return cell;
  }

  static Widget headerCell(
    String text, {
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return ColoredBox(
      color: backgroundColor,
      child: SizedBox(
        width: double.infinity,
        height: headerHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: Text(
            text,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.05,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ),
      ),
    );
  }

  static Widget bodyCell(Widget child) {
    return SizedBox(height: bodyRowHeight, child: child);
  }

  static Widget tapCell(Widget child, VoidCallback onTap) {
    return LoanPlanGestureDetector(onTap: onTap, child: child);
  }

  static Widget textCell(
    String text, {
    TextAlign align = TextAlign.center,
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: color,
        ),
      ),
    );
  }

  static TableBorder tableBorder(ColorScheme colors) {
    return TableBorder(
      top: BorderSide(color: colors.outlineVariant),
      bottom: BorderSide(color: colors.outlineVariant),
      left: BorderSide(color: colors.outlineVariant),
      right: BorderSide(color: colors.outlineVariant),
      horizontalInside: BorderSide(
        color: colors.outlineVariant.withValues(alpha: 0.72),
        width: 0.6,
      ),
      verticalInside: BorderSide(
        color: colors.outlineVariant.withValues(alpha: 0.42),
        width: 0.45,
      ),
    );
  }
}

/// Keeps the selected fixed columns and the header visible over both scroll axes.

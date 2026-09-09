import 'package:flutter/material.dart';

import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_table.dart';

/// Paints the fixed columns and header above the two-axis table scroll.
class LoanPlanFrozenOverlay extends StatelessWidget {
  const LoanPlanFrozenOverlay({
    super.key,
    required this.viewModel,
    required this.visibleColumns,
    required this.amountsMasked,
    required this.highlightedMonth,
    required this.onRowTap,
    required this.tableWidth,
    required this.verticalController,
    required this.horizontalController,
  });

  static const _tableInset = 8.0;

  final LoanPlannerViewModel viewModel;
  final Set<LoanPlanColumnKey> visibleColumns;
  final bool amountsMasked;
  final String? highlightedMonth;
  final ValueChanged<String> onRowTap;
  final double tableWidth;
  final ScrollController verticalController;
  final ScrollController horizontalController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([verticalController, horizontalController]),
      builder: (context, _) {
        final verticalOffset = verticalController.hasClients
            ? verticalController.offset
            : 0.0;
        final horizontalOffset = horizontalController.hasClients
            ? horizontalController.offset
            : 0.0;
        final fixedWidth = LoanPlanTable.fixedColumnWidth(
          visibleColumns: visibleColumns,
        );
        final headerColor = Theme.of(context).colorScheme.primary;

        return Stack(
          children: [
            // Paint an opaque surface behind the whole frozen header so the
            // row underneath cannot show through after two-axis scrolling.
            Positioned(
              top: 0,
              left: _tableInset,
              right: _tableInset,
              height: LoanPlanTable.headerHeight,
              child: ColoredBox(color: headerColor),
            ),
            Positioned(
              top: 0,
              left: _tableInset + fixedWidth,
              right: _tableInset,
              height: LoanPlanTable.headerHeight,
              child: IgnorePointer(
                child: ClipRect(
                  child: Transform.translate(
                    offset: Offset(-fixedWidth - horizontalOffset, 0),
                    child: LoanPlanFrozenHeader(
                      visibleColumns: visibleColumns,
                      tableWidth: tableWidth,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: _tableInset,
              width: fixedWidth,
              height: LoanPlanTable.headerHeight,
              child: IgnorePointer(
                child: LoanPlanFrozenFixedHeader(
                  visibleColumns: visibleColumns,
                ),
              ),
            ),
            Positioned(
              top: LoanPlanTable.headerHeight,
              bottom: 0,
              left: _tableInset,
              width: fixedWidth,
              child: ClipRect(
                child: Transform.translate(
                  offset: Offset(0, -verticalOffset),
                  child: LoanPlanFrozenFixedColumns(
                    viewModel: viewModel,
                    visibleColumns: visibleColumns,
                    amountsMasked: amountsMasked,
                    highlightedMonth: highlightedMonth,
                    onRowTap: onRowTap,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Renders the horizontally scrolling portion of the fixed header.
class LoanPlanFrozenHeader extends StatelessWidget {
  const LoanPlanFrozenHeader({
    super.key,
    required this.visibleColumns,
    required this.tableWidth,
  });

  final Set<LoanPlanColumnKey> visibleColumns;
  final double tableWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final columns = LoanPlanTable.columns(visibleColumns: visibleColumns);
    return SizedBox(
      width: tableWidth,
      height: LoanPlanTable.headerHeight,
      child: Table(
        columnWidths: LoanPlanTable.columnWidthMap(
          visibleColumns: visibleColumns,
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: LoanPlanTable.tableBorder(colors),
        children: [
          TableRow(
            decoration: BoxDecoration(color: colors.primary),
            children: columns
                .map(
                  (column) => LoanPlanTable.headerCell(
                    column.header,
                    backgroundColor: colors.primary,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Renders the fixed month columns in the table header.
class LoanPlanFrozenFixedHeader extends StatelessWidget {
  const LoanPlanFrozenFixedHeader({super.key, required this.visibleColumns});

  final Set<LoanPlanColumnKey> visibleColumns;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final columns = LoanPlanTable.fixedColumns(visibleColumns: visibleColumns);
    return Table(
      columnWidths: {
        for (var index = 0; index < columns.length; index++)
          index: FixedColumnWidth(columns[index].width),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: LoanPlanTable.tableBorder(colors),
      children: [
        TableRow(
          decoration: BoxDecoration(color: colors.primary),
          children: columns
              .map(
                (column) => LoanPlanTable.headerCell(
                  column.header,
                  backgroundColor: colors.primary,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

/// Renders the fixed month columns over the vertically scrolling table.
class LoanPlanFrozenFixedColumns extends StatelessWidget {
  const LoanPlanFrozenFixedColumns({
    super.key,
    required this.viewModel,
    required this.visibleColumns,
    required this.amountsMasked,
    required this.highlightedMonth,
    required this.onRowTap,
  });

  final LoanPlannerViewModel viewModel;
  final Set<LoanPlanColumnKey> visibleColumns;
  final bool amountsMasked;
  final String? highlightedMonth;
  final ValueChanged<String> onRowTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final columns = LoanPlanTable.fixedColumns(visibleColumns: visibleColumns);
    return Table(
      columnWidths: {
        for (var index = 0; index < columns.length; index++)
          index: FixedColumnWidth(columns[index].width),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: LoanPlanTable.tableBorder(colors),
      children: LoanPlanDisplayRow.expand(viewModel.rows).asMap().entries.map((
        entry,
      ) {
        final rowIndex = entry.key;
        final displayRow = entry.value;
        final row = displayRow.row;
        final rowColor = row.month == highlightedMonth
            ? colors.secondaryContainer
            : row.totalBalance < 0.01
            ? colors.tertiaryContainer
            : rowIndex.isEven
            ? colors.surface
            : colors.surfaceContainerLowest;
        void onTap() => onRowTap(row.month);
        return TableRow(
          decoration: BoxDecoration(color: rowColor),
          children: columns
              .map(
                (column) => LoanPlanTable.tapCell(
                  LoanPlanTable.bodyCell(
                    LoanPlanTable.dataCell(
                      context: context,
                      column: column,
                      displayRow: displayRow,
                      viewModel: viewModel,
                      amountsMasked: amountsMasked,
                    ),
                  ),
                  onTap,
                ),
              )
              .toList(),
        );
      }).toList(),
    );
  }
}

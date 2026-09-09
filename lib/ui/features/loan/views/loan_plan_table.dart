import 'package:flutter/material.dart';

import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_calendar_formatters.dart';
import 'loan_plan_formatters.dart';
import 'loan_plan_gesture_detector.dart';

/// Identifies a selectable column in the repayment table.
enum LoanPlanColumnKey {
  gregorianMonth(label: '公历月份', header: '公历\n月份', width: 64),
  lunarMonth(label: '农历月份', header: '农历\n月份', width: 72),
  commercialPayment(label: '商贷月供', header: '商贷\n月供', width: 74),
  commercialPrincipal(label: '商贷月供本金', header: '商贷月供\n本金', width: 78),
  commercialInterest(label: '商贷月供利息', header: '商贷月供\n利息', width: 78),
  commercialReduction(label: '商贷减少', header: '商贷\n减少', width: 74),
  providentPayment(label: '公积金月供', header: '公积金\n月供', width: 74),
  providentPrincipal(label: '公积金月供本金', header: '公积金月供\n本金', width: 82),
  providentInterest(label: '公积金月供利息', header: '公积金月供\n利息', width: 82),
  providentReduction(label: '公积金减少', header: '公积金\n减少', width: 74),
  totalPayment(label: '月供合计', header: '月供\n合计', width: 74),
  totalReduction(label: '总额减少', header: '总额\n减少', width: 74),
  expectedPrepayment(label: '预期提前', header: '预期\n提前', width: 74),
  repaymentDate(label: '还贷日期', header: '还贷\n日期', width: 92),
  repaymentStatus(label: '还贷状态', header: '还贷\n状态', width: 70),
  prepaymentInterest(label: '当日提前利息', header: '当日\n利息', width: 78),
  nextMonthBasePayment(label: '转息前月供', header: '转息前\n月供', width: 86),
  transferDifference(label: '转息差额', header: '转息\n差额', width: 74),
  nextMonthBaseReduction(label: '转息前月供减少', header: '转息前\n月供减少', width: 78),
  commercialBalance(label: '商贷余额', header: '商贷\n余额', width: 80),
  providentBalance(label: '公积金余额', header: '公积金\n余额', width: 80),
  totalBalance(label: '本金合计', header: '本金\n合计', width: 80);

  const LoanPlanColumnKey({
    required this.label,
    required this.header,
    required this.width,
  });

  final String label;
  final String header;
  final double width;
}

/// Default columns shown when no user preference has been saved.
const defaultLoanPlanVisibleColumns = <LoanPlanColumnKey>{
  LoanPlanColumnKey.commercialPayment,
  LoanPlanColumnKey.commercialPrincipal,
  LoanPlanColumnKey.commercialInterest,
  LoanPlanColumnKey.commercialReduction,
  LoanPlanColumnKey.providentPayment,
  LoanPlanColumnKey.providentPrincipal,
  LoanPlanColumnKey.providentInterest,
  LoanPlanColumnKey.providentReduction,
  LoanPlanColumnKey.totalPayment,
  LoanPlanColumnKey.totalReduction,
  LoanPlanColumnKey.expectedPrepayment,
  LoanPlanColumnKey.repaymentDate,
  LoanPlanColumnKey.repaymentStatus,
  LoanPlanColumnKey.prepaymentInterest,
  LoanPlanColumnKey.nextMonthBasePayment,
  LoanPlanColumnKey.transferDifference,
  LoanPlanColumnKey.nextMonthBaseReduction,
  LoanPlanColumnKey.commercialBalance,
  LoanPlanColumnKey.providentBalance,
  LoanPlanColumnKey.totalBalance,
};

/// A display row expands one monthly calculation into one row per repayment
/// event. Each row compares its monthly fields with the preceding month,
/// never with another transaction in the same month.
/// Expands same-month transactions into rows suitable for table rendering.
class LoanPlanDisplayRow {
  const LoanPlanDisplayRow({
    required this.row,
    this.prepayment,
    required this.isPrimary,
    required this.isLast,
  });

  final LoanPlanRow row;
  final LoanPrepaymentDetail? prepayment;
  final bool isPrimary;
  final bool isLast;

  static List<LoanPlanDisplayRow> expand(List<LoanPlanRow> rows) {
    return [
      for (final row in rows)
        if (row.prepaymentDetails.length <= 1)
          LoanPlanDisplayRow(
            row: row,
            prepayment: row.prepaymentDetails.isEmpty
                ? null
                : row.prepaymentDetails.single,
            isPrimary: true,
            isLast: true,
          )
        else
          for (var index = 0; index < row.prepaymentDetails.length; index++)
            LoanPlanDisplayRow(
              row: row,
              prepayment: row.prepaymentDetails[index],
              isPrimary: index == 0,
              isLast: index == row.prepaymentDetails.length - 1,
            ),
    ];
  }
}

/// Full-screen, compact view for editing and reviewing all repayment rows.

/// Renders the horizontally scrollable repayment data table.
class LoanPlanTable extends StatelessWidget {
  const LoanPlanTable({
    super.key,
    required this.viewModel,
    required this.visibleColumns,
    required this.amountsMasked,
    this.targetMonth,
    this.targetRowKey,
    required this.highlightedMonth,
    required this.onRowTap,
  });

  static const headerHeight = 36.0;
  static const bodyRowHeight = 40.0;

  final LoanPlannerViewModel viewModel;
  final Set<LoanPlanColumnKey> visibleColumns;
  final bool amountsMasked;
  final String? targetMonth;
  final GlobalKey? targetRowKey;
  final String? highlightedMonth;
  final ValueChanged<String> onRowTap;

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
  }) {
    return fixedColumns(
      visibleColumns: visibleColumns,
    ).fold<double>(0, (total, column) => total + column.width);
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
    final rows = LoanPlanDisplayRow.expand(viewModel.rows);
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
                (column) =>
                    headerCell(column.header, backgroundColor: colors.primary),
              )
              .toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final displayRow = entry.value;
          final row = displayRow.row;
          void onTap() => onRowTap(row.month);
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
                row.month == targetMonth &&
                targetRowKey != null) {
              columnCell = KeyedSubtree(key: targetRowKey, child: columnCell);
            }
            if (column == LoanPlanColumnKey.gregorianMonth) {
              columnCell = Semantics(
                container: true,
                key: ValueKey<String>('plan-row-${row.month}'),
                label: '还款计划行 ${row.month}',
                selected: row.month == highlightedMonth,
                child: columnCell,
              );
            }
            rowCells.add(cell(columnCell));
          }

          return TableRow(
            decoration: BoxDecoration(
              color: row.month == highlightedMonth
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
    final row = displayRow.row;
    final prepayment = displayRow.prepayment;
    // An expanded transaction shows its own pre-prepayment monthly-payment
    // preview instead of repeating the outer calendar row's payment values.
    final paymentBefore = prepayment?.hasNormalPaymentBefore == true
        ? prepayment
        : null;
    final isLaterSameMonthPrepayment =
        prepayment != null && !displayRow.isPrimary;
    final commercialPayment =
        paymentBefore?.commercialPaymentBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.commercialPayment);
    final commercialPrincipal =
        paymentBefore?.commercialPrincipalBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.commercialPrincipal);
    final commercialInterest =
        paymentBefore?.commercialInterestBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.commercialInterest);
    final providentPayment =
        paymentBefore?.providentPaymentBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.providentPayment);
    final providentPrincipal =
        paymentBefore?.providentPrincipalBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.providentPrincipal);
    final providentInterest =
        paymentBefore?.providentInterestBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.providentInterest);
    final totalPayment = paymentBefore == null
        ? isLaterSameMonthPrepayment
              ? 0.0
              : row.totalPayment
        : paymentBefore.commercialPaymentBefore +
              paymentBefore.providentPaymentBefore;
    final colors = Theme.of(context).colorScheme;
    return switch (column) {
      LoanPlanColumnKey.gregorianMonth => textCell(
        row.month,
        align: TextAlign.center,
        bold: true,
      ),
      LoanPlanColumnKey.lunarMonth => textCell(
        formatLoanLunarMonth(row.month),
        align: TextAlign.center,
      ),
      LoanPlanColumnKey.commercialPayment => textCell(
        formatLoanMoneyProtected(
          commercialPayment,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
      ),
      LoanPlanColumnKey.commercialPrincipal => textCell(
        formatLoanMoneyProtected(commercialPrincipal, masked: amountsMasked),
      ),
      LoanPlanColumnKey.commercialInterest => textCell(
        formatLoanMoneyProtected(commercialInterest, masked: amountsMasked),
      ),
      LoanPlanColumnKey.commercialReduction => textCell(
        formatLoanMoneyProtected(
          row.commercialReduction,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
      ),
      LoanPlanColumnKey.providentPayment => textCell(
        formatLoanMoneyProtected(
          providentPayment,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
      ),
      LoanPlanColumnKey.providentPrincipal => textCell(
        formatLoanMoneyProtected(providentPrincipal, masked: amountsMasked),
      ),
      LoanPlanColumnKey.providentInterest => textCell(
        formatLoanMoneyProtected(providentInterest, masked: amountsMasked),
      ),
      LoanPlanColumnKey.providentReduction => textCell(
        formatLoanMoneyProtected(
          row.providentReduction,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
      ),
      LoanPlanColumnKey.totalPayment => textCell(
        formatLoanMoneyProtected(totalPayment, masked: amountsMasked),
        bold: true,
      ),
      LoanPlanColumnKey.totalReduction => textCell(
        formatLoanMoneyProtected(
          row.totalReduction,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
        color: colors.primary,
        bold: row.totalReduction != null,
      ),
      LoanPlanColumnKey.expectedPrepayment => textCell(
        formatLoanMoneyProtected(
          prepayment?.expectedAmount ?? row.expectedPrepayment,
          masked: amountsMasked,
        ),
        color: colors.primary,
      ),
      LoanPlanColumnKey.repaymentDate => textCell(
        amountsMasked
            ? '****'
            : (prepayment?.repaymentDate ?? row.effectivePrepaymentDate ?? '—'),
      ),
      LoanPlanColumnKey.repaymentStatus => textCell(
        (prepayment?.actualPrepayment ?? row.actualPrepayment) == null
            ? '预定日期'
            : '已结清',
        bold: (prepayment?.actualPrepayment ?? row.actualPrepayment) != null,
        color: (prepayment?.actualPrepayment ?? row.actualPrepayment) == null
            ? colors.onSurfaceVariant
            : colors.tertiary,
      ),
      LoanPlanColumnKey.prepaymentInterest => textCell(
        formatLoanMoneyProtected(
          prepayment?.interestDueNow ?? row.prepaymentInterestDueNow,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
        color: (prepayment?.interestDueNow ?? row.prepaymentInterestDueNow) > 0
            ? colors.tertiary
            : colors.onSurfaceVariant,
      ),
      LoanPlanColumnKey.nextMonthBasePayment => textCell(
        formatLoanMoneyProtected(
          row.nextMonthBasePayment,
          masked: amountsMasked,
        ),
        bold: true,
        color: colors.primary,
      ),
      LoanPlanColumnKey.transferDifference => textCell(
        formatLoanMoneyProtected(row.transferDifference, masked: amountsMasked),
        color: row.transferDifference == 0
            ? colors.onSurfaceVariant
            : colors.tertiary,
      ),
      LoanPlanColumnKey.nextMonthBaseReduction => textCell(
        formatLoanMoneyProtected(
          row.nextMonthBasePaymentReduction,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
        color: row.nextMonthBasePaymentReduction == null
            ? colors.onSurfaceVariant
            : colors.primary,
      ),
      LoanPlanColumnKey.commercialBalance => textCell(
        formatLoanMoneyProtected(
          prepayment?.commercialClosing ?? row.commercialClosing,
          masked: amountsMasked,
        ),
      ),
      LoanPlanColumnKey.providentBalance => textCell(
        formatLoanMoneyProtected(
          prepayment?.providentClosing ?? row.providentClosing,
          masked: amountsMasked,
        ),
      ),
      LoanPlanColumnKey.totalBalance => textCell(
        formatLoanMoneyProtected(
          prepayment?.totalBalance ?? row.totalBalance,
          masked: amountsMasked,
        ),
      ),
    };
  }

  static Widget headerCell(String text, {required Color backgroundColor}) {
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
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.05,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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

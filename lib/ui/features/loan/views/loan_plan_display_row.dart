import '../../../../domain/models/loan_models.dart';
import 'loan_plan_calendar_formatters.dart';
import 'loan_plan_formatters.dart';

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
  repaymentAmount(label: '还款金额', header: '还款\n金额', width: 78),
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
  LoanPlanColumnKey.repaymentAmount,
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

/// 预测沿用原有逐笔展示，历史单独列出月供及每笔实际提前还款。
class LoanPlanDisplayRow {
  const LoanPlanDisplayRow({
    this.previous,
    required this.row,
    this.prepayment,
    required this.isPrimary,
    required this.isLast,
  });

  final LoanPlanDisplayRow? previous;
  final LoanPlanRow row;
  final LoanPrepaymentDetail? prepayment;
  final bool isPrimary;
  final bool isLast;

  /// 先展开交易，再按实际展示顺序关联前一行；允许上一行属于上个月。
  static List<LoanPlanDisplayRow> expand(List<LoanPlanRow> rows) {
    final result = <LoanPlanDisplayRow>[];
    for (final row in rows) {
      if (row.isArchived || row.prepaymentDetails.isEmpty) {
        result.add(
          LoanPlanDisplayRow(
            row: row,
            previous: result.lastOrNull,
            isPrimary: true,
            isLast: row.prepaymentDetails.isEmpty,
          ),
        );
      }
      for (final (index, detail) in row.prepaymentDetails.indexed) {
        result.add(
          LoanPlanDisplayRow(
            row: row,
            previous: result.lastOrNull,
            prepayment: detail,
            isPrimary: !row.isArchived && index == 0,
            isLast: index == row.prepaymentDetails.length - 1,
          ),
        );
      }
    }
    return result;
  }

  /// 冻结列和滚动表各自展开行，通过相同的账单和交易对象识别同一笔。
  bool sameLine(LoanPlanDisplayRow? other) =>
      other != null &&
      identical(row, other.row) &&
      identical(prepayment, other.prepayment);

  String get selectionLabel {
    final detail = prepayment;
    if (detail == null) return '${row.month} 月供';
    final index = row.prepaymentDetails.indexOf(detail) + 1;
    return '${row.month} 第 $index 笔提前还款';
  }

  /// 表格与即时比差共用逐笔取值，保留未知金额、零值和待核利息的区别。
  LoanPlanCellValue valueFor(LoanPlanColumnKey column) {
    final prepayment = this.prepayment;
    late final archivedPayment = row.isArchived && prepayment == null;
    // 历史月供行对应实际扣款，各提前行使用本笔后的测算；预测行沿用逐笔前预览。
    final after = prepayment?.paymentAfter;
    late final paymentBefore = prepayment?.hasNormalPaymentBefore == true
        ? prepayment
        : null;
    late final isLaterSameMonthPrepayment = prepayment != null && !isPrimary;
    late final commercialPayment =
        after?.commercial.payment ??
        paymentBefore?.commercialPaymentBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.commercialPayment);
    late final commercialPrincipal =
        after?.commercial.principal ??
        paymentBefore?.commercialPrincipalBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.commercialPrincipal);
    late final commercialInterest =
        after?.commercial.interest ??
        paymentBefore?.commercialInterestBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.commercialInterest);
    late final providentPayment =
        after?.provident.payment ??
        paymentBefore?.providentPaymentBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.providentPayment);
    late final providentPrincipal =
        after?.provident.principal ??
        paymentBefore?.providentPrincipalBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.providentPrincipal);
    late final providentInterest =
        after?.provident.interest ??
        paymentBefore?.providentInterestBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.providentInterest);
    late final totalPayment = after != null
        ? after.commercial.payment + after.provident.payment
        : paymentBefore != null
        ? paymentBefore.commercialPaymentBefore +
              paymentBefore.providentPaymentBefore
        : isLaterSameMonthPrepayment
        ? 0.0
        : row.totalPayment;
    late final basePayment = after == null
        ? (prepayment?.basePaymentBefore ?? row.nextMonthBasePayment)
        : after.commercial.basePayment + after.provident.basePayment;
    late final interestRecorded =
        archivedPayment ||
        (prepayment?.interestRecorded ?? row.prepaymentInterestRecorded);
    late final prepaymentInterest = archivedPayment
        ? null
        : prepayment?.interestDueNow ?? row.prepaymentInterestDueNow;
    // 历史月供有独立展示行，提前本金只计入对应的交易行。
    final repaymentAmount = archivedPayment
        ? null
        : prepayment?.amount ?? row.usedPrepayment;
    late final repaymentDate = archivedPayment
        ? (row.commercialPayment > 0 ? '${row.month}-01' : null)
        : prepayment?.repaymentDate ?? row.effectivePrepaymentDate;
    late final commercialBalance = archivedPayment
        ? row.commercialOpening - row.commercialPrincipal
        : prepayment?.commercialClosing ?? row.commercialClosing;
    late final providentBalance = archivedPayment
        ? row.providentOpening - row.providentPrincipal
        : prepayment?.providentClosing ?? row.providentClosing;
    // 单月校准首行有时没有正常扣款，这种空基准沿用原来的缺值处理。
    double? reduction(
      LoanPlanColumnKey source,
      double current,
      double? fallback,
    ) {
      final prior = previous;
      if (prior == null) return fallback;
      if (source != LoanPlanColumnKey.nextMonthBasePayment &&
          !prior.row.isArchived &&
          prior.row.totalPayment == 0 &&
          prior.prepayment?.hasNormalPaymentBefore != true) {
        return fallback;
      }
      final before = prior.valueFor(source).amount;
      return before == null ? null : loanDisplayedDifference(before, current);
    }

    return switch (column) {
      LoanPlanColumnKey.gregorianMonth => LoanPlanCellValue.text(row.month),
      LoanPlanColumnKey.lunarMonth => LoanPlanCellValue.text(
        formatLoanLunarMonth(row.month),
      ),
      LoanPlanColumnKey.repaymentDate => LoanPlanCellValue.text(
        repaymentDate,
        private: true,
      ),
      LoanPlanColumnKey.repaymentStatus => LoanPlanCellValue.text(
        row.isArchived
            ? (archivedPayment ? '正常月供' : '提前还款')
            : prepayment?.isRecorded == true
            ? '已录入'
            : row.usedPrepayment > 0
            ? '自动测算'
            : '正常月供',
      ),
      LoanPlanColumnKey.commercialPayment => LoanPlanCellValue.money(
        commercialPayment,
        dashWhenZero: !row.isArchived,
      ),
      LoanPlanColumnKey.commercialPrincipal => LoanPlanCellValue.money(
        commercialPrincipal,
      ),
      LoanPlanColumnKey.commercialInterest => LoanPlanCellValue.money(
        commercialInterest,
      ),
      LoanPlanColumnKey.commercialReduction => LoanPlanCellValue.money(
        reduction(
          LoanPlanColumnKey.commercialPayment,
          commercialPayment,
          row.commercialReduction,
        ),
      ),
      LoanPlanColumnKey.providentPayment => LoanPlanCellValue.money(
        providentPayment,
        dashWhenZero: !row.isArchived,
      ),
      LoanPlanColumnKey.providentPrincipal => LoanPlanCellValue.money(
        providentPrincipal,
      ),
      LoanPlanColumnKey.providentInterest => LoanPlanCellValue.money(
        providentInterest,
      ),
      LoanPlanColumnKey.providentReduction => LoanPlanCellValue.money(
        reduction(
          LoanPlanColumnKey.providentPayment,
          providentPayment,
          row.providentReduction,
        ),
      ),
      LoanPlanColumnKey.totalPayment => LoanPlanCellValue.money(totalPayment),
      LoanPlanColumnKey.totalReduction => LoanPlanCellValue.money(
        reduction(
          LoanPlanColumnKey.totalPayment,
          totalPayment,
          row.totalReduction,
        ),
      ),
      LoanPlanColumnKey.repaymentAmount => LoanPlanCellValue.money(
        repaymentAmount,
        dashWhenZero: true,
      ),
      LoanPlanColumnKey.prepaymentInterest => LoanPlanCellValue.money(
        interestRecorded ? prepaymentInterest : null,
        dashWhenZero: !row.isArchived,
        pending: !interestRecorded,
      ),
      LoanPlanColumnKey.nextMonthBasePayment => LoanPlanCellValue.money(
        basePayment,
      ),
      LoanPlanColumnKey.transferDifference => LoanPlanCellValue.money(
        after == null && prepayment?.basePaymentBefore == null
            ? row.transferDifference
            : totalPayment - basePayment,
      ),
      LoanPlanColumnKey.nextMonthBaseReduction => LoanPlanCellValue.money(
        reduction(
          LoanPlanColumnKey.nextMonthBasePayment,
          basePayment,
          row.nextMonthBasePaymentReduction,
        ),
      ),
      LoanPlanColumnKey.commercialBalance => LoanPlanCellValue.money(
        commercialBalance,
      ),
      LoanPlanColumnKey.providentBalance => LoanPlanCellValue.money(
        providentBalance,
      ),
      LoanPlanColumnKey.totalBalance => LoanPlanCellValue.money(
        commercialBalance + providentBalance,
      ),
    };
  }
}

class LoanPlanCellValue {
  const LoanPlanCellValue.money(
    this.amount, {
    this.dashWhenZero = false,
    this.pending = false,
  }) : text = null,
       private = true;
  const LoanPlanCellValue.text(this.text, {this.private = false})
    : amount = null,
      pending = false,
      dashWhenZero = false;

  final double? amount;
  final String? text;
  final bool private;
  final bool dashWhenZero;
  final bool pending;

  String display(bool masked) {
    if (private && masked) return '****';
    if (pending) return '待核';
    if (amount case final value?) {
      return formatLoanMoneyProtected(
        value,
        masked: false,
        dashWhenEmpty: dashWhenZero,
      );
    }
    return text ?? '—';
  }
}

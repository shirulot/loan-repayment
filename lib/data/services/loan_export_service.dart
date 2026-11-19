import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/loan_models.dart';
import '../../domain/models/loan_payment_history.dart';
import 'loan_cache_service.dart';

class ExportedLoanFile {
  const ExportedLoanFile({required this.path, required this.kind});

  final String path;
  final String kind;
}

class LoanExportService {
  const LoanExportService();

  Future<ExportedLoanFile> exportCsv(
    LoanPlanConfig config,
    List<LoanPlanRow> rows,
  ) async {
    final content = _csvContent(config, rows);
    return _save('loan-repayment-plan.csv', content, 'CSV');
  }

  Future<ExportedLoanFile> exportExcel(
    LoanPlanConfig config,
    List<LoanPlanRow> rows,
  ) async {
    final content = _excelHtmlContent(config, rows);
    return _save('loan-repayment-plan.xls', content, 'Excel');
  }

  Future<ExportedLoanFile> exportJson(
    LoanPlanConfig config,
    List<LoanPlanRow> rows,
    Map<String, double?> actualPrepayments, {
    List<LoanPaymentHistory> paymentHistory = const <LoanPaymentHistory>[],
    LoanInitialBalance? recordedInitialBalance,
  }) async {
    final payload =
        LoanCachedState(
          config: config,
          actualPrepayments: actualPrepayments,
          paymentHistory: paymentHistory,
          recordedInitialBalance: recordedInitialBalance,
        ).toJson()..addAll(<String, Object?>{
          'rows': rows.map(_rowToJson).toList(),
          'exportedAt': DateTime.now().toIso8601String(),
        });
    return _save(
      'loan-repayment-plan.json',
      const JsonEncoder.withIndent('  ').convert(payload),
      'JSON',
    );
  }

  Future<ExportedLoanFile> _save(
    String fileName,
    String content,
    String kind,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDirectory = Directory('${directory.path}/loan-repayment-plans');
    if (!exportDirectory.existsSync()) {
      await exportDirectory.create(recursive: true);
    }
    final file = File('${exportDirectory.path}/$fileName');
    await file.writeAsString(content, encoding: utf8);
    return ExportedLoanFile(path: file.path, kind: kind);
  }

  // CSV 与 Excel 按同一份列顺序导出，历史实录与计算值能够逐列核对。
  static const _tabularHeaders = <String>[
    '月份',
    '商贷月供',
    '商贷减少额',
    '公积金月供',
    '公积金减少额',
    '本月月供总额',
    '总减少额',
    '还款金额',
    '还贷日期',
    '当日提前利息',
    '下月基础月供',
    '转息差额',
    '基础月供减少额',
    '商贷余额',
    '公积金余额',
    '本金总额',
    '商贷期初本金',
    '商贷月供本金',
    '商贷月供利息',
    '公积金期初本金',
    '公积金月供本金',
    '公积金月供利息',
  ];

  List<Object?> _tabularValues(LoanPlanRow row) => [
    row.month,
    row.commercialPayment,
    row.commercialReduction,
    row.providentPayment,
    row.providentReduction,
    row.totalPayment,
    row.totalReduction,
    row.usedPrepayment,
    row.prepaymentDates.join('、'),
    row.prepaymentInterestRecorded ? row.prepaymentInterestDueNow : null,
    row.nextMonthBasePayment,
    row.transferDifference,
    row.nextMonthBasePaymentReduction,
    row.commercialClosing,
    row.providentClosing,
    row.totalBalance,
    row.commercialOpening,
    row.commercialPrincipal,
    row.commercialInterest,
    row.providentOpening,
    row.providentPrincipal,
    row.providentInterest,
  ];

  String _csvContent(LoanPlanConfig config, List<LoanPlanRow> rows) {
    final lines = <List<Object?>>[
      <Object?>['还款方式', config.repaymentMethod.label],
      const <Object?>[],
      _tabularHeaders,
      ...rows.map(_tabularValues),
    ];
    return '\uFEFF${lines.map((line) => line.map(_csvCell).join(',')).join('\r\n')}\r\n';
  }

  String _excelHtmlContent(LoanPlanConfig config, List<LoanPlanRow> rows) {
    final body = rows.map((row) {
      final values = _tabularValues(row);
      return '<tr>${values.map((value) => '<td>${_htmlCell(value)}</td>').join()}</tr>';
    }).join();
    return '''<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
body{font-family:Arial,"Microsoft YaHei",sans-serif} table{border-collapse:collapse}
th{background:#1f4e78;color:#fff;padding:7px;border:1px solid #d9e2f3}
td{padding:6px;border:1px solid #d9e2f3;text-align:right} td:first-child{text-align:center}
</style></head><body>
<h1>提前还贷计算器计划表</h1>
<p>还款方式：${_escapeHtml(config.repaymentMethod.label)}</p>
<p>商贷利率：${(config.commercialAnnualRate * 100).toStringAsFixed(2)}%；公积金利率：${(config.providentAnnualRate * 100).toStringAsFixed(2)}%</p>
<table><thead><tr>${_tabularHeaders.map((item) => '<th>${_escapeHtml(item)}</th>').join()}</tr></thead><tbody>$body</tbody></table>
</body></html>''';
  }

  Map<String, Object?> _rowToJson(LoanPlanRow row) {
    return <String, Object?>{
      'month': row.month,
      if (row.isArchived) 'isArchived': true,
      if (row.commercialPaymentEvidence != LoanPaymentEvidence.statement)
        'commercialPaymentEvidence': row.commercialPaymentEvidence.name,
      if (row.providentInterestEstimated) 'providentInterestEstimated': true,
      if (row.commercialAnnualRate != null)
        'commercialAnnualRate': row.commercialAnnualRate,
      if (row.providentAnnualRate != null)
        'providentAnnualRate': row.providentAnnualRate,
      if (row.commercialAnnualRateInferred)
        'commercialAnnualRateInferred': true,
      if (row.providentAnnualRateInferred) 'providentAnnualRateInferred': true,
      'commercialOpening': row.commercialOpening,
      'commercialPrincipal': row.commercialPrincipal,
      'commercialInterest': row.commercialInterest,
      'commercialPayment': row.commercialPayment,
      'commercialReduction': row.commercialReduction,
      'providentOpening': row.providentOpening,
      'providentPrincipal': row.providentPrincipal,
      'providentInterest': row.providentInterest,
      'providentPayment': row.providentPayment,
      'providentReduction': row.providentReduction,
      'totalPayment': row.totalPayment,
      'totalReduction': row.totalReduction,
      'repaymentAmount': row.usedPrepayment,
      'prepaymentDates': row.prepaymentDates,
      'prepaymentDetails': row.prepaymentDetails
          .map(
            (detail) => <String, Object?>{
              'amount': detail.amount,
              'repaymentDate': detail.repaymentDate,
              'interestDueNow': detail.interestRecorded
                  ? detail.interestDueNow
                  : null,
              'nextMonthDeferredInterest': row.isArchived
                  ? null
                  : detail.nextMonthDeferredInterest,
              'commercialClosing': detail.commercialClosing,
              'providentClosing': detail.providentClosing,
              'commercialPrincipalBefore': detail.commercialPrincipalBefore,
              'commercialInterestBefore': detail.commercialInterestBefore,
              'commercialPaymentBefore': detail.commercialPaymentBefore,
              'providentPrincipalBefore': detail.providentPrincipalBefore,
              'providentInterestBefore': detail.providentInterestBefore,
              'providentPaymentBefore': detail.providentPaymentBefore,
            },
          )
          .toList(growable: false),
      'prepaymentInterestDueNow': row.prepaymentInterestRecorded
          ? row.prepaymentInterestDueNow
          : null,
      'nextMonthBasePayment': row.nextMonthBasePayment,
      'transferDifference': row.transferDifference,
      'nextMonthBasePaymentReduction': row.nextMonthBasePaymentReduction,
      'commercialBalance': row.commercialClosing,
      'providentBalance': row.providentClosing,
      'totalBalance': row.totalBalance,
    };
  }

  String _csvCell(Object? value) {
    final text = value is num
        ? value.toStringAsFixed(2)
        : (value?.toString() ?? '');
    return '"${text.replaceAll('"', '""')}"';
  }

  String _htmlCell(Object? value) {
    final text = value is num
        ? value.toStringAsFixed(2)
        : (value?.toString() ?? '');
    return _escapeHtml(text);
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}

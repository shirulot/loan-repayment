import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/loan_models.dart';
import '../../domain/models/loan_payment_history.dart';

/// Snapshot restored before the first application frame is shown.
class LoanCachedState {
  const LoanCachedState({
    required this.config,
    required this.actualPrepayments,
    this.paymentHistory = const <LoanPaymentHistory>[],
    this.recordedInitialBalance,
    this.calculatorExpression = '',
    this.temporaryCalculatorResults = const <double>[],
    this.temporaryCalculatorExpressions = const <String?>[],
  });

  final LoanPlanConfig config;
  final Map<String, double?> actualPrepayments;
  final List<LoanPaymentHistory> paymentHistory;
  final LoanInitialBalance? recordedInitialBalance;
  final String calculatorExpression;
  final List<double> temporaryCalculatorResults;
  final List<String?> temporaryCalculatorExpressions;

  /// Parses both cache files and JSON backups exported by this application.
  factory LoanCachedState.fromJson(Map<dynamic, dynamic> json) {
    final configJson = json['config'];
    if (configJson is! Map) {
      throw const FormatException('缺少贷款参数。');
    }

    final actualPrepayments = <String, double?>{};
    final actualJson = json['actualPrepayments'];
    if (actualJson is Map) {
      for (final entry in actualJson.entries) {
        if (entry.key is String && entry.value is num) {
          actualPrepayments[entry.key as String] = (entry.value as num)
              .toDouble();
        }
      }
    }
    final history = json.containsKey('paymentHistory')
        ? LoanPaymentHistory.parseList(json['paymentHistory'])
        : const <LoanPaymentHistory>[];
    // 已由流水解释的旧月合计不能再转写给同月另一笔手工事件。
    for (final bill in history) {
      final amount = actualPrepayments[bill.month];
      if (amount != null && bill.coversLegacyMonthlyAmount(amount)) {
        actualPrepayments.remove(bill.month);
      }
    }
    var config = LoanPlanConfig.fromJson(Map<String, dynamic>.from(configJson));
    if (actualPrepayments.isNotEmpty && config.recentPrepayments.isNotEmpty) {
      final rawRecords = configJson['recentPrepayments'];
      final recordedIds = rawRecords is List
          ? rawRecords
                .whereType<Map>()
                .where(
                  (record) =>
                      double.tryParse('${record['actualPrepayment']}') != null,
                )
                .map((record) => record['id']?.toString())
                .toSet()
          : const <String?>{};
      config = _mergeLegacyMonthlyAmounts(
        config,
        actualPrepayments,
        recordedIds,
      );
    }
    final temporaryCalculatorResults = <double>[];
    final temporaryJson = json['temporaryCalculatorResults'];
    if (temporaryJson is List) {
      for (final value in temporaryJson) {
        if (value is num) temporaryCalculatorResults.add(value.toDouble());
      }
    }
    final temporaryCalculatorExpressions = <String?>[];
    final expressionsJson = json['temporaryCalculatorExpressions'];
    if (expressionsJson is List) {
      for (final expression in expressionsJson) {
        temporaryCalculatorExpressions.add(
          expression is String ? expression : null,
        );
      }
    }
    final initialBalance = json['initialBalance'] ?? json['historicalOpening'];
    return LoanCachedState(
      config: config,
      actualPrepayments: actualPrepayments,
      paymentHistory: history,
      recordedInitialBalance: initialBalance == null
          ? null
          : LoanInitialBalance.fromJson(initialBalance),
      calculatorExpression: json['calculatorExpression']?.toString() ?? '',
      temporaryCalculatorResults: temporaryCalculatorResults,
      temporaryCalculatorExpressions: temporaryCalculatorExpressions,
    );
  }

  /// 旧版按月覆盖值只迁移一次，避免更正日期后，旧月份重新出现同一笔。
  static LoanPlanConfig _mergeLegacyMonthlyAmounts(
    LoanPlanConfig config,
    Map<String, double?> monthlyAmounts,
    Set<String?> recordedIds,
  ) {
    final records = [...config.recentPrepayments];
    final indexesByMonth = <String, List<int>>{};
    for (final (index, record) in records.indexed) {
      final month = record.repaymentMonth;
      if (month == null) continue;
      (indexesByMonth[month] ??= []).add(index);
    }
    for (final entry in indexesByMonth.entries) {
      final monthly = monthlyAmounts[entry.key];
      if (monthly == null) continue;
      if (entry.value.length == 1) {
        final index = entry.value.single;
        if (!recordedIds.contains(records[index].id)) {
          records[index] = records[index].copyWith(
            amount: monthly,
            isSettled: true,
          );
        }
      } else {
        // 多笔旧预约与实还总数对不上时，保留原月扣款，等待用户更正明细。
        final total = entry.value.fold<double>(
          0,
          (sum, index) => sum + records[index].amount,
        );
        if ((total - monthly).abs() >= 0.005) continue;
      }
      monthlyAmounts.remove(entry.key);
    }
    return config.copyWith(recentPrepayments: records);
  }

  /// Keeps export and cache formats aligned for reliable backup restoration.
  Map<String, Object?> toJson() => <String, Object?>{
    'config': config.toJson(),
    'actualPrepayments': actualPrepayments,
    if (paymentHistory.isNotEmpty)
      'paymentHistory': paymentHistory
          .map((record) => record.toJson())
          .toList(),
    'initialBalance': ?recordedInitialBalance?.toJson(),
    'calculatorExpression': calculatorExpression,
    'temporaryCalculatorResults': temporaryCalculatorResults,
    'temporaryCalculatorExpressions': temporaryCalculatorExpressions,
  };
}

/// Stores the editable plan state separately from exported plan files.
class LoanCacheService {
  const LoanCacheService();

  static const _directoryName = 'loan-repayment-plans';
  static const _fileName = 'loan-plan-state.json';

  Future<LoanCachedState?> load() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;

      return LoanCachedState.fromJson(decoded);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(
    LoanPlanConfig config,
    Map<String, double?> actualPrepayments, {
    List<LoanPaymentHistory> paymentHistory = const <LoanPaymentHistory>[],
    LoanInitialBalance? recordedInitialBalance,
    String calculatorExpression = '',
    List<double> temporaryCalculatorResults = const <double>[],
    List<String?> temporaryCalculatorExpressions = const <String?>[],
  }) async {
    final file = await _stateFile();
    final payload = LoanCachedState(
      config: config,
      actualPrepayments: actualPrepayments,
      paymentHistory: paymentHistory,
      recordedInitialBalance: recordedInitialBalance,
      calculatorExpression: calculatorExpression,
      temporaryCalculatorResults: temporaryCalculatorResults,
      temporaryCalculatorExpressions: temporaryCalculatorExpressions,
    ).toJson();
    // Replace the cache only after a complete write so interrupted imports
    // cannot leave existing loan parameters or repayment records truncated.
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<File> _stateFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDirectory = Directory('${directory.path}/$_directoryName');
    if (!await cacheDirectory.exists()) {
      await cacheDirectory.create(recursive: true);
    }
    return File('${cacheDirectory.path}/$_fileName');
  }
}

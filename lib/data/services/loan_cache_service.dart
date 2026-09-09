import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/loan_models.dart';

/// Snapshot restored before the first application frame is shown.
class LoanCachedState {
  const LoanCachedState({
    required this.config,
    required this.actualPrepayments,
    this.calculatorExpression = '',
    this.temporaryCalculatorResults = const <double>[],
  });

  final LoanPlanConfig config;
  final Map<String, double?> actualPrepayments;
  final String calculatorExpression;
  final List<double> temporaryCalculatorResults;

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
    final temporaryCalculatorResults = <double>[];
    final temporaryJson = json['temporaryCalculatorResults'];
    if (temporaryJson is List) {
      for (final value in temporaryJson) {
        if (value is num) temporaryCalculatorResults.add(value.toDouble());
      }
    }
    return LoanCachedState(
      config: LoanPlanConfig.fromJson(Map<String, dynamic>.from(configJson)),
      actualPrepayments: actualPrepayments,
      calculatorExpression: json['calculatorExpression']?.toString() ?? '',
      temporaryCalculatorResults: temporaryCalculatorResults,
    );
  }

  /// Keeps export and cache formats aligned for reliable backup restoration.
  Map<String, Object?> toJson() => <String, Object?>{
    'config': config.toJson(),
    'actualPrepayments': actualPrepayments,
    'calculatorExpression': calculatorExpression,
    'temporaryCalculatorResults': temporaryCalculatorResults,
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
    String calculatorExpression = '',
    List<double> temporaryCalculatorResults = const <double>[],
  }) async {
    final file = await _stateFile();
    final payload = LoanCachedState(
      config: config,
      actualPrepayments: actualPrepayments,
      calculatorExpression: calculatorExpression,
      temporaryCalculatorResults: temporaryCalculatorResults,
    ).toJson();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
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

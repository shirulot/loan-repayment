import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/loan_models.dart';

/// Snapshot restored before the first application frame is shown.
class LoanCachedState {
  const LoanCachedState({
    required this.config,
    required this.actualPrepayments,
  });

  final LoanPlanConfig config;
  final Map<String, double?> actualPrepayments;
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

      final configJson = decoded['config'];
      if (configJson is! Map) return null;

      final actualJson = decoded['actualPrepayments'];
      final actualPrepayments = <String, double?>{};
      if (actualJson is Map) {
        for (final entry in actualJson.entries) {
          if (entry.key is String && entry.value is num) {
            actualPrepayments[entry.key as String] = (entry.value as num)
                .toDouble();
          }
        }
      }

      return LoanCachedState(
        config: LoanPlanConfig.fromJson(Map<String, dynamic>.from(configJson)),
        actualPrepayments: actualPrepayments,
      );
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
    Map<String, double?> actualPrepayments,
  ) async {
    final file = await _stateFile();
    final payload = <String, Object?>{
      'config': config.toJson(),
      'actualPrepayments': actualPrepayments,
    };
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

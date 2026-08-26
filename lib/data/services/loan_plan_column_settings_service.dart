import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists the user's repayment-plan column selection separately from loan data.
class LoanPlanColumnSettingsService {
  const LoanPlanColumnSettingsService();

  static const _directoryName = 'loan-repayment-plans';
  static const _fileName = 'loan-plan-column-settings.json';

  Future<Set<String>?> load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;

      final columns = decoded['visibleColumns'];
      if (columns is! List) return null;
      return columns.whereType<String>().toSet();
    } on Object {
      // A settings failure should fall back to the built-in default columns.
      return null;
    }
  }

  Future<void> save(Iterable<String> visibleColumns) async {
    final file = await _settingsFile();
    final payload = <String, Object?>{
      'visibleColumns': visibleColumns.toList(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  Future<File> _settingsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final settingsDirectory = Directory('${directory.path}/$_directoryName');
    if (!await settingsDirectory.exists()) {
      await settingsDirectory.create(recursive: true);
    }
    return File('${settingsDirectory.path}/$_fileName');
  }
}

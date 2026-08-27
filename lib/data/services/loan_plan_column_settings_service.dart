import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persisted visibility choices plus the schema version used for migrations.
class LoanPlanColumnSettings {
  const LoanPlanColumnSettings({
    required this.visibleColumns,
    required this.schemaVersion,
  });

  final Set<String> visibleColumns;
  final int schemaVersion;
}

/// Persists the user's repayment-plan column selection separately from loan data.
class LoanPlanColumnSettingsService {
  const LoanPlanColumnSettingsService();

  static const currentSchemaVersion = 1;
  static const _directoryName = 'loan-repayment-plans';
  static const _fileName = 'loan-plan-column-settings.json';

  Future<LoanPlanColumnSettings?> load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;

      final columns = decoded['visibleColumns'];
      if (columns is! List) return null;
      final version = decoded['schemaVersion'];
      return LoanPlanColumnSettings(
        visibleColumns: columns.whereType<String>().toSet(),
        schemaVersion: version is num ? version.toInt() : 0,
      );
    } on Object {
      // A settings failure should fall back to the built-in default columns.
      return null;
    }
  }

  Future<void> save(Iterable<String> visibleColumns) async {
    final file = await _settingsFile();
    final payload = <String, Object?>{
      'schemaVersion': currentSchemaVersion,
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

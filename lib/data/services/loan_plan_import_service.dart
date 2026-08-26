import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'loan_cache_service.dart';

/// Reads a JSON backup chosen by the user without changing local state itself.
class LoanPlanImportService {
  const LoanPlanImportService();

  Future<LoanCachedState?> pickBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes);
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('备份文件格式不正确。');
    }
    return LoanCachedState.fromJson(decoded);
  }
}

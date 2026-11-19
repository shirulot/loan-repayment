import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../../domain/models/loan_payment_history.dart';
import 'loan_cache_service.dart';

/// Reads a JSON backup chosen by the user without changing local state itself.
class LoanPlanImportService {
  const LoanPlanImportService();

  Future<LoanCachedState?> pickBackup() async {
    final decoded = await _pickJson();
    return decoded == null ? null : LoanCachedState.fromJson(decoded);
  }

  /// Reads only history from the selected file, even if it is a full backup.
  Future<List<LoanPaymentHistory>?> pickPaymentHistory() async {
    final decoded = await _pickJson();
    if (decoded == null) return null;
    final records = LoanPaymentHistory.parseList(decoded['paymentHistory']);
    if (records.isEmpty) {
      throw const FormatException('该文件没有历史还款记录。');
    }
    return records;
  }

  Future<Map<dynamic, dynamic>?> _pickJson() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes);
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('JSON 文件须包含对象。');
    }
    return decoded;
  }
}

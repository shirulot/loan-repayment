import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Stores appearance preferences separately from loan plans and repayment data.
class AppAppearanceSettingsService {
  const AppAppearanceSettingsService();

  static const _directoryName = 'app-settings';
  static const _fileName = 'appearance-settings.json';
  static const _supportedModes = {'system', 'light', 'dark'};

  Future<String?> loadThemeMode() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;

      final themeMode = decoded['themeMode'];
      return themeMode is String && _supportedModes.contains(themeMode)
          ? themeMode
          : null;
    } on Object {
      return null;
    }
  }

  Future<void> saveThemeMode(String themeMode) async {
    if (!_supportedModes.contains(themeMode)) {
      throw ArgumentError.value(themeMode, 'themeMode');
    }

    final file = await _settingsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({'themeMode': themeMode}),
      flush: true,
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

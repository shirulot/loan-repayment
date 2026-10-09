import 'package:flutter/material.dart';

class AppAppearanceSettingsSheet extends StatefulWidget {
  const AppAppearanceSettingsSheet({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  final ThemeMode selectedMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  State<AppAppearanceSettingsSheet> createState() =>
      _AppAppearanceSettingsSheetState();
}

class _AppAppearanceSettingsSheetState
    extends State<AppAppearanceSettingsSheet> {
  late ThemeMode _selectedMode = widget.selectedMode;

  void _selectMode(ThemeMode? mode) {
    if (mode == null || mode == _selectedMode) return;
    setState(() => _selectedMode = mode);
    widget.onChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Text(
                '外观',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            RadioGroup<ThemeMode>(
              groupValue: _selectedMode,
              onChanged: _selectMode,
              child: Column(
                children: [
                  _modeOption(ThemeMode.system, '跟随系统', colors),
                  _modeOption(ThemeMode.light, '白天模式', colors),
                  _modeOption(ThemeMode.dark, '黑夜模式', colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeOption(ThemeMode mode, String label, ColorScheme colors) {
    return RadioListTile<ThemeMode>(
      value: mode,
      selected: _selectedMode == mode,
      title: Text(label),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      dense: true,
      activeColor: colors.primary,
    );
  }
}

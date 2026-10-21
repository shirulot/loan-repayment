import 'package:flutter/material.dart';

import 'loan_calculator_layout_style.dart';

/// Both keypad arrangements dispatch the same calculator actions.
class LoanCalculatorKeypad extends StatelessWidget {
  const LoanCalculatorKeypad({
    super.key,
    required this.onAppend,
    required this.onBackspace,
    required this.onCalculate,
    required this.onClear,
    this.onSave,
    this.landscape = false,
    this.desktop = false,
  });

  final ValueChanged<String> onAppend;
  final VoidCallback onBackspace;
  final VoidCallback onCalculate;
  final VoidCallback onClear;
  final VoidCallback? onSave;
  final bool landscape;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    const regularKeys = [
      '7',
      '8',
      '9',
      '÷',
      '4',
      '5',
      '6',
      '×',
      '1',
      '2',
      '3',
      '-',
      '.',
      '0',
      '(',
      '+',
    ];
    const landscapeKeys = [
      '7',
      '8',
      '9',
      '÷',
      '(',
      ')',
      '退格',
      '4',
      '5',
      '6',
      '×',
      '.',
      '0',
      '置空',
      '1',
      '2',
      '3',
      '-',
      '+',
      '暂存',
      '=',
    ];
    return Column(
      children: [
        GridView.count(
          crossAxisCount: landscape ? 7 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: LoanCalculatorLayoutStyle.keyGap,
          crossAxisSpacing: LoanCalculatorLayoutStyle.keyGap,
          childAspectRatio: 1.45,
          mainAxisExtent: landscape
              ? LoanCalculatorLayoutStyle.landscapeKeyHeight
              : desktop
              ? LoanCalculatorLayoutStyle.desktopKeyHeight
              : null,
          children: (landscape ? landscapeKeys : regularKeys)
              .map((key) => _button(context, key))
              .toList(),
        ),
        if (!landscape) ...[
          const SizedBox(height: LoanCalculatorLayoutStyle.keyGap),
          Row(
            children: [
              Expanded(child: _button(context, '退格')),
              const SizedBox(width: LoanCalculatorLayoutStyle.keyGap),
              Expanded(child: _button(context, ')')),
              const SizedBox(width: LoanCalculatorLayoutStyle.keyGap),
              Expanded(child: _button(context, '=')),
            ],
          ),
        ],
      ],
    );
  }

  Widget _button(BuildContext context, String key) {
    final VoidCallback? action = switch (key) {
      '退格' => onBackspace,
      '置空' => onClear,
      '暂存' => onSave,
      '=' => onCalculate,
      _ => () => onAppend(key),
    };
    final label = Text(
      key,
      style: key.length == 1 ? Theme.of(context).textTheme.titleLarge : null,
    );
    if (key == '=') return FilledButton(onPressed: action, child: label);
    if (key == '退格' && !landscape) {
      return OutlinedButton.icon(
        onPressed: action,
        icon: const Icon(Icons.backspace_outlined),
        label: label,
      );
    }
    return OutlinedButton(onPressed: action, child: label);
  }
}

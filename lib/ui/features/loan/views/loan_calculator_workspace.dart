import 'package:flutter/material.dart';

import 'loan_calculator_layout_style.dart';

/// E's three independent panes keep long reference/history lists from moving
/// the expression and keypad out of view in a wide desktop window.
class LoanCalculatorWorkspace extends StatelessWidget {
  const LoanCalculatorWorkspace({
    super.key,
    required this.references,
    required this.calculator,
    required this.temporaryResults,
  });

  final Widget references;
  final Widget calculator;
  final Widget temporaryResults;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: LoanCalculatorLayoutStyle.workspaceMaxWidth,
      ),
      child: Padding(
        padding: const EdgeInsets.all(LoanCalculatorLayoutStyle.panelPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: _pane(references)),
            const SizedBox(width: LoanCalculatorLayoutStyle.gap),
            Expanded(flex: 5, child: _pane(calculator)),
            const SizedBox(width: LoanCalculatorLayoutStyle.gap),
            Expanded(flex: 3, child: _pane(temporaryResults)),
          ],
        ),
      ),
    ),
  );

  Widget _pane(Widget child) => Card.outlined(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(LoanCalculatorLayoutStyle.panelPadding),
      child: child,
    ),
  );
}

/// Keep all calculator keys visible at phone landscape heights. Very short
/// windows or enlarged text can scroll the whole surface instead of clipping.
class LoanCalculatorLandscape extends StatelessWidget {
  const LoanCalculatorLandscape({
    super.key,
    required this.expression,
    required this.keypad,
    required this.references,
    required this.minimumHeight,
  });

  final Widget expression;
  final Widget keypad;
  final Widget references;
  final double minimumHeight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(LoanCalculatorLayoutStyle.gap),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final controls = [
          expression,
          const SizedBox(height: LoanCalculatorLayoutStyle.keyGap),
          keypad,
          const SizedBox(height: LoanCalculatorLayoutStyle.keyGap),
        ];
        if (constraints.maxHeight < minimumHeight) {
          return ListView(primary: false, children: [...controls, references]);
        }
        return Column(
          children: [
            ...controls,
            Expanded(child: ListView(primary: false, children: [references])),
          ],
        );
      },
    ),
  );
}

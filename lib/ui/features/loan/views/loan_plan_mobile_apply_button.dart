import 'package:flutter/material.dart';

import '../../../theme/loan_palette.dart';

/// Applies the mobile parameter edits and starts a recalculation.
class LoanMobileApplyButton extends StatelessWidget {
  const LoanMobileApplyButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          gradient: LoanPalette.primaryActionGradient(colors),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            onTap: onPressed,
            child: Center(
              child: Text(
                '应用并重算',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

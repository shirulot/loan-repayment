import 'package:flutter/material.dart';

import '../../../theme/loan_palette.dart';

/// Applies the mobile parameter edits and starts a recalculation.
class LoanMobileApplyButton extends StatelessWidget {
  const LoanMobileApplyButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          gradient: LinearGradient(
            colors: [LoanPalette.primary, LoanPalette.primaryGradientEnd],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            onTap: onPressed,
            child: const Center(
              child: Text(
                '应用并重算',
                style: TextStyle(
                  color: Colors.white,
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

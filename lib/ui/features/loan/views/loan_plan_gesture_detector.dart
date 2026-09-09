import 'package:flutter/material.dart';

/// Provides a shared opaque tap target for repayment table cells and previews.
class LoanPlanGestureDetector extends StatelessWidget {
  const LoanPlanGestureDetector({
    super.key,
    required this.onTap,
    required this.child,
  });

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}

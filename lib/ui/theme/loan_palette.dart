import 'package:flutter/material.dart';

/// Shared palette tokens for the repayment calculator's financial UI.
abstract final class LoanPalette {
  static const Color primary = Color(0xff3f72d8);

  /// Keeps the branded action gradient tied to the active theme's contrast.
  static Gradient primaryActionGradient(ColorScheme colorScheme) =>
      LinearGradient(
        colors: [
          colorScheme.primary,
          Color.lerp(colorScheme.primary, colorScheme.inverseSurface, 0.1)!,
        ],
      );
}

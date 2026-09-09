/// Small, side-effect-free string helpers adapted from the YZT Flutter module.
extension LoanStringValidation on String {
  /// Whether this value is empty or contains whitespace only.
  bool get isBlank => trim().isEmpty;

  /// Parses an integer and returns [defaultValue] when parsing fails.
  int toIntOr(int defaultValue) => int.tryParse(this) ?? defaultValue;

  /// Parses a double and returns [defaultValue] when parsing fails.
  double toDoubleOr(double defaultValue) =>
      double.tryParse(this) ?? defaultValue;
}

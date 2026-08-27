/// Keeps editable amount fields easy to modify by omitting insignificant
/// trailing zeros while retaining the existing two-decimal currency precision.
String formatLoanEditableNumber(double value) {
  if (value == 0) return '';

  final fixed = value.toStringAsFixed(2);
  final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed.isEmpty ? '0' : trimmed;
}

/// Formats loan amounts consistently across the overview and detail pages.
String formatLoanMoney(double value) {
  if (!value.isFinite) return value.toString();

  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  if (parts.length != 2) return fixed;

  final integerPart = parts[0];
  final sign = integerPart.startsWith('-') ? '-' : '';
  final digits = sign.isEmpty ? integerPart : integerPart.substring(1);
  final grouped = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      grouped.write(',');
    }
    grouped.write(digits[index]);
  }

  return '$sign$grouped.${parts[1]}';
}

String formatLoanMoneyOrDash(double? value) =>
    value == null || value.abs() < 0.005 ? '—' : formatLoanMoney(value);

/// Masks monetary content without changing the underlying calculation value.
String formatLoanMoneyProtected(
  double? value, {
  required bool masked,
  bool dashWhenEmpty = false,
}) {
  if (masked) return '****';
  return dashWhenEmpty
      ? formatLoanMoneyOrDash(value)
      : formatLoanMoney(value ?? 0);
}

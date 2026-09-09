import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared editable field used by the mobile loan settings surfaces.
class LoanMobileInputField extends StatelessWidget {
  const LoanMobileInputField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.suffix,
    this.integer = false,
    this.date = false,
    this.enabled = true,
    this.amountsMasked = false,
    this.onChanged,
    this.onPickDate,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String suffix;
  final bool integer;
  final bool date;
  final bool enabled;
  final bool amountsMasked;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onPickDate;

  @override
  Widget build(BuildContext context) {
    final fieldEnabled = enabled && !(suffix == '元' && amountsMasked);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: fieldEnabled,
        readOnly: date,
        onTap: date && fieldEnabled ? onPickDate : null,
        onChanged: onChanged,
        obscureText: suffix == '元' && amountsMasked,
        obscuringCharacter: '*',
        keyboardType: date
            ? TextInputType.datetime
            : TextInputType.numberWithOptions(decimal: !integer),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(
              date
                  ? r'[0-9-]'
                  : integer
                  ? r'[0-9]'
                  : r'[0-9.]',
            ),
          ),
        ],
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.primary,
        ),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          hintText: date ? 'YYYY-MM-DD' : null,
          suffixIcon: date
              ? IconButton(
                  tooltip: '选择还贷日期',
                  onPressed: fieldEnabled ? onPickDate : null,
                  icon: const Icon(Icons.calendar_month_outlined),
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
        ),
      ),
    );
  }
}

/// Shared calculated/read-only field used by mobile loan surfaces.
class LoanMobileReadonlyField extends StatelessWidget {
  const LoanMobileReadonlyField({
    super.key,
    required this.label,
    required this.value,
    required this.suffix,
    this.highlight = false,
    this.amountsMasked = false,
  });

  final String label;
  final String value;
  final String suffix;
  final bool highlight;
  final bool amountsMasked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
          filled: highlight,
          fillColor: highlight ? colors.primaryContainer : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
        ),
        child: Text(
          suffix == '元' && amountsMasked ? '****' : value,
          style: TextStyle(
            fontSize: 14,
            color: highlight ? colors.primary : colors.onSurfaceVariant,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

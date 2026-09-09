import 'package:flutter_test/flutter_test.dart';
import 'package:loan_repayment_manager/core/extensions/string_extensions.dart';

void main() {
  test('detects blank strings without changing non-blank content', () {
    expect('  '.isBlank, isTrue);
    expect('\n'.isBlank, isTrue);
    expect('  12  '.isBlank, isFalse);
  });

  test('parses integers with an explicit fallback', () {
    expect('12'.toIntOr(0), 12);
    expect('not-a-number'.toIntOr(7), 7);
  });

  test('parses doubles with an explicit fallback', () {
    expect('12.5'.toDoubleOr(0), 12.5);
    expect('not-a-number'.toDoubleOr(7.5), 7.5);
  });
}

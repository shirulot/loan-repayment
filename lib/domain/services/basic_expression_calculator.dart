/// Evaluates the four basic operations used by the in-app calculator.
/// References are resolved by the caller before parsing, so the service stays
/// independent from the repayment-plan data model.
class BasicExpressionCalculator {
  const BasicExpressionCalculator();

  double evaluate(String expression, Map<String, double> references) {
    final resolved = expression.replaceAllMapped(RegExp(r'【([^】]+)】'), (match) {
      final value = references[match.group(1)];
      if (value == null) throw const FormatException('包含无法识别的引用值');
      return value.toString();
    });
    final parser = _ExpressionParser(
      resolved.replaceAll('×', '*').replaceAll('÷', '/'),
    );
    final value = parser.parse();
    if (!value.isFinite) throw const FormatException('计算结果无效');
    return value;
  }
}

class _ExpressionParser {
  _ExpressionParser(this.source);

  final String source;
  var _index = 0;

  double parse() {
    final value = _readSum();
    _skipWhitespace();
    if (_index != source.length) throw const FormatException('算式格式不正确');
    return value;
  }

  double _readSum() {
    var value = _readProduct();
    while (true) {
      _skipWhitespace();
      if (_take('+')) {
        value += _readProduct();
      } else if (_take('-')) {
        value -= _readProduct();
      } else {
        return value;
      }
    }
  }

  double _readProduct() {
    var value = _readValue();
    while (true) {
      _skipWhitespace();
      if (_take('*')) {
        value *= _readValue();
      } else if (_take('/')) {
        final divisor = _readValue();
        if (divisor == 0) throw const FormatException('除数不能为 0');
        value /= divisor;
      } else if (_take('%')) {
        final divisor = _readValue();
        if (divisor == 0) throw const FormatException('除数不能为 0');
        value %= divisor;
      } else {
        return value;
      }
    }
  }

  double _readValue() {
    _skipWhitespace();
    if (_take('+')) return _readValue();
    if (_take('-')) return -_readValue();
    if (_take('(')) {
      final value = _readSum();
      _skipWhitespace();
      if (!_take(')')) throw const FormatException('缺少右括号');
      return value;
    }
    final start = _index;
    while (_index < source.length && '0123456789.'.contains(source[_index])) {
      _index++;
    }
    if (start == _index) throw const FormatException('缺少数字或引用值');
    return double.tryParse(source.substring(start, _index)) ??
        (throw const FormatException('数字格式不正确'));
  }

  bool _take(String character) {
    if (_index >= source.length || source[_index] != character) return false;
    _index++;
    return true;
  }

  void _skipWhitespace() {
    while (_index < source.length && source[_index].trim().isEmpty) {
      _index++;
    }
  }
}

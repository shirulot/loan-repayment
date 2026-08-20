import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/services/loan_cache_service.dart';
import '../../../../domain/models/loan_models.dart';
import '../../../../domain/services/loan_calculator.dart';

class LoanPlannerViewModel extends ChangeNotifier {
  LoanPlannerViewModel({
    LoanCalculator? calculator,
    LoanCacheService? cacheService,
  }) : _calculator = calculator ?? const LoanCalculator(),
       _cacheService = cacheService ?? const LoanCacheService() {
    _actualPrepayments[_calculator.startMonth] = 17500;
    _recalculate();
  }

  final LoanCalculator _calculator;
  final LoanCacheService _cacheService;
  LoanPlanConfig _config = const LoanPlanConfig();
  final Map<String, double?> _actualPrepayments = <String, double?>{};
  List<LoanPlanRow> _rows = const <LoanPlanRow>[];
  Future<void> _pendingSave = Future<void>.value();

  LoanPlanConfig get config => _config;
  List<LoanPlanRow> get rows => List.unmodifiable(_rows);
  Map<String, double?> get actualPrepayments =>
      Map.unmodifiable(_actualPrepayments);

  int get calculatedRemainingTerms =>
      _config.remainingTermsAt(_calculator.currentDate ?? DateTime.now());

  String get expectedFinishMonth {
    final row = _rows.firstWhere(
      (item) => item.totalBalance < 0.01,
      orElse: () => _rows.last,
    );
    return row.month;
  }

  int get actualOverrideCount =>
      _actualPrepayments.values.where((value) => value != null).length;

  /// The first row is a balance-calibration month and has no normal payment.
  /// Use the first following row for the monthly cash-flow display.
  double get currentMonthlyPayment {
    if (_rows.length > 1) return _rows[1].totalPayment;
    return _rows.isEmpty ? 0 : _rows.first.totalPayment;
  }

  /// Uses the same normal-payment row as [currentMonthlyPayment].
  double get currentAvailablePrepayment {
    if (_rows.length > 1) return _rows[1].availableFunds;
    return _config.monthlySalary -
        currentMonthlyPayment -
        _config.monthlyLivingCost +
        _config.monthlyExtraIncome;
  }

  List<String> get fixedPrepaymentMonths =>
      List.unmodifiable(List<String>.generate(3, _calculator.monthAt));

  /// Loads the last editable state before the first frame is rendered.
  Future<void> loadCachedState() async {
    try {
      final cachedState = await _cacheService.load();
      if (cachedState != null) {
        _config = cachedState.config;
        _actualPrepayments
          ..clear()
          ..addAll(cachedState.actualPrepayments);
      }
    } catch (_) {
      // A missing or unavailable cache falls back to the default model.
    }
    _recalculate();
  }

  void updateActualPrepayment(String month, double? value) {
    if (value == null) {
      _actualPrepayments.remove(month);
    } else {
      _actualPrepayments[month] = value;
    }
    _recalculate();
    _persist();
  }

  void updateConfig(LoanPlanConfig config) {
    _config = config;
    _recalculate();
    _persist();
  }

  void reset() {
    _config = const LoanPlanConfig();
    _actualPrepayments
      ..clear()
      ..[_calculator.startMonth] = 17500;
    _recalculate();
    _persist();
  }

  void _recalculate() {
    _rows = _calculator.calculate(_config, _actualPrepayments);
    notifyListeners();
  }

  void _persist() {
    final config = _config;
    final actualPrepayments = Map<String, double?>.from(_actualPrepayments);
    // Queue writes so rapid edits cannot finish out of order and restore stale data.
    _pendingSave = _pendingSave.then((_) async {
      try {
        await _cacheService.save(config, actualPrepayments);
      } catch (_) {
        // A cache failure must not interrupt editing or calculation.
      }
    });
    unawaited(_pendingSave);
  }
}

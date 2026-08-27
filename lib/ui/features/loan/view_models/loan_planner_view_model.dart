import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/services/loan_cache_service.dart';
import '../../../../domain/models/loan_models.dart';
import '../../../../domain/services/loan_calculator.dart';

class LoanPlannerViewModel extends ChangeNotifier {
  LoanPlannerViewModel({
    LoanCalculator? calculator,
    LoanCacheService? cacheService,
    LoanPlanConfig initialConfig = const LoanPlanConfig(),
  }) : _calculator = calculator ?? const LoanCalculator(),
       _cacheService = cacheService ?? const LoanCacheService(),
       _config = initialConfig {
    _recalculate();
  }

  final LoanCalculator _calculator;
  final LoanCacheService _cacheService;
  LoanPlanConfig _config;
  final Map<String, double?> _actualPrepayments = <String, double?>{};
  List<LoanPlanRow> _rows = const <LoanPlanRow>[];
  Future<void> _pendingSave = Future<void>.value();
  bool _amountsMasked = false;

  LoanPlanConfig get config => _config;
  List<LoanPlanRow> get rows => List.unmodifiable(_rows);
  Map<String, double?> get actualPrepayments =>
      Map.unmodifiable(_actualPrepayments);

  /// 仅用于当前界面展示，避免将隐私显示偏好写入贷款数据缓存。
  bool get amountsMasked => _amountsMasked;

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

  /// 首行是余额校准月，当前月供展示紧随其后的银行实扣月供。
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

  /// Historical settled records are used to fill an empty recent-event slot.
  List<RecentPrepayment> get settledPrepaymentCandidates {
    final candidates = <RecentPrepayment>[
      for (final event in _config.recentPrepayments)
        if (event.actualPrepayment != null &&
            event.actualPrepayment! > 0 &&
            LoanPlanConfig.parseLoanStartDate(event.repaymentDate) != null)
          event.copyWith(isSettled: true),
    ];
    for (final row in _rows) {
      final amount = _actualPrepayments[row.month];
      if (amount == null || amount <= 0) continue;
      candidates.add(
        RecentPrepayment(
          id: 'settled-${row.month}',
          amount: amount,
          repaymentDate: row.effectivePrepaymentDate ?? '${row.month}-01',
          isSettled: true,
        ),
      );
    }
    candidates.sort(
      (left, right) => right.repaymentDate.compareTo(left.repaymentDate),
    );
    return List.unmodifiable(candidates);
  }

  RecentPrepayment? get latestSettledPrepayment {
    final candidates = settledPrepaymentCandidates;
    return candidates.isEmpty ? null : candidates.first;
  }

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

  /// Records the actual principal for one event without changing other events
  /// that happen to share the same calendar month.
  void updateRecentPrepaymentActual(String eventId, double? value) {
    _config = _config.copyWith(
      recentPrepayments: _config.recentPrepayments
          .map(
            (event) => event.id == eventId
                ? event.copyWith(
                    actualPrepayment: value,
                    clearActualPrepayment: value == null,
                    isSettled: value != null,
                  )
                : event,
          )
          .toList(growable: false),
    );
    _recalculate();
    _persist();
  }

  /// Applies a user-selected backup and persists it as the new local state.
  void restoreImportedState(LoanCachedState state) {
    _config = state.config;
    _actualPrepayments
      ..clear()
      ..addAll(state.actualPrepayments);
    _recalculate();
    _persist();
  }

  /// 在首页与计划详情间共享金额脱敏状态。
  void toggleAmountsMasked() {
    _amountsMasked = !_amountsMasked;
    notifyListeners();
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

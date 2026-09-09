import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:lunar/lunar.dart';

import '../../../../data/services/loan_cache_service.dart';
import '../../../../domain/models/loan_models.dart';
import '../../../../domain/services/loan_calculator.dart';

/// A numeric value that can be inserted into the calculator expression.
class CalculatorReference {
  const CalculatorReference({
    required this.label,
    required this.value,
    this.isHomeSummary = false,
    this.isPlanValue = false,
    this.searchKeywords = const [],
  });

  final String label;
  final double value;
  final bool isHomeSummary;
  final bool isPlanValue;
  final List<String> searchKeywords;
}

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
  final List<CalculatorReference> _temporaryCalculatorReferences = [];
  var _nextTemporaryCalculatorReference = 1;
  var _calculatorExpression = '';

  LoanPlanConfig get config => _config;
  List<LoanPlanRow> get rows => List.unmodifiable(_rows);
  Map<String, double?> get actualPrepayments =>
      Map.unmodifiable(_actualPrepayments);

  /// 仅用于当前界面展示，避免将隐私显示偏好写入贷款数据缓存。
  bool get amountsMasked => _amountsMasked;

  /// 向界面暴露与还款计划一致的计算日期，避免预览使用另一套时钟。
  DateTime get calculationDate => _calculator.calculationDate;

  int get calculatedRemainingTerms => _config.remainingTermsAt(calculationDate);

  String get expectedFinishMonth {
    final row = _rows.firstWhere(
      (item) => item.totalBalance < 0.01,
      orElse: () => _rows.last,
    );
    return row.month;
  }

  int get actualOverrideCount =>
      _actualPrepayments.values.where((value) => value != null).length;

  LoanPlanRow? get _currentPlanRow {
    final currentMonth = _calculator.monthAt(0);
    for (final row in _rows) {
      if (row.month == currentMonth) return row;
    }
    return null;
  }

  LoanPlanRow? get _nextPlanRow {
    final nextMonth = _calculator.monthAt(1);
    for (final row in _rows) {
      if (row.month == nextMonth) return row;
    }
    return null;
  }

  /// 首行是余额校准月，当前月供展示紧随其后的银行实扣月供。
  double get currentMonthlyPayment {
    final current = _currentPlanRow;
    // 首行仅校准当前余额时，首页仍展示紧随其后的首笔银行月供。
    if (current != null && identical(current, _rows.first)) {
      return _nextPlanRow?.totalPayment ?? current.totalPayment;
    }
    return current?.totalPayment ?? 0;
  }

  /// Uses the same normal-payment row as [currentMonthlyPayment].
  double get currentAvailablePrepayment {
    final current = _currentPlanRow;
    if (current != null && !identical(current, _rows.first)) {
      return current.availableFunds;
    }
    if (_nextPlanRow != null) return _nextPlanRow!.availableFunds;
    return _config.monthlySalary -
        currentMonthlyPayment -
        _config.monthlyLivingCost +
        _config.monthlyExtraIncome;
  }

  /// 当前余额仅扣除已实际录入或日期已到的提前还款，不预扣本月未来预约。
  double get currentCommercialBalance => _currentBalances().$1;

  /// 当前余额仅扣除已实际录入或日期已到的提前还款，不预扣本月未来预约。
  double get currentProvidentBalance => _currentBalances().$2;

  (double, double) _currentBalances() {
    final currentRow = _currentPlanRow;
    if (currentRow == null) {
      // A prior month may have fully settled both loans. Keep its history row,
      // but never restore the editable opening principal as a current balance.
      if (_rows.isNotEmpty && _rows.last.totalBalance < 0.01) {
        return (0, 0);
      }
      return (
        _config.commercialOpeningBalance,
        _config.providentOpeningBalance,
      );
    }
    var commercial = currentRow.commercialOpening;
    var provident = currentRow.providentOpening;
    var normalPaymentApplied = false;

    final today = _calculator.calculationDate;
    for (final detail in currentRow.prepaymentDetails) {
      final date = LoanPlanConfig.parseLoanStartDate(
        detail.repaymentDate ?? '',
      );
      final isActual = detail.actualPrepayment != null;
      final isDue = date != null && !date.isAfter(today);
      if (!isActual && !isDue) continue;

      // The first detail applies the month's normal payment before its own
      // prepayment. Later payment values are display-only previews.
      if (!normalPaymentApplied && detail.hasNormalPaymentBefore) {
        normalPaymentApplied = true;
        commercial = math
            .max(0.0, commercial - detail.commercialPrincipalBefore)
            .toDouble();
        provident = math
            .max(0.0, provident - detail.providentPrincipalBefore)
            .toDouble();
      }

      final commercialPart = detail.amount.clamp(0.0, commercial).toDouble();
      commercial -= commercialPart;
      provident -= (detail.amount - commercialPart).clamp(0.0, provident);
    }
    return (commercial, provident);
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
    // Old backups recorded a single actual amount for a whole month. Keep them
    // readable, but never use this fallback for event-based repayment data:
    // multiple transactions in one month must be ordered by their dates.
    final eventMonths = candidates
        .map((event) => event.repaymentDate.substring(0, 7))
        .toSet();
    for (final row in _rows) {
      if (eventMonths.contains(row.month)) continue;
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

  /// The home summary follows the repayment table: use the latest dated entry
  /// that is not later than today, whether it is planned or already settled.
  RecentPrepayment? get latestPrepaymentOnOrBeforeToday {
    final today = DateTime(
      calculationDate.year,
      calculationDate.month,
      calculationDate.day,
    );
    RecentPrepayment? latest;
    DateTime? latestDate;
    for (final row in _rows) {
      for (final detail in row.prepaymentDetails) {
        final date = LoanPlanConfig.parseLoanStartDate(
          detail.repaymentDate ?? '',
        );
        if (date == null || date.isAfter(today)) continue;
        if (latestDate != null && !date.isAfter(latestDate)) continue;
        latestDate = date;
        latest = RecentPrepayment(
          id: detail.eventId ?? '${row.month}-${detail.repaymentDate}',
          amount: detail.expectedAmount,
          actualPrepayment: detail.actualPrepayment,
          repaymentDate: detail.repaymentDate!,
          isSettled: detail.actualPrepayment != null,
        );
      }
    }
    return latest;
  }

  /// Numeric values shown on the home page, plus its expandable parameters.
  List<CalculatorReference> get calculatorReferences {
    return List.unmodifiable([
      CalculatorReference(
        label: '本月收入',
        value: _config.monthlySalary,
        isHomeSummary: true,
      ),
      CalculatorReference(
        label: '额外收入',
        value: _config.monthlyExtraIncome,
        isHomeSummary: true,
      ),
      CalculatorReference(
        label: '当月月供',
        value: currentMonthlyPayment,
        isHomeSummary: true,
      ),
      CalculatorReference(
        label: '每月生活费',
        value: _config.monthlyLivingCost,
        isHomeSummary: true,
      ),
      CalculatorReference(
        label: '可供提前还贷额',
        value: currentAvailablePrepayment,
        isHomeSummary: true,
      ),
      CalculatorReference(
        label: '当前贷款余额',
        value: currentCommercialBalance + currentProvidentBalance,
        isHomeSummary: true,
      ),
      CalculatorReference(label: '当前商贷余额', value: currentCommercialBalance),
      CalculatorReference(label: '当前公积金余额', value: currentProvidentBalance),
      CalculatorReference(
        label: '初期商贷本金',
        value: _config.commercialOpeningBalance,
      ),
      CalculatorReference(
        label: '初期公积金本金',
        value: _config.providentOpeningBalance,
      ),
      CalculatorReference(
        label: '商贷年利率',
        value: _config.commercialAnnualRate * 100,
      ),
      CalculatorReference(
        label: '公积金年利率',
        value: _config.providentAnnualRate * 100,
      ),
      CalculatorReference(
        label: '剩余期数',
        value: calculatedRemainingTerms.toDouble(),
      ),
      ..._temporaryCalculatorReferences,
      ..._planRowCalculatorReferences(),
    ]);
  }

  Map<String, double> get calculatorReferenceValues => Map.unmodifiable({
    for (final reference in calculatorReferences)
      reference.label: reference.value,
  });

  /// Matches visible labels and month aliases such as `8月` and `八月`.
  bool matchesCalculatorReference(CalculatorReference reference, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return !reference.isPlanValue;
    final searchText =
        '${reference.label} ${reference.searchKeywords.join(' ')}'
            .toLowerCase();
    if (searchText.contains(normalizedQuery)) return true;

    // Combined searches are AND queries over their recognizable date fragments.
    final fragments = RegExp(
      r'(?:20)?\d{2}年|\d{1,2}月|[一二三四五六七八九十]+月|农历',
    ).allMatches(normalizedQuery).map((match) => match.group(0)!).toSet();
    return fragments.isNotEmpty && fragments.every(searchText.contains);
  }

  List<CalculatorReference> _planRowCalculatorReferences() {
    final references = <CalculatorReference>[];
    for (final row in _rows) {
      final keywords = _monthSearchKeywords(row.month);
      void add(String column, double? value) {
        if (value == null) return;
        references.add(
          CalculatorReference(
            label: '${row.month} $column',
            value: value,
            isPlanValue: true,
            searchKeywords: keywords,
          ),
        );
      }

      add('商贷月供', row.commercialPayment);
      add('商贷减少', row.commercialReduction);
      add('公积金月供', row.providentPayment);
      add('公积金减少', row.providentReduction);
      add('月供合计', row.totalPayment);
      add('总额减少', row.totalReduction);
      add('预期提前', row.expectedPrepayment);
      add('实际提前', row.actualPrepayment);
      add('当日提前利息', row.prepaymentInterestDueNow);
      add('转息前月供', row.nextMonthBasePayment);
      add('转息差额', row.transferDifference);
      add('转息前月供减少', row.nextMonthBasePaymentReduction);
      add('商贷余额', row.commercialClosing);
      add('公积金余额', row.providentClosing);
      add('本金合计', row.totalBalance);
    }
    return references;
  }

  List<String> _monthSearchKeywords(String month) {
    final match = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(month);
    if (match == null) return [month];
    final year = int.parse(match.group(1)!);
    final monthNumber = int.parse(match.group(2)!);
    final lunar = Solar.fromYmd(year, monthNumber, 1).getLunar();
    final lunarMonth = lunar.getMonth().abs();
    final lunarChineseMonth = _chineseMonth(lunarMonth);
    return [
      month,
      '$year年$monthNumber月',
      '${year % 100}年$monthNumber月',
      '$monthNumber月',
      _chineseMonth(monthNumber),
      '${lunar.getYear()}农历$lunarMonth月',
      '${lunar.getYear()}农历$lunarChineseMonth',
      '农历$lunarMonth月',
      '农历$lunarChineseMonth',
      '$lunarMonth月',
      lunarChineseMonth,
      '农历',
    ];
  }

  String _chineseMonth(int month) => const [
    '',
    '一月',
    '二月',
    '三月',
    '四月',
    '五月',
    '六月',
    '七月',
    '八月',
    '九月',
    '十月',
    '十一月',
    '十二月',
  ][month];

  List<CalculatorReference> get temporaryCalculatorReferences =>
      List.unmodifiable(_temporaryCalculatorReferences);

  String get calculatorExpression => _calculatorExpression;

  /// Persists the unfinished calculator expression independently of loan edits.
  void updateCalculatorExpression(String value) {
    if (_calculatorExpression == value) return;
    _calculatorExpression = value;
    _persist();
  }

  void saveTemporaryCalculatorResult(double value) {
    _temporaryCalculatorReferences.add(
      CalculatorReference(
        label: '暂存结果 ${_nextTemporaryCalculatorReference++}',
        value: value,
      ),
    );
    _persist();
    notifyListeners();
  }

  void clearTemporaryCalculatorReferences() {
    if (_temporaryCalculatorReferences.isEmpty) return;
    _temporaryCalculatorReferences.clear();
    _persist();
    notifyListeners();
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
        _calculatorExpression = cachedState.calculatorExpression;
        _restoreTemporaryCalculatorResults(
          cachedState.temporaryCalculatorResults,
        );
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
    _calculatorExpression = state.calculatorExpression;
    _restoreTemporaryCalculatorResults(state.temporaryCalculatorResults);
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

  void _restoreTemporaryCalculatorResults(List<double> results) {
    _temporaryCalculatorReferences
      ..clear()
      ..addAll(
        results.indexed.map(
          (item) =>
              CalculatorReference(label: '暂存结果 ${item.$1 + 1}', value: item.$2),
        ),
      );
    _nextTemporaryCalculatorReference =
        _temporaryCalculatorReferences.length + 1;
  }

  void _persist() {
    final config = _config;
    final actualPrepayments = Map<String, double?>.from(_actualPrepayments);
    final calculatorExpression = _calculatorExpression;
    final temporaryCalculatorResults = _temporaryCalculatorReferences
        .map((reference) => reference.value)
        .toList(growable: false);
    // Queue writes so rapid edits cannot finish out of order and restore stale data.
    _pendingSave = _pendingSave.then((_) async {
      try {
        await _cacheService.save(
          config,
          actualPrepayments,
          calculatorExpression: calculatorExpression,
          temporaryCalculatorResults: temporaryCalculatorResults,
        );
      } catch (_) {
        // A cache failure must not interrupt editing or calculation.
      }
    });
    unawaited(_pendingSave);
  }
}

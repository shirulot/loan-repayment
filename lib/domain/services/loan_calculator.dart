import 'dart:math' as math;

import '../models/loan_models.dart';

class LoanCalculator {
  const LoanCalculator({this.currentDate});

  final DateTime? currentDate;

  String get startMonth => monthAt(0);

  List<LoanPlanRow> calculate(
    LoanPlanConfig config,
    Map<String, double?> actualPrepayments,
  ) {
    var commercialOpening = config.commercialOpeningBalance;
    var providentOpening = config.providentOpeningBalance;
    final calculationDate = currentDate ?? DateTime.now();
    var remainingTerms = config.remainingTermsAt(calculationDate);
    var commercialDeferredInterest = 0.0;
    var providentDeferredInterest = 0.0;
    final rows = <LoanPlanRow>[];

    // The limit is only a safety net for invalid configurations that cannot make progress.
    const maxCalculationMonths = 1200;
    for (var index = 0; index < maxCalculationMonths; index++) {
      final month = monthAt(index);
      final isCalibrationMonth = index == 0;
      final openingBalance = commercialOpening + providentOpening;

      final commercialPrincipal = _commercialPrincipal(
        index: index,
        opening: commercialOpening,
        remainingTerms: remainingTerms,
        config: config,
      );
      final commercialInterest =
          _commercialInterest(
            index: index,
            opening: commercialOpening,
            config: config,
          ) +
          commercialDeferredInterest;
      final providentPrincipal = isCalibrationMonth
          ? 0.0
          : _normalPrincipal(providentOpening, remainingTerms);
      final providentInterest =
          (isCalibrationMonth
              ? 0.0
              : providentOpening * config.providentAnnualRate / 12) +
          providentDeferredInterest;
      final commercialPayment = commercialPrincipal + commercialInterest;
      final providentPayment = providentPrincipal + providentInterest;
      final totalPayment = commercialPayment + providentPayment;
      // Keep the cash-flow amount aligned with the editable fields shown on
      // the first page: income - payment - living cost + extra income.
      final availableFunds =
          config.monthlySalary -
          totalPayment -
          config.monthlyLivingCost +
          config.monthlyExtraIncome;

      final requestedPrepayment = _requestedPrepayment(
        index: index,
        availableFunds: availableFunds,
        config: config,
      );
      final remainingAfterNormalPayment =
          math.max(0.0, commercialOpening - commercialPrincipal).toDouble() +
          math.max(0.0, providentOpening - providentPrincipal).toDouble();
      // 预约金额始终按“向上取整到十元”展示；真正使用的金额仍会在下方
      // 按剩余本金封顶，避免最后一笔出现负余额。
      final expectedPrepayment = _roundUpToTen(
        math.min(requestedPrepayment, remainingAfterNormalPayment).toDouble(),
      );
      final actualPrepayment = actualPrepayments[month];
      final plannedPrepaymentDate = _plannedPrepaymentDate(index, config);
      final effectivePrepaymentDate = _validPrepaymentDate(
        plannedPrepaymentDate,
        month,
      );
      final usedPrepayment = math
          .min(
            actualPrepayment == null
                ? expectedPrepayment
                : math.max(0.0, actualPrepayment),
            remainingAfterNormalPayment,
          )
          .toDouble();

      final commercialPrepayment = math
          .min(
            usedPrepayment,
            math.max(0.0, commercialOpening - commercialPrincipal),
          )
          .toDouble();
      final providentPrepayment = math
          .min(
            math.max(0.0, usedPrepayment - commercialPrepayment),
            math.max(0.0, providentOpening - providentPrincipal),
          )
          .toDouble();
      final commercialClosing = math
          .max(
            0.0,
            commercialOpening - commercialPrincipal - commercialPrepayment,
          )
          .toDouble();
      final providentClosing = math
          .max(0.0, providentOpening - providentPrincipal - providentPrepayment)
          .toDouble();
      final prepaymentInterestDueNow =
          _interestDueOnRepaymentDay(
            prepayment: commercialPrepayment,
            annualRate: config.commercialAnnualRate,
            prepaymentDate: effectivePrepaymentDate,
          ) +
          _interestDueOnRepaymentDay(
            prepayment: providentPrepayment,
            annualRate: config.providentAnnualRate,
            prepaymentDate: effectivePrepaymentDate,
          );
      // 提前还款日后的剩余天数利息会附加到下一个月的月供。
      commercialDeferredInterest = _remainingMonthInterest(
        prepayment: commercialPrepayment,
        annualRate: config.commercialAnnualRate,
        prepaymentDate: effectivePrepaymentDate,
      );
      providentDeferredInterest = _remainingMonthInterest(
        prepayment: providentPrepayment,
        annualRate: config.providentAnnualRate,
        prepaymentDate: effectivePrepaymentDate,
      );
      final nextMonthBasePayment = _baseMonthlyPayment(
        commercialOpening: commercialOpening,
        providentOpening: providentOpening,
        remainingTerms: remainingTerms,
        config: config,
      );
      final previousRow = rows.isEmpty ? null : rows.last;
      final commercialReduction = index < 2 || previousRow == null
          ? null
          : previousRow.commercialPayment - commercialPayment;
      final providentReduction = index < 2 || previousRow == null
          ? null
          : previousRow.providentPayment - providentPayment;
      final totalReduction = index < 2 || previousRow == null
          ? null
          : previousRow.totalPayment - totalPayment;
      final nextMonthBasePaymentReduction = previousRow == null
          ? null
          : previousRow.nextMonthBasePayment - nextMonthBasePayment;

      rows.add(
        LoanPlanRow(
          month: month,
          remainingTerms: remainingTerms,
          commercialOpening: commercialOpening,
          commercialPrincipal: commercialPrincipal,
          commercialInterest: commercialInterest,
          commercialPayment: commercialPayment,
          providentOpening: providentOpening,
          providentPrincipal: providentPrincipal,
          providentInterest: providentInterest,
          providentPayment: providentPayment,
          totalPayment: totalPayment,
          commercialReduction: commercialReduction,
          providentReduction: providentReduction,
          totalReduction: totalReduction,
          availableFunds: availableFunds,
          expectedPrepayment: expectedPrepayment,
          actualPrepayment: actualPrepayment,
          plannedPrepaymentDate: plannedPrepaymentDate,
          effectivePrepaymentDate: effectivePrepaymentDate,
          prepaymentInterestDueNow: prepaymentInterestDueNow,
          nextMonthBasePayment: nextMonthBasePayment,
          nextMonthBasePaymentReduction: nextMonthBasePaymentReduction,
          usedPrepayment: usedPrepayment,
          commercialPrepayment: commercialPrepayment,
          providentPrepayment: providentPrepayment,
          commercialClosing: commercialClosing,
          providentClosing: providentClosing,
        ),
      );

      commercialOpening = commercialClosing;
      providentOpening = providentClosing;
      if (!isCalibrationMonth) {
        remainingTerms = math.max(0, remainingTerms - 1).toInt();
      }

      final closingBalance = commercialClosing + providentClosing;
      final pendingInterest =
          commercialDeferredInterest + providentDeferredInterest;
      if (closingBalance < 0.01 && pendingInterest < 0.01) break;
      // 首行只负责按当前余额校准；后续若本金无法下降则停止，避免死循环。
      if (!isCalibrationMonth &&
          openingBalance - closingBalance <= 0.000001 &&
          pendingInterest < 0.01) {
        break;
      }
    }
    return rows;
  }

  /// Returns the month at [index] relative to the current calendar month.
  String monthAt(int index) {
    final now = currentDate ?? DateTime.now();
    final date = DateTime(now.year, now.month + index);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  double _commercialPrincipal({
    required int index,
    required double opening,
    required int remainingTerms,
    required LoanPlanConfig config,
  }) {
    if (index == 0 || opening <= 0 || remainingTerms <= 0) return 0;
    if (index == 1 && config.bankSeptemberPrincipal > 0) {
      return math.min(opening, config.bankSeptemberPrincipal);
    }
    return _normalPrincipal(opening, remainingTerms);
  }

  double _commercialInterest({
    required int index,
    required double opening,
    required LoanPlanConfig config,
  }) {
    if (index == 0 || opening <= 0) return 0;
    if (index == 1 && config.bankSeptemberInterest > 0) {
      return config.bankSeptemberInterest;
    }
    return opening * config.commercialAnnualRate / 12;
  }

  double _normalPrincipal(double opening, int remainingTerms) {
    if (opening <= 0 || remainingTerms <= 0) return 0;
    return math.min(opening, opening / remainingTerms);
  }

  double _requestedPrepayment({
    required int index,
    required double availableFunds,
    required LoanPlanConfig config,
  }) {
    if (index == 0) {
      return _recentExpectedOrAvailable(
        config.fixedAugustPrepayment,
        availableFunds,
      );
    }
    if (index == 1) {
      return _recentExpectedOrAvailable(
        config.fixedSeptemberPrepayment,
        availableFunds,
      );
    }
    if (index == 2) {
      return _recentExpectedOrAvailable(
        config.fixedOctoberPrepayment,
        availableFunds,
      );
    }
    // The available amount rises naturally as normal monthly payments decline.
    return math.max(0, availableFunds);
  }

  String? _plannedPrepaymentDate(int index, LoanPlanConfig config) {
    return switch (index) {
      0 => config.fixedAugustPrepaymentDate,
      1 => config.fixedSeptemberPrepaymentDate,
      2 => config.fixedOctoberPrepaymentDate,
      _ => null,
    };
  }

  String? _validPrepaymentDate(String? value, String month) {
    if (value == null || value.trim().isEmpty) return null;
    final date = LoanPlanConfig.parseLoanStartDate(value);
    if (date == null ||
        '${date.year}-${date.month.toString().padLeft(2, '0')}' != month) {
      return null;
    }
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 按实际自然月天数，计算提前还款日已产生的利息。
  double _interestDueOnRepaymentDay({
    required double prepayment,
    required double annualRate,
    required String? prepaymentDate,
  }) {
    if (prepayment <= 0 || annualRate <= 0 || prepaymentDate == null) return 0;
    return prepayment *
        annualRate /
        _daysInYear(prepaymentDate) *
        _elapsedDays(prepaymentDate);
  }

  /// 将本自然月内尚未经过的天数利息附加到下个月月供。
  double _remainingMonthInterest({
    required double prepayment,
    required double annualRate,
    required String? prepaymentDate,
  }) {
    if (prepayment <= 0 || annualRate <= 0 || prepaymentDate == null) return 0;
    return prepayment *
        annualRate /
        _daysInYear(prepaymentDate) *
        _remainingDaysInMonth(prepaymentDate);
  }

  int _elapsedDays(String prepaymentDate) {
    return LoanPlanConfig.parseLoanStartDate(prepaymentDate)?.day ?? 1;
  }

  int _remainingDaysInMonth(String prepaymentDate) {
    final date = LoanPlanConfig.parseLoanStartDate(prepaymentDate);
    if (date == null) return 0;
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    return daysInMonth - date.day;
  }

  /// 日息分母使用当前年份的实际天数，闰年为 366 天。
  int _daysInYear(String prepaymentDate) {
    final year = LoanPlanConfig.parseLoanStartDate(prepaymentDate)?.year;
    if (year == null) return 365;
    return DateTime(year + 1, 1).difference(DateTime(year, 1)).inDays;
  }

  /// 只按当月余额、剩余期数及两类利率计算转息前基础月供。
  double _baseMonthlyPayment({
    required double commercialOpening,
    required double providentOpening,
    required int remainingTerms,
    required LoanPlanConfig config,
  }) {
    // 不使用银行账单、结转息和当月提前还款后的余额。
    final commercialPrincipal = _normalPrincipal(
      commercialOpening,
      remainingTerms,
    );
    final commercialInterest =
        commercialOpening * config.commercialAnnualRate / 12;
    final providentPrincipal = _normalPrincipal(
      providentOpening,
      remainingTerms,
    );
    final providentInterest =
        providentOpening * config.providentAnnualRate / 12;
    return commercialPrincipal +
        commercialInterest +
        providentPrincipal +
        providentInterest;
  }

  /// A recent expected amount takes priority; empty and zero values use cash flow.
  double _recentExpectedOrAvailable(
    double expectedAmount,
    double availableFunds,
  ) {
    return expectedAmount > 0 ? expectedAmount : math.max(0, availableFunds);
  }

  double _roundUpToTen(double value) {
    if (value <= 0) return 0;
    final quotient = value / 10;
    final nearestInteger = quotient.roundToDouble();
    // Avoid turning an exact multiple of ten into the next ten because of
    // floating-point noise in the interest calculation.
    final units = (quotient - nearestInteger).abs() < 0.0000001
        ? nearestInteger
        : quotient.ceilToDouble();
    return (units * 10).toDouble();
  }
}

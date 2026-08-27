import 'dart:math' as math;

import '../models/loan_models.dart';

class LoanCalculator {
  const LoanCalculator({this.currentDate});

  final DateTime? currentDate;
  static const _prepaymentInterestDayBase = 360;

  String get startMonth => monthAt(0);

  List<LoanPlanRow> calculate(
    LoanPlanConfig config,
    Map<String, double?> actualPrepayments,
  ) {
    var commercialOpening = config.commercialOpeningBalance;
    var providentOpening = config.providentOpeningBalance;
    final calculationDate = currentDate ?? DateTime.now();
    var remainingTerms = config.remainingTermsAt(calculationDate);
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
      final commercialInterest = _commercialInterest(
        index: index,
        month: month,
        opening: commercialOpening,
        config: config,
      );
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

      final scheduledPrepayments = _scheduledPrepaymentsForMonth(
        config: config,
        month: month,
      );
      final requestedPrepayment = scheduledPrepayments.isNotEmpty
          ? scheduledPrepayments.fold<double>(
              0,
              (total, item) => total + item.amount,
            )
          : config.recentPrepayments.isNotEmpty
          ? math.max(0.0, availableFunds)
          : _requestedPrepayment(
              index: index,
              availableFunds: availableFunds,
              config: config,
            );
      final remainingAfterNormalPayment =
          math.max(0.0, commercialOpening - commercialPrincipal).toDouble() +
          math.max(0.0, providentOpening - providentPrincipal).toDouble();
      // 预约金额始终按“向上取整到十元”展示；真正使用的金额仍会在下方
      // 按剩余本金封顶，避免最后一笔出现负余额。
      final expectedPrepayment = scheduledPrepayments.isNotEmpty
          ? math
                .min(requestedPrepayment, remainingAfterNormalPayment)
                .toDouble()
          : _roundUpToTen(
              math
                  .min(requestedPrepayment, remainingAfterNormalPayment)
                  .toDouble(),
            );
      final actualPrepayment = actualPrepayments[month];
      final prepayments = actualPrepayment == null
          ? scheduledPrepayments
          : <_ScheduledPrepayment>[
              _ScheduledPrepayment(
                amount: math.max(0.0, actualPrepayment),
                actualPrepayment: math.max(0.0, actualPrepayment),
                repaymentDate: scheduledPrepayments.isEmpty
                    ? _validPrepaymentDate(
                        _plannedPrepaymentDate(index, config),
                        month,
                      )
                    : scheduledPrepayments.first.repaymentDate,
              ),
            ];
      final appliedPrepayments = _applyPrepayments(
        prepayments: prepayments.isEmpty
            ? <_ScheduledPrepayment>[
                _ScheduledPrepayment(amount: expectedPrepayment),
              ]
            : prepayments,
        commercialBalance: math
            .max(0.0, commercialOpening - commercialPrincipal)
            .toDouble(),
        providentBalance: math
            .max(0.0, providentOpening - providentPrincipal)
            .toDouble(),
        config: config,
      );
      final plannedPrepaymentDate = scheduledPrepayments.isEmpty
          ? _plannedPrepaymentDate(index, config)
          : scheduledPrepayments.first.repaymentDate;
      final effectivePrepaymentDate = appliedPrepayments.dates.isEmpty
          ? null
          : appliedPrepayments.dates.first;
      final usedPrepayment = appliedPrepayments.usedPrepayment;
      final commercialPrepayment = appliedPrepayments.commercialPrepayment;
      final providentPrepayment = appliedPrepayments.providentPrepayment;
      final commercialClosing = appliedPrepayments.commercialClosing;
      final providentClosing = appliedPrepayments.providentClosing;
      final prepaymentInterestDueNow = appliedPrepayments.interestDueNow;
      providentDeferredInterest = appliedPrepayments.providentDeferredInterest;
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
          prepaymentDates: appliedPrepayments.dates,
          prepaymentDetails: appliedPrepayments.details,
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
      final pendingInterest = providentDeferredInterest;
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
    return _normalPrincipal(opening, remainingTerms);
  }

  double _commercialInterest({
    required int index,
    required String month,
    required double opening,
    required LoanPlanConfig config,
  }) {
    if (index == 0 || opening <= 0) return 0;
    final date = LoanPlanConfig.parseLoanStartDate('$month-01');
    if (date == null) return opening * config.commercialAnnualRate / 12;
    // 月供发生在当月 1 日，计息周期对应上一个完整自然月。
    // 例如 9 月月供对应 8 月 31 天，10 月月供对应 9 月 30 天。
    final daysInInterestMonth = DateTime(date.year, date.month, 0).day;
    // 商贷每一行都按对应计息月份的自然日数、360 天计息；转息不再额外叠加利息。
    return opening *
        config.commercialAnnualRate /
        _prepaymentInterestDayBase *
        daysInInterestMonth;
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

  List<_ScheduledPrepayment> _scheduledPrepaymentsForMonth({
    required LoanPlanConfig config,
    required String month,
  }) {
    final prepayments = <_ScheduledPrepayment>[];
    for (final event in config.recentPrepayments) {
      if (event.amount <= 0) continue;
      final dated = _validPrepaymentDate(event.repaymentDate, month);
      if (dated != null) {
        prepayments.add(
          _ScheduledPrepayment(
            eventId: event.id,
            amount: event.actualPrepayment ?? event.amount,
            expectedAmount: event.amount,
            actualPrepayment: event.actualPrepayment,
            repaymentDate: dated,
          ),
        );
        continue;
      }
    }
    prepayments.sort(
      (left, right) =>
          (left.repaymentDate ?? '').compareTo(right.repaymentDate ?? ''),
    );
    return prepayments;
  }

  _AppliedPrepayments _applyPrepayments({
    required List<_ScheduledPrepayment> prepayments,
    required double commercialBalance,
    required double providentBalance,
    required LoanPlanConfig config,
  }) {
    var remainingCommercial = commercialBalance;
    var remainingProvident = providentBalance;
    var commercialPrepayment = 0.0;
    var providentPrepayment = 0.0;
    var interestDueNow = 0.0;
    var providentDeferredInterest = 0.0;
    final dates = <String>[];
    final details = <LoanPrepaymentDetail>[];

    for (final prepayment in prepayments) {
      final used = math
          .min(
            math.max(0.0, prepayment.amount),
            remainingCommercial + remainingProvident,
          )
          .toDouble();
      final commercialPart = math.min(used, remainingCommercial).toDouble();
      final providentPart = math
          .min(math.max(0.0, used - commercialPart), remainingProvident)
          .toDouble();
      remainingCommercial -= commercialPart;
      remainingProvident -= providentPart;
      commercialPrepayment += commercialPart;
      providentPrepayment += providentPart;
      final date = prepayment.repaymentDate;
      final commercialInterestDueNow = _interestDueOnRepaymentDay(
        prepayment: commercialPart,
        annualRate: config.commercialAnnualRate,
        prepaymentDate: date,
      );
      final providentInterestDueNow = _interestDueOnRepaymentDay(
        prepayment: providentPart,
        annualRate: config.providentAnnualRate,
        prepaymentDate: date,
      );
      final providentDeferred = _remainingMonthInterest(
        prepayment: providentPart,
        annualRate: config.providentAnnualRate,
        prepaymentDate: date,
      );
      interestDueNow += commercialInterestDueNow + providentInterestDueNow;
      providentDeferredInterest += providentDeferred;
      if (date != null) dates.add(date);
      if (used > 0) {
        details.add(
          LoanPrepaymentDetail(
            eventId: prepayment.eventId,
            amount: used,
            expectedAmount: prepayment.expectedAmount ?? used,
            actualPrepayment: prepayment.actualPrepayment == null ? null : used,
            repaymentDate: date,
            interestDueNow: commercialInterestDueNow + providentInterestDueNow,
            nextMonthDeferredInterest: providentDeferred,
            commercialClosing: remainingCommercial,
            providentClosing: remainingProvident,
          ),
        );
      }
    }

    return _AppliedPrepayments(
      usedPrepayment: commercialPrepayment + providentPrepayment,
      commercialPrepayment: commercialPrepayment,
      providentPrepayment: providentPrepayment,
      commercialClosing: remainingCommercial,
      providentClosing: remainingProvident,
      interestDueNow: interestDueNow,
      providentDeferredInterest: providentDeferredInterest,
      dates: dates,
      details: details,
    );
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
        _prepaymentInterestDayBase *
        _elapsedDays(prepaymentDate);
  }

  /// Provident-fund repayment keeps the remaining-days carry convention.
  double _remainingMonthInterest({
    required double prepayment,
    required double annualRate,
    required String? prepaymentDate,
  }) {
    if (prepayment <= 0 || annualRate <= 0 || prepaymentDate == null) return 0;
    return prepayment *
        annualRate /
        _prepaymentInterestDayBase *
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

class _ScheduledPrepayment {
  const _ScheduledPrepayment({
    required this.amount,
    this.eventId,
    this.expectedAmount,
    this.actualPrepayment,
    this.repaymentDate,
  });

  final double amount;
  final String? eventId;
  final double? expectedAmount;
  final double? actualPrepayment;
  final String? repaymentDate;
}

class _AppliedPrepayments {
  const _AppliedPrepayments({
    required this.usedPrepayment,
    required this.commercialPrepayment,
    required this.providentPrepayment,
    required this.commercialClosing,
    required this.providentClosing,
    required this.interestDueNow,
    required this.providentDeferredInterest,
    required this.dates,
    required this.details,
  });

  final double usedPrepayment;
  final double commercialPrepayment;
  final double providentPrepayment;
  final double commercialClosing;
  final double providentClosing;
  final double interestDueNow;
  final double providentDeferredInterest;
  final List<String> dates;
  final List<LoanPrepaymentDetail> details;
}

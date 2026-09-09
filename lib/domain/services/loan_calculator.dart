import 'dart:math' as math;

import '../models/loan_models.dart';

class LoanCalculator {
  const LoanCalculator({this.currentDate});

  final DateTime? currentDate;
  static const _prepaymentInterestDayBase = 360;

  String get startMonth => monthAt(0);

  /// The date used to decide whether a scheduled prepayment has taken effect.
  DateTime get calculationDate => currentDate ?? DateTime.now();

  List<LoanPlanRow> calculate(
    LoanPlanConfig config,
    Map<String, double?> actualPrepayments,
  ) {
    var commercialOpening = config.commercialOpeningBalance;
    var providentOpening = config.providentOpeningBalance;
    final planStartDate = _planStartDate(config, actualPrepayments);
    var remainingTerms = config.remainingTermsAt(planStartDate);
    final rows = <LoanPlanRow>[];

    // The limit is only a safety net for invalid configurations that cannot make progress.
    const maxCalculationMonths = 1200;
    for (var index = 0; index < maxCalculationMonths; index++) {
      final month = _monthAt(planStartDate, index);
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
      final providentInterest = isCalibrationMonth
          ? 0.0
          : providentOpening * config.providentAnnualRate / 12;
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
      final legacyActualPrepayment = actualPrepayments[month];
      // Each dated event owns its actual amount. The old month-keyed value is
      // only retained for imported backups that predate event-based records.
      final eventActualPrepayment = scheduledPrepayments
          .where((prepayment) => prepayment.actualPrepayment != null)
          .fold<double>(0, (total, prepayment) => total + prepayment.amount);
      final actualPrepayment =
          legacyActualPrepayment ??
          (eventActualPrepayment > 0 ? eventActualPrepayment : null);
      final prepayments = legacyActualPrepayment == null
          ? scheduledPrepayments
          : <_ScheduledPrepayment>[
              _ScheduledPrepayment(
                amount: math.max(0.0, legacyActualPrepayment),
                actualPrepayment: math.max(0.0, legacyActualPrepayment),
                repaymentDate: scheduledPrepayments.isEmpty
                    ? _validPrepaymentDate(
                        _plannedPrepaymentDate(index, config),
                        month,
                      )
                    : scheduledPrepayments.first.repaymentDate,
              ),
            ];
      final hasMultiplePrepayments = prepayments.length > 1;
      // 多笔同月交易时，唯一一次月供要延后到第一笔提前还款之后重新计算。
      final normalPaymentAppliedInPlanRow =
          !isCalibrationMonth && !hasMultiplePrepayments;
      final appliedPrepayments = _applyPrepayments(
        prepayments: prepayments.isEmpty
            ? <_ScheduledPrepayment>[
                _ScheduledPrepayment(amount: expectedPrepayment),
              ]
            : prepayments,
        commercialBalance: math
            .max(
              0.0,
              commercialOpening -
                  (normalPaymentAppliedInPlanRow ? commercialPrincipal : 0),
            )
            .toDouble(),
        providentBalance: math
            .max(
              0.0,
              providentOpening -
                  (normalPaymentAppliedInPlanRow ? providentPrincipal : 0),
            )
            .toDouble(),
        remainingTermsForAdditionalPayment: normalPaymentAppliedInPlanRow
            ? math.max(0, remainingTerms - 1).toInt()
            : remainingTerms,
        normalPaymentAlreadyApplied: normalPaymentAppliedInPlanRow,
        paymentMonthStart: month,
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
      final normalPaymentsApplied =
          (normalPaymentAppliedInPlanRow ? 1 : 0) +
          appliedPrepayments.additionalNormalPayments;
      remainingTerms = math
          .max(0, remainingTerms - normalPaymentsApplied)
          .toInt();

      final closingBalance = commercialClosing + providentClosing;
      if (closingBalance < 0.01) break;
      // 首行只负责按当前余额校准；后续若本金无法下降则停止，避免死循环。
      if (!isCalibrationMonth && openingBalance - closingBalance <= 0.000001) {
        break;
      }
    }
    return rows;
  }

  /// Returns the month at [index] relative to the current calendar month.
  String monthAt(int index) {
    return _monthAt(calculationDate, index);
  }

  String _monthAt(DateTime startDate, int index) {
    final date = DateTime(startDate.year, startDate.month + index);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// Keeps the months containing confirmed repayments as auditable history.
  DateTime _planStartDate(
    LoanPlanConfig config,
    Map<String, double?> actualPrepayments,
  ) {
    final currentMonth = DateTime(calculationDate.year, calculationDate.month);
    var startDate = currentMonth;

    void consider(DateTime? date, double? amount) {
      if (date == null || amount == null || amount <= 0) return;
      final month = DateTime(date.year, date.month);
      if (month.isBefore(currentMonth) && month.isBefore(startDate)) {
        startDate = month;
      }
    }

    for (final entry in actualPrepayments.entries) {
      consider(
        LoanPlanConfig.parseLoanStartDate('${entry.key}-01'),
        entry.value,
      );
    }
    for (final event in config.recentPrepayments) {
      consider(
        LoanPlanConfig.parseLoanStartDate(event.repaymentDate),
        event.actualPrepayment,
      );
    }
    return startDate;
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
    return _commercialInterestForPaymentMonth(
      month: month,
      opening: opening,
      config: config,
    );
  }

  double _commercialInterestForPaymentMonth({
    required String month,
    required double opening,
    required LoanPlanConfig config,
  }) {
    if (opening <= 0) return 0;
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

  /// Calculates an optional normal-payment step between same-month
  /// prepayments. Interest is paid as part of that step; only principal
  /// reduces the loan balances. The caller controls whether the calendar
  /// row has already applied that month's normal payment.
  _NormalPayment _normalPayment({
    required double commercialOpening,
    required double providentOpening,
    required int remainingTerms,
    required String paymentMonth,
    required LoanPlanConfig config,
  }) {
    final commercialPrincipal = _normalPrincipal(
      commercialOpening,
      remainingTerms,
    );
    final commercialInterest = _commercialInterestForPaymentMonth(
      month: paymentMonth,
      opening: commercialOpening,
      config: config,
    );
    final providentPrincipal = _normalPrincipal(
      providentOpening,
      remainingTerms,
    );
    final providentInterest =
        providentOpening * config.providentAnnualRate / 12;
    return _NormalPayment(
      commercialPrincipal: commercialPrincipal,
      commercialInterest: commercialInterest,
      providentPrincipal: providentPrincipal,
      providentInterest: providentInterest,
    );
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
    required int remainingTermsForAdditionalPayment,
    required bool normalPaymentAlreadyApplied,
    required String paymentMonthStart,
    required LoanPlanConfig config,
  }) {
    var remainingCommercial = commercialBalance;
    var remainingProvident = providentBalance;
    var commercialPrepayment = 0.0;
    var providentPrepayment = 0.0;
    var interestDueNow = 0.0;
    var paymentRemainingTerms = remainingTermsForAdditionalPayment;
    var additionalNormalPayments = 0;
    // A calendar month may reduce principal through normal payment only once.
    var normalPaymentApplied = normalPaymentAlreadyApplied;
    // Later transaction rows retain the recalculated payment information for
    // display, but only the first transaction applies it to the balance.
    var normalPaymentForNextDetail = const _NormalPayment.zero();
    final dates = <String>[];
    final details = <LoanPrepaymentDetail>[];

    for (var index = 0; index < prepayments.length; index++) {
      final prepayment = prepayments[index];
      var normalPaymentBefore = index == 0
          ? const _NormalPayment.zero()
          : normalPaymentForNextDetail;
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

      if (index == 0 && prepayments.length > 1 && !normalPaymentApplied) {
        // The first transaction owns the month's only normal payment. Calculate
        // it after that transaction's prepayment so later payments use the
        // reduced balance without deducting another payment for each event.
        normalPaymentApplied = true;
        normalPaymentBefore = _normalPayment(
          commercialOpening: remainingCommercial,
          providentOpening: remainingProvident,
          remainingTerms: paymentRemainingTerms,
          paymentMonth: _monthAt(
            LoanPlanConfig.parseLoanStartDate('$paymentMonthStart-01')!,
            index + 1,
          ),
          config: config,
        );
        remainingCommercial = math
            .max(
              0.0,
              remainingCommercial - normalPaymentBefore.commercialPrincipal,
            )
            .toDouble();
        remainingProvident = math
            .max(
              0.0,
              remainingProvident - normalPaymentBefore.providentPrincipal,
            )
            .toDouble();
        if (normalPaymentBefore.hasPrincipal) {
          additionalNormalPayments++;
          paymentRemainingTerms = math
              .max(0, paymentRemainingTerms - 1)
              .toInt();
        }
        normalPaymentForNextDetail = normalPaymentBefore;
      } else if (index > 0 && index < prepayments.length - 1) {
        normalPaymentForNextDetail = _normalPayment(
          commercialOpening: remainingCommercial,
          providentOpening: remainingProvident,
          remainingTerms: paymentRemainingTerms,
          paymentMonth: _monthAt(
            LoanPlanConfig.parseLoanStartDate('$paymentMonthStart-01')!,
            index + 1,
          ),
          config: config,
        );
      }

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
      interestDueNow += commercialInterestDueNow + providentInterestDueNow;
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
            // 提前还款日利息单独结算，不能叠加到下一期常规月供。
            nextMonthDeferredInterest: 0,
            commercialClosing: remainingCommercial,
            providentClosing: remainingProvident,
            commercialPrincipalBefore: normalPaymentBefore.commercialPrincipal,
            commercialInterestBefore: normalPaymentBefore.commercialInterest,
            commercialPaymentBefore: normalPaymentBefore.commercialPayment,
            providentPrincipalBefore: normalPaymentBefore.providentPrincipal,
            providentInterestBefore: normalPaymentBefore.providentInterest,
            providentPaymentBefore: normalPaymentBefore.providentPayment,
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
      additionalNormalPayments: additionalNormalPayments,
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

  int _elapsedDays(String prepaymentDate) {
    return LoanPlanConfig.parseLoanStartDate(prepaymentDate)?.day ?? 1;
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
    required this.additionalNormalPayments,
    required this.dates,
    required this.details,
  });

  final double usedPrepayment;
  final double commercialPrepayment;
  final double providentPrepayment;
  final double commercialClosing;
  final double providentClosing;
  final double interestDueNow;
  final int additionalNormalPayments;
  final List<String> dates;
  final List<LoanPrepaymentDetail> details;
}

class _NormalPayment {
  const _NormalPayment({
    required this.commercialPrincipal,
    required this.commercialInterest,
    required this.providentPrincipal,
    required this.providentInterest,
  });

  const _NormalPayment.zero()
    : commercialPrincipal = 0,
      commercialInterest = 0,
      providentPrincipal = 0,
      providentInterest = 0;

  final double commercialPrincipal;
  final double commercialInterest;
  final double providentPrincipal;
  final double providentInterest;

  double get commercialPayment => commercialPrincipal + commercialInterest;

  double get providentPayment => providentPrincipal + providentInterest;

  bool get hasPrincipal => commercialPrincipal > 0 || providentPrincipal > 0;
}

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
    var recurringPaymentBaseline = 0.0;
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
      if (index == 3) {
        // The first recurring month anchors the later automatic increase.
        recurringPaymentBaseline = totalPayment;
      }
      final availableFunds = index < 3
          ? config.monthlySalary
          : config.recurringPrepaymentStart + recurringPaymentBaseline;

      final requestedPrepayment = _requestedPrepayment(
        index: index,
        totalPayment: totalPayment,
        recurringPaymentBaseline: recurringPaymentBaseline,
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
      if (closingBalance < 0.01) break;
      // The first month is intentionally a calibration month and may have no
      // normal payment. After that, stop if the configuration cannot reduce
      // the balance so the calculator never loops forever.
      if (!isCalibrationMonth && openingBalance - closingBalance <= 0.000001) {
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
    if (index == 1) {
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
    if (index == 1) return config.bankSeptemberInterest;
    return opening * config.commercialAnnualRate / 12;
  }

  double _normalPrincipal(double opening, int remainingTerms) {
    if (opening <= 0 || remainingTerms <= 0) return 0;
    return math.min(opening, opening / remainingTerms);
  }

  double _requestedPrepayment({
    required int index,
    required double totalPayment,
    required double recurringPaymentBaseline,
    required LoanPlanConfig config,
  }) {
    if (index == 0) return config.fixedAugustPrepayment;
    if (index == 1) return config.fixedSeptemberPrepayment;
    if (index == 2) return config.fixedOctoberPrepayment;
    return math.max(
      0,
      config.recurringPrepaymentStart + recurringPaymentBaseline - totalPayment,
    );
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

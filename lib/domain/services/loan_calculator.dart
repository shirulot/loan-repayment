import 'dart:math' as math;

import '../../core/extensions/string_extensions.dart';
import '../models/loan_models.dart';
import '../models/loan_payment_history.dart';

part 'loan_history_replay.dart';

class LoanCalculator {
  const LoanCalculator({this.currentDate});

  final DateTime? currentDate;
  static const _prepaymentInterestDayBase = 360;

  String get startMonth => monthAt(0);

  /// The date used to decide whether a scheduled prepayment has taken effect.
  DateTime get calculationDate => currentDate ?? DateTime.now();

  List<LoanPlanRow> calculate(
    LoanPlanConfig config,
    Map<String, double?> actualPrepayments, {
    List<LoanPlanRow> archivedMonths = const [],
    List<LoanPaymentHistory> history = const [],
    List<LoanPaymentHistory>? frozenHistory,
    Map<String, LoanPaymentHistory> priorHistory = const {},
    bool migrateLegacyRates = false,
    bool validateImport = false,
  }) {
    config = LoanPaymentHistory.reconcileMonthlyPlaceholders(config, history);
    final calibration = _planStartDate(config, actualPrepayments);
    var start = calibration;
    LoanPlanRow? precedingBill;
    final result = <LoanPlanRow>[];

    // 已按月份排序的账单是结算点。只推算两张账单之间和末张账单之后的月份。
    var gapConfig = config;
    void projectUntil([DateTime? end]) {
      if (end != null && !start.isBefore(end)) return;
      result.addAll(
        _project(
          end == null ? config : gapConfig,
          actualPrepayments,
          start,
          calibration,
          precedingBill: precedingBill,
          end: end,
        ),
      );
    }

    for (final bill in archivedMonths) {
      final date = DateTime.parse('${bill.month}-01');
      projectUntil(date);
      result.add(bill);
      precedingBill = bill;
      start = DateTime(date.year, date.month + 1);
    }
    LoanPaymentHistory? previousSource;
    for (final bill in history) {
      final date = DateTime.parse('${bill.month}-01');
      projectUntil(date);
      final previous = precedingBill == null ? null : result.last;
      final precedingMonth = _monthAt(date, -1);
      if (previous != null && previous.month != precedingMonth) {
        throw FormatException('${bill.month} 之前的计划已经结束，无法承接该月账单。');
      }
      if (validateImport && previous != null) {
        if (bill.remainingTerms != previous.remainingTerms - 1) {
          throw FormatException(
            '${bill.month} 剩余期数应为 ${previous.remainingTerms - 1}，文件为 ${bill.remainingTerms}。',
          );
        }
        if (previousSource?.month == precedingMonth) {
          bill.validateOpening(previousSource!, previous);
        }
      }
      final prior = priorHistory[bill.month];
      final mode =
          bill.manualMode ?? prior?.manualMode ?? config.isPlanRepaymentMode;
      final method =
          bill.repaymentMethod ??
          prior?.repaymentMethod ??
          config.repaymentMethod;
      // 已有缓存按旧账单原先的计息口径冻结利率，新导入使用普通计划的转息条件。
      final legacy = migrateLegacyRates && bill.manualMode == null;
      final days = _commercialDays(
        bill.month,
        legacy
            ? (previous?.isArchived == true &&
                  (previous?.commercialPrepayment ?? 0) > 0)
            : _usesTransfer(mode, previous),
        legacy ? LoanRepaymentMethod.equalPrincipal : method,
      );
      final frozen = bill.freeze(config, days, existing: prior);
      frozenHistory?.add(frozen);
      final row = historyRow(
        frozen,
        config,
        previous: previous,
        legacyAmount: actualPrepayments[bill.month],
      );
      gapConfig = config.copyWith(
        commercialAnnualRate: row.commercialAnnualRate ?? 0,
        providentAnnualRate: row.providentAnnualRate ?? 0,
        repaymentMethod: frozen.repaymentMethod,
        isPlanRepaymentMode: frozen.manualMode,
      );
      result.add(row);
      previousSource = bill;
      precedingBill = row;
      start = DateTime(date.year, date.month + 1);
    }
    projectUntil();
    return result;
  }

  List<LoanPlanRow> _project(
    LoanPlanConfig config,
    Map<String, double?> actualPrepayments,
    DateTime planStartDate,
    DateTime calibration, {
    LoanPlanRow? precedingBill,
    DateTime? end,
  }) {
    // 账单期末已扣过月供和逐笔提前本金，下一月直接从其余额和剩余期数续算。
    var commercialOpening =
        precedingBill?.commercialClosing ?? config.commercialOpeningBalance;
    var providentOpening =
        precedingBill?.providentClosing ?? config.providentOpeningBalance;
    if (precedingBill != null && commercialOpening + providentOpening < 0.01) {
      return [];
    }
    var remainingTerms = precedingBill == null
        ? config.remainingTermsAt(planStartDate)
        : math.max(0, precedingBill.remainingTerms - 1);
    // 旧版三笔预期额度按原校准月编号，导入更早的账单不移动这些预约。
    final scheduleOffset =
        (planStartDate.year - calibration.year) * 12 +
        planStartDate.month -
        calibration.month;
    final endMonth = end == null ? null : _monthAt(end, 0);
    var accumulatedAvailableFunds = 0.0;
    final rows = <LoanPlanRow>[];

    // The limit is only a safety net for invalid configurations that cannot make progress.
    const maxCalculationMonths = 1200;
    for (var index = 0; index < maxCalculationMonths; index++) {
      final month = _monthAt(planStartDate, index);
      if (month == endMonth) break;
      final scheduleIndex = scheduleOffset + index;
      final isCalibrationMonth = index == 0 && precedingBill == null;
      final previousRow = rows.isEmpty ? precedingBill : rows.last;
      // 手动模式只在上一月实际计入提前还款后的本月转息；普通还款不延续转息。
      // 自动规划模式保持原有计息规则。
      final applyTransferInterest = _usesTransfer(
        config.isPlanRepaymentMode,
        previousRow,
      );
      final openingBalance = commercialOpening + providentOpening;

      final normalPayment = isCalibrationMonth
          ? const _NormalPayment.zero()
          : _normalPayment(
              commercialOpening: commercialOpening,
              providentOpening: providentOpening,
              remainingTerms: remainingTerms,
              paymentMonth: month,
              applyTransferInterest: applyTransferInterest,
              config: config,
            );
      final commercialPrincipal = normalPayment.commercialPrincipal;
      final commercialInterest = normalPayment.commercialInterest;
      final providentPrincipal = normalPayment.providentPrincipal;
      final providentInterest = normalPayment.providentInterest;
      final commercialPayment = commercialPrincipal + commercialInterest;
      final providentPayment = providentPrincipal + providentInterest;
      final totalPayment = commercialPayment + providentPayment;
      // Keep the cash-flow amount aligned with the editable fields shown on
      // the first page: income - payment - living cost - other expense + extra income.
      final availableFunds =
          config.monthlySalary -
          totalPayment -
          config.monthlyLivingCost +
          config.monthlyExtraIncome -
          config.monthlyOtherExpense;

      final scheduledPrepayments = _scheduledPrepaymentsForMonth(
        config: config,
        month: month,
      );
      final legacyActualPrepayment = actualPrepayments[month];
      final hasRecentPrepayments = _hasRecentPrepayments(config);
      final isPlanningMonth = _isPlanningMonth(
        month,
        config.prepaymentFrequencyMonths,
      );
      // 无法唯一拆分的旧版月扣款保留原金额和原先采用的首笔日期。
      final prepayments = legacyActualPrepayment == null
          ? scheduledPrepayments
          : [
              _ScheduledPrepayment(
                amount: math.max(0.0, legacyActualPrepayment),
                repaymentDate:
                    scheduledPrepayments.firstOrNull?.repaymentDate ??
                    _validPrepaymentDate(
                      _plannedPrepaymentDate(scheduleIndex, config),
                      month,
                    ),
                isRecorded: true,
              ),
            ];
      double requestedPrepayment = 0;
      if (prepayments.isNotEmpty) {
        accumulatedAvailableFunds = 0;
      } else if (config.isFixedPrepaymentMode) {
        // 每个周期使用同一笔手填金额，不累加现金流，也不倍乘间隔月数。
        requestedPrepayment = isPlanningMonth
            ? math.max(0.0, config.fixedPrepaymentAmount)
            : 0.0;
      } else {
        final isCurrentOrFutureMonth = !_isBeforeCalculationMonth(month);
        if (isCurrentOrFutureMonth && !config.isPlanRepaymentMode) {
          accumulatedAvailableFunds += math.max(0.0, availableFunds);
        }
        // 手动模式只读录入记录，不因收入结余或频率生成提前还款。
        requestedPrepayment = config.isPlanRepaymentMode
            ? 0.0
            : _requestedPrepayment(
                index: scheduleIndex,
                accumulatedAvailableFunds: accumulatedAvailableFunds,
                config: config,
                hasRecentPrepayments: hasRecentPrepayments,
                isPlanningMonth: isPlanningMonth,
                isCurrentOrFutureMonth: isCurrentOrFutureMonth,
              );
        if ((config.isPlanRepaymentMode || isPlanningMonth) &&
            isCurrentOrFutureMonth) {
          accumulatedAvailableFunds = 0;
        }
      }
      final remainingAfterNormalPayment =
          math.max(0.0, commercialOpening - commercialPrincipal).toDouble() +
          math.max(0.0, providentOpening - providentPrincipal).toDouble();
      // 自动增量按十元向上取整；手填定额和还款记录保留原金额。
      // 各模式均按剩余本金封顶，避免最后一笔出现负余额。
      final automaticAmount = math.min(
        remainingAfterNormalPayment,
        config.isFixedPrepaymentMode || config.isPlanRepaymentMode
            ? requestedPrepayment
            : _roundUpToTen(requestedPrepayment),
      );
      final hasMultiplePrepayments = prepayments.length > 1;
      // 同月多笔由第一笔明细扣除唯一一次当期月供，避免月度行重复扣款。
      final normalPaymentAppliedInPlanRow =
          !isCalibrationMonth && !hasMultiplePrepayments;
      final appliedPrepayments = _applyPrepayments(
        prepayments: prepayments.isEmpty
            ? <_ScheduledPrepayment>[
                _ScheduledPrepayment(amount: automaticAmount),
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
        applyTransferInterest: applyTransferInterest,
        config: config,
      );
      final effectivePrepaymentDate = appliedPrepayments.dates.isEmpty
          ? null
          : appliedPrepayments.dates.first;
      final usedPrepayment = appliedPrepayments.usedPrepayment;
      final commercialPrepayment = appliedPrepayments.commercialPrepayment;
      final providentPrepayment = appliedPrepayments.providentPrepayment;
      final commercialClosing = appliedPrepayments.commercialClosing;
      final providentClosing = appliedPrepayments.providentClosing;
      final prepaymentInterestDueNow = appliedPrepayments.interestDueNow;
      // 转息基准和实际月供必须使用同一触发条件，不能按本月提前金额隐藏
      // 上月提前还款产生的本月差额。
      final nextMonthBasePayment =
          config.isPlanRepaymentMode && !applyTransferInterest
          ? totalPayment
          : _baseMonthlyPayment(
              commercialOpening: commercialOpening,
              providentOpening: providentOpening,
              remainingTerms: remainingTerms,
              config: config,
            );
      final commercialReduction =
          previousRow == null || (precedingBill == null && index < 2)
          ? null
          : previousRow.commercialPayment - commercialPayment;
      final providentReduction =
          previousRow == null || (precedingBill == null && index < 2)
          ? null
          : previousRow.providentPayment - providentPayment;
      final totalReduction =
          previousRow == null || (precedingBill == null && index < 2)
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
        event.amount,
      );
    }
    return startDate;
  }

  double _commercialInterestForPaymentMonth({
    required String month,
    required bool applyTransferInterest,
    required double opening,
    required LoanPlanConfig config,
  }) {
    final days = _commercialDays(
      month,
      applyTransferInterest,
      config.repaymentMethod,
    );
    return opening *
        config.commercialAnnualRate *
        days /
        _prepaymentInterestDayBase;
  }

  /// 手动模式按上月实际提前还款触发转息，等额本息始终按月息计算。
  bool _usesTransfer(bool manual, LoanPlanRow? previous) =>
      !manual || (previous?.usedPrepayment ?? 0) > 0;

  int _commercialDays(String month, bool transfer, LoanRepaymentMethod method) {
    if (!transfer || method == LoanRepaymentMethod.equalPrincipalAndInterest) {
      return 30;
    }
    final date = LoanPlanConfig.parseLoanStartDate('$month-01');
    return date == null ? 30 : DateTime(date.year, date.month, 0).day;
  }

  double _normalPrincipal({
    required double opening,
    required double annualRate,
    required double interest,
    required int remainingTerms,
    required LoanRepaymentMethod repaymentMethod,
  }) {
    if (opening <= 0 || remainingTerms <= 0) return 0;
    if (repaymentMethod == LoanRepaymentMethod.equalPrincipal) {
      return math.min(opening, opening / remainingTerms);
    }

    final monthlyRate = annualRate / 12;
    if (monthlyRate <= 0) {
      return math.min(opening, opening / remainingTerms);
    }
    // 等额本息先求固定月供，再扣除当期利息得到实际归还本金。
    final compoundFactor = math.pow(1 + monthlyRate, remainingTerms).toDouble();
    final monthlyPayment =
        opening * monthlyRate * compoundFactor / (compoundFactor - 1);
    return (monthlyPayment - interest).clamp(0.0, opening).toDouble();
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
    required bool applyTransferInterest,
    required LoanPlanConfig config,
  }) {
    final commercialInterest = _commercialInterestForPaymentMonth(
      month: paymentMonth,
      applyTransferInterest: applyTransferInterest,
      opening: commercialOpening,
      config: config,
    );
    final commercialPrincipal = _normalPrincipal(
      opening: commercialOpening,
      annualRate: config.commercialAnnualRate,
      interest: commercialInterest,
      remainingTerms: remainingTerms,
      repaymentMethod: config.repaymentMethod,
    );
    final providentInterest =
        providentOpening * config.providentAnnualRate / 12;
    final providentPrincipal = _normalPrincipal(
      opening: providentOpening,
      annualRate: config.providentAnnualRate,
      interest: providentInterest,
      remainingTerms: remainingTerms,
      repaymentMethod: config.repaymentMethod,
    );
    return _NormalPayment(
      commercialPrincipal: commercialPrincipal,
      commercialInterest: commercialInterest,
      providentPrincipal: providentPrincipal,
      providentInterest: providentInterest,
    );
  }

  double _requestedPrepayment({
    required int index,
    required double accumulatedAvailableFunds,
    required LoanPlanConfig config,
    required bool hasRecentPrepayments,
    required bool isPlanningMonth,
    required bool isCurrentOrFutureMonth,
  }) {
    if (!isCurrentOrFutureMonth || !isPlanningMonth) return 0;

    // When no recent repayment event is available, retain the three legacy
    // expected amounts as the first planning inputs. Once recent events exist,
    // the remaining plan is based on accumulated available cash instead.
    if (!hasRecentPrepayments) {
      final expectedAmount = _expectedPrepaymentForIndex(index, config);
      if (expectedAmount > 0) return expectedAmount;
    }
    return math.max(0, accumulatedAvailableFunds);
  }

  double _expectedPrepaymentForIndex(int index, LoanPlanConfig config) {
    return switch (index) {
      0 => config.fixedAugustPrepayment,
      1 => config.fixedSeptemberPrepayment,
      2 => config.fixedOctoberPrepayment,
      _ => 0.0,
    };
  }

  bool _hasRecentPrepayments(LoanPlanConfig config) {
    return config.recentPrepayments.any(
      (event) => event.amount > 0 || event.repaymentDate.trim().isNotEmpty,
    );
  }

  bool _isBeforeCalculationMonth(String month) {
    final date = LoanPlanConfig.parseLoanStartDate('$month-01');
    if (date == null) return false;
    final current = DateTime(calculationDate.year, calculationDate.month);
    return date.isBefore(current);
  }

  bool _isPlanningMonth(String month, int frequencyMonths) {
    final date = LoanPlanConfig.parseLoanStartDate('$month-01');
    if (date == null) return false;
    final current = DateTime(calculationDate.year, calculationDate.month);
    if (date.isBefore(current)) return false;
    final elapsedMonths =
        (date.year - current.year) * 12 + date.month - current.month;
    final normalizedFrequency = frequencyMonths < 1 ? 1 : frequencyMonths;
    return elapsedMonths % normalizedFrequency == 0;
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
            amount: event.amount,
            isRecorded: true,
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
    required bool applyTransferInterest,
    required LoanPlanConfig config,
  }) {
    var remainingCommercial = commercialBalance;
    var remainingProvident = providentBalance;
    var commercialPrepayment = 0.0;
    var providentPrepayment = 0.0;
    var interestDueNow = 0.0;
    var paymentRemainingTerms = remainingTermsForAdditionalPayment;
    var additionalNormalPayments = 0;
    // Preview balances only accumulate prepayments. They let every detail
    // show the newly reduced monthly payment without applying it repeatedly.
    var previewCommercial = commercialBalance;
    var previewProvident = providentBalance;
    // Same-month previews describe the same upcoming instalment, so they
    // must retain one shared term count until the next calendar month.
    final previewRemainingTerms = remainingTermsForAdditionalPayment;
    final dates = <String>[];
    final details = <LoanPrepaymentDetail>[];

    for (var index = 0; index < prepayments.length; index++) {
      final prepayment = prepayments[index];
      var normalPaymentBefore = const _NormalPayment.zero();
      double? basePaymentBefore;
      if (prepayments.length > 1 && !normalPaymentAlreadyApplied) {
        // Each detail shows the payment immediately before its own prepayment:
        // the first uses the opening balance and later details use prior
        // cumulative prepayments. Only the first payment affects balance.
        normalPaymentBefore = _normalPayment(
          commercialOpening: previewCommercial,
          providentOpening: previewProvident,
          remainingTerms: previewRemainingTerms,
          // 同月明细与月度行属于同一期月供，均按上一自然月日数计息。
          // 不能传入下一月，否则 11 月会误用 11 月的 30 天，而非 10 月的 31 天。
          paymentMonth: paymentMonthStart,
          applyTransferInterest: applyTransferInterest,
          config: config,
        );
        basePaymentBefore = _baseMonthlyPayment(
          commercialOpening: previewCommercial,
          providentOpening: previewProvident,
          remainingTerms: previewRemainingTerms,
          config: config,
        );
        if (index == 0) {
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
        }
      }
      final previewUsed = math
          .min(
            math.max(0.0, prepayment.amount),
            previewCommercial + previewProvident,
          )
          .toDouble();
      final previewCommercialPart = math
          .min(previewUsed, previewCommercial)
          .toDouble();
      final previewProvidentPart = math
          .min(
            math.max(0.0, previewUsed - previewCommercialPart),
            previewProvident,
          )
          .toDouble();
      previewCommercial -= previewCommercialPart;
      previewProvident -= previewProvidentPart;
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
      interestDueNow += commercialInterestDueNow + providentInterestDueNow;
      if (date != null) dates.add(date);
      if (used > 0) {
        details.add(
          LoanPrepaymentDetail(
            eventId: prepayment.eventId,
            amount: used,
            isRecorded: prepayment.isRecorded,
            repaymentDate: date,
            interestDueNow: commercialInterestDueNow + providentInterestDueNow,
            // 提前还款日利息单独结算，不能叠加到下一期常规月供。
            nextMonthDeferredInterest: 0,
            commercialClosing: remainingCommercial,
            providentClosing: remainingProvident,
            basePaymentBefore: basePaymentBefore,
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
    if (value == null || value.isBlank) return null;
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
    final commercialInterest =
        commercialOpening * config.commercialAnnualRate / 12;
    final commercialPrincipal = _normalPrincipal(
      opening: commercialOpening,
      annualRate: config.commercialAnnualRate,
      interest: commercialInterest,
      remainingTerms: remainingTerms,
      repaymentMethod: config.repaymentMethod,
    );
    final providentInterest =
        providentOpening * config.providentAnnualRate / 12;
    final providentPrincipal = _normalPrincipal(
      opening: providentOpening,
      annualRate: config.providentAnnualRate,
      interest: providentInterest,
      remainingTerms: remainingTerms,
      repaymentMethod: config.repaymentMethod,
    );
    return commercialPrincipal +
        commercialInterest +
        providentPrincipal +
        providentInterest;
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
    this.isRecorded = false,
    this.repaymentDate,
  });

  final double amount;
  final String? eventId;
  final bool isRecorded;
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

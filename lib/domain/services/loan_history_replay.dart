part of 'loan_calculator.dart';

/// 按时间顺序合并银行流水与首页补录，所有月供预览都调用普通计划的公式。
extension LoanHistoryReplay on LoanCalculator {
  LoanPlanRow historyRow(
    LoanPaymentHistory source,
    LoanPlanConfig config, {
    LoanPlanRow? previous,
    double? legacyAmount,
  }) {
    final manual = source.manualMode ?? config.isPlanRepaymentMode;
    final method = source.repaymentMethod ?? config.repaymentMethod;
    final transfer = _usesTransfer(manual, previous);
    final bill = source.freeze(
      config,
      _commercialDays(source.month, transfer, method),
    );
    final terms = previous == null
        ? bill.remainingTerms
        : previous.remainingTerms - 1;
    final period = config.copyWith(
      commercialAnnualRate: bill.commercial.annualRate ?? 0,
      providentAnnualRate: bill.provident.annualRate ?? 0,
      repaymentMethod: method,
    );
    double money(double x) => (x * 100).round() / 100;
    double? difference(double? last, double value) =>
        last == null ? null : money(last - value);
    final commercialOpening = money(
      previous?.commercialClosing ?? bill.commercial.openingBalance,
    );
    final providentOpening = money(
      previous?.providentClosing ?? bill.provident.openingBalance,
    );
    if (terms <= 0) throw FormatException('${bill.month} 超过剩余贷款期数，请核对初期期数。');
    _NormalPayment preview(double c, double p) => _normalPayment(
      commercialOpening: c,
      providentOpening: p,
      remainingTerms: terms,
      paymentMonth: bill.month,
      applyTransferInterest: transfer,
      config: period,
    );
    double base(double c, double p) => _baseMonthlyPayment(
      commercialOpening: c,
      providentOpening: p,
      remainingTerms: terms,
      config: period,
    );
    final calculated = preview(commercialOpening, providentOpening);
    final estimated =
        bill.commercialPaymentEvidence == LoanPaymentEvidence.estimated;
    final commercialPrincipal = estimated
        ? money(calculated.commercialPrincipal)
        : bill.commercial.principal;
    final commercialInterest = estimated
        ? money(calculated.commercialInterest)
        : bill.commercial.interest;
    final providentPrincipal = bill.provident.principal;
    final providentInterest = bill.providentInterestEstimated
        ? money(calculated.providentInterest)
        : bill.provident.interest;
    final paid = _NormalPayment(
      commercialPrincipal: commercialPrincipal,
      commercialInterest: commercialInterest,
      providentPrincipal: providentPrincipal,
      providentInterest: providentInterest,
    );
    double commercialClosing = money(commercialOpening - commercialPrincipal),
        providentClosing = money(providentOpening - providentPrincipal);
    if (commercialClosing < 0 || providentClosing < 0) {
      throw FormatException('${bill.month} 月供实扣本金超过承接的期初余额。');
    }
    final events = _scheduledPrepaymentsForMonth(
      config: config,
      month: bill.month,
    );
    final linked = {for (final p in bill.prepayments) ?p.eventId};
    // 旧按月合计只补足未由同月银行流水解释的部分。
    final bankTotal = bill.prepayments.fold(
      0.0,
      (v, p) => v + p.commercialPrincipal + p.providentPrincipal,
    );
    final extra =
        legacyAmount == null || bill.coversLegacyMonthlyAmount(legacyAmount)
        ? null
        : money(legacyAmount - bankTotal);
    final entries =
        <
          ({
            String date,
            LoanPaymentHistoryPrepayment? bank,
            _ScheduledPrepayment? local,
          })
        >[
          for (final p in bill.prepayments)
            (date: p.date, bank: p, local: null),
          if (extra == null)
            for (final e in events)
              if (!linked.contains(e.eventId))
                (date: e.repaymentDate!, bank: null, local: e),
          if (extra != null && extra > 0)
            (
              date: events.firstOrNull?.repaymentDate ?? '${bill.month}-01',
              bank: null,
              local: _ScheduledPrepayment(amount: extra, isRecorded: true),
            ),
        ];
    final ordered = entries.indexed.toList()
      ..sort((a, b) {
        final byDate = a.$2.date.compareTo(b.$2.date);
        return byDate == 0 ? a.$1.compareTo(b.$1) : byDate;
      });
    var commercialPrepaid = 0.0, providentPrepaid = 0.0, interest = 0.0;
    final details = <LoanPrepaymentDetail>[];
    final monthTotal = money(paid.commercialPayment + paid.providentPayment);
    final monthBase = manual && !transfer
        ? monthTotal
        : base(commercialOpening, providentOpening);
    for (final (_, e) in ordered) {
      final bank = e.bank;
      final amount = e.local?.amount ?? 0;
      final c =
          bank?.commercialPrincipal ??
          money(math.min(commercialClosing, amount));
      final p =
          bank?.providentPrincipal ??
          money(math.min(providentClosing, math.max(0, amount - c)));
      if (money(commercialClosing - c) < 0 || money(providentClosing - p) < 0) {
        throw FormatException('${e.date} 的实扣本金超过余额，请核对之前的补录。');
      }
      if (c + p <= 0) continue;
      final before = details.isEmpty
          ? paid
          : preview(
              commercialOpening - commercialPrepaid,
              providentOpening - providentPrepaid,
            );
      final baseBefore = details.isEmpty
          ? monthBase
          : base(
              commercialOpening - commercialPrepaid,
              providentOpening - providentPrepaid,
            );
      final due = bank != null
          ? bank.interest
          : _interestDueOnRepaymentDay(
                  prepayment: c,
                  annualRate: period.commercialAnnualRate,
                  prepaymentDate: e.date,
                ) +
                _interestDueOnRepaymentDay(
                  prepayment: p,
                  annualRate: period.providentAnnualRate,
                  prepaymentDate: e.date,
                );
      commercialClosing = money(commercialClosing - c);
      providentClosing = money(providentClosing - p);
      commercialPrepaid = money(commercialPrepaid + c);
      providentPrepaid = money(providentPrepaid + p);
      interest += due ?? 0;
      details.add(
        LoanPrepaymentDetail(
          eventId: bank?.eventId ?? e.local?.eventId,
          amount: money(c + p),
          isRecorded: true,
          repaymentDate: e.date,
          interestDueNow: due ?? 0,
          interestRecorded: due != null,
          fromStatement: bank != null,
          nextMonthDeferredInterest: 0,
          commercialClosing: commercialClosing,
          providentClosing: providentClosing,
          basePaymentBefore: baseBefore,
          commercialPrincipalBefore: before.commercialPrincipal,
          commercialInterestBefore: before.commercialInterest,
          commercialPaymentBefore: before.commercialPayment,
          providentPrincipalBefore: before.providentPrincipal,
          providentInterestBefore: before.providentInterest,
          providentPaymentBefore: before.providentPayment,
        ),
      );
    }
    return LoanPlanRow(
      month: bill.month,
      isArchived: true,
      repaymentMethod: method,
      commercialPaymentDate: bill.commercialDate,
      providentPaymentDate: bill.providentDate,
      commercialPaymentEvidence: bill.commercialPaymentEvidence,
      providentInterestEstimated: bill.providentInterestEstimated,
      commercialAnnualRate: bill.commercial.annualRate,
      providentAnnualRate: bill.provident.annualRate,
      commercialAnnualRateInferred: bill.commercial.rateInferred,
      providentAnnualRateInferred: bill.provident.rateInferred,
      remainingTerms: terms,
      commercialOpening: commercialOpening,
      commercialPrincipal: commercialPrincipal,
      commercialInterest: commercialInterest,
      commercialPayment: paid.commercialPayment,
      providentOpening: providentOpening,
      providentPrincipal: providentPrincipal,
      providentInterest: providentInterest,
      providentPayment: paid.providentPayment,
      totalPayment: monthTotal,
      commercialReduction: difference(
        previous?.commercialPayment,
        paid.commercialPayment,
      ),
      providentReduction: difference(
        previous?.providentPayment,
        paid.providentPayment,
      ),
      totalReduction: difference(previous?.totalPayment, monthTotal),
      availableFunds:
          config.monthlySalary -
          monthTotal -
          config.monthlyLivingCost +
          config.monthlyExtraIncome -
          config.monthlyOtherExpense,
      effectivePrepaymentDate: details.firstOrNull?.repaymentDate,
      prepaymentDates: [for (final d in details) d.repaymentDate!],
      prepaymentDetails: details,
      prepaymentInterestDueNow: interest,
      nextMonthBasePayment: monthBase,
      nextMonthBasePaymentReduction: difference(
        previous?.nextMonthBasePayment,
        monthBase,
      ),
      usedPrepayment: money(commercialPrepaid + providentPrepaid),
      commercialPrepayment: commercialPrepaid,
      providentPrepayment: providentPrepaid,
      commercialClosing: commercialClosing,
      providentClosing: providentClosing,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:loan_repayment_manager/data/services/loan_cache_service.dart';
import 'package:loan_repayment_manager/domain/models/loan_models.dart';
import 'package:loan_repayment_manager/domain/services/loan_calculator.dart';
import 'package:loan_repayment_manager/ui/features/loan/view_models/loan_planner_view_model.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_formatters.dart';

class _NoopCacheService extends LoanCacheService {
  const _NoopCacheService();

  @override
  Future<void> save(
    LoanPlanConfig config,
    Map<String, double?> actualPrepayments, {
    String calculatorExpression = '',
    List<double> temporaryCalculatorResults = const <double>[],
  }) async {}
}

void main() {
  final calculator = LoanCalculator(currentDate: DateTime(2026, 8, 19));
  const config = LoanPlanConfig(
    commercialOpeningBalance: 375409.31,
    providentOpeningBalance: 500000,
    commercialAnnualRate: 0.032,
    providentAnnualRate: 0.026,
    remainingTerms: 200,
    monthlySalary: 16500,
    monthlyLivingCost: 3300,
    fixedAugustPrepayment: 17000,
    fixedSeptemberPrepayment: 30000,
    fixedOctoberPrepayment: 7000,
    bankSeptemberPrincipal: 1789.55,
    bankSeptemberInterest: 986.24,
    bankSeptemberPayment: 2775.79,
  );

  test(
    'uses the 2026/8 actual repayment to calibrate the commercial balance',
    () {
      final rows = calculator.calculate(config, {'2026-08': 17500});

      expect(rows.first.commercialClosing, closeTo(357909.31, 0.001));
      expect(rows.first.providentClosing, closeTo(500000, 0.001));
      expect(rows.first.nextMonthBasePayment, closeTo(6461.4714, 0.001));
      expect(rows[1].nextMonthBasePayment, closeTo(6327.3047, 0.001));
      expect(
        rows[2].nextMonthBasePayment,
        lessThan(rows[1].nextMonthBasePayment),
      );
    },
  );

  test('an actual repayment overrides the expectation and flows forward', () {
    final rows = calculator.calculate(config, {
      '2026-08': 17500,
      '2026-09': 28000,
    });

    expect(rows[1].actualPrepayment, 28000);
    expect(rows[1].commercialClosing, closeTo(328119.76345, 0.001));
    expect(
      rows[2].commercialOpening,
      closeTo(rows[1].commercialClosing, 0.001),
    );
  });

  test('keeps same-month actual repayments separate by their dates', () {
    const eventConfig = LoanPlanConfig(
      commercialOpeningBalance: 100000,
      remainingTerms: 100,
      recentPrepayments: [
        RecentPrepayment(
          id: 'september-early',
          amount: 17500,
          actualPrepayment: 17500,
          repaymentDate: '2026-09-05',
          isSettled: true,
        ),
        RecentPrepayment(
          id: 'september-late',
          amount: 31000,
          actualPrepayment: 31000,
          repaymentDate: '2026-09-20',
          isSettled: true,
        ),
      ],
    );

    final rows = LoanCalculator(
      currentDate: DateTime(2026, 9, 21),
    ).calculate(eventConfig, const <String, double?>{});

    final september = rows.firstWhere((row) => row.month == '2026-09');
    expect(september.actualPrepayment, 48500);
    expect(september.prepaymentDetails, hasLength(2));
    expect(september.prepaymentDetails[0].repaymentDate, '2026-09-05');
    expect(september.prepaymentDetails[1].repaymentDate, '2026-09-20');
    expect(september.prepaymentDetails[1].actualPrepayment, 31000);
  });

  test('calculates every commercial payment on the 360-day basis', () {
    const transferConfig = LoanPlanConfig(
      commercialOpeningBalance: 375409.31,
      commercialAnnualRate: 0.032,
      remainingTerms: 200,
      recentPrepayments: [
        RecentPrepayment(
          id: 'august-settled',
          amount: 17500,
          actualPrepayment: 17500,
          repaymentDate: '2026-08-19',
          isSettled: true,
        ),
      ],
    );
    final rows = calculator.calculate(transferConfig, {'2026-08': 17500});

    expect(rows[1].commercialPrincipal, closeTo(1789.54655, 0.001));
    expect(rows[1].commercialInterest, closeTo(986.23899, 0.001));
    expect(rows[1].commercialPayment, closeTo(2775.78554, 0.001));
    // October's payment uses September's 30-day interest period instead of
    // falling back to the old annual-rate / 12 calculation.
    expect(
      rows[2].commercialInterest,
      closeTo(rows[2].commercialOpening * 0.032 / 360 * 30, 0.001),
    );
  });

  test('calculates the transfer difference from the two monthly totals', () {
    final rows = calculator.calculate(config, {'2026-08': 17500});

    expect(
      rows[1].transferDifference,
      closeTo(rows[1].totalPayment - rows[1].nextMonthBasePayment, 0.001),
    );
  });

  test('planned prepayments are rounded up to whole tens', () {
    final rows = calculator.calculate(config, {'2026-08': 17500});

    for (final row in rows.skip(3)) {
      expect(row.expectedPrepayment % 10, closeTo(0, 0.001));
    }
  });

  test(
    'uses and increases available funds after recent expected repayments',
    () {
      final rows = calculator.calculate(config, {'2026-08': 17500});

      expect(
        rows[3].expectedPrepayment,
        closeTo((rows[3].availableFunds / 10).ceilToDouble() * 10, 0.001),
      );
      expect(
        rows[4].expectedPrepayment,
        closeTo((rows[4].availableFunds / 10).ceilToDouble() * 10, 0.001),
      );
      expect(
        rows[4].expectedPrepayment,
        greaterThan(rows[3].expectedPrepayment),
      );
    },
  );

  test('does not carry an empty legacy October amount after dated events', () {
    final eventConfig = config.copyWith(
      monthlyExtraIncome: 10000,
      recentPrepayments: const [
        RecentPrepayment(
          id: 'legacy-august',
          amount: 17000,
          legacyMonthOffset: 0,
        ),
        RecentPrepayment(
          id: 'september-4',
          amount: 30000,
          repaymentDate: '2026-09-04',
          legacyMonthOffset: 1,
        ),
        RecentPrepayment(
          id: 'legacy-october',
          amount: 7000,
          legacyMonthOffset: 2,
        ),
      ],
    );

    final rows = calculator.calculate(eventConfig, {'2026-08': 17500});

    expect(rows[1].expectedPrepayment, 30000);
    expect(
      rows[2].expectedPrepayment,
      closeTo((rows[2].availableFunds / 10).ceilToDouble() * 10, 0.001),
    );
    expect(rows[2].expectedPrepayment, greaterThan(17000));
  });

  test(
    'monthly cash flow uses the first normal payment instead of calibration zero',
    () {
      final viewModel = LoanPlannerViewModel(
        calculator: calculator,
        initialConfig: config,
      );

      expect(
        viewModel.currentMonthlyPayment,
        closeTo(viewModel.rows[1].totalPayment, 0.001),
      );
      expect(viewModel.currentMonthlyPayment, greaterThan(0));
      expect(
        viewModel.currentAvailablePrepayment,
        closeTo(
          config.monthlySalary -
              viewModel.currentMonthlyPayment -
              config.monthlyLivingCost +
              config.monthlyExtraIncome,
          0.001,
        ),
      );
      expect(
        viewModel.currentAvailablePrepayment,
        closeTo(viewModel.rows[1].availableFunds, 0.001),
      );
      viewModel.dispose();
    },
  );

  test('restores editable configuration from cached JSON', () {
    final restored = LoanPlanConfig.fromJson({
      'loanStartDate': '2020-01-15',
      'loanTermYears': 20,
      'monthlySalary': 14000,
      'monthlyExtraIncome': 800,
      'monthlyLivingCost': 3200,
      'remainingTerms': 180,
    });

    expect(restored.loanStartDate, '2020-01-15');
    expect(restored.loanTermYears, 20);
    expect(restored.monthlySalary, 14000);
    expect(restored.monthlyExtraIncome, 800);
    expect(restored.monthlyLivingCost, 3200);
    expect(restored.remainingTerms, 180);
    expect(restored.commercialOpeningBalance, 0);
  });

  test('starts a new plan without preset monetary values', () {
    const freshConfig = LoanPlanConfig();

    expect(freshConfig.commercialOpeningBalance, 0);
    expect(freshConfig.providentOpeningBalance, 0);
    expect(freshConfig.monthlySalary, 0);
    expect(freshConfig.monthlyLivingCost, 0);
    expect(freshConfig.fixedAugustPrepayment, 0);
  });

  test('restores parameters and actual repayments from a JSON backup', () {
    final backup = LoanCachedState.fromJson({
      'config': config.toJson(),
      'actualPrepayments': {'2026-08': 17500, '2026-09': 28000},
    });
    final viewModel = LoanPlannerViewModel(
      calculator: calculator,
      cacheService: const _NoopCacheService(),
    );

    viewModel.restoreImportedState(backup);

    expect(viewModel.config.commercialOpeningBalance, 375409.31);
    expect(viewModel.actualPrepayments['2026-09'], 28000);
    expect(viewModel.rows[1].actualPrepayment, 28000);
    viewModel.dispose();
  });

  test('restores the calculator expression and saved results from cache', () {
    final cached = LoanCachedState.fromJson({
      'config': config.toJson(),
      'actualPrepayments': const <String, double>{},
      'calculatorExpression': '1 + 2',
      'temporaryCalculatorResults': [3, 42.5],
    });
    final viewModel = LoanPlannerViewModel(
      calculator: calculator,
      cacheService: const _NoopCacheService(),
    );

    viewModel.restoreImportedState(cached);

    expect(viewModel.calculatorExpression, '1 + 2');
    expect(viewModel.temporaryCalculatorReferences.map((item) => item.value), [
      3,
      42.5,
    ]);
    viewModel.dispose();
  });

  test('calculates remaining terms from start date and total years', () {
    final durationConfig = config.copyWith(
      loanStartDate: '2020-01-15',
      loanTermYears: 20,
    );

    expect(durationConfig.remainingTermsAt(DateTime(2026, 8, 19)), 161);
    expect(
      calculator
          .calculate(durationConfig, {'2026-08': 17500})
          .first
          .remainingTerms,
      161,
    );
  });

  test(
    'keeps the legacy remaining terms until the new inputs are complete',
    () {
      final startOnlyConfig = config.copyWith(loanStartDate: '2020-01');
      final invalidDateConfig = config.copyWith(
        loanStartDate: '2020-02-30',
        loanTermYears: 20,
      );

      expect(startOnlyConfig.remainingTermsAt(DateTime(2026, 8, 19)), 200);
      expect(invalidDateConfig.remainingTermsAt(DateTime(2026, 8, 19)), 200);
    },
  );

  test('formats amounts without leading or trailing commas', () {
    expect(formatLoanMoney(0), '0.00');
    expect(formatLoanMoney(999.99), '999.99');
    expect(formatLoanMoney(1234.56), '1,234.56');
    expect(formatLoanMoney(-1234567.89), '-1,234,567.89');
    expect(formatLoanMoney(1000000), '1,000,000.00');
  });

  test('shares the amount masking toggle without changing loan data', () {
    final viewModel = LoanPlannerViewModel(
      calculator: calculator,
      initialConfig: config,
    );
    final originalBalance = viewModel.rows.first.totalBalance;

    expect(viewModel.amountsMasked, isFalse);
    viewModel.toggleAmountsMasked();
    expect(viewModel.amountsMasked, isTrue);
    expect(viewModel.rows.first.totalBalance, originalBalance);
    viewModel.toggleAmountsMasked();
    expect(viewModel.amountsMasked, isFalse);
    viewModel.dispose();
  });

  test('extra income increases the available prepayment amount', () {
    final extraIncomeConfig = config.copyWith(monthlyExtraIncome: 2500);
    final rows = calculator.calculate(extraIncomeConfig, {});

    expect(
      rows[1].availableFunds,
      closeTo(
        extraIncomeConfig.monthlySalary -
            rows[1].totalPayment -
            extraIncomeConfig.monthlyLivingCost +
            extraIncomeConfig.monthlyExtraIncome,
        0.001,
      ),
    );
  });

  test('zero recent expected amounts fall back to available funds', () {
    final fallbackConfig = config.copyWith(
      fixedAugustPrepayment: 0,
      fixedSeptemberPrepayment: 0,
      fixedOctoberPrepayment: 0,
    );
    final rows = calculator.calculate(fallbackConfig, {});

    expect(rows[0].expectedPrepayment, closeTo(rows[0].availableFunds, 0.001));
    expect(
      rows[1].expectedPrepayment,
      closeTo((rows[1].availableFunds / 10).ceilToDouble() * 10, 0.001),
    );
  });

  test('continues generating months until the balance is cleared', () {
    const longPlanConfig = LoanPlanConfig(
      commercialOpeningBalance: 1000000,
      providentOpeningBalance: 1000000,
      commercialAnnualRate: 0,
      providentAnnualRate: 0,
      remainingTerms: 200,
      monthlySalary: 16500,
      monthlyLivingCost: 0,
      fixedAugustPrepayment: 0,
      fixedSeptemberPrepayment: 0,
      fixedOctoberPrepayment: 0,
      bankSeptemberPrincipal: 5000,
      bankSeptemberInterest: 0,
      bankSeptemberPayment: 5000,
    );

    final rows = calculator.calculate(longPlanConfig, {});

    expect(rows.length, greaterThan(39));
    expect(rows.last.totalBalance, lessThan(0.01));
  });

  test('removes months after an early actual payoff', () {
    final rows = calculator.calculate(config, {'2026-08': 9999999});

    expect(rows, hasLength(1));
    expect(rows.single.totalBalance, closeTo(0, 0.001));
  });

  test('splits dated prepayment interest into current and next month', () {
    const datedConfig = LoanPlanConfig(
      commercialOpeningBalance: 10000,
      commercialAnnualRate: 0.365,
      remainingTerms: 12,
      fixedAugustPrepaymentDate: '2026-08-04',
    );
    final rows = calculator.calculate(datedConfig, {'2026-08': 1000});

    expect(rows.first.effectivePrepaymentDate, '2026-08-04');
    expect(rows.first.prepaymentInterestDueNow, closeTo(4.0555556, 0.001));
    expect(rows.first.nextMonthBasePayment, closeTo(1137.5, 0.001));
    expect(rows[1].commercialInterest, closeTo(282.875, 0.001));
    expect(rows[1].nextMonthBasePaymentReduction, closeTo(113.75, 0.001));
    expect(rows[2].nextMonthBasePaymentReduction, closeTo(22.8125, 0.001));
  });

  test('does not increase the next provident payment after a prepayment', () {
    const providentConfig = LoanPlanConfig(
      providentOpeningBalance: 500000,
      providentAnnualRate: 0.026,
      remainingTerms: 200,
      recentPrepayments: [
        RecentPrepayment(
          id: 'august-provident',
          amount: 10000,
          repaymentDate: '2026-08-04',
        ),
      ],
    );

    final rows = calculator.calculate(providentConfig, {});

    expect(rows[1].providentPayment, closeTo(3511.6667, 0.001));
    expect(rows[2].providentPayment, lessThan(rows[1].providentPayment));
    expect(rows[2].providentPayment, closeTo(3506.3580, 0.001));
  });

  test(
    'keeps October commercial and total expected payments below September',
    () {
      final rows = calculator.calculate(config, {'2026-08': 17500});

      // 首个正常月不减期数；进入下一期后，余额和期数同步递推。
      expect(rows[1].remainingTerms, 200);
      expect(rows[2].remainingTerms, 199);
      expect(rows[2].commercialPayment, lessThan(rows[1].commercialPayment));
      expect(rows[2].totalPayment, lessThan(rows[1].totalPayment));
    },
  );

  test('keeps the current balance until this month\'s repayment date', () {
    const datedConfig = LoanPlanConfig(
      commercialOpeningBalance: 100000,
      remainingTerms: 100,
      recentPrepayments: [
        RecentPrepayment(
          id: 'future-august',
          amount: 10000,
          repaymentDate: '2026-08-25',
        ),
      ],
    );
    final beforeDue = LoanPlannerViewModel(
      calculator: LoanCalculator(currentDate: DateTime(2026, 8, 19)),
      initialConfig: datedConfig,
      cacheService: const _NoopCacheService(),
    );
    final onDue = LoanPlannerViewModel(
      calculator: LoanCalculator(currentDate: DateTime(2026, 8, 25)),
      initialConfig: datedConfig,
      cacheService: const _NoopCacheService(),
    );

    expect(beforeDue.currentCommercialBalance, 100000);
    expect(onDue.currentCommercialBalance, 90000);
    beforeDue.dispose();
    onDue.dispose();
  });

  test('keeps confirmed prior repayment months in the generated history', () {
    const historyConfig = LoanPlanConfig(
      commercialOpeningBalance: 100000,
      remainingTerms: 100,
      recentPrepayments: [
        RecentPrepayment(
          id: 'august-settled',
          amount: 10000,
          repaymentDate: '2026-08-19',
        ),
      ],
    );
    final septemberCalculator = LoanCalculator(
      currentDate: DateTime(2026, 9, 1),
    );

    final rows = septemberCalculator.calculate(historyConfig, {
      '2026-08': 10000,
    });

    expect(rows[0].month, '2026-08');
    expect(rows[0].commercialClosing, 90000);
    expect(rows[1].month, '2026-09');
    expect(rows[1].commercialOpening, 90000);
    expect(rows[1].commercialPayment, closeTo(900, 0.001));
  });

  test(
    'keeps a fully settled month as history after the calendar advances',
    () {
      const payoffConfig = LoanPlanConfig(
        commercialOpeningBalance: 10000,
        remainingTerms: 12,
        recentPrepayments: [
          RecentPrepayment(
            id: 'august-payoff',
            amount: 10000,
            repaymentDate: '2026-08-19',
          ),
        ],
      );
      final septemberCalculator = LoanCalculator(
        currentDate: DateTime(2026, 9, 1),
      );

      final rows = septemberCalculator.calculate(payoffConfig, {
        '2026-08': 10000,
      });
      final viewModel = LoanPlannerViewModel(
        calculator: septemberCalculator,
        initialConfig: payoffConfig,
        cacheService: const _NoopCacheService(),
      )..updateActualPrepayment('2026-08', 10000);

      expect(rows, hasLength(1));
      expect(rows.single.month, '2026-08');
      expect(rows.single.usedPrepayment, 10000);
      expect(rows.single.commercialClosing, 0);
      expect(viewModel.currentCommercialBalance, 0);
      viewModel.dispose();
    },
  );

  test('keeps a settlement-interest row after a dated final prepayment', () {
    const payoffConfig = LoanPlanConfig(
      commercialOpeningBalance: 10000,
      commercialAnnualRate: 0.365,
      remainingTerms: 12,
      fixedAugustPrepaymentDate: '2026-08-04',
    );
    final rows = calculator.calculate(payoffConfig, {'2026-08': 10000});

    expect(rows, hasLength(1));
    expect(rows.single.totalBalance, 0);
  });

  test('uses the 360-day basis for a leap-year repayment month', () {
    const leapYearConfig = LoanPlanConfig(
      commercialOpeningBalance: 10000,
      commercialAnnualRate: 0.366,
      remainingTerms: 12,
      fixedAugustPrepaymentDate: '2024-02-04',
    );
    final leapYearCalculator = LoanCalculator(currentDate: DateTime(2024, 2));
    final rows = leapYearCalculator.calculate(leapYearConfig, {
      '2024-02': 1000,
    });

    expect(rows.first.prepaymentInterestDueNow, closeTo(4.0666667, 0.001));
    expect(rows[1].commercialInterest, closeTo(265.35, 0.001));
  });

  test(
    'applies another normal payment before a later same-month prepayment',
    () {
      const multipleRepaymentConfig = LoanPlanConfig(
        commercialOpeningBalance: 10000,
        commercialAnnualRate: 0.365,
        remainingTerms: 12,
        recentPrepayments: [
          RecentPrepayment(
            id: 'august-4',
            amount: 1000,
            repaymentDate: '2026-08-04',
          ),
          RecentPrepayment(
            id: 'august-20',
            amount: 2000,
            repaymentDate: '2026-08-20',
          ),
        ],
      );

      final rows = calculator.calculate(multipleRepaymentConfig, {});

      expect(rows.first.expectedPrepayment, 3000);
      expect(rows.first.prepaymentDetails, hasLength(2));
      expect(
        rows.first.prepaymentDetails.first.interestDueNow,
        closeTo(4.0555556, 0.001),
      );
      expect(
        rows.first.prepaymentDetails.last.interestDueNow,
        closeTo(40.5555556, 0.001),
      );
      expect(rows.first.prepaymentInterestDueNow, closeTo(44.6111111, 0.001));
      expect(
        rows.first.prepaymentDetails.first.nextMonthDeferredInterest,
        closeTo(0, 0.001),
      );
      expect(
        rows.first.prepaymentDetails.last.nextMonthDeferredInterest,
        closeTo(0, 0.001),
      );
      expect(
        rows.first.prepaymentDetails.last.commercialPrincipalBefore,
        closeTo(750, 0.001),
      );
      expect(
        rows.first.prepaymentDetails.last.commercialInterestBefore,
        closeTo(282.875, 0.001),
      );
      expect(rows.first.prepaymentDetails.last.commercialClosing, 6250);
      expect(rows[1].remainingTerms, 11);
      expect(rows[1].commercialInterest, closeTo(196.4409722, 0.001));
      expect(
        rows[1].nextMonthBasePaymentReduction,
        closeTo(379.2140152, 0.001),
      );
    },
  );

  test('applies the inserted payment to both loan balances', () {
    const multipleLoanConfig = LoanPlanConfig(
      commercialOpeningBalance: 1000,
      providentOpeningBalance: 5000,
      commercialAnnualRate: 0.12,
      providentAnnualRate: 0.06,
      remainingTerms: 10,
      recentPrepayments: [
        RecentPrepayment(
          id: 'august-first',
          amount: 500,
          repaymentDate: '2026-08-04',
        ),
        RecentPrepayment(
          id: 'august-second',
          amount: 500,
          repaymentDate: '2026-08-20',
        ),
      ],
    );

    final rows = calculator.calculate(multipleLoanConfig, {});
    final second = rows.first.prepaymentDetails[1];

    expect(second.commercialPrincipalBefore, closeTo(50, 0.001));
    expect(second.commercialInterestBefore, closeTo(5.1666667, 0.001));
    expect(second.providentPrincipalBefore, closeTo(500, 0.001));
    expect(second.providentInterestBefore, closeTo(25, 0.001));
    expect(second.commercialClosing, closeTo(0, 0.001));
    expect(second.providentClosing, closeTo(4450, 0.001));
    expect(rows[1].commercialOpening, closeTo(0, 0.001));
    expect(rows[1].providentOpening, closeTo(4450, 0.001));
    expect(rows[1].remainingTerms, 9);

    final viewModel = LoanPlannerViewModel(
      calculator: LoanCalculator(currentDate: DateTime(2026, 8, 21)),
      initialConfig: multipleLoanConfig,
      cacheService: const _NoopCacheService(),
    );
    expect(viewModel.currentCommercialBalance, closeTo(0, 0.001));
    expect(viewModel.currentProvidentBalance, closeTo(4450, 0.001));
    viewModel.dispose();
  });

  test(
    'uses the current month as the recent expected repayment sequence start',
    () {
      final futureCalculator = LoanCalculator(
        currentDate: DateTime(2030, 3, 19),
      );
      final rows = futureCalculator.calculate(config, {'2030-03': 17500});

      expect(futureCalculator.monthAt(0), '2030-03');
      expect(futureCalculator.monthAt(1), '2030-04');
      expect(futureCalculator.monthAt(2), '2030-05');
      expect(rows[0].expectedPrepayment, config.fixedAugustPrepayment);
      expect(rows[1].expectedPrepayment, config.fixedSeptemberPrepayment);
      expect(rows[2].expectedPrepayment, config.fixedOctoberPrepayment);
    },
  );
}

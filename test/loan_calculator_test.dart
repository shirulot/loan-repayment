import 'package:flutter_test/flutter_test.dart';
import 'package:loan_repayment_manager/domain/models/loan_models.dart';
import 'package:loan_repayment_manager/domain/services/loan_calculator.dart';
import 'package:loan_repayment_manager/ui/features/loan/view_models/loan_planner_view_model.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_formatters.dart';

void main() {
  final calculator = LoanCalculator(currentDate: DateTime(2026, 8, 19));
  const config = LoanPlanConfig();

  test(
    'uses the 2026/8 actual repayment to calibrate the commercial balance',
    () {
      final rows = calculator.calculate(config, {'2026-08': 17500});

      expect(rows.first.commercialClosing, closeTo(357909.31, 0.001));
      expect(rows.first.providentClosing, closeTo(500000, 0.001));
    },
  );

  test('an actual repayment overrides the expectation and flows forward', () {
    final rows = calculator.calculate(config, {
      '2026-08': 17500,
      '2026-09': 28000,
    });

    expect(rows[1].actualPrepayment, 28000);
    expect(rows[1].commercialClosing, closeTo(328119.76, 0.001));
    expect(
      rows[2].commercialOpening,
      closeTo(rows[1].commercialClosing, 0.001),
    );
  });

  test('planned prepayments are rounded up to whole tens', () {
    final rows = calculator.calculate(config, {'2026-08': 17500});

    for (final row in rows.skip(3)) {
      expect(row.expectedPrepayment % 10, closeTo(0, 0.001));
    }
  });

  test('uses the editable recurring start for automatic prepayments', () {
    final rows = calculator.calculate(config, {'2026-08': 17500});

    expect(
      rows[3].expectedPrepayment,
      closeTo(config.recurringPrepaymentStart, 0.001),
    );
    expect(rows[4].expectedPrepayment, greaterThan(rows[3].expectedPrepayment));
  });

  test(
    'changing the recurring start changes the first automatic prepayment',
    () {
      final customConfig = config.copyWith(recurringPrepaymentStart: 12000);
      final rows = calculator.calculate(customConfig, {'2026-08': 17500});

      expect(rows[3].expectedPrepayment, closeTo(12000, 0.001));
    },
  );

  test(
    'monthly cash flow uses the first normal payment instead of calibration zero',
    () {
      final viewModel = LoanPlannerViewModel(calculator: calculator);

      expect(
        viewModel.currentMonthlyPayment,
        closeTo(viewModel.rows[1].totalPayment, 0.001),
      );
      expect(viewModel.currentMonthlyPayment, greaterThan(0));
      viewModel.dispose();
    },
  );

  test('restores editable configuration from cached JSON', () {
    final restored = LoanPlanConfig.fromJson({
      'loanStartDate': '2020-01-15',
      'loanTermYears': 20,
      'monthlySalary': 14000,
      'recurringPrepaymentStart': 12000,
      'monthlyLivingCost': 3200,
      'remainingTerms': 180,
    });

    expect(restored.loanStartDate, '2020-01-15');
    expect(restored.loanTermYears, 20);
    expect(restored.monthlySalary, 14000);
    expect(restored.recurringPrepaymentStart, 12000);
    expect(restored.monthlyLivingCost, 3200);
    expect(restored.remainingTerms, 180);
    expect(restored.commercialOpeningBalance, config.commercialOpeningBalance);
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

  test('uses the current month as the fixed repayment sequence start', () {
    final futureCalculator = LoanCalculator(currentDate: DateTime(2030, 3, 19));
    final rows = futureCalculator.calculate(config, {'2030-03': 17500});

    expect(futureCalculator.monthAt(0), '2030-03');
    expect(futureCalculator.monthAt(1), '2030-04');
    expect(futureCalculator.monthAt(2), '2030-05');
    expect(rows[0].expectedPrepayment, config.fixedAugustPrepayment);
    expect(rows[1].expectedPrepayment, config.fixedSeptemberPrepayment);
    expect(rows[2].expectedPrepayment, config.fixedOctoberPrepayment);
  });
}

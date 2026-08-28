import 'package:flutter_test/flutter_test.dart';
import 'package:loan_repayment_manager/domain/models/loan_models.dart';
import 'package:loan_repayment_manager/domain/services/basic_expression_calculator.dart';
import 'package:loan_repayment_manager/domain/services/loan_calculator.dart';
import 'package:loan_repayment_manager/ui/features/loan/view_models/loan_planner_view_model.dart';

void main() {
  const calculator = BasicExpressionCalculator();

  test('evaluates basic operations and referenced values', () {
    expect(
      calculator.evaluate('100 + 【本月收入】 × (2 - 1)', {'本月收入': 16500}),
      16600,
    );
  });

  test('rejects unknown references and division by zero', () {
    expect(
      () => calculator.evaluate('【不存在】 + 1', const {}),
      throwsFormatException,
    );
    expect(() => calculator.evaluate('1 ÷ 0', const {}), throwsFormatException);
  });

  test(
    'temporary calculator results become references without persistence',
    () {
      final viewModel = LoanPlannerViewModel();
      addTearDown(viewModel.dispose);

      viewModel.saveTemporaryCalculatorResult(1234.5);

      expect(viewModel.temporaryCalculatorReferences.single.label, '暂存结果 1');
      expect(viewModel.calculatorReferenceValues['暂存结果 1'], 1234.5);

      viewModel.clearTemporaryCalculatorReferences();
      expect(viewModel.temporaryCalculatorReferences, isEmpty);
    },
  );

  test(
    'month aliases find every numeric reference in the matching plan row',
    () {
      final viewModel = LoanPlannerViewModel(
        calculator: LoanCalculator(currentDate: DateTime(2026, 8, 19)),
        initialConfig: const LoanPlanConfig(
          commercialOpeningBalance: 375409.31,
          providentOpeningBalance: 500000,
          commercialAnnualRate: 0.032,
          providentAnnualRate: 0.026,
          monthlySalary: 16500,
          monthlyLivingCost: 3300,
        ),
      );
      addTearDown(viewModel.dispose);

      final augustReferences = viewModel.calculatorReferences
          .where(
            (item) => viewModel.matchesCalculatorReference(item, '2026-08'),
          )
          .toList();
      final labels = augustReferences.map((item) => item.label);
      expect(labels, contains('2026-08 商贷月供'));
      expect(labels, contains('2026-08 月供合计'));
      expect(
        viewModel.calculatorReferences
            .where((item) => viewModel.matchesCalculatorReference(item, '八月'))
            .where((item) => item.isPlanValue),
        isNotEmpty,
      );
    },
  );
}

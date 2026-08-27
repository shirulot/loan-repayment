import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_repayment_manager/domain/models/loan_models.dart';
import 'package:loan_repayment_manager/domain/services/loan_calculator.dart';
import 'package:loan_repayment_manager/ui/features/loan/view_models/loan_planner_view_model.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_detail_page.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_calendar_formatters.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_formatters.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_mobile_layout.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_page.dart';

void main() {
  LoanPlannerViewModel createViewModel() {
    return LoanPlannerViewModel(
      calculator: LoanCalculator(currentDate: DateTime(2026, 8, 19)),
      initialConfig: const LoanPlanConfig(
        commercialOpeningBalance: 375409.31,
        providentOpeningBalance: 500000,
        commercialAnnualRate: 0.032,
        providentAnnualRate: 0.026,
        monthlySalary: 16500,
        monthlyLivingCost: 3300,
        fixedAugustPrepayment: 17000,
        fixedSeptemberPrepayment: 30000,
        fixedOctoberPrepayment: 7000,
        bankSeptemberPrincipal: 1789.55,
        bankSeptemberInterest: 986.24,
      ),
    );
  }

  test('formats a lunar month in the user-facing year-month style', () {
    expect(formatLoanLunarMonth('2026-08'), '2026-6月');
    expect(formatLoanLunarMonth('not-a-month'), '—');
  });

  test('keeps editable amounts free of insignificant trailing zeros', () {
    expect(formatLoanEditableNumber(500000), '500000');
    expect(formatLoanEditableNumber(1.2), '1.2');
    expect(formatLoanEditableNumber(0), '');
  });

  testWidgets('editing an amount preserves its text and caret', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileLoanPlanLayout(
            viewModel: viewModel,
            config: viewModel.config,
            onViewDetails: () {},
            onViewMonth: (_) {},
            onShowInfo: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final recentSection = find.text('最近三笔提前还款');
    await tester.ensureVisible(recentSection);
    await tester.tap(recentSection);
    await tester.pumpAndSettle();

    final amountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '第 1 笔金额',
    );
    expect(amountField, findsOneWidget);
    await tester.ensureVisible(amountField);
    await tester.tap(amountField);
    await tester.enterText(amountField, '1');

    final controller = tester.widget<TextField>(amountField).controller!;
    expect(controller.text, '1');

    await tester.pump(const Duration(milliseconds: 351));

    expect(controller.text, '1');
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
  });

  testWidgets('tapping a preview row reports its repayment month', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);
    String? selectedMonth;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileLoanPlanLayout(
            viewModel: viewModel,
            config: viewModel.config,
            onViewDetails: () {},
            onViewMonth: (month) => selectedMonth = month,
            onShowInfo: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final monthFinder = find.text('2026年9月');
    await tester.ensureVisible(monthFinder);
    await tester.tap(monthFinder);

    expect(selectedMonth, '2026-09');
  });

  testWidgets('future preview skips only a dated settled repayment month', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = LoanPlannerViewModel(
      calculator: LoanCalculator(currentDate: DateTime(2026, 8, 19)),
      initialConfig: const LoanPlanConfig(
        commercialOpeningBalance: 375409.31,
        providentOpeningBalance: 500000,
        commercialAnnualRate: 0.032,
        providentAnnualRate: 0.026,
        monthlySalary: 16500,
        monthlyLivingCost: 3300,
        recentPrepayments: [
          RecentPrepayment(
            id: 'august-settled',
            amount: 17500,
            actualPrepayment: 17500,
            repaymentDate: '2026-08-04',
            isSettled: true,
          ),
        ],
      ),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileLoanPlanLayout(
            viewModel: viewModel,
            config: viewModel.config,
            onViewDetails: () {},
            onViewMonth: (_) {},
            onShowInfo: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026年8月'), findsNothing);
    expect(find.text('2026年9月'), findsOneWidget);
    expect(find.text('2026年10月'), findsOneWidget);
    expect(find.text('2026年11月'), findsOneWidget);
  });

  testWidgets(
    'future preview keeps a settled month when its repayment date is empty',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final viewModel = LoanPlannerViewModel(
        calculator: LoanCalculator(currentDate: DateTime(2026, 8, 19)),
        initialConfig: const LoanPlanConfig(
          commercialOpeningBalance: 375409.31,
          providentOpeningBalance: 500000,
          commercialAnnualRate: 0.032,
          providentAnnualRate: 0.026,
          monthlySalary: 16500,
          monthlyLivingCost: 3300,
          recentPrepayments: [
            RecentPrepayment(
              id: 'august-date-missing',
              amount: 17500,
              actualPrepayment: 17500,
              isSettled: true,
            ),
          ],
        ),
      );
      addTearDown(viewModel.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileLoanPlanLayout(
              viewModel: viewModel,
              config: viewModel.config,
              onViewDetails: () {},
              onViewMonth: (_) {},
              onShowInfo: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026年8月'), findsOneWidget);
    },
  );

  testWidgets('column settings controls lunar and other visible columns', (
    tester,
  ) async {
    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(home: LoanPlanDetailPage(viewModel: viewModel)),
    );
    await tester.pump();

    expect(find.text('公历\n月份'), findsAtLeastNWidgets(1));
    expect(find.text('农历\n月份'), findsNothing);
    expect(find.text('差额'), findsNothing);
    expect(find.text('转息\n差额'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('列设置'));
    await tester.pumpAndSettle();
    expect(find.text('选择显示列'), findsOneWidget);
    expect(find.text('农历月份'), findsOneWidget);

    await tester.tap(find.text('农历月份'));
    await tester.tap(find.text('商贷月供'));
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(find.text('公历\n月份'), findsAtLeastNWidgets(1));
    expect(find.text('农历\n月份'), findsAtLeastNWidgets(1));
    expect(find.text('商贷\n月供'), findsNothing);

    await tester.tap(find.text('列设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认'));
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();

    expect(find.text('公历\n月份'), findsAtLeastNWidgets(1));
    expect(find.text('农历\n月份'), findsNothing);
    expect(find.text('商贷\n月供'), findsAtLeastNWidgets(1));
  });

  testWidgets('tapping a repayment row toggles its highlight', (tester) async {
    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(home: LoanPlanDetailPage(viewModel: viewModel)),
    );
    await tester.pump();

    final row = find.byKey(const ValueKey('plan-row-2026-09'));
    expect(
      tester.getSemantics(row).getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
    );

    await tester.tapAt(tester.getCenter(row));
    await tester.pump();
    expect(
      tester.getSemantics(row).getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );

    await tester.tapAt(tester.getCenter(row));
    await tester.pump();
    expect(
      tester.getSemantics(row).getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
    );
  });

  testWidgets('mobile preview opens the detail table for the selected month', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(home: LoanPlanPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    final monthFinder = find.text('2026年9月');
    await tester.ensureVisible(monthFinder);
    await tester.tap(monthFinder);
    await tester.pumpAndSettle();

    expect(find.text('公历\n月份'), findsAtLeastNWidgets(1));
    expect(find.byKey(const ValueKey('plan-row-2026-09')), findsOneWidget);
  });

  testWidgets('amount masking is shared by the home and repayment plan pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      MaterialApp(home: LoanPlanPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('隐藏金额').first);
    await tester.pumpAndSettle();
    expect(viewModel.amountsMasked, isTrue);
    expect(find.textContaining('****'), findsWidgets);

    await tester.tap(find.text('查看详情').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('****'), findsWidgets);
    expect(find.byTooltip('显示金额'), findsOneWidget);
  });

  testWidgets('detail table scrolls to the requested month', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);
    final targetMonth = viewModel.rows[12].month;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoanPlanDetailPage(
            viewModel: viewModel,
            embedded: true,
            initialMonth: targetMonth,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewport = tester.getRect(find.byType(SingleChildScrollView).first);
    final target = tester.getRect(
      find.byKey(ValueKey('plan-row-$targetMonth')),
    );
    expect(target.top, greaterThanOrEqualTo(viewport.top));
    expect(target.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  testWidgets(
    'frozen header remains visible after horizontal then vertical scroll',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoanPlanDetailPage(viewModel: viewModel, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollViews = find.byType(SingleChildScrollView);
      final viewport = tester.getRect(scrollViews.first);
      final dragStart = Offset(
        viewport.left + viewport.width * 0.7,
        viewport.top + viewport.height * 0.5,
      );
      await tester.dragFrom(dragStart, const Offset(-260, 0));
      await tester.pumpAndSettle();
      await tester.dragFrom(dragStart, const Offset(0, -240));
      await tester.pumpAndSettle();

      final headerFinder = find.text('公历\n月份');
      final hasVisibleFixedHeader = List<bool>.generate(
        headerFinder.evaluate().length,
        (index) {
          final rect = tester.getRect(headerFinder.at(index));
          return rect.top >= viewport.top &&
              rect.top < viewport.top + 32 &&
              rect.left >= 0 &&
              rect.left < 80;
        },
      ).contains(true);
      expect(hasVisibleFixedHeader, isTrue);
    },
  );
}

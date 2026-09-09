import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_repayment_manager/domain/models/loan_models.dart';
import 'package:loan_repayment_manager/domain/services/loan_calculator.dart';
import 'package:loan_repayment_manager/ui/features/loan/view_models/loan_planner_view_model.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_calculator_page.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_detail_page.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_calendar_formatters.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_formatters.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_mobile_layout.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_plan_page.dart';
import 'package:loan_repayment_manager/ui/features/loan/views/loan_month_detail_page.dart';

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

  testWidgets(
    'sorts recent repayments by date and shows the actual settled amount',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final viewModel = LoanPlannerViewModel(
        calculator: LoanCalculator(currentDate: DateTime(2026, 8, 19)),
        initialConfig: const LoanPlanConfig(
          commercialOpeningBalance: 100000,
          remainingTerms: 100,
          recentPrepayments: [
            RecentPrepayment(
              id: 'later',
              amount: 3000,
              repaymentDate: '2026-10-20',
            ),
            RecentPrepayment(
              id: 'settled',
              amount: 5000,
              actualPrepayment: 4200,
              repaymentDate: '2026-09-10',
              isSettled: true,
            ),
            RecentPrepayment(
              id: 'earlier',
              amount: 1000,
              repaymentDate: '2026-08-04',
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

      final recentSection = find.text('最近三笔提前还款');
      await tester.ensureVisible(recentSection);
      await tester.tap(recentSection);
      await tester.pumpAndSettle();

      TextField field(String label) {
        return tester.widget<TextField>(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.labelText == label,
          ),
        );
      }

      expect(field('第 1 笔金额').controller!.text, '1000');
      expect(field('第 2 笔金额').controller!.text, '4200');
      expect(field('第 3 笔金额').controller!.text, '3000');
      expect(field('第 1 笔还款日期').controller!.text, '2026-08-04');
      expect(field('第 2 笔还款日期').controller!.text, '2026-09-10');
      expect(field('第 3 笔还款日期').controller!.text, '2026-10-20');
    },
  );

  test('selects the latest settled repayment by date within one month', () {
    final viewModel = LoanPlannerViewModel(
      calculator: LoanCalculator(currentDate: DateTime(2026, 9, 21)),
      initialConfig: const LoanPlanConfig(
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
      ),
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.latestSettledPrepayment?.id, 'september-late');
    expect(viewModel.latestSettledPrepayment?.actualPrepayment, 31000);
  });

  test(
    'uses the latest repayment-table date not later than today for summary',
    () {
      final viewModel = LoanPlannerViewModel(
        calculator: LoanCalculator(currentDate: DateTime(2026, 9, 9)),
        initialConfig: const LoanPlanConfig(
          commercialOpeningBalance: 100000,
          remainingTerms: 100,
          recentPrepayments: [
            RecentPrepayment(
              id: 'august',
              amount: 17500,
              repaymentDate: '2026-08-05',
            ),
            RecentPrepayment(
              id: 'today',
              amount: 31000,
              repaymentDate: '2026-09-09',
            ),
            RecentPrepayment(
              id: 'future',
              amount: 7000,
              repaymentDate: '2026-10-01',
            ),
          ],
        ),
      );
      addTearDown(viewModel.dispose);

      final latest = viewModel.latestPrepaymentOnOrBeforeToday;
      expect(latest?.id, 'today');
      expect(latest?.amount, 31000);
    },
  );

  testWidgets('keeps newly added repayments in ascending date order', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = LoanPlannerViewModel(
      calculator: LoanCalculator(currentDate: DateTime(2026, 8, 19)),
      initialConfig: const LoanPlanConfig(
        commercialOpeningBalance: 100000,
        remainingTerms: 100,
        recentPrepayments: [
          RecentPrepayment(
            id: 'oldest',
            amount: 1000,
            repaymentDate: '2020-01-01',
          ),
          RecentPrepayment(
            id: 'future-one',
            amount: 2000,
            repaymentDate: '2090-01-01',
          ),
          RecentPrepayment(
            id: 'future-two',
            amount: 3000,
            repaymentDate: '2091-01-01',
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

    final recentSection = find.text('最近三笔提前还款');
    await tester.ensureVisible(recentSection);
    await tester.tap(recentSection);
    await tester.pumpAndSettle();
    final addButton = find.widgetWithText(OutlinedButton, '添加一笔（保留最近三笔）');
    tester.widget<OutlinedButton>(addButton).onPressed!();
    await tester.pumpAndSettle();

    final dates = viewModel.config.recentPrepayments
        .map((event) => event.repaymentDate)
        .toList();
    final sortedDates = List<String>.from(dates)..sort();
    expect(dates, hasLength(3));
    expect(dates, isNot(contains('2020-01-01')));
    expect(dates, sortedDates);

    final visibleDates = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText?.contains('还款日期') == true,
    );
    expect(visibleDates, findsNWidgets(3));
    expect([
      for (var index = 0; index < visibleDates.evaluate().length; index++)
        tester.widget<TextField>(visibleDates.at(index)).controller!.text,
    ], dates);
  });

  testWidgets('preview row opens its repayment month on the second tap', (
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

    expect(find.text('总月供'), findsNothing);
    expect(find.text('商贷月供\n本金'), findsNothing);
    expect(find.text('商贷月供\n利息'), findsNothing);
    expect(find.text('公积金月供\n本金'), findsNothing);
    expect(find.text('公积金月供\n利息'), findsNothing);

    final monthFinder = find.text('2026年9月');
    await tester.ensureVisible(monthFinder);
    await tester.tap(monthFinder);
    expect(selectedMonth, isNull);

    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(monthFinder);
    await tester.pumpAndSettle();

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

  testWidgets('future preview never moves before the calculation month', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = LoanPlannerViewModel(
      calculator: LoanCalculator(currentDate: DateTime(2026, 9, 7)),
      initialConfig: const LoanPlanConfig(
        commercialOpeningBalance: 100000,
        remainingTerms: 100,
        recentPrepayments: [
          RecentPrepayment(
            id: 'july-settled',
            amount: 10000,
            actualPrepayment: 10000,
            repaymentDate: '2026-07-20',
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

    // 完整计划保留 7、8 月历史，但首页预览始终从 9 月开始。
    expect(find.text('2026年7月'), findsNothing);
    expect(find.text('2026年8月'), findsNothing);
    expect(find.text('2026年9月'), findsOneWidget);
    expect(find.text('2026年10月'), findsOneWidget);
    expect(find.text('2026年11月'), findsOneWidget);
  });

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

  testWidgets('tapping a repayment row selects its highlight', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.getSemantics(row).getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('mobile preview opens monthly detail on the second tap', (
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
    await tester.pump();
    expect(find.text('还款详情 · 2026-09'), findsNothing);

    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(monthFinder);
    await tester.pumpAndSettle();

    expect(find.text('还款详情 · 2026-09'), findsOneWidget);
    expect(find.text('商贷月供构成'), findsOneWidget);
  });

  testWidgets('calculator inserts a current home reference', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LoanCalculatorPage(viewModel: viewModel)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('引用首页数值'), findsOneWidget);
    final incomeReference = find.byType(ActionChip).first;
    await tester.ensureVisible(incomeReference);
    await tester.tap(incomeReference);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '【本月收入】',
    );

    final expandButton = find.text('展开全部');
    await tester.ensureVisible(expandButton);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('搜索月份、农历月'), findsOneWidget);
  });

  testWidgets('switching mobile tabs keeps the calculator expression', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 390,
          height: 844,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: LoanPlanPage(viewModel: viewModel),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigationBar = find.byType(NavigationBar);
    final calculatorDestination = find.descendant(
      of: navigationBar,
      matching: find.byIcon(Icons.calculate_outlined),
    );
    await tester.tap(calculatorDestination);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '1'));
    await tester.tap(find.widgetWithText(OutlinedButton, '+'));
    await tester.tap(find.widgetWithText(OutlinedButton, '2'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '1+2',
    );

    await tester.tap(
      find.descendant(
        of: navigationBar,
        matching: find.byIcon(Icons.home_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(calculatorDestination);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '1+2',
    );
  });

  testWidgets('mobile navigation hides the my tab', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      MaterialApp(home: LoanPlanPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的'), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsNothing);
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
    'plan row single tap highlights and second tap opens month detail',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final viewModel = createViewModel();
      addTearDown(viewModel.dispose);
      final targetMonth = viewModel.rows.first.month;
      final rowFinder = find.byKey(ValueKey('plan-row-$targetMonth'));

      await tester.pumpWidget(
        MaterialApp(home: LoanPlanDetailPage(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      await tester.tap(rowFinder);
      expect(find.text('还款详情 · $targetMonth'), findsNothing);

      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(rowFinder);
      await tester.pumpAndSettle();
      expect(find.text('还款详情 · $targetMonth'), findsOneWidget);
      expect(find.text('商贷月供构成'), findsOneWidget);
    },
  );

  testWidgets('month detail swipes left to next and right to previous month', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);
    final targetMonth = viewModel.rows[2].month;
    final previousMonth = viewModel.rows[1].month;
    final nextMonth = viewModel.rows[3].month;

    await tester.pumpWidget(
      MaterialApp(
        home: LoanMonthDetailPage(
          viewModel: viewModel,
          initialMonth: targetMonth,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('还款详情 · $targetMonth'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(find.text('还款详情 · $nextMonth'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(280, 0));
    await tester.pumpAndSettle();
    expect(find.text('还款详情 · $targetMonth'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(280, 0));
    await tester.pumpAndSettle();

    expect(find.text('还款详情 · $previousMonth'), findsOneWidget);
  });

  testWidgets('month detail sums same-month prepayment payment reduction', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final viewModel = LoanPlannerViewModel(
      calculator: LoanCalculator(currentDate: DateTime(2026, 8, 1)),
      initialConfig: const LoanPlanConfig(
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
      ),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: LoanMonthDetailPage(
          viewModel: viewModel,
          initialMonth: '2026-08',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(viewModel.rows.first.prepaymentDetails, hasLength(2));
    expect(
      viewModel.rows[1].nextMonthBasePaymentReduction,
      closeTo(379.2140152, 0.001),
    );
    expect(find.text('下月基础月供减少'), findsOneWidget);
    expect(find.text('379.21'), findsOneWidget);
    expect(find.text('本笔前商贷月供本金'), findsOneWidget);
    expect(find.text('750.00'), findsOneWidget);
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

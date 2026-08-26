import 'package:flutter/material.dart';

import 'ui/features/loan/view_models/loan_planner_view_model.dart';
import 'ui/features/loan/views/loan_plan_page.dart';
import 'ui/theme/loan_palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final viewModel = LoanPlannerViewModel();
  // Restore the last editable state before showing the first frame.
  await viewModel.loadCachedState();
  runApp(LoanRepaymentApp(viewModel: viewModel));
}

class LoanRepaymentApp extends StatefulWidget {
  const LoanRepaymentApp({super.key, required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  State<LoanRepaymentApp> createState() => _LoanRepaymentAppState();
}

class _LoanRepaymentAppState extends State<LoanRepaymentApp> {
  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: LoanPalette.primary,
      brightness: Brightness.light,
      error: LoanPalette.repaymentAccent,
    );
    return MaterialApp(
      title: '提前还贷计算器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: colorScheme.surfaceContainerLowest,
          foregroundColor: colorScheme.onSurface,
          titleTextStyle: const TextStyle(
            fontSize: 19,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: colorScheme.outlineVariant,
          space: 1,
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            // Size.fromHeight uses an infinite width, which is invalid for
            // buttons laid out as non-flex children inside a Row.
            minimumSize: const Size(0, 50),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: LoanPlanPage(viewModel: widget.viewModel),
    );
  }
}

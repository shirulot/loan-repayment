import 'package:flutter/material.dart';

import 'ui/features/loan/view_models/loan_planner_view_model.dart';
import 'ui/features/loan/views/loan_plan_page.dart';

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
    const seed = Color(0xff1f4e78);
    return MaterialApp(
      title: '提前还贷计算器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff5f7fa),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xffd9e2f3)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xffc7d3e3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xffc7d3e3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: seed, width: 2),
          ),
        ),
      ),
      home: LoanPlanPage(viewModel: widget.viewModel),
    );
  }
}

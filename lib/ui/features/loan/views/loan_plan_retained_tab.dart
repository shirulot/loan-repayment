import 'package:flutter/material.dart';

/// 页面离开视口后保留编辑及滚动状态，同时让隐藏页面停止参与布局。
class LoanPlanRetainedTab extends StatefulWidget {
  const LoanPlanRetainedTab({super.key, required this.child});

  final Widget child;

  @override
  State<LoanPlanRetainedTab> createState() => _LoanPlanRetainedTabState();
}

class _LoanPlanRetainedTabState extends State<LoanPlanRetainedTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

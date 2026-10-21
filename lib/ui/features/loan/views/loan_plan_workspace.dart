import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_detail_page.dart';
import 'loan_plan_layout_style.dart';
import 'loan_plan_mobile_layout.dart';

/// C 方案：宽窗口并排编辑与看表，较窄横屏通过参数抽屉保留表格宽度。
class LoanPlanWorkspace extends StatefulWidget {
  const LoanPlanWorkspace({
    super.key,
    required this.viewModel,
    this.initialMonth,
    this.onPrepaymentDeleted,
    this.active = true,
  });
  final LoanPlannerViewModel viewModel;
  final String? initialMonth;
  final ValueChanged<String>? onPrepaymentDeleted;
  final bool active;

  @override
  State<LoanPlanWorkspace> createState() => _LoanPlanWorkspaceState();
}

class _LoanPlanWorkspaceState extends State<LoanPlanWorkspace> {
  bool _parametersOpen = false;
  final _parameterFocus = FocusScopeNode();

  @override
  void dispose() {
    _parameterFocus.dispose();
    super.dispose();
  }

  void _openParameters() {
    setState(() => _parametersOpen = true);
    // 抽屉可见后接管焦点，使 Escape 在尚未点击输入框时也能关闭它。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active && _parametersOpen) {
        _parameterFocus.requestFocus();
      }
    });
  }

  void _closeParameters() => setState(() => _parametersOpen = false);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final sidebar =
          constraints.maxWidth >= LoanPlanLayoutStyle.planSidebarMinWidth;
      final drawer = _parametersOpen && !sidebar;
      final visible = sidebar || drawer;
      final width = math.min(
        LoanPlanLayoutStyle.parameterWidth,
        math.max(0.0, constraints.maxWidth - LoanPlanLayoutStyle.gap),
      );
      final colors = Theme.of(context).colorScheme;
      return PopScope(
        canPop: !drawer || !widget.active,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && drawer) _closeParameters();
        },
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (drawer) _closeParameters();
            },
          },
          child: Stack(
            children: [
              // 表格与编辑器一直保持同一挂载位置，缩放不会清空输入或滚动状态。
              Positioned.fill(
                child: ExcludeFocus(
                  excluding: drawer,
                  child: ExcludeSemantics(
                    excluding: drawer,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: sidebar ? width + LoanPlanLayoutStyle.gap : 0,
                      ),
                      child: LoanPlanDetailPage(
                        viewModel: widget.viewModel,
                        embedded: true,
                        active: widget.active,
                        initialMonth: widget.initialMonth,
                        showOverview: sidebar,
                        onViewParameters:
                            !sidebar &&
                                constraints.maxWidth >=
                                    LoanPlanLayoutStyle.twoColumnMinWidth
                            ? _openParameters
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Offstage(
                  offstage: !drawer,
                  child: ModalBarrier(
                    dismissible: true,
                    onDismiss: _closeParameters,
                    color: colors.scrim.withValues(alpha: 0.36),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: width,
                child: Offstage(
                  offstage: !visible,
                  child: FocusScope(
                    node: _parameterFocus,
                    canRequestFocus: visible && widget.active,
                    child: Material(
                      key: const ValueKey('loan-plan-parameters-panel'),
                      color: colors.surfaceContainerLow,
                      elevation: drawer ? 8 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Offstage(
                            offstage: constraints.maxHeight < 160,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '贷款参数',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  Offstage(
                                    offstage: sidebar,
                                    child: IconButton(
                                      tooltip: '关闭参数',
                                      onPressed: _closeParameters,
                                      icon: const Icon(Icons.close),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: MobileLoanPlanLayout(
                              viewModel: widget.viewModel,
                              config: widget.viewModel.config,
                              parametersOnly: true,
                              onViewDetails: () {},
                              onViewMonth: (_) {},
                              onShowInfo: () {},
                              onPrepaymentDeleted: widget.onPrepaymentDeleted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../data/services/loan_export_service.dart';
import '../../../../data/services/loan_plan_import_service.dart';
import '../../../../data/services/loan_plan_column_settings_service.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_month_detail_page.dart';
import 'loan_plan_column_settings_sheet.dart';
import 'loan_plan_frozen_overlay.dart';
import 'loan_plan_table.dart';
import 'loan_plan_responsive_home.dart';

class LoanPlanDetailPage extends StatefulWidget {
  const LoanPlanDetailPage({
    super.key,
    required this.viewModel,
    this.embedded = false,
    this.initialMonth,
    this.onViewParameters,
    this.showOverview = false,
    this.active = true,
  });

  final LoanPlannerViewModel viewModel;
  final bool embedded;
  final String? initialMonth;
  // 仅在表格无法与参数并排时提供抽屉入口。
  final VoidCallback? onViewParameters;
  final bool showOverview;
  final bool active;

  @override
  State<LoanPlanDetailPage> createState() => _LoanPlanDetailPageState();
}

class _LoanPlanDetailPageState extends State<LoanPlanDetailPage> {
  final _exportService = const LoanExportService();
  final _importService = const LoanPlanImportService();
  final _columnSettingsService = const LoanPlanColumnSettingsService();
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();
  final _targetRowKey = GlobalKey();
  String? _exportPath;
  final _visibleColumns = <LoanPlanColumnKey>{...defaultLoanPlanVisibleColumns};
  var _columnSettingsRevision = 0;
  String? _highlightedMonth;
  Widget? _retainedContent;

  @override
  void initState() {
    super.initState();
    _highlightedMonth = widget.initialMonth;
    unawaited(_restoreVisibleColumns());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToInitialMonth(),
    );
  }

  Future<void> _restoreVisibleColumns() async {
    final savedSettings = await _columnSettingsService.load();
    if (!mounted || _columnSettingsRevision != 0 || savedSettings == null) {
      return;
    }

    final restoredColumns = LoanPlanColumnKey.values
        .where(
          (column) =>
              column != LoanPlanColumnKey.gregorianMonth &&
              savedSettings.visibleColumns.contains(column.name),
        )
        .toSet();
    if (savedSettings.schemaVersion <
        LoanPlanColumnSettingsService.currentSchemaVersion) {
      // Add newly introduced default columns once without overriding future
      // visibility choices made by the user.
      restoredColumns.add(LoanPlanColumnKey.transferDifference);
      restoredColumns.addAll({
        LoanPlanColumnKey.commercialPrincipal,
        LoanPlanColumnKey.commercialInterest,
        LoanPlanColumnKey.providentPrincipal,
        LoanPlanColumnKey.providentInterest,
      });
      unawaited(
        _columnSettingsService.save(
          restoredColumns.map((column) => column.name),
        ),
      );
    }
    setState(() {
      _visibleColumns
        ..clear()
        ..addAll(restoredColumns);
    });
  }

  /// Saves column visibility asynchronously so changing the table stays instant.
  Future<void> _persistVisibleColumns() async {
    try {
      await _columnSettingsService.save(
        _visibleColumns.map((column) => column.name),
      );
    } catch (_) {
      // A settings failure must not interrupt table interaction.
    }
  }

  @override
  void didUpdateWidget(covariant LoanPlanDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMonth != widget.initialMonth) {
      _highlightedMonth = widget.initialMonth;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToInitialMonth(),
      );
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _scrollToInitialMonth() async {
    if (widget.initialMonth == null) return;
    final targetContext = _targetRowKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.3,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// The first tap selects a row; tapping the selected row opens its detail.
  void _selectOrOpenMonth(String month) {
    if (_highlightedMonth == month) {
      unawaited(_openMonthDetail(month));
      return;
    }
    setState(() => _highlightedMonth = month);
  }

  Future<void> _openColumnSettings() async {
    final result = await showLoanPlanColumnSettings(
      context: context,
      visibleColumns: _visibleColumns,
    );
    if (result == null || !mounted) return;
    _columnSettingsRevision++;
    setState(() {
      _visibleColumns
        ..clear()
        ..addAll(result);
    });
    unawaited(_persistVisibleColumns());
  }

  Future<void> _export(String kind) async {
    final result = switch (kind) {
      'Excel' => await _exportService.exportExcel(
        widget.viewModel.config,
        widget.viewModel.rows,
      ),
      'CSV' => await _exportService.exportCsv(
        widget.viewModel.config,
        widget.viewModel.rows,
      ),
      _ => await _exportService.exportJson(
        widget.viewModel.config,
        widget.viewModel.rows,
        widget.viewModel.actualPrepayments,
      ),
    };
    if (!mounted) return;
    setState(() => _exportPath = result.path);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.kind} 已导出：${result.path}')),
    );
  }

  Future<void> _importBackup() async {
    try {
      final state = await _importService.pickBackup();
      if (state == null || !mounted) return;
      widget.viewModel.restoreImportedState(state);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('备份已导入并保存到本机。')));
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法导入：${error.message}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法读取该备份文件。')));
    }
  }

  Future<void> _handleDataAction(String action) async {
    if (action == 'Import') {
      await _importBackup();
      return;
    }
    await _export(action);
  }

  /// Opens the complete monthly detail page for the selected row.
  Future<void> _openMonthDetail(String month) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoanMonthDetailPage(
          viewModel: widget.viewModel,
          initialMonth: month,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        // 已访问的隐藏表格保留现有视图，返回前再读取最新数据；避免保存收入时
        // 仍为不可见的数千个单元格创建新 Widget。首次构建仍正常完成。
        if (!widget.active && _retainedContent != null) {
          return _retainedContent!;
        }
        final content = _buildContent(context);
        if (widget.embedded) return _retainedContent = content;
        return _retainedContent = Scaffold(
          appBar: AppBar(
            title: const Text('还款计划详情'),
            actions: [
              IconButton(
                tooltip: widget.viewModel.amountsMasked ? '显示金额' : '隐藏金额',
                onPressed: widget.viewModel.toggleAmountsMasked,
                icon: Icon(
                  widget.viewModel.amountsMasked
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '导入或导出',
                icon: const Icon(Icons.download_outlined),
                onSelected: _handleDataAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'Excel',
                    child: Text('导出 Excel 兼容文件 (.xls)'),
                  ),
                  PopupMenuItem(value: 'CSV', child: Text('导出 CSV')),
                  PopupMenuItem(value: 'JSON', child: Text('导出 JSON（含参数）')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'Import', child: Text('导入 JSON 备份')),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(child: content),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 矮横屏与键盘弹出时，把列设置收进标题栏，优先保留表格高度。
        final compactHeader = widget.embedded && constraints.maxHeight < 360;
        final minimumTableWidth = LoanPlanTable.minimumWidth(
          visibleColumns: _visibleColumns,
        );
        final tableWidth = math
            .max(constraints.maxWidth - 16, minimumTableWidth)
            .toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embedded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '还款计划',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.onViewParameters != null)
                      TextButton(
                        onPressed: widget.onViewParameters,
                        child: const Text('查看参数'),
                      ),
                    if (compactHeader)
                      IconButton(
                        tooltip: '列设置',
                        onPressed: _openColumnSettings,
                        icon: const Icon(Icons.view_column_outlined),
                      ),
                    if (compactHeader)
                      const Tooltip(
                        message: '实际提前金额仅填本金；利息按当月实际天数计算，剩余天数利息结转下月。',
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.info_outline, size: 18),
                        ),
                      ),
                    IconButton(
                      tooltip: widget.viewModel.amountsMasked ? '显示金额' : '隐藏金额',
                      onPressed: widget.viewModel.toggleAmountsMasked,
                      icon: Icon(
                        widget.viewModel.amountsMasked
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '导入或导出',
                      icon: const Icon(Icons.download_outlined),
                      onSelected: _handleDataAction,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'Excel',
                          child: Text('导出 Excel 兼容文件 (.xls)'),
                        ),
                        PopupMenuItem(value: 'CSV', child: Text('导出 CSV')),
                        PopupMenuItem(
                          value: 'JSON',
                          child: Text('导出 JSON（含参数）'),
                        ),
                        PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'Import',
                          child: Text('导入 JSON 备份'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_exportPath != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: SelectableText(
                  '最近导出：$_exportPath',
                  maxLines: compactHeader ? 1 : null,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (!compactHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Text(
                  '实际提前金额仅填本金；利息按当月实际天数计算，剩余天数利息结转下月。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (!compactHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '已显示 ${_visibleColumns.length + 1} 列',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openColumnSettings,
                      icon: const Icon(Icons.view_column_outlined, size: 18),
                      label: const Text('列设置'),
                    ),
                  ],
                ),
              ),
            // 矮窗口优先给表格留出高度，概况仍可在首页查看。
            if (widget.showOverview && constraints.maxHeight >= 480)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: LoanWideOverview(
                  viewModel: widget.viewModel,
                  columns: 4,
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                      child: Scrollbar(
                        controller: _horizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) =>
                            notification.depth == 1,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: LoanPlanTable(
                              viewModel: widget.viewModel,
                              visibleColumns: _visibleColumns,
                              amountsMasked: widget.viewModel.amountsMasked,
                              targetMonth: widget.initialMonth,
                              targetRowKey: _targetRowKey,
                              highlightedMonth: _highlightedMonth,
                              onRowTap: _selectOrOpenMonth,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  LoanPlanFrozenOverlay(
                    viewModel: widget.viewModel,
                    visibleColumns: _visibleColumns,
                    amountsMasked: widget.viewModel.amountsMasked,
                    highlightedMonth: _highlightedMonth,
                    onRowTap: _selectOrOpenMonth,
                    tableWidth: tableWidth,
                    verticalController: _verticalController,
                    horizontalController: _horizontalController,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

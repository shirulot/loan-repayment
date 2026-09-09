import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../data/services/loan_export_service.dart';
import '../../../../data/services/loan_plan_import_service.dart';
import '../../../../data/services/loan_plan_column_settings_service.dart';
import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_calendar_formatters.dart';
import 'loan_plan_formatters.dart';
import 'loan_month_detail_page.dart';
import 'loan_plan_gesture_detector.dart';

enum _PlanColumnKey {
  gregorianMonth(label: '公历月份', header: '公历\n月份', width: 64),
  lunarMonth(label: '农历月份', header: '农历\n月份', width: 72),
  commercialPayment(label: '商贷月供', header: '商贷\n月供', width: 74),
  commercialPrincipal(label: '商贷月供本金', header: '商贷月供\n本金', width: 78),
  commercialInterest(label: '商贷月供利息', header: '商贷月供\n利息', width: 78),
  commercialReduction(label: '商贷减少', header: '商贷\n减少', width: 74),
  providentPayment(label: '公积金月供', header: '公积金\n月供', width: 74),
  providentPrincipal(label: '公积金月供本金', header: '公积金月供\n本金', width: 82),
  providentInterest(label: '公积金月供利息', header: '公积金月供\n利息', width: 82),
  providentReduction(label: '公积金减少', header: '公积金\n减少', width: 74),
  totalPayment(label: '月供合计', header: '月供\n合计', width: 74),
  totalReduction(label: '总额减少', header: '总额\n减少', width: 74),
  expectedPrepayment(label: '预期提前', header: '预期\n提前', width: 74),
  repaymentDate(label: '还贷日期', header: '还贷\n日期', width: 92),
  repaymentStatus(label: '还贷状态', header: '还贷\n状态', width: 70),
  prepaymentInterest(label: '当日提前利息', header: '当日\n利息', width: 78),
  nextMonthBasePayment(label: '转息前月供', header: '转息前\n月供', width: 86),
  transferDifference(label: '转息差额', header: '转息\n差额', width: 74),
  nextMonthBaseReduction(label: '转息前月供减少', header: '转息前\n月供减少', width: 78),
  commercialBalance(label: '商贷余额', header: '商贷\n余额', width: 80),
  providentBalance(label: '公积金余额', header: '公积金\n余额', width: 80),
  totalBalance(label: '本金合计', header: '本金\n合计', width: 80);

  const _PlanColumnKey({
    required this.label,
    required this.header,
    required this.width,
  });

  final String label;
  final String header;
  final double width;
}

const _defaultPlanVisibleColumns = <_PlanColumnKey>{
  _PlanColumnKey.commercialPayment,
  _PlanColumnKey.commercialPrincipal,
  _PlanColumnKey.commercialInterest,
  _PlanColumnKey.commercialReduction,
  _PlanColumnKey.providentPayment,
  _PlanColumnKey.providentPrincipal,
  _PlanColumnKey.providentInterest,
  _PlanColumnKey.providentReduction,
  _PlanColumnKey.totalPayment,
  _PlanColumnKey.totalReduction,
  _PlanColumnKey.expectedPrepayment,
  _PlanColumnKey.repaymentDate,
  _PlanColumnKey.repaymentStatus,
  _PlanColumnKey.prepaymentInterest,
  _PlanColumnKey.nextMonthBasePayment,
  _PlanColumnKey.transferDifference,
  _PlanColumnKey.nextMonthBaseReduction,
  _PlanColumnKey.commercialBalance,
  _PlanColumnKey.providentBalance,
  _PlanColumnKey.totalBalance,
};

/// A display row expands one monthly calculation into one row per repayment
/// event. Each row compares its monthly fields with the preceding month,
/// never with another transaction in the same month.
class _PlanDisplayRow {
  const _PlanDisplayRow({
    required this.row,
    this.prepayment,
    required this.isPrimary,
    required this.isLast,
  });

  final LoanPlanRow row;
  final LoanPrepaymentDetail? prepayment;
  final bool isPrimary;
  final bool isLast;

  static List<_PlanDisplayRow> expand(List<LoanPlanRow> rows) {
    return [
      for (final row in rows)
        if (row.prepaymentDetails.length <= 1)
          _PlanDisplayRow(
            row: row,
            prepayment: row.prepaymentDetails.isEmpty
                ? null
                : row.prepaymentDetails.single,
            isPrimary: true,
            isLast: true,
          )
        else
          for (var index = 0; index < row.prepaymentDetails.length; index++)
            _PlanDisplayRow(
              row: row,
              prepayment: row.prepaymentDetails[index],
              isPrimary: index == 0,
              isLast: index == row.prepaymentDetails.length - 1,
            ),
    ];
  }
}

/// Full-screen, compact view for editing and reviewing all repayment rows.
class LoanPlanDetailPage extends StatefulWidget {
  const LoanPlanDetailPage({
    super.key,
    required this.viewModel,
    this.embedded = false,
    this.initialMonth,
  });

  final LoanPlannerViewModel viewModel;
  final bool embedded;
  final String? initialMonth;

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
  final _visibleColumns = <_PlanColumnKey>{..._defaultPlanVisibleColumns};
  var _columnSettingsRevision = 0;
  String? _highlightedMonth;

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

    final restoredColumns = _PlanColumnKey.values
        .where(
          (column) =>
              column != _PlanColumnKey.gregorianMonth &&
              savedSettings.visibleColumns.contains(column.name),
        )
        .toSet();
    if (savedSettings.schemaVersion <
        LoanPlanColumnSettingsService.currentSchemaVersion) {
      // Add newly introduced default columns once without overriding future
      // visibility choices made by the user.
      restoredColumns.add(_PlanColumnKey.transferDifference);
      restoredColumns.addAll({
        _PlanColumnKey.commercialPrincipal,
        _PlanColumnKey.commercialInterest,
        _PlanColumnKey.providentPrincipal,
        _PlanColumnKey.providentInterest,
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
    var selected = Set<_PlanColumnKey>.from(_visibleColumns);
    final result = await showModalBottomSheet<Set<_PlanColumnKey>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final optionalColumns = _PlanColumnKey.values
                .where((column) => column != _PlanColumnKey.gregorianMonth)
                .toList();
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '选择显示列',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '公历月份始终保留并固定，其他列可按需开关。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: true,
                            onChanged: null,
                            title: const Text('公历月份'),
                            subtitle: const Text('固定显示'),
                          ),
                          ...optionalColumns.map(
                            (column) => CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: selected.contains(column),
                              onChanged: (checked) {
                                setSheetState(() {
                                  if (checked == true) {
                                    selected.add(column);
                                  } else {
                                    selected.remove(column);
                                  }
                                });
                              },
                              title: Text(column.label),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              selected = Set<_PlanColumnKey>.from(
                                _defaultPlanVisibleColumns,
                              );
                            });
                          },
                          child: const Text('恢复默认'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.of(
                            sheetContext,
                          ).pop(Set<_PlanColumnKey>.from(selected)),
                          child: const Text('应用'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
        final content = _buildContent(context);
        if (widget.embedded) return content;
        return Scaffold(
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
        final minimumTableWidth = _CompactPlanTable.minimumWidth(
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
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Text(
                '实际提前金额仅填本金；利息按当月实际天数计算，剩余天数利息结转下月。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
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
                            child: _CompactPlanTable(
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
                  _FrozenPlanOverlay(
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

/// Uses fixed compact columns so a landscape window can show more fields at once.
class _CompactPlanTable extends StatelessWidget {
  const _CompactPlanTable({
    required this.viewModel,
    required this.visibleColumns,
    required this.amountsMasked,
    this.targetMonth,
    this.targetRowKey,
    required this.highlightedMonth,
    required this.onRowTap,
  });

  static const headerHeight = 36.0;
  static const bodyRowHeight = 40.0;

  final LoanPlannerViewModel viewModel;
  final Set<_PlanColumnKey> visibleColumns;
  final bool amountsMasked;
  final String? targetMonth;
  final GlobalKey? targetRowKey;
  final String? highlightedMonth;
  final ValueChanged<String> onRowTap;

  static List<_PlanColumnKey> columns({
    required Set<_PlanColumnKey> visibleColumns,
  }) {
    return _PlanColumnKey.values
        .where(
          (column) =>
              column == _PlanColumnKey.gregorianMonth ||
              visibleColumns.contains(column),
        )
        .toList();
  }

  static List<_PlanColumnKey> fixedColumns({
    required Set<_PlanColumnKey> visibleColumns,
  }) {
    return columns(visibleColumns: visibleColumns)
        .where(
          (column) =>
              column == _PlanColumnKey.gregorianMonth ||
              column == _PlanColumnKey.lunarMonth,
        )
        .toList();
  }

  static double minimumWidth({required Set<_PlanColumnKey> visibleColumns}) {
    return columns(
      visibleColumns: visibleColumns,
    ).fold<double>(0, (total, column) => total + column.width);
  }

  static double fixedColumnWidth({
    required Set<_PlanColumnKey> visibleColumns,
  }) {
    return fixedColumns(
      visibleColumns: visibleColumns,
    ).fold<double>(0, (total, column) => total + column.width);
  }

  static Map<int, TableColumnWidth> columnWidthMap({
    required Set<_PlanColumnKey> visibleColumns,
  }) {
    final columnsToRender = columns(visibleColumns: visibleColumns);
    return <int, TableColumnWidth>{
      for (var index = 0; index < columnsToRender.length; index++)
        index: FixedColumnWidth(columnsToRender[index].width),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = _PlanDisplayRow.expand(viewModel.rows);
    final columnsToRender = columns(visibleColumns: visibleColumns);

    return Table(
      columnWidths: columnWidthMap(visibleColumns: visibleColumns),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _tableBorder(colors),
      children: [
        TableRow(
          decoration: BoxDecoration(color: colors.primary),
          children: columnsToRender
              .map(
                (column) =>
                    _headerCell(column.header, backgroundColor: colors.primary),
              )
              .toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final displayRow = entry.value;
          final row = displayRow.row;
          void onTap() => onRowTap(row.month);
          Widget cell(Widget child) => _tapCell(child, onTap);
          final rowCells = <Widget>[];
          for (final column in columnsToRender) {
            Widget columnCell = _bodyCell(
              _dataCell(
                context: context,
                column: column,
                displayRow: displayRow,
                viewModel: viewModel,
                amountsMasked: amountsMasked,
              ),
            );
            if (column == _PlanColumnKey.gregorianMonth &&
                row.month == targetMonth &&
                targetRowKey != null) {
              columnCell = KeyedSubtree(key: targetRowKey, child: columnCell);
            }
            if (column == _PlanColumnKey.gregorianMonth) {
              columnCell = Semantics(
                container: true,
                key: ValueKey<String>('plan-row-${row.month}'),
                label: '还款计划行 ${row.month}',
                selected: row.month == highlightedMonth,
                child: columnCell,
              );
            }
            rowCells.add(cell(columnCell));
          }

          return TableRow(
            decoration: BoxDecoration(
              color: row.month == highlightedMonth
                  ? colors.secondaryContainer
                  : row.totalBalance < 0.01
                  ? colors.tertiaryContainer
                  : rowIndex.isEven
                  ? colors.surface
                  : colors.surfaceContainerLowest,
            ),
            children: rowCells,
          );
        }),
      ],
    );
  }

  static Widget _dataCell({
    required BuildContext context,
    required _PlanColumnKey column,
    required _PlanDisplayRow displayRow,
    required LoanPlannerViewModel viewModel,
    required bool amountsMasked,
  }) {
    final row = displayRow.row;
    final prepayment = displayRow.prepayment;
    // An expanded transaction uses its own normal-payment step instead of
    // repeating the outer calendar row's payment values. Later same-month
    // transactions do not display a second normal payment.
    final paymentBefore = prepayment?.hasNormalPaymentBefore == true
        ? prepayment
        : null;
    final isLaterSameMonthPrepayment =
        prepayment != null && !displayRow.isPrimary;
    final commercialPayment =
        paymentBefore?.commercialPaymentBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.commercialPayment);
    final commercialPrincipal =
        paymentBefore?.commercialPrincipalBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.commercialPrincipal);
    final commercialInterest =
        paymentBefore?.commercialInterestBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.commercialInterest);
    final providentPayment =
        paymentBefore?.providentPaymentBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.providentPayment);
    final providentPrincipal =
        paymentBefore?.providentPrincipalBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.providentPrincipal);
    final providentInterest =
        paymentBefore?.providentInterestBefore ??
        (isLaterSameMonthPrepayment ? 0 : row.providentInterest);
    final totalPayment = paymentBefore == null
        ? isLaterSameMonthPrepayment
              ? 0.0
              : row.totalPayment
        : paymentBefore.commercialPaymentBefore +
              paymentBefore.providentPaymentBefore;
    final colors = Theme.of(context).colorScheme;
    return switch (column) {
      _PlanColumnKey.gregorianMonth => _textCell(
        row.month,
        align: TextAlign.center,
        bold: true,
      ),
      _PlanColumnKey.lunarMonth => _textCell(
        formatLoanLunarMonth(row.month),
        align: TextAlign.center,
      ),
      _PlanColumnKey.commercialPayment => _textCell(
        formatLoanMoneyProtected(
          commercialPayment,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
      ),
      _PlanColumnKey.commercialPrincipal => _textCell(
        formatLoanMoneyProtected(commercialPrincipal, masked: amountsMasked),
      ),
      _PlanColumnKey.commercialInterest => _textCell(
        formatLoanMoneyProtected(commercialInterest, masked: amountsMasked),
      ),
      _PlanColumnKey.commercialReduction => _textCell(
        formatLoanMoneyProtected(
          row.commercialReduction,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
      ),
      _PlanColumnKey.providentPayment => _textCell(
        formatLoanMoneyProtected(
          providentPayment,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
      ),
      _PlanColumnKey.providentPrincipal => _textCell(
        formatLoanMoneyProtected(providentPrincipal, masked: amountsMasked),
      ),
      _PlanColumnKey.providentInterest => _textCell(
        formatLoanMoneyProtected(providentInterest, masked: amountsMasked),
      ),
      _PlanColumnKey.providentReduction => _textCell(
        formatLoanMoneyProtected(
          row.providentReduction,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
      ),
      _PlanColumnKey.totalPayment => _textCell(
        formatLoanMoneyProtected(totalPayment, masked: amountsMasked),
        bold: true,
      ),
      _PlanColumnKey.totalReduction => _textCell(
        formatLoanMoneyProtected(
          row.totalReduction,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
        color: colors.primary,
        bold: row.totalReduction != null,
      ),
      _PlanColumnKey.expectedPrepayment => _textCell(
        formatLoanMoneyProtected(
          prepayment?.expectedAmount ?? row.expectedPrepayment,
          masked: amountsMasked,
        ),
        color: colors.primary,
      ),
      _PlanColumnKey.repaymentDate => _textCell(
        amountsMasked
            ? '****'
            : (prepayment?.repaymentDate ?? row.effectivePrepaymentDate ?? '—'),
      ),
      _PlanColumnKey.repaymentStatus => _textCell(
        (prepayment?.actualPrepayment ?? row.actualPrepayment) == null
            ? '预定日期'
            : '已结清',
        bold: (prepayment?.actualPrepayment ?? row.actualPrepayment) != null,
        color: (prepayment?.actualPrepayment ?? row.actualPrepayment) == null
            ? colors.onSurfaceVariant
            : colors.tertiary,
      ),
      _PlanColumnKey.prepaymentInterest => _textCell(
        formatLoanMoneyProtected(
          prepayment?.interestDueNow ?? row.prepaymentInterestDueNow,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
        color: (prepayment?.interestDueNow ?? row.prepaymentInterestDueNow) > 0
            ? colors.tertiary
            : colors.onSurfaceVariant,
      ),
      _PlanColumnKey.nextMonthBasePayment => _textCell(
        formatLoanMoneyProtected(
          row.nextMonthBasePayment,
          masked: amountsMasked,
        ),
        bold: true,
        color: colors.primary,
      ),
      _PlanColumnKey.transferDifference => _textCell(
        formatLoanMoneyProtected(row.transferDifference, masked: amountsMasked),
        color: row.transferDifference == 0
            ? colors.onSurfaceVariant
            : colors.tertiary,
      ),
      _PlanColumnKey.nextMonthBaseReduction => _textCell(
        formatLoanMoneyProtected(
          row.nextMonthBasePaymentReduction,
          masked: amountsMasked,
          dashWhenEmpty: true,
        ),
        color: row.nextMonthBasePaymentReduction == null
            ? colors.onSurfaceVariant
            : colors.primary,
      ),
      _PlanColumnKey.commercialBalance => _textCell(
        formatLoanMoneyProtected(
          prepayment?.commercialClosing ?? row.commercialClosing,
          masked: amountsMasked,
        ),
      ),
      _PlanColumnKey.providentBalance => _textCell(
        formatLoanMoneyProtected(
          prepayment?.providentClosing ?? row.providentClosing,
          masked: amountsMasked,
        ),
      ),
      _PlanColumnKey.totalBalance => _textCell(
        formatLoanMoneyProtected(
          prepayment?.totalBalance ?? row.totalBalance,
          masked: amountsMasked,
        ),
      ),
    };
  }

  static Widget _headerCell(String text, {required Color backgroundColor}) {
    return ColoredBox(
      color: backgroundColor,
      child: SizedBox(
        width: double.infinity,
        height: headerHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: Text(
            text,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.05,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _bodyCell(Widget child) {
    return SizedBox(height: bodyRowHeight, child: child);
  }

  static Widget _tapCell(Widget child, VoidCallback onTap) {
    return LoanPlanGestureDetector(onTap: onTap, child: child);
  }

  static Widget _textCell(
    String text, {
    TextAlign align = TextAlign.center,
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: color,
        ),
      ),
    );
  }

  static TableBorder _tableBorder(ColorScheme colors) {
    return TableBorder(
      top: BorderSide(color: colors.outlineVariant),
      bottom: BorderSide(color: colors.outlineVariant),
      left: BorderSide(color: colors.outlineVariant),
      right: BorderSide(color: colors.outlineVariant),
      horizontalInside: BorderSide(
        color: colors.outlineVariant.withValues(alpha: 0.72),
        width: 0.6,
      ),
      verticalInside: BorderSide(
        color: colors.outlineVariant.withValues(alpha: 0.42),
        width: 0.45,
      ),
    );
  }
}

/// Keeps the selected fixed columns and the header visible over both scroll axes.
class _FrozenPlanOverlay extends StatelessWidget {
  const _FrozenPlanOverlay({
    required this.viewModel,
    required this.visibleColumns,
    required this.amountsMasked,
    required this.highlightedMonth,
    required this.onRowTap,
    required this.tableWidth,
    required this.verticalController,
    required this.horizontalController,
  });

  static const _tableInset = 8.0;

  final LoanPlannerViewModel viewModel;
  final Set<_PlanColumnKey> visibleColumns;
  final bool amountsMasked;
  final String? highlightedMonth;
  final ValueChanged<String> onRowTap;
  final double tableWidth;
  final ScrollController verticalController;
  final ScrollController horizontalController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([verticalController, horizontalController]),
      builder: (context, _) {
        final verticalOffset = verticalController.hasClients
            ? verticalController.offset
            : 0.0;
        final horizontalOffset = horizontalController.hasClients
            ? horizontalController.offset
            : 0.0;
        final fixedWidth = _CompactPlanTable.fixedColumnWidth(
          visibleColumns: visibleColumns,
        );
        final headerColor = Theme.of(context).colorScheme.primary;

        return Stack(
          children: [
            // Paint an opaque surface behind the whole frozen header so the
            // row underneath cannot show through after two-axis scrolling.
            Positioned(
              top: 0,
              left: _tableInset,
              right: _tableInset,
              height: _CompactPlanTable.headerHeight,
              child: ColoredBox(color: headerColor),
            ),
            Positioned(
              top: 0,
              left: _tableInset + fixedWidth,
              right: _tableInset,
              height: _CompactPlanTable.headerHeight,
              child: IgnorePointer(
                child: ClipRect(
                  child: Transform.translate(
                    offset: Offset(-fixedWidth - horizontalOffset, 0),
                    child: _FrozenPlanHeader(
                      visibleColumns: visibleColumns,
                      tableWidth: tableWidth,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: _tableInset,
              width: fixedWidth,
              height: _CompactPlanTable.headerHeight,
              child: IgnorePointer(
                child: _FrozenFixedHeader(visibleColumns: visibleColumns),
              ),
            ),
            Positioned(
              top: _CompactPlanTable.headerHeight,
              bottom: 0,
              left: _tableInset,
              width: fixedWidth,
              child: ClipRect(
                child: Transform.translate(
                  offset: Offset(0, -verticalOffset),
                  child: _FrozenFixedColumns(
                    viewModel: viewModel,
                    visibleColumns: visibleColumns,
                    amountsMasked: amountsMasked,
                    highlightedMonth: highlightedMonth,
                    onRowTap: onRowTap,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FrozenPlanHeader extends StatelessWidget {
  const _FrozenPlanHeader({
    required this.visibleColumns,
    required this.tableWidth,
  });

  final Set<_PlanColumnKey> visibleColumns;
  final double tableWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final columns = _CompactPlanTable.columns(visibleColumns: visibleColumns);
    return SizedBox(
      width: tableWidth,
      height: _CompactPlanTable.headerHeight,
      child: Table(
        columnWidths: _CompactPlanTable.columnWidthMap(
          visibleColumns: visibleColumns,
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: _CompactPlanTable._tableBorder(colors),
        children: [
          TableRow(
            decoration: BoxDecoration(color: colors.primary),
            children: columns
                .map(
                  (column) => _CompactPlanTable._headerCell(
                    column.header,
                    backgroundColor: colors.primary,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FrozenFixedHeader extends StatelessWidget {
  const _FrozenFixedHeader({required this.visibleColumns});

  final Set<_PlanColumnKey> visibleColumns;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final columns = _CompactPlanTable.fixedColumns(
      visibleColumns: visibleColumns,
    );
    return Table(
      columnWidths: {
        for (var index = 0; index < columns.length; index++)
          index: FixedColumnWidth(columns[index].width),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _CompactPlanTable._tableBorder(colors),
      children: [
        TableRow(
          decoration: BoxDecoration(color: colors.primary),
          children: columns
              .map(
                (column) => _CompactPlanTable._headerCell(
                  column.header,
                  backgroundColor: colors.primary,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _FrozenFixedColumns extends StatelessWidget {
  const _FrozenFixedColumns({
    required this.viewModel,
    required this.visibleColumns,
    required this.amountsMasked,
    required this.highlightedMonth,
    required this.onRowTap,
  });

  final LoanPlannerViewModel viewModel;
  final Set<_PlanColumnKey> visibleColumns;
  final bool amountsMasked;
  final String? highlightedMonth;
  final ValueChanged<String> onRowTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final columns = _CompactPlanTable.fixedColumns(
      visibleColumns: visibleColumns,
    );
    return Table(
      columnWidths: {
        for (var index = 0; index < columns.length; index++)
          index: FixedColumnWidth(columns[index].width),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _CompactPlanTable._tableBorder(colors),
      children: _PlanDisplayRow.expand(viewModel.rows).asMap().entries.map((
        entry,
      ) {
        final rowIndex = entry.key;
        final displayRow = entry.value;
        final row = displayRow.row;
        final rowColor = row.month == highlightedMonth
            ? colors.secondaryContainer
            : row.totalBalance < 0.01
            ? colors.tertiaryContainer
            : rowIndex.isEven
            ? colors.surface
            : colors.surfaceContainerLowest;
        void onTap() => onRowTap(row.month);
        return TableRow(
          decoration: BoxDecoration(color: rowColor),
          children: columns
              .map(
                (column) => _CompactPlanTable._tapCell(
                  _CompactPlanTable._bodyCell(
                    _CompactPlanTable._dataCell(
                      context: context,
                      column: column,
                      displayRow: displayRow,
                      viewModel: viewModel,
                      amountsMasked: amountsMasked,
                    ),
                  ),
                  onTap,
                ),
              )
              .toList(),
        );
      }).toList(),
    );
  }
}

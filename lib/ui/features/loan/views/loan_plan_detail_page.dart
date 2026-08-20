import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/services/loan_export_service.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';

/// Full-screen, compact view for editing and reviewing all repayment rows.
class LoanPlanDetailPage extends StatefulWidget {
  const LoanPlanDetailPage({super.key, required this.viewModel});

  final LoanPlannerViewModel viewModel;

  @override
  State<LoanPlanDetailPage> createState() => _LoanPlanDetailPageState();
}

class _LoanPlanDetailPageState extends State<LoanPlanDetailPage> {
  final _exportService = const LoanExportService();
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();
  String? _exportPath;

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
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
      ),
    };
    if (!mounted) return;
    setState(() => _exportPath = result.path);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.kind} 已导出：${result.path}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('还款计划详情'),
            actions: [
              PopupMenuButton<String>(
                tooltip: '导出',
                icon: const Icon(Icons.download_outlined),
                onSelected: _export,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'Excel',
                    child: Text('导出 Excel 兼容文件 (.xls)'),
                  ),
                  PopupMenuItem(value: 'CSV', child: Text('导出 CSV')),
                  PopupMenuItem(value: 'JSON', child: Text('导出 JSON（含参数）')),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = math
                    .max(constraints.maxWidth - 16, 980.0)
                    .toDouble();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        '横屏窗口会尽量一次显示完整行；实际提前还款在淡黄色单元格中录入。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
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
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Uses fixed compact columns so a landscape window can show more fields at once.
class _CompactPlanTable extends StatelessWidget {
  const _CompactPlanTable({required this.viewModel});

  static const _headers = <String>[
    '月份',
    '商贷\n月供',
    '商贷\n减少',
    '公积金\n月供',
    '公积金\n减少',
    '月供\n合计',
    '总额\n减少',
    '预期\n提前',
    '实际\n提前',
    '差额',
    '商贷\n余额',
    '公积金\n余额',
    '本金\n合计',
  ];

  static const _columnWidths = <double>[
    64,
    74,
    74,
    74,
    74,
    74,
    74,
    74,
    78,
    70,
    80,
    80,
    80,
  ];

  final LoanPlannerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = viewModel.rows;
    final columnWidths = <int, TableColumnWidth>{
      for (var index = 0; index < _columnWidths.length; index++)
        index: FixedColumnWidth(_columnWidths[index]),
    };

    return Table(
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder.all(color: colors.outlineVariant, width: 0.6),
      children: [
        TableRow(
          decoration: BoxDecoration(color: colors.primary),
          children: _headers.map((header) => _headerCell(header)).toList(),
        ),
        ...rows.map(
          (row) => TableRow(
            decoration: row.totalBalance < 0.01
                ? const BoxDecoration(color: Color(0xffe2f0d9))
                : null,
            children: [
              _textCell(row.month, align: TextAlign.center, bold: true),
              _textCell(formatLoanMoneyOrDash(row.commercialPayment)),
              _textCell(formatLoanMoneyOrDash(row.commercialReduction)),
              _textCell(formatLoanMoneyOrDash(row.providentPayment)),
              _textCell(formatLoanMoneyOrDash(row.providentReduction)),
              _textCell(formatLoanMoney(row.totalPayment)),
              _textCell(formatLoanMoneyOrDash(row.totalReduction)),
              _textCell(formatLoanMoney(row.expectedPrepayment)),
              _ActualPrepaymentCell(
                key: ValueKey(row.month),
                value: row.actualPrepayment,
                onChanged: (value) =>
                    viewModel.updateActualPrepayment(row.month, value),
              ),
              _textCell(formatLoanMoneyOrDash(row.difference)),
              _textCell(formatLoanMoney(row.commercialClosing)),
              _textCell(formatLoanMoney(row.providentClosing)),
              _textCell(formatLoanMoney(row.totalBalance)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Text(
        text,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.clip,
        style: const TextStyle(
          fontSize: 10,
          height: 1.05,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _textCell(
    String text, {
    TextAlign align = TextAlign.right,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        textAlign: align,
        style: TextStyle(
          fontSize: 10.5,
          height: 1,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _ActualPrepaymentCell extends StatefulWidget {
  const _ActualPrepaymentCell({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  State<_ActualPrepaymentCell> createState() => _ActualPrepaymentCellState();
}

class _ActualPrepaymentCellState extends State<_ActualPrepaymentCell> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _asText(widget.value));
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _ActualPrepaymentCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != _asText(widget.value)) {
      _controller.text = _asText(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final text = _controller.text.trim();
    widget.onChanged(text.isEmpty ? null : double.tryParse(text));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: SizedBox(
        height: 30,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onSubmitted: (_) => _commit(),
          onEditingComplete: _commit,
          style: const TextStyle(fontSize: 10.5),
          decoration: const InputDecoration(
            hintText: '实际',
            hintStyle: TextStyle(fontSize: 10),
            filled: true,
            fillColor: Color(0xfffff2cc),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  String _asText(double? value) =>
      value == null ? '' : value.toStringAsFixed(2);
}

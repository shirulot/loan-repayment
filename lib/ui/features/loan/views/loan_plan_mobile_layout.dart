import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/extensions/string_extensions.dart';
import '../../../../domain/models/loan_models.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';
import 'loan_plan_frequency_selector.dart';
import 'loan_plan_mobile_apply_button.dart';
import 'loan_plan_mobile_cash_flow.dart';
import 'loan_plan_mobile_header.dart';
import 'loan_plan_mobile_preview.dart';
import 'loan_plan_mobile_settings.dart';
import 'loan_plan_responsive_home.dart';
import 'loan_repayment_method_selector.dart';

/// Compact phone layout that keeps the repayment preview above the fold.
class MobileLoanPlanLayout extends StatefulWidget {
  const MobileLoanPlanLayout({
    super.key,
    required this.viewModel,
    required this.config,
    required this.onViewDetails,
    required this.onViewMonth,
    required this.onShowInfo,
    this.onOpenAppearance,
    this.onPrepaymentDeleted,
    this.parametersOnly = false,
  });

  final LoanPlannerViewModel viewModel;
  final LoanPlanConfig config;
  final VoidCallback onViewDetails;
  final ValueChanged<String> onViewMonth;
  final VoidCallback onShowInfo;
  final VoidCallback? onOpenAppearance;
  final ValueChanged<String>? onPrepaymentDeleted;

  // 计划页复用同一套表单处理，不另建桌面数据规则。
  final bool parametersOnly;

  @override
  State<MobileLoanPlanLayout> createState() => _MobileLoanPlanLayoutState();
}

class _MobileLoanPlanLayoutState extends State<MobileLoanPlanLayout> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  // Tracks active edits so model synchronization does not overwrite them.
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};
  late List<RecentPrepayment> _recentPrepayments;
  Timer? _recentPrepaymentSyncTimer;
  // Stores correction mode by event identity so sorting does not unlock the
  // wrong repayment row.
  final Set<String> _correctingRecentPrepaymentIds = <String>{};
  final Set<String> _expandedSections = <String>{};
  String? _highlightedPreviewMonth;
  String? _lastEditedDurationKey;
  // 跨单双栏重排时保留输入框的焦点、光标及展开状态。
  final _settingsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _recentPrepayments = _recentEventsForEditing(widget.config);
    _syncFromConfig();
  }

  @override
  void didUpdateWidget(covariant MobileLoanPlanLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _recentPrepayments = _recentEventsForEditing(widget.config);
      _correctingRecentPrepaymentIds.retainAll(
        _recentPrepayments.map((event) => event.id),
      );
      _syncFromConfig();
    }
  }

  @override
  void dispose() {
    _recentPrepaymentSyncTimer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  FocusNode _focusNodeFor(String key) =>
      _focusNodes.putIfAbsent(key, FocusNode.new);

  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  /// Avoids rewriting an active field when its own edit triggers a model sync.
  void _setControllerTextIfIdle(String key, String value) {
    final controller = _controllers.putIfAbsent(key, TextEditingController.new);
    if (_focusNodeFor(key).hasFocus || controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _syncFromConfig() {
    for (final entry in _values(widget.config).entries) {
      _setControllerTextIfIdle(entry.key, entry.value);
    }
  }

  Map<String, String> _values(LoanPlanConfig config) {
    String editableNumber(double value) => formatLoanEditableNumber(value);
    return {
      'commercialOpeningBalance': editableNumber(
        config.commercialOpeningBalance,
      ),
      'providentOpeningBalance': editableNumber(config.providentOpeningBalance),
      'commercialAnnualRate': editableNumber(config.commercialAnnualRate * 100),
      'providentAnnualRate': editableNumber(config.providentAnnualRate * 100),
      'loanStartDate': config.loanStartDate,
      'loanTermYears': formatLoanEditableNumber(config.loanTermYears),
      'remainingTerms': '${widget.viewModel.calculatedRemainingTerms}',
      'monthlySalary': editableNumber(config.monthlySalary),
      'monthlyExtraIncome': editableNumber(config.monthlyExtraIncome),
      'monthlyLivingCost': editableNumber(config.monthlyLivingCost),
      'monthlyOtherExpense': editableNumber(config.monthlyOtherExpense),
      for (final event in _recentPrepayments) ...{
        _recentAmountKey(event): editableNumber(_displayAmount(event)),
        _recentDateKey(event): event.repaymentDate,
      },
    };
  }

  double _number(String key, double fallback) =>
      (_controllers[key]?.text ?? '').toDoubleOr(fallback);

  double _zeroIfBlank(String key) =>
      (_controllers[key]?.text ?? '').toDoubleOr(0);

  void _apply() {
    final old = widget.viewModel.config;
    final loanStartDate = _controllers['loanStartDate']?.text.trim() ?? '';
    final loanTermYears = (_controllers['loanTermYears']?.text ?? '')
        .toDoubleOr(0);
    final remainingTerms = (_controllers['remainingTerms']?.text ?? '').toIntOr(
      old.remainingTermsAt(widget.viewModel.calculationDate),
    );
    final hasStartDate = !loanStartDate.isBlank;
    final hasTermYears = loanTermYears > 0;
    if (hasStartDate != hasTermYears ||
        (hasStartDate &&
            LoanPlanConfig.parseLoanStartDate(loanStartDate) == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请同时填写有效的贷款开始日期和总年限。')));
      return;
    }
    if (!_hasValidRecentPrepaymentDates()) return;

    var updatedConfig = old.copyWith(
      commercialOpeningBalance: _number(
        'commercialOpeningBalance',
        old.commercialOpeningBalance,
      ),
      providentOpeningBalance: _number(
        'providentOpeningBalance',
        old.providentOpeningBalance,
      ),
      commercialAnnualRate:
          _number('commercialAnnualRate', old.commercialAnnualRate * 100) / 100,
      providentAnnualRate:
          _number('providentAnnualRate', old.providentAnnualRate * 100) / 100,
      loanStartDate: loanStartDate,
      loanTermYears: loanTermYears,
      monthlySalary: _number('monthlySalary', old.monthlySalary),
      monthlyExtraIncome: _number('monthlyExtraIncome', old.monthlyExtraIncome),
      monthlyLivingCost: _number('monthlyLivingCost', old.monthlyLivingCost),
      monthlyOtherExpense: _zeroIfBlank('monthlyOtherExpense'),
      recentPrepayments: _eventsFromControllers(),
    );
    if (_lastEditedDurationKey == 'remainingTerms') {
      updatedConfig = updatedConfig.withRemainingTermsAt(
        widget.viewModel.calculationDate,
        remainingTerms,
      );
    }
    widget.viewModel.updateConfig(updatedConfig);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('参数已应用，计划已重算。')));
  }

  bool _hasValidRecentPrepaymentDates() {
    for (var index = 0; index < _recentPrepayments.length; index++) {
      final event = _recentPrepayments[index];
      final value = _controllers[_recentDateKey(event)]?.text.trim() ?? '';
      final amount = _zeroIfBlank(_recentAmountKey(event));
      if (value.isBlank && amount <= 0) continue;
      if (value.isBlank || LoanPlanConfig.parseLoanStartDate(value) == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('每笔提前还款均需同时填写金额和有效日期。')));
        return false;
      }
    }
    return true;
  }

  // Key controllers by event identity so reordering does not swap amounts.
  String _recentAmountKey(RecentPrepayment event) =>
      'recentPrepayment-${event.id}-amount';

  String _recentDateKey(RecentPrepayment event) =>
      'recentPrepayment-${event.id}-date';

  List<RecentPrepayment> _eventsFromControllers() {
    final events = _recentPrepayments.map((event) {
      final isSettled = widget.viewModel.isRecentPrepaymentSettled(event);
      final isCorrecting = _correctingRecentPrepaymentIds.contains(event.id);
      final editedAmount = _zeroIfBlank(_recentAmountKey(event));
      final keepsPlannedAmount =
          (isSettled && !isCorrecting) ||
          (isCorrecting && event.actualPrepayment != null);
      final updated = event.copyWith(
        // Explicit actual records keep their planned amount while correction
        // mode writes the edited value to actualPrepayment below.
        amount: keepsPlannedAmount ? event.amount : editedAmount,
        repaymentDate:
            _controllers[_recentDateKey(event)]?.text.trim() ??
            event.repaymentDate,
      );
      if (isCorrecting && event.actualPrepayment != null) {
        // An explicit actual amount is corrected independently from the
        // planned amount; date-based settled events use amount directly.
        return updated.copyWith(actualPrepayment: editedAmount);
      }
      return updated;
    });
    return _sortedRecentPrepayments(events);
  }

  /// Recent transactions drive the plan directly, so they do not wait for the
  /// page-wide apply button before the repayment tab is refreshed.
  void _scheduleRecentPrepaymentSync() {
    _recentPrepaymentSyncTimer?.cancel();
    _recentPrepaymentSyncTimer = Timer(
      const Duration(milliseconds: 350),
      _commitRecentPrepayments,
    );
  }

  void _commitRecentPrepayments() {
    if (!mounted) return;
    widget.viewModel.updateConfig(
      widget.viewModel.config.copyWith(
        recentPrepayments: _eventsFromControllers(),
      ),
    );
  }

  List<RecentPrepayment> _recentEventsForEditing(LoanPlanConfig config) {
    final events = List<RecentPrepayment>.from(config.recentPrepayments);
    if (events.isEmpty) {
      events.addAll([
        RecentPrepayment(
          id: 'legacy-0',
          amount: config.fixedAugustPrepayment,
          repaymentDate: config.fixedAugustPrepaymentDate,
          legacyMonthOffset: 0,
        ),
        RecentPrepayment(
          id: 'legacy-1',
          amount: config.fixedSeptemberPrepayment,
          repaymentDate: config.fixedSeptemberPrepaymentDate,
          legacyMonthOffset: 1,
        ),
        RecentPrepayment(
          id: 'legacy-2',
          amount: config.fixedOctoberPrepayment,
          repaymentDate: config.fixedOctoberPrepaymentDate,
          legacyMonthOffset: 2,
        ),
      ]);
    }
    while (events.length < LoanPlanConfig.initialRecentPrepaymentCount) {
      events.add(_newRecentPrepayment());
    }
    return _sortedRecentPrepayments(events);
  }

  RecentPrepayment _newRecentPrepayment() => RecentPrepayment(
    id: 'recent-${DateTime.now().microsecondsSinceEpoch}',
    repaymentDate: _dateText(DateTime.now()),
  );

  void _addRecentPrepayment() {
    final events = _eventsFromControllers()..add(_newRecentPrepayment());
    // 新增只追加记录，保留原有金额、日期和实际还款状态。
    _replaceRecentPrepayments(_sortedRecentPrepayments(events));
    _commitRecentPrepayments();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已加入一笔还款，原有记录已保留。')));
  }

  /// Unlocks only the selected settled event for a user-requested correction.
  void _correctRecentPrepayment(String eventId) {
    if (!_recentPrepayments.any((event) => event.id == eventId)) return;
    setState(() => _correctingRecentPrepaymentIds.add(eventId));
  }

  /// Saves the edited values before locking the settled event again.
  void _confirmRecentPrepayment(String eventId) {
    if (!_correctingRecentPrepaymentIds.contains(eventId)) return;
    // A fast confirmation must not be followed by the old delayed sync.
    _recentPrepaymentSyncTimer?.cancel();
    final correctedEvents = _eventsFromControllers();
    setState(() {
      _recentPrepayments = correctedEvents;
      _correctingRecentPrepaymentIds.remove(eventId);
    });
    widget.viewModel.updateConfig(
      widget.viewModel.config.copyWith(recentPrepayments: correctedEvents),
    );
  }

  void _removeRecentPrepayment(String eventId) {
    final removedEvent = _recentPrepayments.firstWhere(
      (event) => event.id == eventId,
    );
    widget.onPrepaymentDeleted?.call(removedEvent.id);
    // 展示列表只是完整记录的子集，删除必须按身份匹配，不能复用显示下标。
    final events = _eventsFromControllers()
      ..removeWhere((event) => event.id == eventId);
    final existingIds = events.map((event) => event.id).toSet();
    final existingPayments = events
        .map((event) => '${event.repaymentDate}-${event.amount}')
        .toSet();
    // The removed event is still present in the view model until this method
    // commits the new list, so exclude it from the replacement candidates.
    final replacement = widget.viewModel.settledPrepaymentCandidates
        .where(
          (event) =>
              event.id != removedEvent.id &&
              !existingIds.contains(event.id) &&
              !existingPayments.contains(
                '${event.repaymentDate}-${event.amount}',
              ),
        )
        .cast<RecentPrepayment?>()
        .firstWhere((event) => event != null, orElse: () => null);
    if (replacement != null) events.add(replacement);
    while (events.length < LoanPlanConfig.initialRecentPrepaymentCount) {
      events.add(_newRecentPrepayment());
    }
    _replaceRecentPrepayments(_sortedRecentPrepayments(events));
    _commitRecentPrepayments();
  }

  double _displayAmount(RecentPrepayment event) =>
      event.actualPrepayment ?? event.amount;

  List<RecentPrepayment> _sortedRecentPrepayments(
    Iterable<RecentPrepayment> source,
  ) => LoanPlanConfig.sortedRecentPrepayments(source);

  void _replaceRecentPrepayments(List<RecentPrepayment> events) {
    setState(() {
      _recentPrepayments = events;
      _correctingRecentPrepaymentIds.retainAll(events.map((event) => event.id));
      for (final event in events) {
        _setControllerTextIfIdle(
          _recentAmountKey(event),
          formatLoanEditableNumber(_displayAmount(event)),
        );
        _setControllerTextIfIdle(_recentDateKey(event), event.repaymentDate);
      }
    });
  }

  String _dateText(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  void _saveCashFlow() {
    final old = widget.viewModel.config;
    widget.viewModel.updateConfig(
      old.copyWith(
        monthlySalary: _number('monthlySalary', old.monthlySalary),
        monthlyExtraIncome: _number(
          'monthlyExtraIncome',
          old.monthlyExtraIncome,
        ),
        monthlyLivingCost: _number('monthlyLivingCost', old.monthlyLivingCost),
        monthlyOtherExpense: _zeroIfBlank('monthlyOtherExpense'),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _openCashFlowEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LoanMobileCashFlowSheet(
        viewModel: widget.viewModel,
        monthlySalaryController: _controllerFor('monthlySalary'),
        monthlySalaryFocusNode: _focusNodeFor('monthlySalary'),
        monthlyExtraIncomeController: _controllerFor('monthlyExtraIncome'),
        monthlyExtraIncomeFocusNode: _focusNodeFor('monthlyExtraIncome'),
        monthlyLivingCostController: _controllerFor('monthlyLivingCost'),
        monthlyLivingCostFocusNode: _focusNodeFor('monthlyLivingCost'),
        monthlyOtherExpenseController: _controllerFor('monthlyOtherExpense'),
        monthlyOtherExpenseFocusNode: _focusNodeFor('monthlyOtherExpense'),
        onSave: _saveCashFlow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final frequency = LoanPlanFrequencySelector(
      config: widget.config,
      amountsMasked: widget.viewModel.amountsMasked,
      onChanged: widget.viewModel.updateConfig,
    );
    final method = LoanRepaymentMethodSelector(
      method: widget.config.repaymentMethod,
      onChanged: (method) {
        widget.viewModel.updateConfig(
          widget.viewModel.config.copyWith(repaymentMethod: method),
        );
      },
    );
    final settings = LoanMobileSettingsGroup(
      key: _settingsKey,
      config: widget.config,
      viewModel: widget.viewModel,
      // 只截取传给界面的三笔，控制器及持久化始终保留完整记录。
      recentPrepayments: LoanPlanConfig.latestRecentPrepayments(
        _recentPrepayments,
      ),
      correctingRecentPrepaymentIds: _correctingRecentPrepaymentIds,
      expandedSections: _expandedSections,
      controllerFor: _controllerFor,
      focusNodeFor: _focusNodeFor,
      onPickRepaymentDate: (key) {
        _pickRepaymentDate(key);
      },
      onRecentPrepaymentChanged: _scheduleRecentPrepaymentSync,
      onAddRecentPrepayment: _addRecentPrepayment,
      onRemoveRecentPrepayment: _removeRecentPrepayment,
      onCorrectRecentPrepayment: _correctRecentPrepayment,
      onConfirmRecentPrepayment: _confirmRecentPrepayment,
      onDurationFieldChanged: (key) {
        _lastEditedDurationKey = key;
      },
      onSectionExpansionChanged: (title, expanded) {
        setState(() {
          if (expanded) {
            _expandedSections.add(title);
          } else {
            _expandedSections.remove(title);
          }
        });
      },
    );
    final applyButton = LoanMobileApplyButton(onPressed: _apply);
    // 页面重排仅改变呈现，所有控制器、还款修正及校验继续由此状态管理。
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.1,
        ),
      ),
      child: widget.parametersOnly
          ? LoanParameterEditorLayout(
              frequency: frequency,
              method: method,
              settings: settings,
              applyButton: applyButton,
            )
          : LoanResponsiveHome(
              header: LoanMobilePageHeader(
                viewModel: widget.viewModel,
                onShowInfo: widget.onShowInfo,
                onOpenAppearance: widget.onOpenAppearance ?? () {},
              ),
              frequency: frequency,
              method: method,
              settings: settings,
              cashFlow: LoanMobileCashFlowSummary(
                config: widget.config,
                viewModel: widget.viewModel,
                onTap: _openCashFlowEditor,
              ),
              preview: LoanMobilePreviewSection(
                viewModel: widget.viewModel,
                periods: _futurePreviewPeriods(widget.viewModel.rows),
                highlightedMonth: _highlightedPreviewMonth,
                onViewDetails: widget.onViewDetails,
                onRowTap: _handlePreviewRowTap,
              ),
              applyButton: applyButton,
              viewModel: widget.viewModel,
            ),
    );
  }

  /// Groups monthly plan rows into three repayment periods ending at the
  /// current month and each following configured frequency boundary.
  List<LoanMobilePreviewPeriod> _futurePreviewPeriods(List<LoanPlanRow> rows) {
    final calculationDate = widget.viewModel.calculationDate;
    final today = DateTime(
      calculationDate.year,
      calculationDate.month,
      calculationDate.day,
    );
    final currentMonth = DateTime(today.year, today.month);
    final frequency = widget.config.isPlanRepaymentMode
        ? 1
        : widget.config.prepaymentFrequencyMonths;
    final rowsByMonth = <DateTime, LoanPlanRow>{
      for (final row in rows)
        if (LoanPlanConfig.parseLoanStartDate(row.month) case final month?)
          DateTime(month.year, month.month): row,
    };
    final periods = <LoanMobilePreviewPeriod>[];

    for (
      var periodIndex = 0;
      periods.length < LoanPlanConfig.recentPrepaymentPlanningCycles &&
          periodIndex < rows.length;
      periodIndex++
    ) {
      final endMonth = DateTime(
        currentMonth.year,
        currentMonth.month + periodIndex * frequency,
      );
      final startMonth = DateTime(
        endMonth.year,
        endMonth.month - frequency + 1,
      );
      final periodRows = <LoanPlanRow>[];
      var missingPastMonths = 0;
      for (var offset = 0; offset < frequency; offset++) {
        final month = DateTime(startMonth.year, startMonth.month + offset);
        final row = rowsByMonth[month];
        if (row != null) {
          periodRows.add(row);
        } else if (month.isBefore(currentMonth)) {
          // The full plan intentionally starts at the current month unless
          // history exists. Fill only this unavailable past budget so the
          // first displayed period still represents (for example) 7 + 8 月.
          missingPastMonths++;
        }
      }
      final endRow = rowsByMonth[endMonth];
      if (endRow == null) break;
      if (_isSettledPreviewPeriod(endRow, today)) continue;

      final expectedPrepayment =
          periodRows.fold<double>(
            0,
            (total, row) => total + row.expectedPrepayment,
          ) +
          missingPastMonths * widget.viewModel.currentAvailablePrepayment;
      periods.add(
        LoanMobilePreviewPeriod(
          endMonth: endRow.month,
          expectedPrepayment: expectedPrepayment,
          totalBalance: endRow.totalBalance,
        ),
      );
    }
    return periods;
  }

  /// A period whose final month is already settled moves out of the preview.
  bool _isSettledPreviewPeriod(LoanPlanRow row, DateTime today) {
    return row.prepaymentDetails.any((detail) {
      if (detail.actualPrepayment == null || detail.repaymentDate == null) {
        return false;
      }
      final repaymentDate = LoanPlanConfig.parseLoanStartDate(
        detail.repaymentDate!,
      );
      return repaymentDate != null && today.isAfter(repaymentDate);
    });
  }

  void _handlePreviewRowTap(String month) {
    if (_highlightedPreviewMonth == month) {
      widget.onViewMonth(month);
      return;
    }
    setState(() => _highlightedPreviewMonth = month);
  }

  /// Recent events can use any valid historical or future repayment date.
  Future<void> _pickRepaymentDate(String key) async {
    final parsed = LoanPlanConfig.parseLoanStartDate(
      _controllers[key]?.text ?? '',
    );
    final firstDate = DateTime(2000);
    final lastDate = DateTime(2100, 12, 31);
    final initialDate =
        parsed != null &&
            !parsed.isBefore(firstDate) &&
            !parsed.isAfter(lastDate)
        ? parsed
        : DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: '选择还贷日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected == null || !mounted) return;
    _controllers[key]?.text =
        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    _commitRecentPrepayments();
  }
}

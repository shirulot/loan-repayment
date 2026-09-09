import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/loan_models.dart';
import '../../../theme/loan_palette.dart';
import '../view_models/loan_planner_view_model.dart';
import 'loan_plan_formatters.dart';
import 'loan_plan_gesture_detector.dart';

/// Compact phone layout that keeps the repayment preview above the fold.
class MobileLoanPlanLayout extends StatefulWidget {
  const MobileLoanPlanLayout({
    super.key,
    required this.viewModel,
    required this.config,
    required this.onViewDetails,
    required this.onViewMonth,
    required this.onShowInfo,
  });

  final LoanPlannerViewModel viewModel;
  final LoanPlanConfig config;
  final VoidCallback onViewDetails;
  final ValueChanged<String> onViewMonth;
  final VoidCallback onShowInfo;

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
  final Set<String> _expandedSections = <String>{};
  String? _highlightedPreviewMonth;

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
      'loanTermYears': config.loanTermYears > 0
          ? '${config.loanTermYears}'
          : '',
      'monthlySalary': editableNumber(config.monthlySalary),
      'monthlyExtraIncome': editableNumber(config.monthlyExtraIncome),
      'monthlyLivingCost': editableNumber(config.monthlyLivingCost),
      for (final event in _recentPrepayments) ...{
        _recentAmountKey(event): editableNumber(_displayAmount(event)),
        _recentDateKey(event): event.repaymentDate,
      },
    };
  }

  double _number(String key, double fallback) =>
      double.tryParse(_controllers[key]?.text ?? '') ?? fallback;

  double _zeroIfBlank(String key) =>
      double.tryParse(_controllers[key]?.text ?? '') ?? 0;

  void _apply() {
    final old = widget.viewModel.config;
    final loanStartDate = _controllers['loanStartDate']?.text.trim() ?? '';
    final loanTermYears =
        int.tryParse(_controllers['loanTermYears']?.text ?? '') ?? 0;
    final hasStartDate = loanStartDate.isNotEmpty;
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

    widget.viewModel.updateConfig(
      old.copyWith(
        commercialOpeningBalance: _number(
          'commercialOpeningBalance',
          old.commercialOpeningBalance,
        ),
        providentOpeningBalance: _number(
          'providentOpeningBalance',
          old.providentOpeningBalance,
        ),
        commercialAnnualRate:
            _number('commercialAnnualRate', old.commercialAnnualRate * 100) /
            100,
        providentAnnualRate:
            _number('providentAnnualRate', old.providentAnnualRate * 100) / 100,
        loanStartDate: loanStartDate,
        loanTermYears: loanTermYears,
        monthlySalary: _number('monthlySalary', old.monthlySalary),
        monthlyExtraIncome: _number(
          'monthlyExtraIncome',
          old.monthlyExtraIncome,
        ),
        monthlyLivingCost: _number('monthlyLivingCost', old.monthlyLivingCost),
        recentPrepayments: _eventsFromControllers(),
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('参数已应用，计划已重算。')));
  }

  bool _hasValidRecentPrepaymentDates() {
    for (var index = 0; index < _recentPrepayments.length; index++) {
      final event = _recentPrepayments[index];
      final value = _controllers[_recentDateKey(event)]?.text.trim() ?? '';
      final amount = _zeroIfBlank(_recentAmountKey(event));
      if (value.isEmpty && amount <= 0) continue;
      if (value.isEmpty || LoanPlanConfig.parseLoanStartDate(value) == null) {
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
      final keepsPlannedAmount =
          event.isSettled || event.actualPrepayment != null;
      return event.copyWith(
        // A settled field shows the actual amount, but the planned amount must
        // remain intact for expected-amount calculations and history export.
        amount: keepsPlannedAmount
            ? event.amount
            : _zeroIfBlank(_recentAmountKey(event)),
        repaymentDate:
            _controllers[_recentDateKey(event)]?.text.trim() ??
            event.repaymentDate,
      );
    });
    return _latestRecentPrepayments(events);
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
    while (events.length < 3) {
      events.add(_newRecentPrepayment());
    }
    return _latestRecentPrepayments(events);
  }

  RecentPrepayment _newRecentPrepayment() => RecentPrepayment(
    id: 'recent-${DateTime.now().microsecondsSinceEpoch}',
    repaymentDate: _dateText(DateTime.now()),
  );

  void _addRecentPrepayment() {
    final events = _eventsFromControllers()..add(_newRecentPrepayment());
    final retained = _latestRecentPrepayments(events);
    _replaceRecentPrepayments(retained);
    _commitRecentPrepayments();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已加入一笔还款，日期最远的一笔已移出最近三笔。')));
  }

  void _removeRecentPrepayment(int index) {
    final events = _eventsFromControllers()..removeAt(index);
    final existingIds = events.map((event) => event.id).toSet();
    final existingPayments = events
        .map((event) => '${event.repaymentDate}-${event.amount}')
        .toSet();
    final replacement = widget.viewModel.settledPrepaymentCandidates
        .where(
          (event) =>
              !existingIds.contains(event.id) &&
              !existingPayments.contains(
                '${event.repaymentDate}-${event.amount}',
              ),
        )
        .cast<RecentPrepayment?>()
        .firstWhere((event) => event != null, orElse: () => null);
    if (replacement != null) events.add(replacement);
    while (events.length < 3) {
      events.add(_newRecentPrepayment());
    }
    _replaceRecentPrepayments(_latestRecentPrepayments(events));
    _commitRecentPrepayments();
  }

  double _displayAmount(RecentPrepayment event) =>
      event.actualPrepayment ?? event.amount;

  List<RecentPrepayment> _latestRecentPrepayments(
    Iterable<RecentPrepayment> source,
  ) {
    final newestFirst = _sortRecentPrepayments(source, ascending: false);
    return _sortRecentPrepayments(newestFirst.take(3), ascending: true);
  }

  List<RecentPrepayment> _sortRecentPrepayments(
    Iterable<RecentPrepayment> source, {
    required bool ascending,
  }) {
    final indexed = source.toList(growable: false).indexed.toList();
    indexed.sort((left, right) {
      final leftDate = LoanPlanConfig.parseLoanStartDate(left.$2.repaymentDate);
      final rightDate = LoanPlanConfig.parseLoanStartDate(
        right.$2.repaymentDate,
      );
      if (leftDate == null || rightDate == null) {
        if (leftDate == null && rightDate == null) {
          return left.$1.compareTo(right.$1);
        }
        // Undated/invalid entries stay at the end in either direction.
        return leftDate == null ? 1 : -1;
      }
      final comparison = leftDate.compareTo(rightDate);
      return comparison == 0
          ? ascending
                ? left.$1.compareTo(right.$1)
                : right.$1.compareTo(left.$1)
          : ascending
          ? comparison
          : -comparison;
    });
    return indexed.map((entry) => entry.$2).toList(growable: true);
  }

  void _replaceRecentPrepayments(List<RecentPrepayment> events) {
    setState(() {
      _recentPrepayments = events;
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
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _openCashFlowEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '编辑每月现金流',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _inputField('本月收入', 'monthlySalary', suffix: '元'),
                _inputField('额外收入', 'monthlyExtraIncome', suffix: '元'),
                _readonlyField(
                  '当月月供',
                  _money(widget.viewModel.currentMonthlyPayment),
                  suffix: '元',
                ),
                _inputField('每月生活费', 'monthlyLivingCost', suffix: '元'),
                _readonlyField(
                  '可供提前还贷额',
                  _money(widget.viewModel.currentAvailablePrepayment),
                  suffix: '元',
                  highlight: true,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saveCashFlow,
                  child: const Text('保存现金流'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.viewModel.rows;
    final mediaQuery = MediaQuery.of(context);
    // Keep compact financial rows legible when the system font scale is large.
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.1,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _pageHeader(context),
          const SizedBox(height: 8),
          _cashFlowSummary(context),
          const SizedBox(height: 16),
          _settingsGroup(context),
          const SizedBox(height: 12),
          _previewHeader(context),
          const SizedBox(height: 8),
          _upcomingPreview(context, _futurePreviewRows(rows)),
          const SizedBox(height: 18),
          _gradientApplyButton(),
        ],
      ),
    );
  }

  Widget _gradientApplyButton() {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          gradient: LinearGradient(
            colors: [LoanPalette.primary, LoanPalette.primaryGradientEnd],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            onTap: _apply,
            child: const Center(
              child: Text(
                '应用并重算',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 首页预览只展示尚未结清的未来月份，完整计划仍保留已还记录。
  List<LoanPlanRow> _futurePreviewRows(List<LoanPlanRow> rows) {
    final calculationDate = widget.viewModel.calculationDate;
    final today = DateTime(
      calculationDate.year,
      calculationDate.month,
      calculationDate.day,
    );
    final currentMonth = DateTime(today.year, today.month);
    return rows
        .where((row) {
          final rowMonth = LoanPlanConfig.parseLoanStartDate(row.month);
          // 历史行仅属于完整计划，不能因新增记录进入未来预览。
          if (rowMonth == null || rowMonth.isBefore(currentMonth)) {
            return false;
          }
          return !row.prepaymentDetails.any((detail) {
            if (detail.actualPrepayment == null ||
                detail.repaymentDate == null) {
              return false;
            }
            final repaymentDate = LoanPlanConfig.parseLoanStartDate(
              detail.repaymentDate!,
            );
            // 当天仍展示当月；从还款日的下一天开始进入下一个月预览。
            return repaymentDate != null && today.isAfter(repaymentDate);
          });
        })
        .take(3)
        .toList(growable: false);
  }

  Widget _pageHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, color: colors.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            '提前还贷计算器',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: widget.viewModel.amountsMasked ? '显示金额' : '隐藏金额',
            onPressed: widget.viewModel.toggleAmountsMasked,
            icon: Icon(
              widget.viewModel.amountsMasked
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          IconButton(
            tooltip: '使用说明',
            onPressed: widget.onShowInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
    );
  }

  Widget _settingsGroup(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.48),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _compactSection(
            context,
            title: '贷款期限',
            icon: Icons.calendar_month_outlined,
            summary: _termSummary(),
            children: [
              _inputField(
                '贷款开始日期',
                'loanStartDate',
                suffix: 'YYYY-MM',
                date: true,
              ),
              _inputField('贷款总年限', 'loanTermYears', suffix: '年', integer: true),
              _readonlyField(
                '剩余期数（自动）',
                '${widget.viewModel.calculatedRemainingTerms}',
                suffix: '月',
              ),
            ],
          ),
          Divider(color: colors.outlineVariant.withValues(alpha: 0.48)),
          _compactSection(
            context,
            title: '本金与利率',
            icon: Icons.percent_outlined,
            summary: _currentLoanSummary(),
            children: [
              _subsectionLabel(context, '当前贷款余额'),
              _readonlyField(
                '当前商贷余额',
                _money(_currentCommercialBalance()),
                suffix: '元',
              ),
              _readonlyField(
                '当前公积金余额',
                _money(_currentProvidentBalance()),
                suffix: '元',
              ),
              _subsectionLabel(context, '初期贷款本金与利率'),
              _inputField('初期商贷本金', 'commercialOpeningBalance', suffix: '元'),
              _inputField('初期公积金本金', 'providentOpeningBalance', suffix: '元'),
              _inputField('商贷年利率', 'commercialAnnualRate', suffix: '%'),
              _inputField('公积金年利率', 'providentAnnualRate', suffix: '%'),
            ],
          ),
          Divider(color: colors.outlineVariant.withValues(alpha: 0.48)),
          _compactSection(
            context,
            title: '最近三笔提前还款',
            icon: Icons.track_changes_outlined,
            summary: _expectedPrepaymentSummary(),
            children: [
              ...List<Widget>.generate(
                _recentPrepayments.length,
                _recentPrepaymentFields,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addRecentPrepayment,
                icon: const Icon(Icons.add_outlined, size: 18),
                label: const Text('添加一笔（保留最近三笔）'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _termSummary() {
    final years = widget.config.loanTermYears;
    final terms = widget.viewModel.calculatedRemainingTerms;
    return years > 0 ? '$terms 期（$years 年）' : '$terms 期';
  }

  // Current balances do not pre-deduct a scheduled repayment before its date.
  double _currentCommercialBalance() {
    return widget.viewModel.currentCommercialBalance;
  }

  double _currentProvidentBalance() {
    return widget.viewModel.currentProvidentBalance;
  }

  String _currentLoanSummary() {
    return '¥${_money(_currentCommercialBalance() + _currentProvidentBalance())}';
  }

  String _expectedPrepaymentSummary() {
    final latest = widget.viewModel.latestPrepaymentOnOrBeforeToday;
    if (latest == null) return '暂无到期还款';
    return '¥${_money(latest.actualPrepayment ?? latest.amount)}';
  }

  /// 仅替换界面文本，保持控制器和计算使用原始金额。
  String _money(double value) =>
      formatLoanMoneyProtected(value, masked: widget.viewModel.amountsMasked);

  Widget _subsectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _cashFlowSummary(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final config = widget.config;
    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openCashFlowEditor,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.48),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 3.25,
                  children: [
                    _cashMetric(
                      context,
                      '本月收入',
                      config.monthlySalary,
                      Icons.account_balance_wallet_outlined,
                    ),
                    _cashMetric(
                      context,
                      '额外收入',
                      config.monthlyExtraIncome,
                      Icons.card_giftcard_outlined,
                    ),
                    _cashMetric(
                      context,
                      '当月月供',
                      widget.viewModel.currentMonthlyPayment,
                      Icons.credit_card_outlined,
                      accent: true,
                    ),
                    _cashMetric(
                      context,
                      '每月生活费',
                      config.monthlyLivingCost,
                      Icons.coffee_outlined,
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.48),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.currency_yen_rounded,
                      color: colors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '可供提前还贷额',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '¥${_money(widget.viewModel.currentAvailablePrepayment)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        color: colors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cashMetric(
    BuildContext context,
    String label,
    double value,
    IconData icon, {
    bool accent = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: accent ? colors.error : colors.primary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '¥${_money(value)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String summary,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isExpanded = _expandedSections.contains(title);
    return ExpansionTile(
      onExpansionChanged: (expanded) {
        setState(() {
          if (expanded) {
            _expandedSections.add(title);
          } else {
            _expandedSections.remove(title);
          }
        });
      },
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      visualDensity: const VisualDensity(vertical: -1),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      collapsedShape: const RoundedRectangleBorder(),
      leading: Icon(icon, size: 21, color: colors.primary),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w400),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Icon(
              Icons.expand_more,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      children: children,
    );
  }

  Widget _previewHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '未来三个月还款预览',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400),
          ),
        ),
        TextButton.icon(
          onPressed: widget.onViewDetails,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: const Text('查看详情'),
        ),
      ],
    );
  }

  Widget _upcomingPreview(BuildContext context, List<LoanPlanRow> rows) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.48),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _previewRow(
            context,
            month: '月份',
            expected: '预计提前\n还款额',
            balance: '剩余\n本金',
            header: true,
          ),
          ...rows.map(
            (row) => _previewRow(
              context,
              month: _displayPreviewMonth(row.month),
              expected: '¥${_money(row.expectedPrepayment)}',
              balance: '¥${_money(row.totalBalance)}',
              selected: row.month == _highlightedPreviewMonth,
              onTap: () => _handlePreviewRowTap(row.month),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '单击选中月份，再次单击进入详情。以上为预测结果，实际以还款后银行数据为准。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A second single tap on the selected preview row opens its month detail.
  void _handlePreviewRowTap(String month) {
    if (_highlightedPreviewMonth == month) {
      widget.onViewMonth(month);
      return;
    }
    setState(() => _highlightedPreviewMonth = month);
  }

  Widget _previewRow(
    BuildContext context, {
    required String month,
    required String expected,
    required String balance,
    bool header = false,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final style = TextStyle(
      fontSize: header ? 12 : 12,
      color: header
          ? Theme.of(context).colorScheme.onSurfaceVariant
          : Theme.of(context).colorScheme.onSurface,
      fontWeight: header ? FontWeight.w500 : FontWeight.w400,
    );
    return Material(
      color: Colors.transparent,
      child: LoanPlanGestureDetector(
        onTap: onTap,
        child: Container(
          height: header ? 34 : 44,
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : header
                ? Theme.of(context).colorScheme.surfaceContainerHigh
                : null,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.48),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(flex: 3, child: _previewCell(month, style)),
              Expanded(
                flex: 4,
                child: _previewCell(
                  expected,
                  header
                      ? style
                      : style.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                ),
              ),
              Expanded(
                flex: 5,
                child: _previewCell(balance, style, withArrow: !header),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewCell(String value, TextStyle style, {bool withArrow = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
        if (withArrow)
          Icon(
            Icons.chevron_right,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }

  Widget _inputField(
    String label,
    String key, {
    required String suffix,
    bool integer = false,
    bool date = false,
    bool enabled = true,
  }) {
    final fieldEnabled =
        enabled && !(suffix == '元' && widget.viewModel.amountsMasked);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: _controllers[key],
        focusNode: _focusNodeFor(key),
        enabled: fieldEnabled,
        readOnly: date,
        onTap: date && fieldEnabled ? () => _pickRepaymentDate(key) : null,
        onChanged: key.startsWith('recentPrepayment-')
            ? (_) => _scheduleRecentPrepaymentSync()
            : null,
        obscureText: suffix == '元' && widget.viewModel.amountsMasked,
        obscuringCharacter: '*',
        keyboardType: date
            ? TextInputType.datetime
            : TextInputType.numberWithOptions(decimal: !integer),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(
              date
                  ? r'[0-9-]'
                  : integer
                  ? r'[0-9]'
                  : r'[0-9.]',
            ),
          ),
        ],
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.primary,
        ),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          hintText: date ? 'YYYY-MM-DD' : null,
          suffixIcon: date
              ? IconButton(
                  tooltip: '选择还贷日期',
                  onPressed: fieldEnabled
                      ? () => _pickRepaymentDate(key)
                      : null,
                  icon: const Icon(Icons.calendar_month_outlined),
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
        ),
      ),
    );
  }

  Widget _recentPrepaymentFields(int index) {
    final event = _recentPrepayments[index];
    final isSettled = event.isSettled || event.actualPrepayment != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _inputField(
          '第 ${index + 1} 笔金额',
          _recentAmountKey(event),
          suffix: '元',
          enabled: !isSettled,
        ),
        _inputField(
          '第 ${index + 1} 笔还款日期',
          _recentDateKey(event),
          suffix: isSettled ? '已结清' : '预定日期',
          date: true,
          enabled: !isSettled,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: isSettled ? null : () => _removeRecentPrepayment(index),
            icon: const Icon(Icons.delete_outline, size: 17),
            label: const Text('删除此笔'),
          ),
        ),
      ],
    );
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

  Widget _readonlyField(
    String label,
    String value, {
    required String suffix,
    bool highlight = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
          filled: highlight,
          fillColor: highlight ? colors.primaryContainer : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
        ),
        child: Text(
          suffix == '元' && widget.viewModel.amountsMasked ? '****' : value,
          style: TextStyle(
            fontSize: 14,
            color: highlight ? colors.primary : colors.onSurfaceVariant,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  String _displayPreviewMonth(String month) {
    final parts = month.split('-');
    return '${parts[0]}年${int.parse(parts[1])}月';
  }
}

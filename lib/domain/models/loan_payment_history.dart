import '../services/loan_calculator.dart';
import 'loan_models.dart';

/// 初期本金和该笔余额的日期，独立于预测使用的校准金额。
class LoanInitialBalance {
  const LoanInitialBalance({
    this.date,
    required this.commercial,
    required this.provident,
  });

  factory LoanInitialBalance.fromRecord(LoanPaymentHistory record) =>
      LoanInitialBalance(
        date: DateTime.parse('${record.month}-01'),
        commercial: record.commercial.openingBalance,
        provident: record.provident.openingBalance,
      );

  factory LoanInitialBalance.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('初期贷款信息格式无效。');

    // 旧备份只保存起始月份，原金额和月份的对应关系照常恢复。
    final month = value['month'];
    final rawDate = value['date'] ?? (month == null ? null : '$month-01');
    final date = rawDate is String
        ? LoanPlanConfig.parseLoanStartDate(rawDate)
        : null;
    if (rawDate != null &&
        (date == null || date.toIso8601String().substring(0, 10) != rawDate)) {
      throw const FormatException('初期贷款日期无效。');
    }

    double principal(String key) {
      final amount = value[key];
      if (amount is! num || !amount.isFinite || amount < 0) {
        throw const FormatException('初期贷款本金须为非负金额。');
      }
      return amount.toDouble();
    }

    return LoanInitialBalance(
      date: date,
      commercial: principal('commercial'),
      provident: principal('provident'),
    );
  }

  final DateTime? date;
  final double commercial;
  final double provident;

  Map<String, Object?> toJson() => {
    if (date case final day?) 'date': day.toIso8601String().substring(0, 10),
    'commercial': commercial,
    'provident': provident,
  };
}

/// 已发生的月供与提前还款。余额按这些实录或估算金额独立核对。
class LoanPaymentHistory {
  LoanPaymentHistory._({
    required this.month,
    required this.remainingTerms,
    this.repaymentMethod,
    this.manualMode,
    this.commercialDate,
    this.providentDate,
    required this.commercial,
    required this.provident,
    required this.commercialPaymentEvidence,
    required this.providentInterestEstimated,
    required this.prepayments,
  });

  static final _monthPattern = RegExp(r'^[0-9]{4}-(0[1-9]|1[0-2])$');

  final String month;
  final int remainingTerms;

  /// 导入时冻结当期还款条件，避免首页调整影响既有账单。
  final LoanRepaymentMethod? repaymentMethod;
  final bool? manualMode;
  final String? commercialDate;
  final String? providentDate;
  final LoanPaymentHistoryAmounts commercial;
  final LoanPaymentHistoryAmounts provident;
  final LoanPaymentEvidence commercialPaymentEvidence;
  final bool providentInterestEstimated;
  final List<LoanPaymentHistoryPrepayment> prepayments;

  /// 只有同月唯一等额的流水，或整月流水之和，能解释无日期的旧月合计。
  bool coversLegacyMonthlyAmount(double amount) {
    if (prepayments.isEmpty || amount <= 0) return false;
    final cents = (amount * 100).round();
    var total = 0;
    var matches = 0;
    for (final debit in prepayments) {
      final principal = debit._commercial + debit._provident;
      total += principal;
      if (principal == cents) matches++;
    }
    return matches == 1 || total == cents;
  }

  /// 用保留银行日期和本息的明细取代旧版合成行。普通事件仍由逐笔身份规则处理。
  static LoanPlanConfig reconcileMonthlyPlaceholders(
    LoanPlanConfig config,
    List<LoanPaymentHistory> history,
  ) {
    if (history.isEmpty) return config;
    final byMonth = {for (final bill in history) bill.month: bill};
    final events = config.recentPrepayments.where((event) {
      final month = event.repaymentMonth;
      return month == null ||
          !event.isMonthlyPlaceholderFor(month) ||
          !(byMonth[month]?.coversLegacyMonthlyAmount(event.amount) ?? false);
    }).toList();
    return events.length == config.recentPrepayments.length
        ? config
        : config.copyWith(recentPrepayments: events);
  }

  /// 整批校验后才允许导入，避免错误文件只覆盖一部分历史。
  static List<LoanPaymentHistory> parseList(Object? value) {
    if (value is! List) {
      throw const FormatException('缺少 paymentHistory 记录列表。');
    }
    final months = <String>{};
    return [for (final item in value) _parse(item, months)];
  }

  static LoanPaymentHistory _parse(Object? item, Set<String> months) {
    final month = item is Map ? item['month'] : null;
    if (item is! Map ||
        month is! String ||
        month.length != 7 ||
        month.startsWith('0000-') ||
        !_monthPattern.hasMatch(month)) {
      throw const FormatException('历史记录月份须使用 YYYY-MM 格式。');
    }
    if (!months.add(month)) throw FormatException('文件中有重复月份：$month。');
    final terms = item['remainingTerms'];
    if (terms is! int || terms <= 0) {
      throw FormatException('$month 的剩余期数须为正整数。');
    }
    final estimated = item['providentInterestEstimated'] ?? false;
    if (estimated is! bool) {
      throw FormatException('$month 的公积金利息估算标记须为布尔值。');
    }
    final evidenceName = item['commercialPaymentEvidence'];
    final evidence = LoanPaymentEvidence.values
        .where((value) => value.name == evidenceName)
        .firstOrNull;
    if (evidenceName != null && evidence == null) {
      throw FormatException('$month 的商贷月供来源无效。');
    }
    final commercial = LoanPaymentHistoryAmounts._parse(
      item['commercial'],
      '$month 商贷',
    );
    final provident = LoanPaymentHistoryAmounts._parse(
      item['provident'],
      '$month 公积金贷',
    );
    final transactions = item['prepayments'] ?? const [];
    if (transactions is! List) {
      throw FormatException('$month 的提前还款须使用列表。');
    }
    final ordered =
        transactions.indexed
            .map(
              (item) => (
                item.$1,
                LoanPaymentHistoryPrepayment._parse(item.$2, month),
              ),
            )
            .toList()
          ..sort((a, b) {
            final byDate = a.$2.date.compareTo(b.$2.date);
            return byDate == 0 ? a.$1.compareTo(b.$1) : byDate;
          });
    final prepayments = ordered.map((item) => item.$2).toList();
    var commercialBalance = commercial._opening - commercial._principal;
    var providentBalance = provident._opening - provident._principal;
    for (final payment in prepayments) {
      commercialBalance -= payment._commercial;
      providentBalance -= payment._provident;
    }
    if (commercialBalance < 0 || providentBalance < 0) {
      throw FormatException('$month 的归还本金超过同类贷款的期初余额。');
    }
    String? debitDate(String key) {
      final value = item[key];
      if (value == null) return null;
      if (value is! String ||
          !value.startsWith('$month-') ||
          DateTime.tryParse(value)?.toIso8601String().substring(0, 10) !=
              value) {
        throw FormatException('$month 的 $key 须为本月有效日期。');
      }
      return value;
    }

    final method = item['repaymentMethod'];
    final manual = item['manualMode'];
    if (method != null &&
            !LoanRepaymentMethod.values.any((m) => m.name == method) ||
        manual != null && manual is! bool) {
      throw FormatException('$month 的还款条件无效。');
    }
    return LoanPaymentHistory._(
      month: month,
      commercialDate: debitDate('commercialPaymentDate'),
      providentDate: debitDate('providentPaymentDate'),
      manualMode: manual as bool?,
      repaymentMethod: method == null
          ? null
          : LoanRepaymentMethod.fromJson(method),
      remainingTerms: terms,
      commercial: commercial,
      provident: provident,
      commercialPaymentEvidence: evidence ?? LoanPaymentEvidence.statement,
      providentInterestEstimated: estimated,
      prepayments: List.unmodifiable(prepayments),
    );
  }

  Map<String, Object?> toJson() => {
    'month': month,
    'remainingTerms': remainingTerms,
    'repaymentMethod': ?repaymentMethod?.name,
    'manualMode': ?manualMode,
    'commercialPaymentDate': ?commercialDate,
    'providentPaymentDate': ?providentDate,
    'commercial': commercial.toJson(),
    'provident': provident.toJson(),
    if (commercialPaymentEvidence != LoanPaymentEvidence.statement)
      'commercialPaymentEvidence': commercialPaymentEvidence.name,
    if (providentInterestEstimated) 'providentInterestEstimated': true,
    if (prepayments.isNotEmpty)
      'prepayments': prepayments.map((item) => item.toJson()).toList(),
  };

  /// 相邻原始账单必须衔接；导入的新账单也可以包含首页补录后的真实余额。
  void validateOpening(LoanPaymentHistory prior, LoanPlanRow effective) {
    void check(
      String label,
      int opening,
      int originalClosing,
      double replayedClosing,
    ) {
      if (opening != originalClosing &&
          opening != (replayedClosing * 100).round()) {
        throw FormatException(
          '$month 的$label期初本金与 ${prior.month} 期末不符，请核对两个月之间的还款。',
        );
      }
    }

    final originalCommercial =
        prior.commercial._opening -
        prior.commercial._principal -
        prior.prepayments.fold<int>(0, (total, p) => total + p._commercial);
    final originalProvident =
        prior.provident._opening -
        prior.provident._principal -
        prior.prepayments.fold<int>(0, (total, p) => total + p._provident);
    check(
      '商贷',
      commercial._opening,
      originalCommercial,
      effective.commercialClosing,
    );
    check(
      '公积金',
      provident._opening,
      originalProvident,
      effective.providentClosing,
    );
  }

  /// 固化反推利率与导入时已有的同笔交易身份；重复金额按出现次数一对一认领。
  LoanPaymentHistory freeze(
    LoanPlanConfig config,
    int commercialDays, {
    LoanPaymentHistory? existing,
  }) {
    if (repaymentMethod != null &&
        manualMode != null &&
        commercial.hasFrozenRate &&
        provident.hasFrozenRate &&
        prepayments.every((p) => p.identityChecked)) {
      return this;
    }
    final available = [
      ...config.recentPrepayments.where((e) => e.repaymentMonth == month),
    ];
    final prior = [...?existing?.prepayments];
    final linked = <LoanPaymentHistoryPrepayment>[];
    for (final p in prepayments) {
      final i = prior.indexWhere(
        (old) =>
            old.date == p.date &&
            old._commercial == p._commercial &&
            old._provident == p._provident,
      );
      final old = i < 0 ? null : prior.removeAt(i);
      final matched = p.identityChecked
          ? p
          : old?.identityChecked == true
          ? old
          : null;
      final id = matched != null
          ? matched.eventId
          : available
                .where(
                  (e) =>
                      e.repaymentDate == p.date &&
                      (e.amount * 100).round() == p._commercial + p._provident,
                )
                .firstOrNull
                ?.id;
      available.removeWhere((e) => e.id == id);
      linked.add(
        LoanPaymentHistoryPrepayment._(
          p.date,
          p._commercial,
          p._provident,
          p._interest,
          eventId: id,
          identityChecked: true,
        ),
      );
    }
    return LoanPaymentHistory._(
      month: month,
      remainingTerms: remainingTerms,
      repaymentMethod:
          repaymentMethod ??
          existing?.repaymentMethod ??
          config.repaymentMethod,
      manualMode:
          manualMode ?? existing?.manualMode ?? config.isPlanRepaymentMode,
      commercialDate: commercialDate ?? existing?.commercialDate,
      providentDate: providentDate ?? existing?.providentDate,
      commercial: commercial.freeze(commercialDays, existing?.commercial),
      provident: provident.freeze(30, existing?.provident),
      commercialPaymentEvidence: commercialPaymentEvidence,
      providentInterestEstimated: providentInterestEstimated,
      prepayments: List.unmodifiable(linked),
    );
  }

  /// 单张账单预览也使用计划引擎，不另设一套逐笔公式。
  LoanPlanRow toPlanRow({LoanPlanRow? previous}) =>
      const LoanCalculator().historyRow(
        this,
        const LoanPlanConfig(isPlanRepaymentMode: true),
        previous: previous,
      );
}

/// 历史金额按分存储，导入文件仍沿用现有备份的元单位。
class LoanPaymentHistoryAmounts {
  LoanPaymentHistoryAmounts._(
    this._opening,
    this._principal,
    this._interest,
    this.annualRate, [
    this.rateInferred = false,
  ]);

  final int _opening;
  final int _principal;
  final int _interest;
  final double? annualRate;

  int get _payment => _principal + _interest;
  double get openingBalance => _opening / 100;
  double get principal => _principal / 100;
  double get interest => _interest / 100;
  double get payment => _payment / 100;

  final bool rateInferred;
  bool get hasFrozenRate => annualRate != null || rateInferred;
  LoanPaymentHistoryAmounts freeze(int days, [LoanPaymentHistoryAmounts? old]) {
    if (hasFrozenRate) return this;
    // 同一张原始账单重导时沿用已经确认的当期利率。
    if (old != null &&
        old.hasFrozenRate &&
        old._opening == _opening &&
        old._interest == _interest) {
      return LoanPaymentHistoryAmounts._(
        _opening,
        _principal,
        _interest,
        old.annualRate,
        old.rateInferred,
      );
    }
    return LoanPaymentHistoryAmounts._(
      _opening,
      _principal,
      _interest,
      _inferAnnualRate(days),
      true,
    );
  }

  double? _inferAnnualRate(int days) {
    if (_opening == 0 || _interest == 0) return null;
    // 利息按分入账，年利率保留到 0.001 个百分点。
    return (_interest * 360 / (_opening * days) * 100000).round() / 100000;
  }

  static LoanPaymentHistoryAmounts _parse(Object? value, String label) {
    if (value is! Map) throw FormatException('$label 缺少金额明细。');
    final rate = value['annualRate'];
    if (rate != null &&
        (rate is! num || !rate.isFinite || rate < 0 || rate > 1)) {
      throw FormatException('$label 年利率须为 0 到 1 的小数。');
    }
    return LoanPaymentHistoryAmounts._(
      _readCents(value['openingBalance'], '$label 期初本金'),
      _readCents(value['principal'], '$label 正常还款本金'),
      _readCents(value['interest'], '$label 正常还款利息'),
      (rate as num?)?.toDouble(),
      value['annualRateInferred'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'openingBalance': openingBalance,
    'principal': principal,
    'interest': interest,
    'annualRate': ?annualRate,
    if (rateInferred) 'annualRateInferred': true,
  };
}

/// 每笔历史提前还款保留日期及实际利息，缺少账单时利息可留空。
class LoanPaymentHistoryPrepayment {
  LoanPaymentHistoryPrepayment._(
    this.date,
    this._commercial,
    this._provident,
    this._interest, {
    this.eventId,
    this.identityChecked = false,
  });

  final String? eventId;
  final bool identityChecked;
  double get commercialPrincipal => _commercial / 100;
  double get providentPrincipal => _provident / 100;
  double? get interest => _interest == null ? null : _interest / 100;

  final String date;
  final int _commercial;
  final int _provident;
  final int? _interest;

  static LoanPaymentHistoryPrepayment _parse(Object? item, String month) {
    final date = item is Map ? item['date'] : null;
    final parsed = date is String
        ? LoanPlanConfig.parseLoanStartDate(date)
        : null;
    if (item is! Map ||
        date is! String ||
        date.length != 10 ||
        !date.startsWith('$month-') ||
        parsed?.toIso8601String().substring(0, 10) != date) {
      throw FormatException('$month 的提前还款日期须为本月有效日期。');
    }
    final commercial = _readCents(
      item['commercialPrincipal'] ?? 0,
      '$date 商贷提前本金',
    );
    final provident = _readCents(
      item['providentPrincipal'] ?? 0,
      '$date 公积金提前本金',
    );
    if (commercial + provident == 0) {
      throw FormatException('$date 的提前还款须包含正数本金。');
    }
    final interest = item['interest'];
    return LoanPaymentHistoryPrepayment._(
      date,
      commercial,
      provident,
      interest == null ? null : _readCents(interest, '$date 提前还款利息'),
      eventId: item['eventId'] is String ? item['eventId'] as String : null,
      identityChecked: item['identityChecked'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'date': date,
    'eventId': ?eventId,
    if (identityChecked) 'identityChecked': true,
    if (_commercial > 0) 'commercialPrincipal': _commercial / 100,
    if (_provident > 0) 'providentPrincipal': _provident / 100,
    if (_interest != null) 'interest': _interest / 100,
  };
}

int _readCents(Object? amount, String field) {
  // 保留各平台整数表示均可精确计算的分位金额范围。
  if (amount is num && amount.isFinite && amount >= 0 && amount < 1e12) {
    final cents = (amount * 100).round();
    if (amount == cents / 100) return cents;
  }
  throw FormatException('$field 须为非负金额，最多两位小数。');
}

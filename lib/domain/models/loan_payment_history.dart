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
    required this.commercial,
    required this.provident,
    required this.commercialPaymentEvidence,
    required this.providentInterestEstimated,
    required this.prepayments,
  });

  static final _monthPattern = RegExp(r'^[0-9]{4}-(0[1-9]|1[0-2])$');

  final String month;
  final int remainingTerms;
  final LoanPaymentHistoryAmounts commercial;
  final LoanPaymentHistoryAmounts provident;
  final LoanPaymentEvidence commercialPaymentEvidence;
  final bool providentInterestEstimated;
  final List<LoanPaymentHistoryPrepayment> prepayments;

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
    return LoanPaymentHistory._(
      month: month,
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
    'commercial': commercial.toJson(),
    'provident': provident.toJson(),
    if (commercialPaymentEvidence != LoanPaymentEvidence.statement)
      'commercialPaymentEvidence': commercialPaymentEvidence.name,
    if (providentInterestEstimated) 'providentInterestEstimated': true,
    if (prepayments.isNotEmpty)
      'prepayments': prepayments.map((item) => item.toJson()).toList(),
  };

  /// 生成账单月行，逐笔冲减真实本金，期末余额供后续月份接续。
  LoanPlanRow toPlanRow({LoanPlanRow? previous}) {
    // 与等额本金测算口径一致，商贷在上月实际提前还款后按天计息。
    final date = DateTime.parse('$month-01');
    final commercialDays = (previous?.commercialPrepayment ?? 0) > 0
        ? DateTime(date.year, date.month, 0).day
        : 30;
    final commercialRate =
        commercial.annualRate ?? commercial._inferAnnualRate(commercialDays);
    final providentRate =
        provident.annualRate ?? provident._inferAnnualRate(30);
    final basePayment =
        commercial._basePayment(commercialRate) +
        provident._basePayment(providentRate);
    var commercialClosing = commercial._opening - commercial._principal;
    var providentClosing = provident._opening - provident._principal;
    var commercialPrepaid = 0;
    var providentPrepaid = 0;
    var totalInterest = 0;
    final details = <LoanPrepaymentDetail>[];
    for (final item in prepayments) {
      // 同月预览沿用同一期账单的本息比例，只计入此前各笔提前归还的本金。
      final commercialBefore = commercial._previewAfter(
        commercialPrepaid,
        commercialRate,
      );
      final providentBefore = provident._previewAfter(
        providentPrepaid,
        providentRate,
      );
      commercialClosing -= item._commercial;
      providentClosing -= item._provident;
      commercialPrepaid += item._commercial;
      providentPrepaid += item._provident;
      totalInterest += item._interest ?? 0;
      final actual = item._commercial + item._provident;
      details.add(
        LoanPrepaymentDetail(
          eventId: null,
          repaymentDate: item.date,
          amount: actual / 100,
          isRecorded: true,
          interestDueNow: (item._interest ?? 0) / 100,
          interestRecorded: item._interest != null,
          nextMonthDeferredInterest: 0,
          commercialClosing: commercialClosing / 100,
          providentClosing: providentClosing / 100,
          paymentAfter: (
            commercial: commercial._previewAfter(
              commercialPrepaid,
              commercialRate,
            ),
            provident: provident._previewAfter(providentPrepaid, providentRate),
          ),
          commercialPrincipalBefore: commercialBefore.principal,
          commercialInterestBefore: commercialBefore.interest,
          commercialPaymentBefore: commercialBefore.payment,
          providentPrincipalBefore: providentBefore.principal,
          providentInterestBefore: providentBefore.interest,
          providentPaymentBefore: providentBefore.payment,
        ),
      );
    }
    final usedPrepayment = (commercialPrepaid + providentPrepaid) / 100;
    final totalPayment = commercial._payment + provident._payment;
    return LoanPlanRow(
      month: month,
      isArchived: true,
      commercialPaymentEvidence: commercialPaymentEvidence,
      providentInterestEstimated: providentInterestEstimated,
      commercialAnnualRate: commercialRate,
      providentAnnualRate: providentRate,
      commercialAnnualRateInferred: commercial.annualRate == null,
      providentAnnualRateInferred: provident.annualRate == null,
      remainingTerms: remainingTerms,
      commercialOpening: commercial.openingBalance,
      commercialPrincipal: commercial.principal,
      commercialInterest: commercial.interest,
      commercialPayment: commercial.payment,
      providentOpening: provident.openingBalance,
      providentPrincipal: provident.principal,
      providentInterest: provident.interest,
      providentPayment: provident.payment,
      totalPayment: totalPayment / 100,
      commercialReduction: _reduction(
        previous?.commercialPayment,
        commercial._payment,
      ),
      providentReduction: _reduction(
        previous?.providentPayment,
        provident._payment,
      ),
      totalReduction: _reduction(previous?.totalPayment, totalPayment),
      availableFunds: 0,
      effectivePrepaymentDate: details.firstOrNull?.repaymentDate,
      prepaymentDates: prepayments.map((item) => item.date).toList(),
      prepaymentDetails: details,
      prepaymentInterestDueNow: totalInterest / 100,
      nextMonthBasePayment: basePayment / 100,
      nextMonthBasePaymentReduction: _reduction(
        previous?.nextMonthBasePayment,
        basePayment,
      ),
      usedPrepayment: usedPrepayment,
      commercialPrepayment: commercialPrepaid / 100,
      providentPrepayment: providentPrepaid / 100,
      commercialClosing: commercialClosing / 100,
      providentClosing: providentClosing / 100,
    );
  }

  static double? _reduction(double? previous, int currentCents) =>
      previous == null ? null : ((previous * 100).round() - currentCents) / 100;
}

/// 历史金额按分存储，导入文件仍沿用现有备份的元单位。
class LoanPaymentHistoryAmounts {
  LoanPaymentHistoryAmounts._(
    this._opening,
    this._principal,
    this._interest,
    this.annualRate,
  );

  final int _opening;
  final int _principal;
  final int _interest;
  final double? annualRate;

  int get _payment => _principal + _interest;
  double get openingBalance => _opening / 100;
  double get principal => _principal / 100;
  double get interest => _interest / 100;
  double get payment => _payment / 100;

  /// 同一期、同利率下月供本息随计息本金等比例变化；首笔保留账单精度。
  LoanInstallmentPreview _previewAfter(int prepaid, double? rate) {
    if (prepaid == 0 || _opening == 0) {
      return LoanInstallmentPreview(
        principal,
        interest,
        _basePayment(rate) / 100,
      );
    }
    if (prepaid >= _opening - _principal) {
      return const LoanInstallmentPreview(0, 0, 0);
    }
    // 固定本期日数和期数，对累计提前本金后的余额重算；正常本金已在流水扣过。
    final balance = _opening - prepaid;
    final principalCents = (_principal * (balance / _opening)).round();
    final interestCents = (_interest * (balance / _opening)).round();
    final baseInterest = rate == null
        ? interestCents
        : (balance * rate / 12).round();
    return LoanInstallmentPreview(
      principalCents / 100,
      interestCents / 100,
      (principalCents + baseInterest) / 100,
    );
  }

  double? _inferAnnualRate(int days) {
    if (_opening == 0 || _interest == 0) return null;
    // 利息按分入账，年利率保留到 0.001 个百分点。
    return (_interest * 360 / (_opening * days) * 100000).round() / 100000;
  }

  /// 保留该期正常本金，只把利息按历史年利率折算为普通月息。
  int _basePayment(double? rate) =>
      _principal + (rate == null ? _interest : (_opening * rate / 12).round());

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
    );
  }

  Map<String, double> toJson() => {
    'openingBalance': openingBalance,
    'principal': principal,
    'interest': interest,
    'annualRate': ?annualRate,
  };
}

/// 每笔历史提前还款保留日期及实际利息，缺少账单时利息可留空。
class LoanPaymentHistoryPrepayment {
  LoanPaymentHistoryPrepayment._(
    this.date,
    this._commercial,
    this._provident,
    this._interest,
  );

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
    );
  }

  Map<String, Object?> toJson() => {
    'date': date,
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

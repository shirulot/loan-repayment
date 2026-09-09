import '../../core/extensions/string_extensions.dart';

class LoanPlanConfig {
  const LoanPlanConfig({
    this.commercialOpeningBalance = 0,
    this.providentOpeningBalance = 0,
    this.commercialAnnualRate = 0,
    this.providentAnnualRate = 0,
    this.remainingTerms = 200,
    this.loanStartDate = '',
    this.loanTermYears = 0,
    this.monthlySalary = 0,
    this.monthlyExtraIncome = 0,
    this.monthlyLivingCost = 0,
    this.fixedAugustPrepayment = 0,
    this.fixedSeptemberPrepayment = 0,
    this.fixedOctoberPrepayment = 0,
    this.fixedAugustPrepaymentDate = '',
    this.fixedSeptemberPrepaymentDate = '',
    this.fixedOctoberPrepaymentDate = '',
    this.recentPrepayments = const <RecentPrepayment>[],
    this.bankSeptemberPrincipal = 0,
    this.bankSeptemberInterest = 0,
    this.bankSeptemberPayment = 0,
  });

  final double commercialOpeningBalance;
  final double providentOpeningBalance;
  final double commercialAnnualRate;
  final double providentAnnualRate;
  final int remainingTerms;

  /// Loan start date in YYYY-MM or YYYY-MM-DD format; empty keeps legacy terms.
  final String loanStartDate;

  /// Total loan duration in years; zero keeps legacy terms.
  final int loanTermYears;
  final double monthlySalary;
  final double monthlyExtraIncome;
  final double monthlyLivingCost;
  final double fixedAugustPrepayment;
  final double fixedSeptemberPrepayment;
  final double fixedOctoberPrepayment;
  final String fixedAugustPrepaymentDate;
  final String fixedSeptemberPrepaymentDate;
  final String fixedOctoberPrepaymentDate;

  /// 最近维护的提前还款事件。日期允许相同，以支持同月多笔还款。
  final List<RecentPrepayment> recentPrepayments;
  final double bankSeptemberPrincipal;
  final double bankSeptemberInterest;
  final double bankSeptemberPayment;

  /// Restores editable parameters while keeping defaults for missing fields.
  factory LoanPlanConfig.fromJson(Map<String, dynamic> json) {
    double number(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : '$value'.toDoubleOr(fallback);
    }

    int integer(String key, int fallback) {
      final value = json[key];
      return value is num ? value.toInt() : '$value'.toIntOr(fallback);
    }

    const defaults = LoanPlanConfig();
    final recentPrepayments = _recentPrepaymentsFromJson(json);
    return LoanPlanConfig(
      commercialOpeningBalance: number(
        'commercialOpeningBalance',
        defaults.commercialOpeningBalance,
      ),
      providentOpeningBalance: number(
        'providentOpeningBalance',
        defaults.providentOpeningBalance,
      ),
      commercialAnnualRate: number(
        'commercialAnnualRate',
        defaults.commercialAnnualRate,
      ),
      providentAnnualRate: number(
        'providentAnnualRate',
        defaults.providentAnnualRate,
      ),
      remainingTerms: integer('remainingTerms', defaults.remainingTerms),
      loanStartDate:
          json['loanStartDate']?.toString() ?? defaults.loanStartDate,
      loanTermYears: integer('loanTermYears', defaults.loanTermYears),
      monthlySalary: number('monthlySalary', defaults.monthlySalary),
      monthlyExtraIncome: number(
        'monthlyExtraIncome',
        defaults.monthlyExtraIncome,
      ),
      monthlyLivingCost: number(
        'monthlyLivingCost',
        defaults.monthlyLivingCost,
      ),
      fixedAugustPrepayment: number(
        'fixedAugustPrepayment',
        defaults.fixedAugustPrepayment,
      ),
      fixedSeptemberPrepayment: number(
        'fixedSeptemberPrepayment',
        defaults.fixedSeptemberPrepayment,
      ),
      fixedOctoberPrepayment: number(
        'fixedOctoberPrepayment',
        defaults.fixedOctoberPrepayment,
      ),
      fixedAugustPrepaymentDate:
          json['fixedAugustPrepaymentDate']?.toString() ??
          defaults.fixedAugustPrepaymentDate,
      fixedSeptemberPrepaymentDate:
          json['fixedSeptemberPrepaymentDate']?.toString() ??
          defaults.fixedSeptemberPrepaymentDate,
      fixedOctoberPrepaymentDate:
          json['fixedOctoberPrepaymentDate']?.toString() ??
          defaults.fixedOctoberPrepaymentDate,
      recentPrepayments: recentPrepayments,
      bankSeptemberPrincipal: number(
        'bankSeptemberPrincipal',
        defaults.bankSeptemberPrincipal,
      ),
      bankSeptemberInterest: number(
        'bankSeptemberInterest',
        defaults.bankSeptemberInterest,
      ),
      bankSeptemberPayment: number(
        'bankSeptemberPayment',
        defaults.bankSeptemberPayment,
      ),
    );
  }

  LoanPlanConfig copyWith({
    double? commercialOpeningBalance,
    double? providentOpeningBalance,
    double? commercialAnnualRate,
    double? providentAnnualRate,
    int? remainingTerms,
    String? loanStartDate,
    int? loanTermYears,
    double? monthlySalary,
    double? monthlyExtraIncome,
    double? monthlyLivingCost,
    double? fixedAugustPrepayment,
    double? fixedSeptemberPrepayment,
    double? fixedOctoberPrepayment,
    String? fixedAugustPrepaymentDate,
    String? fixedSeptemberPrepaymentDate,
    String? fixedOctoberPrepaymentDate,
    List<RecentPrepayment>? recentPrepayments,
    double? bankSeptemberPrincipal,
    double? bankSeptemberInterest,
    double? bankSeptemberPayment,
  }) {
    return LoanPlanConfig(
      commercialOpeningBalance:
          commercialOpeningBalance ?? this.commercialOpeningBalance,
      providentOpeningBalance:
          providentOpeningBalance ?? this.providentOpeningBalance,
      commercialAnnualRate: commercialAnnualRate ?? this.commercialAnnualRate,
      providentAnnualRate: providentAnnualRate ?? this.providentAnnualRate,
      remainingTerms: remainingTerms ?? this.remainingTerms,
      loanStartDate: loanStartDate ?? this.loanStartDate,
      loanTermYears: loanTermYears ?? this.loanTermYears,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      monthlyExtraIncome: monthlyExtraIncome ?? this.monthlyExtraIncome,
      monthlyLivingCost: monthlyLivingCost ?? this.monthlyLivingCost,
      fixedAugustPrepayment:
          fixedAugustPrepayment ?? this.fixedAugustPrepayment,
      fixedSeptemberPrepayment:
          fixedSeptemberPrepayment ?? this.fixedSeptemberPrepayment,
      fixedOctoberPrepayment:
          fixedOctoberPrepayment ?? this.fixedOctoberPrepayment,
      fixedAugustPrepaymentDate:
          fixedAugustPrepaymentDate ?? this.fixedAugustPrepaymentDate,
      fixedSeptemberPrepaymentDate:
          fixedSeptemberPrepaymentDate ?? this.fixedSeptemberPrepaymentDate,
      fixedOctoberPrepaymentDate:
          fixedOctoberPrepaymentDate ?? this.fixedOctoberPrepaymentDate,
      recentPrepayments: recentPrepayments ?? this.recentPrepayments,
      bankSeptemberPrincipal:
          bankSeptemberPrincipal ?? this.bankSeptemberPrincipal,
      bankSeptemberInterest:
          bankSeptemberInterest ?? this.bankSeptemberInterest,
      bankSeptemberPayment: bankSeptemberPayment ?? this.bankSeptemberPayment,
    );
  }

  Map<String, Object> toJson() {
    return {
      'commercialOpeningBalance': commercialOpeningBalance,
      'providentOpeningBalance': providentOpeningBalance,
      'commercialAnnualRate': commercialAnnualRate,
      'providentAnnualRate': providentAnnualRate,
      'remainingTerms': remainingTerms,
      'loanStartDate': loanStartDate,
      'loanTermYears': loanTermYears,
      'monthlySalary': monthlySalary,
      'monthlyExtraIncome': monthlyExtraIncome,
      'monthlyLivingCost': monthlyLivingCost,
      'fixedAugustPrepayment': fixedAugustPrepayment,
      'fixedSeptemberPrepayment': fixedSeptemberPrepayment,
      'fixedOctoberPrepayment': fixedOctoberPrepayment,
      'fixedAugustPrepaymentDate': fixedAugustPrepaymentDate,
      'fixedSeptemberPrepaymentDate': fixedSeptemberPrepaymentDate,
      'fixedOctoberPrepaymentDate': fixedOctoberPrepaymentDate,
      'recentPrepayments': recentPrepayments
          .map((prepayment) => prepayment.toJson())
          .toList(growable: false),
      'bankSeptemberPrincipal': bankSeptemberPrincipal,
      'bankSeptemberInterest': bankSeptemberInterest,
      'bankSeptemberPayment': bankSeptemberPayment,
    };
  }

  /// Parses a month-level loan date while accepting an optional day.
  static DateTime? parseLoanStartDate(String value) {
    final match = RegExp(
      r'^\s*(\d{4})-(\d{1,2})(?:-(\d{1,2}))?\s*$',
    ).firstMatch(value);
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = (match.group(3) ?? '1').toIntOr(1);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  /// Migrates the previous three fixed inputs into editable repayment events.
  /// Empty legacy dates retain their former relative-month behavior.
  static List<RecentPrepayment> _recentPrepaymentsFromJson(
    Map<String, dynamic> json,
  ) {
    final raw = json['recentPrepayments'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map(
            (value) =>
                RecentPrepayment.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(growable: false);
    }

    double number(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : '$value'.toDoubleOr(0);
    }

    return List<RecentPrepayment>.generate(3, (index) {
      final amountKey = switch (index) {
        0 => 'fixedAugustPrepayment',
        1 => 'fixedSeptemberPrepayment',
        _ => 'fixedOctoberPrepayment',
      };
      final dateKey = switch (index) {
        0 => 'fixedAugustPrepaymentDate',
        1 => 'fixedSeptemberPrepaymentDate',
        _ => 'fixedOctoberPrepaymentDate',
      };
      return RecentPrepayment(
        id: 'legacy-$index',
        amount: number(amountKey),
        repaymentDate: json[dateKey]?.toString() ?? '',
        legacyMonthOffset: index,
      );
    });
  }

  /// Calculates remaining months from the configured start date and term.
  /// Falls back to [remainingTerms] until both new inputs are valid.
  int remainingTermsAt(DateTime currentDate) {
    final startDate = parseLoanStartDate(loanStartDate);
    if (startDate == null || loanTermYears <= 0) return remainingTerms;

    final elapsedMonths =
        (currentDate.year - startDate.year) * 12 +
        currentDate.month -
        startDate.month;
    final completedMonths = elapsedMonths < 0 ? 0 : elapsedMonths;
    final totalMonths = loanTermYears * 12;
    final remaining = totalMonths - completedMonths;
    return remaining < 0 ? 0 : remaining;
  }
}

/// A single scheduled or settled early-repayment transaction.
class RecentPrepayment {
  const RecentPrepayment({
    required this.id,
    this.amount = 0,
    this.actualPrepayment,
    this.repaymentDate = '',
    this.isSettled = false,
    this.legacyMonthOffset,
  });

  final String id;
  final double amount;
  final double? actualPrepayment;
  final String repaymentDate;
  final bool isSettled;

  /// Only used while reading the former three-month fixed-field cache.
  final int? legacyMonthOffset;

  factory RecentPrepayment.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    final actualPrepayment = json['actualPrepayment'];
    final offset = json['legacyMonthOffset'];
    return RecentPrepayment(
      id: json['id']?.toString() ?? '',
      amount: amount is num ? amount.toDouble() : '$amount'.toDoubleOr(0),
      actualPrepayment: actualPrepayment is num
          ? actualPrepayment.toDouble()
          : double.tryParse('$actualPrepayment'),
      repaymentDate: json['repaymentDate']?.toString() ?? '',
      isSettled: json['isSettled'] == true,
      legacyMonthOffset: offset is num
          ? offset.toInt()
          : int.tryParse('$offset'),
    );
  }

  RecentPrepayment copyWith({
    String? id,
    double? amount,
    double? actualPrepayment,
    bool clearActualPrepayment = false,
    String? repaymentDate,
    bool? isSettled,
    int? legacyMonthOffset,
  }) {
    return RecentPrepayment(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      actualPrepayment: clearActualPrepayment
          ? null
          : actualPrepayment ?? this.actualPrepayment,
      repaymentDate: repaymentDate ?? this.repaymentDate,
      isSettled: isSettled ?? this.isSettled,
      legacyMonthOffset: legacyMonthOffset ?? this.legacyMonthOffset,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'amount': amount,
    if (actualPrepayment != null) 'actualPrepayment': actualPrepayment,
    'repaymentDate': repaymentDate,
    'isSettled': isSettled,
    if (legacyMonthOffset != null) 'legacyMonthOffset': legacyMonthOffset,
  };
}

class LoanPlanRow {
  const LoanPlanRow({
    required this.month,
    required this.remainingTerms,
    required this.commercialOpening,
    required this.commercialPrincipal,
    required this.commercialInterest,
    required this.commercialPayment,
    required this.providentOpening,
    required this.providentPrincipal,
    required this.providentInterest,
    required this.providentPayment,
    required this.totalPayment,
    required this.commercialReduction,
    required this.providentReduction,
    required this.totalReduction,
    required this.availableFunds,
    required this.expectedPrepayment,
    required this.actualPrepayment,
    required this.plannedPrepaymentDate,
    required this.effectivePrepaymentDate,
    required this.prepaymentDates,
    required this.prepaymentDetails,
    required this.prepaymentInterestDueNow,
    required this.nextMonthBasePayment,
    required this.nextMonthBasePaymentReduction,
    required this.usedPrepayment,
    required this.commercialPrepayment,
    required this.providentPrepayment,
    required this.commercialClosing,
    required this.providentClosing,
  });

  final String month;
  final int remainingTerms;
  final double commercialOpening;
  final double commercialPrincipal;
  final double commercialInterest;
  final double commercialPayment;
  final double providentOpening;
  final double providentPrincipal;
  final double providentInterest;
  final double providentPayment;
  final double totalPayment;
  final double? commercialReduction;
  final double? providentReduction;
  final double? totalReduction;

  /// Income plus extra income after subtracting payment and living cost.
  final double availableFunds;
  final double expectedPrepayment;
  final double? actualPrepayment;

  /// 首页填写的单一还贷日期，同时用于计划展示与利息结转。
  final String? plannedPrepaymentDate;

  /// 与 [plannedPrepaymentDate] 保持一致，供导出和详情表直接使用。
  final String? effectivePrepaymentDate;

  /// Every dated prepayment used by this month, in actual calculation order.
  final List<String> prepaymentDates;

  /// 明细表按该列表展开同月多笔提前还款；多笔场景由第一笔明细计入
  /// 唯一一次正常月供，每笔明细保留累计至本笔提前还款前的月供信息。
  final List<LoanPrepaymentDetail> prepaymentDetails;

  /// 提前还款日当天应付的利息，不计入用户输入的提前本金。
  final double prepaymentInterestDueNow;

  /// 下一个月不含本次结转利息的基础月供。
  final double nextMonthBasePayment;

  /// 仅比较相邻基础月供得出的降低额，不受结转利息影响。
  final double? nextMonthBasePaymentReduction;
  final double usedPrepayment;
  final double commercialPrepayment;
  final double providentPrepayment;
  final double commercialClosing;
  final double providentClosing;

  double get totalBalance => commercialClosing + providentClosing;

  /// 转息导致的月供差额：实际月供合计减去转息前基础月供。
  double get transferDifference => totalPayment - nextMonthBasePayment;

  double? get difference =>
      actualPrepayment == null ? null : actualPrepayment! - expectedPrepayment;
}

class LoanPrepaymentDetail {
  const LoanPrepaymentDetail({
    required this.eventId,
    required this.amount,
    required this.expectedAmount,
    required this.actualPrepayment,
    required this.repaymentDate,
    required this.interestDueNow,
    required this.nextMonthDeferredInterest,
    required this.commercialClosing,
    required this.providentClosing,
    this.commercialPrincipalBefore = 0,
    this.commercialInterestBefore = 0,
    this.commercialPaymentBefore = 0,
    this.providentPrincipalBefore = 0,
    this.providentInterestBefore = 0,
    this.providentPaymentBefore = 0,
  });

  final double amount;
  final double expectedAmount;
  final String? eventId;
  final double? actualPrepayment;
  final String? repaymentDate;
  final double interestDueNow;
  final double nextMonthDeferredInterest;

  /// Balance immediately after this transaction, used by an expanded plan row.
  final double commercialClosing;
  final double providentClosing;

  /// The normal-payment components recalculated after prior cumulative
  /// prepayments and before this transaction. The first transaction owns the
  /// month's single applied payment; later values are display-only previews.
  final double commercialPrincipalBefore;
  final double commercialInterestBefore;
  final double commercialPaymentBefore;
  final double providentPrincipalBefore;
  final double providentInterestBefore;
  final double providentPaymentBefore;

  double get normalPaymentBefore =>
      commercialPaymentBefore + providentPaymentBefore;

  bool get hasNormalPaymentBefore => normalPaymentBefore > 0.000001;

  double get totalBalance => commercialClosing + providentClosing;
}

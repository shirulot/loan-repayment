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
  final double bankSeptemberPrincipal;
  final double bankSeptemberInterest;
  final double bankSeptemberPayment;

  /// Restores editable parameters while keeping defaults for missing fields.
  factory LoanPlanConfig.fromJson(Map<String, dynamic> json) {
    double number(String key, double fallback) {
      final value = json[key];
      return value is num
          ? value.toDouble()
          : double.tryParse('$value') ?? fallback;
    }

    int integer(String key, int fallback) {
      final value = json[key];
      return value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
    }

    const defaults = LoanPlanConfig();
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
    final day = int.tryParse(match.group(3) ?? '1') ?? 1;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
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
  double? get difference =>
      actualPrepayment == null ? null : actualPrepayment! - expectedPrepayment;
}

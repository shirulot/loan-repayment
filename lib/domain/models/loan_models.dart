class LoanPlanConfig {
  const LoanPlanConfig({
    this.commercialOpeningBalance = 375409.31,
    this.providentOpeningBalance = 500000,
    this.commercialAnnualRate = 0.032,
    this.providentAnnualRate = 0.026,
    this.remainingTerms = 200,
    this.loanStartDate = '',
    this.loanTermYears = 0,
    this.monthlySalary = 16500,
    this.recurringPrepaymentStart = 16500,
    this.monthlyLivingCost = 3300,
    this.fixedAugustPrepayment = 17000,
    this.fixedSeptemberPrepayment = 30000,
    this.fixedOctoberPrepayment = 7000,
    this.bankSeptemberPrincipal = 1789.55,
    this.bankSeptemberInterest = 986.24,
    this.bankSeptemberPayment = 2775.79,
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

  /// First automatic prepayment after the three fixed repayment months.
  final double recurringPrepaymentStart;
  final double monthlyLivingCost;
  final double fixedAugustPrepayment;
  final double fixedSeptemberPrepayment;
  final double fixedOctoberPrepayment;
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
      recurringPrepaymentStart: number(
        'recurringPrepaymentStart',
        defaults.recurringPrepaymentStart,
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
    double? recurringPrepaymentStart,
    double? monthlyLivingCost,
    double? fixedAugustPrepayment,
    double? fixedSeptemberPrepayment,
    double? fixedOctoberPrepayment,
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
      recurringPrepaymentStart:
          recurringPrepaymentStart ?? this.recurringPrepaymentStart,
      monthlyLivingCost: monthlyLivingCost ?? this.monthlyLivingCost,
      fixedAugustPrepayment:
          fixedAugustPrepayment ?? this.fixedAugustPrepayment,
      fixedSeptemberPrepayment:
          fixedSeptemberPrepayment ?? this.fixedSeptemberPrepayment,
      fixedOctoberPrepayment:
          fixedOctoberPrepayment ?? this.fixedOctoberPrepayment,
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
      'recurringPrepaymentStart': recurringPrepaymentStart,
      'monthlyLivingCost': monthlyLivingCost,
      'fixedAugustPrepayment': fixedAugustPrepayment,
      'fixedSeptemberPrepayment': fixedSeptemberPrepayment,
      'fixedOctoberPrepayment': fixedOctoberPrepayment,
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
  final double availableFunds;
  final double expectedPrepayment;
  final double? actualPrepayment;
  final double usedPrepayment;
  final double commercialPrepayment;
  final double providentPrepayment;
  final double commercialClosing;
  final double providentClosing;

  double get totalBalance => commercialClosing + providentClosing;
  double? get difference =>
      actualPrepayment == null ? null : actualPrepayment! - expectedPrepayment;
}

class WomenHealthQuestionnaireVM {
  final int? peroidsDuration;
  final int? peroidsCycleCount;
  final int? periodDay;
  final int? periodMonth;
  final int? periodYear;
  final String? disorder; // PCOD, PCOS, Both, or null

  WomenHealthQuestionnaireVM({
    this.peroidsDuration,
    this.peroidsCycleCount,
    this.periodDay,
    this.periodMonth,
    this.periodYear,
    this.disorder,
  });
}

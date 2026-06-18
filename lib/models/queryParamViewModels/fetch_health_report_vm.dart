// mirrors: API.Model.QueryParamViewModels.FetchHealthReportVM

enum ReportFilterType {
  dateRange(1),
  financialYear(2);

  final int value;
  const ReportFilterType(this.value);
}

enum StatementRange {
  last1Month(1),
  last3Months(3),
  last6Months(6),
  last1Year(12),
  custom(99);

  final int value;
  const StatementRange(this.value);
}

enum ExportType {
  pdf(1),
  excel(2);

  final int value;
  const ExportType(this.value);
}

class FetchHealthReportVM {
  final ReportFilterType filterType;
  final StatementRange? range;       // null when filterType = financialYear
  final DateTime? fromDate;          // only when range = custom
  final DateTime? toDate;            // only when range = custom
  final String? financialYear;       // only when filterType = financialYear
  final ExportType exportType;
  final List<String> serviceTypes;   // your health service selections

  FetchHealthReportVM({
    required this.filterType,
    required this.exportType,
    required this.serviceTypes,
    this.range,
    this.fromDate,
    this.toDate,
    this.financialYear,
  });

  Map<String, dynamic> toJson() {
    return {
      'filterType': filterType.value,
      if (range != null) 'range': range!.value,
      if (fromDate != null) 'fromDate': fromDate!.toIso8601String(),
      if (toDate != null) 'toDate': toDate!.toIso8601String(),
      if (financialYear != null) 'financialYear': financialYear,
      'exportType': exportType.value,
      'serviceTypes': serviceTypes,
    };
  }
}
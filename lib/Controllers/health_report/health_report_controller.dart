import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:snevva/consts/colors.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/fetch_health_report_vm.dart';
import 'package:snevva/models/requested_health_record.dart';
import 'package:snevva/services/api_service.dart';

class HealthReportController extends GetxController {
  // ─── Segmented Control ────────────────────────────────────────────
  // 0 → DateRange, 1 → FinancialYear (mirrors ReportFilterType)
  final segmentedControlGroupValue = 0.obs;

  // ─── Download State ───────────────────────────────────────────────
  final RxMap<int, bool> isDownloadingMap = <int, bool>{}.obs;
  final RxMap<int, bool> isDownloadedMap = <int, bool>{}.obs;
  final RxMap<int, double> downloadProgressMap = <int, double>{}.obs;

  // ─── Health Service Selection ─────────────────────────────────────
  final isAllSelected = false.obs;
  final selectedHealthIndexes = <int>{}.obs;

  // ─── Range / Year Selection ───────────────────────────────────────
  final selectedIndex = 0.obs;

  // ─── Custom Date Range (only active when range = Custom) ──────────
  final Rx<DateTime?> customFromDate = Rx<DateTime?>(null);
  final Rx<DateTime?> customToDate = Rx<DateTime?>(null);

  // ─── Export Type ──────────────────────────────────────────────────
  final selectedExportType = ExportType.pdf.obs;

  // ─── Requested Reports ────────────────────────────────────────────
  final requestedReports = <RequestedHealthRecord>[].obs;

  // ─── Segment Switch ───────────────────────────────────────────────
  void onSegmentChanged(int value) {
    segmentedControlGroupValue.value = value;
    selectedIndex.value = 0;
    customFromDate.value = null;
    customToDate.value = null;
  }

  // ─── Range / Year Selection ───────────────────────────────────────
  void onRangeSelected(int index) {
    selectedIndex.value = index;
    // Clear custom dates if user switches away from Custom
    if (!isCustomSelected) {
      customFromDate.value = null;
      customToDate.value = null;
    }
  }

  // ─── Custom date pickers ──────────────────────────────────────────
  void setCustomFromDate(DateTime date) => customFromDate.value = date;
  void setCustomToDate(DateTime date) => customToDate.value = date;

  // ─── Export Type Toggle ───────────────────────────────────────────
  void setExportType(ExportType type) => selectedExportType.value = type;

  // ─── Helpers ──────────────────────────────────────────────────────
  bool get isDateRangeMode => segmentedControlGroupValue.value == 0;

  bool get isCustomSelected =>
      isDateRangeMode && selectedIndex.value == 4; // 'Custom Date Range' index

  /// Maps UI tab → ReportFilterType
  ReportFilterType get _filterType =>
      isDateRangeMode ? ReportFilterType.dateRange : ReportFilterType.financialYear;

  /// Maps dateRangeList index → StatementRange
  StatementRange _mapIndexToRange(int index) {
    const map = {
      0: StatementRange.last1Month,
      1: StatementRange.last3Months,
      2: StatementRange.last6Months,
      3: StatementRange.last1Year,
      4: StatementRange.custom,
    };
    return map[index] ?? StatementRange.last1Month;
  }

  // ─── Health Service Toggle ────────────────────────────────────────
  void toggleHealthService(int index, int totalCount) {
    if (selectedHealthIndexes.contains(index)) {
      selectedHealthIndexes.remove(index);
    } else {
      selectedHealthIndexes.add(index);
    }
    isAllSelected.value = selectedHealthIndexes.length == totalCount;
  }

  void toggleSelectAll(bool? val, int totalCount) {
    isAllSelected.value = val ?? false;
    if (isAllSelected.value) {
      selectedHealthIndexes.assignAll(
        List.generate(totalCount, (i) => i),
      );
    } else {
      selectedHealthIndexes.clear();
    }
  }

  // ─── Build Request Model ──────────────────────────────────────────
  FetchHealthReportVM? _buildRequestModel({
    required List<Map<String, dynamic>> healthServices,
    required List<String> dateRangeList,
    required List<String> yearRangeList,
  }) {
    if (selectedHealthIndexes.isEmpty) {
      Get.snackbar(
        'Select Health Type',
        'Please select at least one health service',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }

    // Custom range validation
    if (isCustomSelected) {
      if (customFromDate.value == null || customToDate.value == null) {
        Get.snackbar(
          'Select Date Range',
          'Please select both From and To dates',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return null;
      }
      if (customFromDate.value!.isAfter(customToDate.value!)) {
        Get.snackbar(
          'Invalid Date Range',
          'From date cannot be after To date',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return null;
      }
    }

    final selectedServices = selectedHealthIndexes
        .map((i) => healthServices[i]['title'] as String)
        .toList();

    if (isDateRangeMode) {
      final range = _mapIndexToRange(selectedIndex.value);
      return FetchHealthReportVM(
        filterType: ReportFilterType.dateRange,
        range: range,
        fromDate: range == StatementRange.custom ? customFromDate.value : null,
        toDate: range == StatementRange.custom ? customToDate.value : null,
        exportType: selectedExportType.value,
        serviceTypes: selectedServices,
      );
    } else {
      return FetchHealthReportVM(
        filterType: ReportFilterType.financialYear,
        financialYear: yearRangeList[selectedIndex.value], // e.g. "2024-25"
        exportType: selectedExportType.value,
        serviceTypes: selectedServices,
      );
    }
  }

  // ─── Request Health Record ────────────────────────────────────────
  void requestHealthRecord({
    required List<Map<String, dynamic>> healthServices,
    required List<String> dateRangeList,
    required List<String> yearRangeList,
  }) {
    final vm = _buildRequestModel(
      healthServices: healthServices,
      dateRangeList: dateRangeList,
      yearRangeList: yearRangeList,
    );
    if (vm == null) return;

    debugPrint("📤 Request Payload: ${vm.toJson()}");
    
    final response = ApiService.post(
      healthreport,
      vm as Map<String, dynamic>?,
      withAuth: true,
      encryptionRequired: true
    );

    final timePeriod = isDateRangeMode
        ? dateRangeList[selectedIndex.value]
        : yearRangeList[selectedIndex.value];

    requestedReports.insert(
      0,
      RequestedHealthRecord(
        serviceType: vm.serviceTypes,
        timePeriod: timePeriod,
        requestedOn: DateTime.now(),
      ),
    );

    Get.snackbar(
      'Success',
      'Health record requested successfully',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.primaryColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
  }

  // ─── Download Report ──────────────────────────────────────────────
  Future<void> downloadReport(int reportIndex) async {
    if (isDownloadedMap[reportIndex] == true) {
      Get.snackbar(
        'Aye!',
        'This report is already downloaded',
        snackPosition: SnackPosition.TOP,
        colorText: Colors.white,
        backgroundColor: AppColors.primaryColor,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    isDownloadingMap[reportIndex] = true;
    downloadProgressMap[reportIndex] = 0;

    for (int i = 1; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      downloadProgressMap[reportIndex] = i / 100;
    }

    isDownloadingMap[reportIndex] = false;
    isDownloadedMap[reportIndex] = true;

    Get.snackbar(
      'Notice Here!',
      'Report downloaded',
      snackPosition: SnackPosition.TOP,
      colorText: Colors.white,
      backgroundColor: AppColors.primaryColor,
      duration: const Duration(seconds: 3),
    );
  }
}
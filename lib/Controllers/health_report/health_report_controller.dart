import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snevva/consts/colors.dart';
import 'package:snevva/models/queryParamViewModels/fetch_health_report_vm.dart';
import 'package:snevva/models/requested_health_record.dart';

import '../../Services/api_service.dart';
import '../../env/env.dart';

class HealthReportController extends GetxController {
  // ─── Loading ──────────────────────────────────────────────────────────────────
  final RxBool isLoading = false.obs;

  // ─── Segmented Control (0 = Date Range, 1 = Year) ────────────────────────────
  final RxInt segmentedControlGroupValue = 0.obs;

  // ─── Selected row index inside whichever list is active ──────────────────────
  final RxInt selectedIndex = 0.obs;

  // ─── Custom Date Range ────────────────────────────────────────────────────────
  final Rx<DateTime?> customFromDate = Rx<DateTime?>(null);
  final Rx<DateTime?> customToDate = Rx<DateTime?>(null);

  // ─── Financial Year dropdown ──────────────────────────────────────────────────
  final RxList<String> yearRangeList = <String>[].obs;
  final RxInt selectedYearIndex = 0.obs;

  // ─── Export Type ──────────────────────────────────────────────────────────────
  final Rx<ExportType> selectedExportType = ExportType.pdf.obs;

  // ─── Health Service Grid ──────────────────────────────────────────────────────
  final RxSet<int> selectedHealthIndexes = <int>{}.obs;
  final RxBool isAllSelected = false.obs;

  // ─── Requested Reports ────────────────────────────────────────────────────────
  final RxList<RequestedHealthRecord> requestedReports =
      <RequestedHealthRecord>[].obs;

  // ─── Per-card download state ──────────────────────────────────────────────────
  final RxMap<int, bool> isDownloadedMap = <int, bool>{}.obs;
  final RxMap<int, bool> isDownloadingMap = <int, bool>{}.obs;
  final RxMap<int, double> downloadProgressMap = <int, double>{}.obs;

  // ─── Static total used for "select all" guard ─────────────────────────────────
  int _totalServices = 0;
  Timer? _yearCheckTimer;
  int _lastKnownYear = DateTime.now().year;

  // ────────────────────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _buildFinancialYearList();
    _startYearChangeWatcher();
  }

  @override
  void onClose() {
    _yearCheckTimer?.cancel();
    super.onClose();
  }

  void _startYearChangeWatcher() {
    // Check every hour — zero overhead, fires only ~8760x/year
    _yearCheckTimer = Timer.periodic(const Duration(hours: 1), (_) {
      final int nowYear = DateTime.now().year;
      if (nowYear != _lastKnownYear) {
        _lastKnownYear = nowYear;
        _buildFinancialYearList();         // rebuild list — new year appended
        selectedYearIndex.value = 0;       // reset selection to first (2026-27)
      }
    });
  }

  // ─── Financial year list (e.g. "2024-25") ────────────────────────────────────
  void _buildFinancialYearList() {
    const int baseYear = 2026; // always starts from 2026-27
    final int currentYear = DateTime.now().year;

    // Generate from baseYear up to currentYear (inclusive), so list grows each year
    final List<String> years = [];
    for (int start = baseYear; start <= currentYear; start++) {
      years.add('$start-${(start + 1).toString().substring(2)}');
    }

    yearRangeList.assignAll(years);
  }

  // ─── Segment changed (Date Range ↔ Year) ──────────────────────────────────────
  void onSegmentChanged(int value) {
    segmentedControlGroupValue.value = value;
    selectedIndex.value = 0; // reset selection on tab switch
  }

  // ─── Row selected inside the range/year list ─────────────────────────────────
  void onRangeSelected(int index) {
    selectedIndex.value = index;

    // If switching to Date Range tab, mirror into StatementRange
    if (segmentedControlGroupValue.value == 0) {
      // clear custom dates when picking a non-custom row
      if (index != 4) {
        customFromDate.value = null;
        customToDate.value = null;
      }
    }
  }

  // ─── Export type chip ─────────────────────────────────────────────────────────
  void setExportType(ExportType type) => selectedExportType.value = type;

  // ─── Custom date setters ──────────────────────────────────────────────────────
  void setCustomFromDate(DateTime date) => customFromDate.value = date;

  void setCustomToDate(DateTime date) => customToDate.value = date;

  // ─── Health service grid toggle ───────────────────────────────────────────────
  // View passes (index, totalCount) — we keep totalCount so we can update
  // isAllSelected correctly without storing total separately.
  void toggleHealthService(int index, int total) {
    _totalServices = total;
    if (selectedHealthIndexes.contains(index)) {
      selectedHealthIndexes.remove(index);
    } else {
      selectedHealthIndexes.add(index);
    }
    isAllSelected.value = selectedHealthIndexes.length == total;
  }

  // ─── Select / deselect all ────────────────────────────────────────────────────
  void toggleSelectAll(bool? value, int total) {
    _totalServices = total;
    final select = value ?? false;
    if (select) {
      selectedHealthIndexes.assignAll(List.generate(total, (i) => i));
    } else {
      selectedHealthIndexes.clear();
    }
    isAllSelected.value = select;
  }

  // ─── Map selectedIndex → StatementRange ──────────────────────────────────────
  StatementRange get _currentRange {
    switch (selectedIndex.value) {
      case 0:
        return StatementRange.last1Month;
      case 1:
        return StatementRange.last3Months;
      case 2:
        return StatementRange.last6Months;
      case 3:
        return StatementRange.last1Year;
      case 4:
        return StatementRange.custom;
      default:
        return StatementRange.last1Month;
    }
  }

  // ─── Build VM ─────────────────────────────────────────────────────────────────
  FetchHealthReportVM _buildRequestModel() {
    // Collect selected service titles
    // The view's healthServices list is static — we resolve titles by index.
    // Since controller shouldn't import the view, the titles are passed in
    // via selectedServiceTitles which are set before this call.
    // We use selectedHealthIndexes to build serviceTypes from the cached list.
    final List<String> serviceTypes =
    List<String>.from(_cachedServiceTitles);

    if (segmentedControlGroupValue.value == 1) {
      // Financial Year mode
      return FetchHealthReportVM(
        filterType: ReportFilterType.financialYear,
        exportType: selectedExportType.value,
        serviceTypes: serviceTypes,
        financialYear: yearRangeList[selectedIndex.value],
      );
    }

    final range = _currentRange;

    if (range == StatementRange.custom) {
      return FetchHealthReportVM(
        filterType: ReportFilterType.dateRange,
        exportType: selectedExportType.value,
        serviceTypes: serviceTypes,
        range: range,
        fromDate: customFromDate.value,
        toDate: customToDate.value,
      );
    }

    return FetchHealthReportVM(
      filterType: ReportFilterType.dateRange,
      exportType: selectedExportType.value,
      serviceTypes: serviceTypes,
      range: range,
    );
  }

  // ─── Cache for service titles (set from view before requestHealthRecord) ──────
  // This avoids the controller importing the view's static list.
  List<String> _cachedServiceTitles = [];

  /// Call this from the view's Request button, passing selected titles.
  void setSelectedServiceTitles(List<Map<String, dynamic>> allServices) {
    _cachedServiceTitles = selectedHealthIndexes
        .map((i) => allServices[i]['title'] as String)
        .toList();
  }

  // ─── Build time period label ──────────────────────────────────────────────────
  String _buildTimePeriodLabel() {
    if (segmentedControlGroupValue.value == 1) {
      return 'FY ${yearRangeList[selectedIndex.value]}';
    }
    switch (_currentRange) {
      case StatementRange.last1Month:
        return 'Last 1 Month';
      case StatementRange.last3Months:
        return 'Last 3 Months';
      case StatementRange.last6Months:
        return 'Last 6 Months';
      case StatementRange.last1Year:
        return 'Last 1 Year';
      case StatementRange.custom:
        final from = customFromDate.value;
        final to = customToDate.value;
        if (from != null && to != null) {
          return '${_fmt(from)} – ${_fmt(to)}';
        }
        return 'Custom Range';
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';

  // ─── Validation ───────────────────────────────────────────────────────────────
  bool _validate() {
    if (selectedHealthIndexes.isEmpty) {
      _showError('Select Service',
          'Please select at least one health service.');
      return false;
    }
    if (segmentedControlGroupValue.value == 0 &&
        _currentRange == StatementRange.custom) {
      if (customFromDate.value == null || customToDate.value == null) {
        _showError('Select Dates',
            'Please select both From and To dates.');
        return false;
      }
      if (customFromDate.value!.isAfter(customToDate.value!)) {
        _showError('Invalid Range',
            'From date cannot be after To date.');
        return false;
      }
    }
    return true;
  }

  // ─── STEP 1 : Request Health Record — API call happens here ──────────────────
  Future<void> requestHealthRecord({
    required List<Map<String, dynamic>> allServices,
  }) async {
    if (!_validate()) return;

    // Resolve titles before building the VM
    setSelectedServiceTitles(allServices);

    isLoading.value = true;

    try {
      final vm = _buildRequestModel();


      // FIX: cast response correctly
      final dynamic raw = await ApiService.post(
        healthreport,
        vm.toJson(),
        withAuth: true,
        encryptionRequired: true,
      );

      final Map<String, dynamic>? response =
      raw != null ? Map<String, dynamic>.from(raw as Map) : null;

      final String? base64Data = response?['data'] as String?;
      final bool failed = base64Data == null || base64Data.isEmpty;

      await Future.delayed(const Duration(seconds: 1)); // simulate network
      // final String? base64Data = vm.exportType == ExportType.pdf
      //     ? pdfDummy
      //     : excelDummy;
      // final bool failed = base64Data == null || base64Data.isEmpty;

      // Shift existing card indices to make room at 0
      final newDownloadedMap = <int, bool>{};
      final newDownloadingMap = <int, bool>{};
      final newProgressMap = <int, double>{};

      isDownloadedMap.forEach((k, v) => newDownloadedMap[k + 1] = v);
      isDownloadingMap.forEach((k, v) => newDownloadingMap[k + 1] = v);
      downloadProgressMap.forEach((k, v) => newProgressMap[k + 1] = v);

      newDownloadedMap[0] = false;
      newDownloadingMap[0] = false;
      newProgressMap[0] = 0.0;

      isDownloadedMap.value = newDownloadedMap;
      isDownloadingMap.value = newDownloadingMap;
      downloadProgressMap.value = newProgressMap;

      requestedReports.insert(
        0,
        RequestedHealthRecord(
          serviceType: vm.serviceTypes,
          timePeriod: _buildTimePeriodLabel(),
          requestedOn: DateTime.now(),
          exportType: vm.exportType,
          base64Data: failed ? null : base64Data,
          isFailed: failed,
        ),
      );

      if (failed) {
        _showError('Generation Failed',
            'Report was requested but no data was returned.');
      } else {
        Get.snackbar(
          'Report Ready',
          'Your report is ready. Tap Download to save it.',
          snackPosition: SnackPosition.TOP,
          colorText: Colors.white,
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('❌ requestHealthRecord error: $e');
      _showError('Request Failed',
          'Could not generate the report. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  // ─── STEP 2 : Download — no API call, reads stored base64 ────────────────────
  Future<void> downloadReport(int reportIndex) async {
    final report = requestedReports[reportIndex];

    if (report.isFailed ||
        report.base64Data == null ||
        report.base64Data!.isEmpty) {
      _showError('Not Available',
          'This report could not be generated. Please request again.');
      return;
    }

    isDownloadingMap[reportIndex] = true;
    downloadProgressMap[reportIndex] = 0.0;

    try {
      downloadProgressMap[reportIndex] = 0.3;

      await _saveAndOpenFromBase64(
        base64String: report.base64Data!,
        exportType: report.exportType,
        reportIndex: reportIndex,
      );

      downloadProgressMap[reportIndex] = 1.0;
      isDownloadingMap[reportIndex] = false;
      isDownloadedMap[reportIndex] = true;

      final label =
      report.exportType == ExportType.pdf ? 'PDF' : 'Excel';
      // Get.snackbar(
      //   'Downloaded!',
      //   '$label report saved to your device.',
      //   snackPosition: SnackPosition.TOP,
      //   colorText: Colors.white,
      //   backgroundColor: AppColors.primaryColor,
      //   duration: const Duration(seconds: 3),
      // );
    } catch (e) {
      debugPrint('❌ downloadReport error: $e');
      isDownloadingMap[reportIndex] = false;
      downloadProgressMap[reportIndex] = 0.0;
      _showError('Download Failed',
          'Could not save the report. Please try again.');
    }
  }

  // ─── Base64 → File → Open ─────────────────────────────────────────────────────
  Future<void> _saveAndOpenFromBase64({
    required String base64String,
    required ExportType exportType,
    required int reportIndex,
  }) async {
    final String padded = _ensurePadding(base64String);
    final Uint8List bytes = base64Decode(padded);

    final String ext = exportType == ExportType.pdf ? 'pdf' : 'xlsx';
    final String label = exportType == ExportType.pdf ? 'PDF' : 'Excel';
    final String ts = DateTime
        .now()
        .millisecondsSinceEpoch
        .toString();

    final Directory dir = await _resolveDirectory();
    final File file =
    File('${dir.path}/health_report_${reportIndex}_$ts.$ext');

    await file.writeAsBytes(bytes, flush: true);
    debugPrint('✅ Saved $label → ${file.path}');

    final OpenResult result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      _showError('Cannot Open File', result.message);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────
  String _ensurePadding(String s) {
    final int rem = s.length % 4;
    return rem == 0 ? s : s + ('=' * (4 - rem));
  }

  Future<Directory> _resolveDirectory() async {
    if (Platform.isAndroid) {
      final Directory dir =
      Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    return getApplicationDocumentsDirectory();
  }

  void _showError(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
}
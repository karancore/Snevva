import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:snevva/Controllers/health_report/health_report_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/consts/images.dart';
import 'package:snevva/widgets/reminder/custom_Radio.dart';

import '../../consts/colors.dart';
import '../../models/queryParamViewModels/fetch_health_report_vm.dart';

const healthServiceBackgroundCardColor = Color(0xffF8F5FC);

class HealthReportScreen extends StatelessWidget {
  const HealthReportScreen({super.key});

  // ─── Static data ─────────────────────────────────────────────────
  static const List<String> dateRangeList = [
    'Last 1 Month',
    'Last 3 Month',
    'Last 6 Month',
    'Last 1 Year',
    'Custom Date Range',
  ];

  static List<Map<String, dynamic>> get healthServices => [
    {"title": "Steps", "icon": stepsHealthReportIcon},
    {"title": "Blood Pressure", "icon": bpHealthReportIcon},
    {"title": "Hydration", "icon": hydrationHealthReportIcon},
    {"title": "Blood Glucose", "icon": bloodHealthReportIcon},
    {"title": "Sleep", "icon": sleepHealthReportIcon},
    {"title": "BMI", "icon": bmiHealthReportIcon},
    {"title": "Mood", "icon": smileyHealthReportIcon},
    {"title": "Women Health", "icon": genderHealthReportIcon},
  ];

  static List<String> get yearRangeList {
    final currentYear = DateTime.now().year;
    return List.generate(3, (index) {
      final startYear = currentYear - 1 + index;
      return '$startYear-${(startYear + 1).toString().substring(2)}';
    }).reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HealthReportController());

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final double scale = width / 360;
    const double itemHeight = 52.0;

    return Scaffold(
      appBar: CustomAppBar(appbarText: 'Health Record', showDrawerIcon: false),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Segmented Control ──────────────────────────────────
              Obx(() {
                final segValue = controller.segmentedControlGroupValue.value;
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    height: scale * 36,
                    width: scale * 332,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.shade900
                          : Colors.grey.shade200,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          offset: const Offset(1, 1),
                          blurRadius: 3,
                          spreadRadius: 1,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: segValue,
                      thumbColor: AppColors.secondaryColor,
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.all(4),
                      children: {
                        0: _buildSegment(
                          title: "Date Range",
                          selected: segValue == 0,
                        ),
                        1: _buildSegment(
                          title: "Year",
                          selected: segValue == 1,
                        ),
                      },
                      onValueChanged: (value) {
                        if (value != null) controller.onSegmentChanged(value);
                      },
                    ),
                  ),
                );
              }),

              SizedBox(height: scale * 18),

              // ── Range List ────────────────────────────────────────
              Obx(() {
                final segValue = controller.segmentedControlGroupValue.value;
                final selectedIdx = controller.selectedIndex.value;
                return _rangeColumn(
                  controller: controller,
                  scale: scale,
                  itemHeight: itemHeight,
                  items: segValue == 0 ? dateRangeList : controller
                      .yearRangeList,
                  selectedIndex: selectedIdx,
                  isDarkMode: isDarkMode,
                );
              }),

              SizedBox(height: 16 * scale),

              // ── Export Type Choice Chips ───────────────────────────
              Obx(() {
                final selectedType = controller.selectedExportType.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      const Text(
                        "Export As  ",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      ...ExportType.values.map((type) {
                        final isSelected = selectedType == type;
                        final label =
                        type == ExportType.pdf ? 'PDF' : 'Excel';
                        final icon = type == ExportType.pdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.table_chart_rounded;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            avatar: Icon(
                              icon,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.secondaryColor,
                            ),
                            label: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.secondaryColor,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) =>
                                controller.setExportType(type),
                            selectedColor: AppColors.secondaryColor,
                            backgroundColor: isDarkMode
                                ? darkGray
                                : healthServiceBackgroundCardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.secondaryColor
                                    : AppColors.secondaryColor
                                    .withOpacity(0.4),
                              ),
                            ),
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),

              SizedBox(height: 4 * scale),

              // ── Select All ────────────────────────────────────────
              Obx(() {
                final isAll = controller.isAllSelected.value;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () =>
                        controller.toggleSelectAll(
                          !isAll,
                          healthServices.length,
                        ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isAll,
                          activeColor: AppColors.secondaryColor,
                          onChanged: (val) =>
                              controller.toggleSelectAll(
                                val,
                                healthServices.length,
                              ),
                        ),
                        const Text(
                          "Select All",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              SizedBox(height: 16 * scale),

              // ── Health Service Grid ───────────────────────────────
              Obx(() {
                final selectedIndexes =
                Set<int>.from(controller.selectedHealthIndexes);
                return _healthServiceList(
                  controller: controller,
                  healthServices: healthServices,
                  selectedIndexes: selectedIndexes,
                  scale: scale,
                  isDarkMode: isDarkMode,
                );
              }),

              SizedBox(height: 18 * scale),

              // ── Request Button ─────────────────────────────────────
              // FIX 1: removed dangling open-paren — no args needed
              Obx(() {
                final isLoading = controller.isLoading.value;
                return CustomOutlinedButton(
                  width: width,
                  isDarkMode: isDarkMode,
                  borderRadius: 12,
                  backgroundColor: AppColors.secondaryColor,
                  buttonName: isLoading
                      ? 'Generating Report…'
                      : 'Request Health Record',
                  onTap: isLoading
                      ? null
                      : () =>
                      controller.requestHealthRecord(
                          allServices: healthServices), // ← FIX 1
                );
              }),

              SizedBox(height: 11 * scale),

              const Text(
                " Requested Health Record",
                style:
                TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),

              SizedBox(height: 12 * scale),

              // ── Requested Reports List ────────────────────────────
              // FIX 2: use requestedReports directly (RxList), no .value
              Obx(() {
                final reports = controller.requestedReports;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: 10 * scale),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _downloadedReportContainer(
                      controller: controller,
                      reportIndex: index,
                      scale: scale,
                      serviceType: report.serviceType,
                      timePeriod: report.timePeriod,
                      // FIX 3: use stored requestedOn, not DateTime.now()
                      requestedOn: report.requestedOn,
                      // FIX 4: pass exportType for dynamic icon
                      exportType: report.exportType,
                      // FIX 5: pass isFailed for badge
                      isFailed: report.isFailed,
                      isDarkMode: isDarkMode,
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widgets ──────────────────────────────────────────────────────

  Widget _healthServiceList({
    required HealthReportController controller,
    required List healthServices,
    required Set<int> selectedIndexes,
    required double scale,
    required bool isDarkMode,
  }) {
    return Container(
      height: 136 * scale,
      width: 342 * scale,
      decoration: BoxDecoration(
        color: isDarkMode ? darkGray.withOpacity(0.5) : white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(1, 1),
            blurRadius: 9,
            spreadRadius: 1,
          ),
        ],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: healthServices.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.3,
          ),
          itemBuilder: (context, index) {
            final item = healthServices[index];
            return InkWell(
              onTap: () =>
                  controller.toggleHealthService(index, healthServices.length),
              child: SizedBox(
                width: 72 * scale,
                height: 52 * scale,
                child: _healthServiceCard(
                  scale: scale,
                  title: item['title'],
                  icon: item['icon'],
                  isDarkMode: isDarkMode,
                  isSelected: selectedIndexes.contains(index),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _healthServiceCard({
    required double scale,
    required String title,
    required String icon,
    required bool isSelected,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.secondaryColor
            : (isDarkMode ? darkGray : healthServiceBackgroundCardColor),
        borderRadius: BorderRadius.circular(7),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              icon,
              color: isSelected ? white : AppColors.secondaryColor,
              width: 20 * scale,
              height: 25 * scale,
            ),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 8,
                color:
                isSelected ? white : (isDarkMode ? white : black),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeColumn({
    required HealthReportController controller,
    required double scale,
    required double itemHeight,
    required List<String> items,
    required int selectedIndex,
    required bool isDarkMode,
  }) {
    return Container(
      width: 332 * scale,
      height: itemHeight * items.length,
      decoration: BoxDecoration(
        color: isDarkMode ? darkGray : white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            offset: const Offset(1, 1),
            blurRadius: 3,
            spreadRadius: 1,
          ),
        ],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.withOpacity(0.2),
            ),
        itemBuilder: (context, index) {
          final isSelected = selectedIndex == index;
          return Container(
            height: itemHeight,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.secondaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.only(
                topLeft:
                index == 0 ? const Radius.circular(12) : Radius.zero,
                topRight:
                index == 0 ? const Radius.circular(12) : Radius.zero,
                bottomLeft: index == items.length - 1
                    ? const Radius.circular(12)
                    : Radius.zero,
                bottomRight: index == items.length - 1
                    ? const Radius.circular(12)
                    : Radius.zero,
              ),
            ),
            child: Center(
              child: ListTile(
                onTap: () => controller.onRangeSelected(index),
                leading: CustomRadio(
                  selected: isSelected,
                  onTap: () => controller.onRangeSelected(index),
                  activeColor: AppColors.secondaryColor,
                ),
                title: Text(
                  items[index],
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _downloadedReportContainer({
    required HealthReportController controller,
    required int reportIndex,
    required double scale,
    required List<String> serviceType,
    required String timePeriod,
    required DateTime requestedOn, // FIX 3
    required ExportType exportType, // FIX 4
    required bool isFailed, // FIX 5
    required bool isDarkMode,
  }) {
    return Obx(() {
      final isDownloading =
          controller.isDownloadingMap[reportIndex] ?? false;
      final isDownloaded =
          controller.isDownloadedMap[reportIndex] ?? false;
      final downloadProgress =
          controller.downloadProgressMap[reportIndex] ?? 0.0;

      // FIX 4: pick icon asset based on export type
      final String reportIcon =
      exportType == ExportType.pdf ? pdfIcon : excelIcon;

      return InkWell(
        onTap: (isDownloading || isFailed)
            ? null
            : () => controller.downloadReport(reportIndex),
        child: Container(
          height: 53 * scale,
          width: double.infinity,
          decoration: BoxDecoration(
            // FIX 5: tint red if generation failed
            color: isFailed
                ? Colors.red.withOpacity(0.07)
                : (isDarkMode
                ? darkGray
                : healthServiceBackgroundCardColor),
            borderRadius: BorderRadius.circular(12),
            border: isFailed
                ? Border.all(color: Colors.red.withOpacity(0.3))
                : null,
          ),
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Row(
              children: [
                // FIX 4: dynamic icon
                CircleAvatar(
                  radius: 16 * scale,
                  backgroundColor:
                  AppColors.secondaryColor.withOpacity(0.2),
                  child: Image.asset(
                    reportIcon,
                    color: AppColors.secondaryColor.withOpacity(0.9),
                    height: 24,
                    width: 24,

                  ),
                ),
                SizedBox(width: 15 * scale),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${serviceType.take(2).join(', ')}"
                            "${serviceType.length > 2 ? ' +${serviceType
                            .length - 2} more' : ''}"
                            " • $timePeriod",
                        style: const TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // FIX 3: use stored requestedOn date
                      Text(
                        isFailed
                            ? "Generation failed"
                            : "Requested on ${requestedOn.day} "
                            "${_monthName(requestedOn.month)} "
                            "${requestedOn.year}",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 7,
                          color: isFailed
                              ? Colors.red
                              : const Color(0xff626262),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // FIX 5: hide download button if generation failed
                if (!isFailed)
                  InkWell(
                    onTap: isDownloading
                        ? null
                        : () => controller.downloadReport(reportIndex),
                    child: Container(
                      height: 26 * scale,
                      width: 110 * scale,
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        gradient: isDownloaded
                            ? AppColors.greenGradient
                            : AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? darkGray.withOpacity(0.3)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: isDownloading
                            ? Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius:
                              BorderRadius.circular(14),
                              child: LinearProgressIndicator(
                                value: downloadProgress,
                                minHeight: double.infinity,
                                backgroundColor: isDarkMode
                                    ? AppColors.secondaryColor
                                    .withOpacity(0.5)
                                    : Colors.grey.shade200,
                                valueColor:
                                AlwaysStoppedAnimation(
                                  isDarkMode
                                      ? white
                                      : AppColors.secondaryColor,
                                ),
                              ),
                            ),
                            Text(
                              "${(downloadProgress * 100).toInt()}%",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color:
                                isDarkMode ? black : white,
                              ),
                            ),
                          ],
                        )
                            : Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Icon(
                              isDownloaded
                                  ? Icons.download_done_rounded
                                  : Icons.download_rounded,
                              size: 14,
                              color: isDownloaded
                                  ? Colors.green
                                  : (isDarkMode ? white : black),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isDownloaded
                                  ? "Downloaded"
                                  : "Download",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDownloaded
                                    ? (isDarkMode ? white : black)
                                    : (isDarkMode ? white : black),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                // FIX 5: "Failed" badge when isFailed = true
                  Container(
                    height: 26 * scale,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.red.withOpacity(0.4)),
                    ),
                    child: const Center(
                      child: Text(
                        "Failed",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSegment({required String title, required bool selected}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.grey.shade700,
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    return months[month - 1];
  }
}
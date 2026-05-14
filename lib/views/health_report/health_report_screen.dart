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

const healthServiceBackgroundCardColor = Color(0xffF8F5FC);

class HealthReportScreen extends StatelessWidget {
  const HealthReportScreen({super.key});

  // ─── Static data (no state, safe as local constants) ─────────────
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
    // ── Put controller once at root ──────────────────────────────────
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
              Obx(
                () => Center(
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    height: scale * 36,
                    width: scale * 332,
                    decoration: BoxDecoration(
                      color:
                          isDarkMode
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
                      groupValue: controller.segmentedControlGroupValue.value,
                      thumbColor: AppColors.secondaryColor,
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.all(4),
                      children: {
                        0: _buildSegment(
                          title: "Date Range",
                          selected:
                              controller.segmentedControlGroupValue.value == 0,
                        ),
                        1: _buildSegment(
                          title: "Year",
                          selected:
                              controller.segmentedControlGroupValue.value == 1,
                        ),
                      },
                      onValueChanged: (value) {
                        if (value != null) controller.onSegmentChanged(value);
                      },
                    ),
                  ),
                ),
              ),

              SizedBox(height: scale * 18),

              // ── Range List ────────────────────────────────────────
              Obx(
                () => _rangeColumn(
                  controller: controller,
                  scale: scale,
                  itemHeight: itemHeight,
                  items:
                      controller.segmentedControlGroupValue.value == 0
                          ? dateRangeList
                          : yearRangeList,
                  isDarkMode: isDarkMode,
                ),
              ),

              SizedBox(height: 16 * scale),

              // ── Select All ────────────────────────────────────────
              Obx(
                () => Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap:
                        () => controller.toggleSelectAll(
                          !controller.isAllSelected.value,
                          healthServices.length,
                        ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: controller.isAllSelected.value,
                          activeColor: AppColors.secondaryColor,
                          onChanged:
                              (val) => controller.toggleSelectAll(
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
                ),
              ),

              // ── Health Service Grid ───────────────────────────────
              Obx(
                () => _healthServiceList(
                  controller: controller,
                  healthServices: healthServices,
                  scale: scale,
                  isDarkMode: isDarkMode,
                ),
              ),

              SizedBox(height: 18 * scale),

              // ── Request Button ────────────────────────────────────
              CustomOutlinedButton(
                width: width,
                isDarkMode: isDarkMode,
                borderRadius: 12,
                backgroundColor: AppColors.secondaryColor,
                buttonName: 'Request Health Record',
                onTap: () {
                  controller.requestHealthRecord(
                    healthServices: HealthReportScreen.healthServices,
                    dateRangeList: HealthReportScreen.dateRangeList,
                    yearRangeList: HealthReportScreen.yearRangeList,
                  );
                },
              ),

              SizedBox(height: 11 * scale),

              const Text(
                " Requested Health Record",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),

              SizedBox(height: 12 * scale),

              // ── Requested Reports List ────────────────────────────
              Obx(
                () => ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.requestedReports.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10 * scale),
                  itemBuilder: (context, index) {
                    final report = controller.requestedReports[index];
                    return _downloadedReportContainer(
                      controller: controller,
                      reportIndex: index,
                      scale: scale,
                      serviceType: report.serviceType,
                      timePeriod: report.timePeriod,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
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
              onTap:
                  () => controller.toggleHealthService(
                    index,
                    healthServices.length,
                  ),
              child: SizedBox(
                width: 72 * scale,
                height: 52 * scale,
                child: _healthServiceCard(
                  scale: scale,
                  title: item['title'],
                  icon: item['icon'],
                  isDarkMode: isDarkMode,
                  isSelected: controller.selectedHealthIndexes.contains(index),
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
        color:
            isSelected
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
                color: isSelected ? white : (isDarkMode ? white : black),
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
        separatorBuilder:
            (_, __) => Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.withOpacity(0.2),
            ),
        itemBuilder: (context, index) {
          final isSelected = controller.selectedIndex.value == index;
          return Container(
            height: itemHeight,
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? AppColors.secondaryColor.withOpacity(0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.only(
                topLeft: index == 0 ? const Radius.circular(12) : Radius.zero,
                topRight: index == 0 ? const Radius.circular(12) : Radius.zero,
                bottomLeft:
                    index == items.length - 1
                        ? const Radius.circular(12)
                        : Radius.zero,
                bottomRight:
                    index == items.length - 1
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
    required bool isDarkMode,
  }) {
    final isDownloading = controller.isDownloadingMap[reportIndex] ?? false;
    final isDownloaded = controller.isDownloadedMap[reportIndex] ?? false;
    final downloadProgress = controller.downloadProgressMap[reportIndex] ?? 0.0;

    return InkWell(
      onTap:
          isDownloading ? null : () => controller.downloadReport(reportIndex),
      child: Container(
        height: 53 * scale,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDarkMode ? darkGray : healthServiceBackgroundCardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Row(
            children: [
              CircleAvatar(
                radius: 16 * scale,
                backgroundColor: AppColors.secondaryColor.withOpacity(0.2),
                child: Image.asset(
                  pdfIcon,
                  color: AppColors.secondaryColor.withOpacity(0.9),
                ),
              ),
              SizedBox(width: 15 * scale),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${serviceType.take(2).join(', ')}${serviceType.length > 2 ? ' +${serviceType.length - 2} more' : ''} • $timePeriod",
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Requested on ${DateTime.now().day} "
                      "${_monthName(DateTime.now().month)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 7,
                        color: Color(0xff626262),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                onTap:
                    isDownloading
                        ? null
                        : () => controller.downloadReport(reportIndex),
                child: Container(
                  height: 26 * scale,
                  width: 110 * scale,
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    gradient:
                        isDownloaded
                            ? AppColors.greenGradient
                            : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isDarkMode ? darkGray.withOpacity(0.3) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        isDownloading
                            ? Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: LinearProgressIndicator(
                                    value: downloadProgress,
                                    minHeight: double.infinity,
                                    backgroundColor:
                                        isDarkMode
                                            ? AppColors.secondaryColor
                                                .withOpacity(0.5)
                                            : Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation(
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
                                    color: isDarkMode ? black : white,
                                  ),
                                ),
                              ],
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isDownloaded
                                      ? Icons.download_done_rounded
                                      : Icons.download_rounded,
                                  size: 14,
                                  color:
                                      isDownloaded
                                          ? Colors.green
                                          : (isDarkMode ? white : black),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isDownloaded ? "Downloaded" : "Download",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDownloaded
                                            ? Colors.green
                                            : (isDarkMode ? white : black),
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[month - 1];
  }
}

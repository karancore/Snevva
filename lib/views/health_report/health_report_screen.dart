import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/consts/images.dart';
import 'package:snevva/widgets/reminder/custom_Radio.dart';

import '../../consts/colors.dart';
import '../../models/requested_health_record.dart';

class HealthReportScreen extends StatefulWidget {
  const HealthReportScreen({super.key});

  @override
  State<HealthReportScreen> createState() => _HealthReportScreenState();
}

const healthServiceBackgroundCardColor = Color(0xffF8F5FC);

class _HealthReportScreenState extends State<HealthReportScreen> {
  int segmentedControlGroupValue = 0;

  Map<int, bool> isDownloadingMap = {};
  Map<int, bool> isDownloadedMap = {};
  Map<int, double> downloadProgressMap = {};
  int selectedHealthIndex = 0;
  bool isAllSelected = false;
  Set<int> selectedHealthIndexes = {};
  int selectedIndex = 0;
  List<RequestedHealthRecord> requestedReports = [];

  Future<void> _downloadReport(int reportIndex) async {
    if (isDownloadedMap[reportIndex] == true) {
      Get.snackbar(
        'Aye!',
        'This report is already downloaded',
        snackPosition: SnackPosition.TOP,
        colorText: white,
        backgroundColor: AppColors.primaryColor,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() {
      isDownloadingMap[reportIndex] = true;
      downloadProgressMap[reportIndex] = 0;
    });

    for (int i = 1; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      setState(() {
        downloadProgressMap[reportIndex] = i / 100;
      });
    }

    if (!mounted) return;
    setState(() {
      isDownloadingMap[reportIndex] = false;
      isDownloadedMap[reportIndex] = true;
    });

    Get.snackbar(
      'Notice Here!',
      'Report downloaded',
      snackPosition: SnackPosition.TOP,
      colorText: white,
      backgroundColor: AppColors.primaryColor,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> requestHealthRecord({
    required List<String> type,
    required String timePeriod,
  }) async {
    final newReport = RequestedHealthRecord(
      serviceType: type,
      timePeriod: timePeriod,
      requestedOn: DateTime.now(),
    );

    setState(() {
      requestedReports.insert(0, newReport);
    });

    Get.snackbar(
      'Success',
      'Health record requested successfully',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.primaryColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );

    debugPrint("Time Period is $timePeriod and title is $type");
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final mediaQuery = MediaQuery.of(context);

    final height = mediaQuery.size.height;

    final width = mediaQuery.size.width;

    double scale = width / 360;

    double itemHeight = 52.00;

    final List<String> dateRangeList = [
      'Last 1 Month',
      'Last 3 Month',
      'Last 6 Month',
      'Last 1 Year',
      'Custom Date Range',
    ];

    //7527884869

    final List<Map<String, dynamic>> healthServices = [
      {"title": "Steps", "icon": stepsHealthReportIcon, "isSelected": true},
      {
        "title": "Blood Pressure",
        "icon": bpHealthReportIcon,
        "isSelected": false,
      },
      {
        "title": "Hydration",
        "icon": hydrationHealthReportIcon,
        "isSelected": false,
      },
      {
        "title": "Blood Glucose",
        "icon": bloodHealthReportIcon,
        "isSelected": false,
      },
      {"title": "Sleep", "icon": sleepHealthReportIcon, "isSelected": false},
      {"title": "BMI", "icon": bmiHealthReportIcon, "isSelected": false},
      {"title": "Mood", "icon": smileyHealthReportIcon, "isSelected": false},
      {
        "title": "Women Health",
        "icon": genderHealthReportIcon,
        "isSelected": false,
      },
    ];
    final currentYear = DateTime.now().year;

    final List<String> yearRangeList = List.generate(3, (index) {
      final startYear = currentYear - 1 + index;

      return '$startYear-${(startYear + 1).toString().substring(2)}';
    });
    return Scaffold(
      appBar: CustomAppBar(appbarText: 'Health Record', showDrawerIcon: false),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
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
                    groupValue: segmentedControlGroupValue,
                    thumbColor: AppColors.secondaryColor,
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                    children: {
                      0: _buildSegment(
                        title: "Date Range",
                        selected: segmentedControlGroupValue == 0,
                      ),
                      1: _buildSegment(
                        title: "Year",
                        selected: segmentedControlGroupValue == 1,
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() {
                          segmentedControlGroupValue = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: scale * 18),
              segmentedControlGroupValue == 0
                  ? _rangeColumn(
                    scale: scale,
                    itemHeight: itemHeight,
                    items: dateRangeList,
                    isDarkMode: isDarkMode,
                  )
                  : _rangeColumn(
                    scale: scale,
                    itemHeight: itemHeight,
                    items: yearRangeList.reversed.toList(),
                    isDarkMode: isDarkMode,
                  ),

              SizedBox(height: 16 * scale),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      isAllSelected = !isAllSelected;

                      if (isAllSelected) {
                        selectedHealthIndexes = Set.from(
                          List.generate(
                            healthServices.length,
                            (index) => index,
                          ),
                        );
                      } else {
                        selectedHealthIndexes.clear();
                      }
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: isAllSelected,
                        activeColor: AppColors.secondaryColor,
                        onChanged: (val) {
                          setState(() {
                            isAllSelected = val ?? false;

                            if (isAllSelected) {
                              selectedHealthIndexes = Set.from(
                                List.generate(
                                  healthServices.length,
                                  (index) => index,
                                ),
                              );
                            } else {
                              selectedHealthIndexes.clear();
                            }
                          });
                        },
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
              _healthServiceList(
                healthServices: healthServices,
                scale: scale,
                isDarkMode: isDarkMode,
                index: selectedHealthIndex,
              ),
              SizedBox(height: 18 * scale),
              CustomOutlinedButton(
                width: width,
                isDarkMode: isDarkMode,
                borderRadius: 12,
                backgroundColor: AppColors.secondaryColor,
                buttonName: 'Request Health Record',
                onTap: () {
                  if (selectedHealthIndexes.isEmpty) {
                    Get.snackbar(
                      'Select Health Type',
                      'Please select at least one health service',
                      snackPosition: SnackPosition.TOP,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }

                  final selectedTime =
                      segmentedControlGroupValue == 0
                          ? dateRangeList[selectedIndex]
                          : yearRangeList.reversed.toList()[selectedIndex];

                  final selectedServices =
                      selectedHealthIndexes
                          .map((i) => healthServices[i]['title'] as String)
                          .toList();
                  requestHealthRecord(
                    type: selectedServices,
                    timePeriod: selectedTime,
                  );
                },
              ),
              SizedBox(height: 11 * scale),
              Text(
                " Requested Health Record",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              SizedBox(height: 12 * scale),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requestedReports.length,
                separatorBuilder: (_, __) => SizedBox(height: 10 * scale),
                itemBuilder: (context, index) {
                  final report = requestedReports[index];

                  return _downloadedReportContainer(
                    reportIndex: index,
                    scale: scale,
                    serviceType: report.serviceType,
                    timePeriod: report.timePeriod,
                    isDarkMode: isDarkMode,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _healthServiceList({
    required List healthServices,
    required double scale,
    required bool isDarkMode,
    required int index,
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
              onTap: () {
                setState(() {
                  if (selectedHealthIndexes.contains(index)) {
                    selectedHealthIndexes.remove(index);
                  } else {
                    selectedHealthIndexes.add(index);
                  }
                });

                debugPrint("Selected: $selectedHealthIndexes");
              },
              child: SizedBox(
                width: 72 * scale,
                height: 52 * scale,
                child: _healthServiceCard(
                  scale: scale,
                  title: item['title'],
                  icon: item['icon'],
                  isDarkMode: isDarkMode,
                  isSelected: selectedHealthIndexes.contains(index),
                ),
              ),
            );
          },
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
    required double scale,
    required double itemHeight,
    required List<String> items,
    required bool isDarkMode,
  }) {
    return Column(
      children: [
        Container(
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

            separatorBuilder: (context, index) {
              return Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.withOpacity(0.2),
              );
            },

            itemBuilder: (context, index) {
              final isSelected = selectedIndex == index;

              return Container(
                height: itemHeight,
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? AppColors.secondaryColor.withOpacity(0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.only(
                    topLeft:
                        index == 0 ? const Radius.circular(12) : Radius.zero,

                    topRight:
                        index == 0 ? const Radius.circular(12) : Radius.zero,

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
                    onTap: () {
                      setState(() {
                        selectedIndex = index;
                      });
                    },

                    leading: CustomRadio(
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
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
        ),
      ],
    );
  }

  Widget _downloadedReportContainer({
    required int reportIndex,
    required double scale,
    required List<String> serviceType,
    required String timePeriod,
    required bool isDarkMode,
  }) {
    final isDownloading = isDownloadingMap[reportIndex] ?? false;
    final isDownloaded = isDownloadedMap[reportIndex] ?? false;
    final downloadProgress = downloadProgressMap[reportIndex] ?? 0.0;

    return InkWell(
      onTap: isDownloading ? null : () => _downloadReport(reportIndex),
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
                // ✅ Correct — wraps in a lambda
                onTap:
                    isDownloading ? null : () => _downloadReport(reportIndex),
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
}

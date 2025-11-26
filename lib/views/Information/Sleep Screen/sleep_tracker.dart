import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import '../../../Controllers/SleepScreen/sleep_controller.dart';
import '../../../Widgets/CommonWidgets/common_stat_graph_widget.dart';

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key});

  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen> {
  final SleepController controller = Get.find<SleepController>();

  TimeOfDay? selectedTime;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
    final double size = 210;
    final double center = size / 2;
    final double radius = center - 20;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: 'Sleep Tracker'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // ========== 1. MONITORING STATUS CARD (TOP) ==========
              Obx(
                () => AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  child: Material(
                    color:
                        controller.isMonitoring.value
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              controller.isMonitoring.value
                                  ? Colors.green.shade300
                                  : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Status Icon and Text
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      controller.isMonitoring.value
                                          ? Colors.green
                                          : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  controller.isMonitoring.value
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    controller.isMonitoring.value
                                        ? 'Monitoring Active'
                                        : 'Monitoring Inactive',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          controller.isMonitoring.value
                                              ? Colors.green.shade800
                                              : Colors.grey.shade700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    controller.isMonitoring.value
                                        ? 'Tracking your sleep pattern'
                                        : 'Start to track your sleep',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 20),

                          // Control Buttons
                          controller.isMonitoring.value
                              ? Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: controller.stopMonitoring,
                                      icon: Icon(Icons.stop, size: 18),
                                      label: Text('Stop'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          controller.calculateActualSleep,
                                      icon: Icon(Icons.calculate, size: 18),
                                      label: Text('Calculate'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: controller.startMonitoring,
                                  icon: Icon(Icons.play_arrow, size: 20),
                                  label: Text('Start Monitoring'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ========== 2. ADJUSTED BEDTIME CARD (BLUE) ==========
              Obx(
                () =>
                    controller.adjustedBedtime.value != null
                        ? Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Material(
                            color: Colors.blue.shade50,
                            elevation: 3,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade300,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Icon with animated glow effect
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.shade200,
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.bedtime_rounded,
                                      color: Colors.blue.shade700,
                                      size: 32,
                                    ),
                                  ),
                                  SizedBox(height: 12),

                                  // Title
                                  Text(
                                    'Adjusted Bedtime',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  SizedBox(height: 8),

                                  // Time Display
                                  Text(
                                    TimeOfDay.fromDateTime(
                                      controller.adjustedBedtime.value!,
                                    ).format(context),
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),

                                  // Additional Info
                                  Container(
                                    margin: EdgeInsets.only(top: 12),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 16,
                                          color: Colors.blue.shade700,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Based on your screen activity',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        : SizedBox.shrink(),
              ),

              const SizedBox(height: 20),

              //========== ORIGINAL CIRCULAR SLEEP INDICATOR ==========
              SizedBox(
                child: Stack(
                  children: [
                    for (int i = 1; i <= 12; i++)
                      Positioned(
                        left:
                            center +
                            radius * cos((i * 30 - 90) * pi / 180) +
                            10,
                        top:
                            center + radius * sin((i * 30 - 90) * pi / 180) + 5,
                        child: Text(
                          '$i',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    Obx(() {
                      final duration = controller.sleepDuration;
                      final totalSleepInMinutes = duration.inMinutes;
                      const maxSleepMinutes = 12 * 60;
                      final percent = (totalSleepInMinutes / maxSleepMinutes)
                          .clamp(0.0, 1.0);
                      final hours = duration.inHours;
                      final minutes = duration.inMinutes % 60;
                      String sleepLabel;
                      if (hours < 5) {
                        sleepLabel = "Low Sleep 😴";
                      } else if (hours < 7) {
                        sleepLabel = "Below Ideal 😐";
                      } else if (hours <= 9) {
                        sleepLabel = "Ideal Sleep";
                      } else if (hours <= 10.5) {
                        sleepLabel = "Oversleep 😴";
                      } else {
                        sleepLabel = "Heavy Sleep 😵";
                      }
                      return CircularPercentIndicator(
                        radius: 120,
                        lineWidth: 20,
                        percent: percent,
                        progressColor: AppColors.primaryColor,
                        backgroundColor: mediumGrey.withValues(alpha: 0.3),
                        circularStrokeCap: CircularStrokeCap.round,
                        center: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${hours}h ${minutes}min',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              sleepLabel,
                              style: TextStyle(fontSize: 14, color: mediumGrey),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ========== SLEEP PHASES INDICATOR ==========
              Stack(
                alignment: Alignment.center,
                children: [
                  Obx(() {
                    const idealSleepMinutes = 8 * 60;
                    final duration = controller.sleepDuration;
                    final totalSleepInMinutes = duration.inMinutes;
                    final idealPercent = (totalSleepInMinutes /
                            idealSleepMinutes)
                        .clamp(0.0, 1.0);
                    return LinearProgressIndicator(
                      value: idealPercent,
                      backgroundColor: mediumGrey.withValues(alpha: 0.3),
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      minHeight: 35,
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: width * 0.32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Image(
                                image: AssetImage(moonIcon),
                                height: 26,
                                width: 26,
                              ),
                              Text(
                                "2:30h",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: white,
                                ),
                              ),
                              Image(
                                image: AssetImage(bedIcon),
                                height: 26,
                                width: 26,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "2:30h",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: white,
                          ),
                        ),
                        SizedBox(
                          width: width * 0.32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Image(
                                image: AssetImage(dreamsIcon),
                                height: 26,
                                width: 26,
                              ),
                              Text(
                                "3:00h",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: white,
                                ),
                              ),
                              Image(
                                image: AssetImage(eyeIcon),
                                height: 26,
                                width: 26,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Sleep Phases",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 24),

              // ========== BEDTIME AND WAKE UP SETTINGS ==========
              Material(
                color: white,
                elevation: 3,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: mediumGrey, width: border04px),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Image(
                                image: AssetImage(bedtimeIcon),
                                height: 30,
                                width: 30,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "Bedtime",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Obx(
                                () => Text(
                                  controller.bedTime.value.format(context),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final TimeOfDay? picked =
                                      await showTimePicker(
                                        context: context,
                                        initialTime: controller.bedTime.value,
                                      );

                                  if (picked != null &&
                                      picked != controller.bedTime.value) {
                                    controller.bedTime.value = picked;
                                  }
                                },
                                icon: Icon(
                                  FontAwesomeIcons.angleRight,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(thickness: border04px, color: mediumGrey),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Image(
                                image: AssetImage(clockIcon),
                                height: 30,
                                width: 30,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "Wake Up",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Obx(
                                () => Text(
                                  controller.wakeupTime.value.format(context),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final TimeOfDay? picked =
                                      await showTimePicker(
                                        context: context,
                                        initialTime:
                                            controller.wakeupTime.value,
                                      );

                                  if (picked != null &&
                                      picked != controller.wakeupTime.value) {
                                    controller.wakeupTime.value = picked;
                                  }
                                },
                                icon: Icon(
                                  FontAwesomeIcons.angleRight,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Activity Log
              Obx(
                () =>
                    controller.isMonitoring.value &&
                            controller.activityLog.isNotEmpty
                        ? Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Material(
                            color: Colors.grey.shade50,
                            elevation: 3,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.list_alt,
                                          size: 20,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Activity Log',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                          Text(
                                            'Real-time tracking events',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Spacer(),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '${controller.activityLog.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),

                                  // Log List
                                  Container(
                                    constraints: BoxConstraints(maxHeight: 200),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: controller.activityLog.length,
                                      separatorBuilder:
                                          (context, index) => Divider(
                                            height: 1,
                                            color: Colors.grey.shade200,
                                          ),
                                      itemBuilder: (context, index) {
                                        final log =
                                            controller.activityLog[index];
                                        return Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Timeline Dot
                                              Container(
                                                margin: EdgeInsets.only(
                                                  top: 4,
                                                  right: 10,
                                                ),
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color:
                                                      index == 0
                                                          ? Colors.green
                                                          : Colors
                                                              .grey
                                                              .shade400,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              // Log Text
                                              Expanded(
                                                child: Text(
                                                  log,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        index == 0
                                                            ? Colors
                                                                .grey
                                                                .shade800
                                                            : Colors
                                                                .grey
                                                                .shade600,
                                                    fontWeight:
                                                        index == 0
                                                            ? FontWeight.w500
                                                            : FontWeight.normal,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        : SizedBox.shrink(),
              ),

              const SizedBox(height: 30),

              // ========== SLEEP STATISTICS GRAPH ==========
              SizedBox(
                height: 200,
                child: CommonStatGraphWidget(
                  isDarkMode: isDarkMode,
                  yAxisInterval: 2,
                  yAxisMaxValue: 11,
                  height: height,
                  graphTitle: 'Sleep Statistics',
                  points: [
                    FlSpot(0, 3),
                    FlSpot(1, 2.3),
                    FlSpot(2, 9),
                    FlSpot(3, 7),
                    FlSpot(4, 8),
                    FlSpot(5, 3),
                    FlSpot(6, 8),
                  ],
                  gridLineInterval: 2,
                  measureUnit: 'h',
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

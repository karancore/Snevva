import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/models/notification_permission.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import '../../../Controllers/SleepScreen/sleep_controller.dart';
import '../../../Widgets/CommonWidgets/common_stat_graph_widget.dart';
import '../../../Widgets/CommonWidgets/custom_outlined_button.dart';

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key});

  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen> {
  TimeOfDay? selectedTime;
  TimeOfDay? start = TimeOfDay.now();
  TimeOfDay? end = TimeOfDay.fromDateTime(
    DateTime.now().add(Duration(hours: 8)),
  );

  final SleepController sleepController = Get.put(SleepController());

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
                    CircularPercentIndicator(
                      radius: 120,
                      lineWidth: 20,
                      percent: 0.3,
                      progressColor: AppColors.primaryColor,
                      backgroundColor: mediumGrey.withValues(alpha: 0.3),
                      circularStrokeCap: CircularStrokeCap.round,
                      center: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${12}h ${21}min',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "Sleep",
                            style: TextStyle(fontSize: 14, color: mediumGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ========== SLEEP PHASES INDICATOR ==========
              Stack(
                alignment: Alignment.center,
                children: [
                  LinearProgressIndicator(
                    value: 58.0,
                    backgroundColor: mediumGrey.withValues(alpha: 0.3),
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    minHeight: 35,
                  ),
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
                              Text(
                                "13:00",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final TimeOfDay? bedtime =
                                      await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                      );
                                  final now = DateTime.now();
                                  final bed = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    bedtime!.hour,
                                    bedtime!.minute,
                                  );
                                  setState(() {
                                    start = bedtime;
                                  });
                                  sleepController.setBedtime(bed);
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
                              Text(
                                "5:00",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final TimeOfDay? wakeupTime =
                                      await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                      );
                                  final now = DateTime.now();
                                  final wakeup = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    wakeupTime!.hour,
                                    wakeupTime!.minute,
                                  );
                                  setState(() {
                                    end = wakeupTime;
                                  });
                                  sleepController.setWakeTime(wakeup);
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: CustomOutlinedButton(
          width: width,
          isDarkMode: isDarkMode,
          buttonName: "Save",
          onTap: () {},
        ),
      ),
    );
  }
}

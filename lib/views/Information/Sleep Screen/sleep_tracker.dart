import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/services/sleep_noticing_service.dart';
import '../../../Controllers/SleepScreen/sleep_controller.dart';
import '../../../Widgets/CommonWidgets/common_stat_graph_widget.dart';
import '../../../Widgets/CommonWidgets/custom_outlined_button.dart';
import '../../../common/global_variables.dart';

enum StatViewMode { weekly, monthly }

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key});

  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen> {
  final sleepService = SleepNoticingService();
  TimeOfDay? selectedTime;

  bool _isMonthlyView = false;
  DateTime _selectedMonth = DateTime.now();
  TimeOfDay? start = TimeOfDay.now();
  TimeOfDay? end = TimeOfDay.fromDateTime(
    DateTime.now().add(Duration(hours: 8)),
  );

  final SleepController sleepController = Get.put(SleepController());

  @override
  void initState() {
    super.initState(); // Always call super.initState() first!
    print("Init Sleep Tracker");
    sleepController.loadDeepSleepData();
  }

  Future<void> _pickTime(BuildContext context, bool isBedtime) async {
    final initial = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );

    if (picked == null) return;

    final now = DateTime.now();

    final dt = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );

    if (isBedtime) {
      sleepController.setBedtime(dt);
    } else {
      sleepController.setWakeTime(dt);
    }
  }

  String _fmt(DateTime dt) {
    int hour = dt.hour;
    String ampm = hour >= 12 ? "PM" : "AM";

    hour = hour % 12; // Convert 13–23 → 1–11
    if (hour == 0) hour = 12; // Convert 0 → 12

    String minute = dt.minute.toString().padLeft(2, '0');

    return "$hour:$minute $ampm";
  }

  double getDeepSleepPercent(Duration? duration) {
    if (duration == null) return 0.0;

    const maxDeepSleepMinutes = 120; // change this to your target
    double minutes = duration.inMinutes.toDouble();

    return (minutes / maxDeepSleepMinutes).clamp(0.0, 1.0);
  }

  void _toggleView() {
    setState(() {
      _isMonthlyView = !_isMonthlyView;
      if (_isMonthlyView) {
        // reset selected month maybe to now
        _selectedMonth = DateTime.now();
      }
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
        1,
      );
    });
  }

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
                      final deepSleep =
                          (sleepController.deepSleepDuration.value?.inMinutes ??
                                  0)
                              .toDouble();
                      final ideal =
                          (sleepController.idealWakeupDuration?.inMinutes ?? 1)
                              .toDouble();

                      final percent = (deepSleep / ideal).clamp(0.0, 1.0);

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
                              sleepController.deepSleepDuration.value == null
                                  ? "--"
                                  : fmtDuration(
                                    sleepController.deepSleepDuration.value!,
                                  ),
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
                    return LinearProgressIndicator(
                      value: getDeepSleepPercent(
                        sleepController.deepSleepDuration.value,
                      ),
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
              const SizedBox(height: 4),
              Obx(
                () => Text(
                  "Adjusted Bedtime: ${sleepController.newBedtime.value == null ? "--" : _fmt(sleepController.newBedtime.value!)}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ========== BEDTIME AND WAKE UP SETTINGS ==========
              Material(
                color: isDarkMode ? black : white,
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
                          Obx(
                            () => Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  _fmt(sleepController.bedtime.value!),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _pickTime(context, true),
                                  icon: Icon(
                                    FontAwesomeIcons.angleRight,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
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
                          Obx(
                            () => Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  _fmt(sleepController.waketime.value!),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _pickTime(context, false),
                                  icon: Icon(
                                    FontAwesomeIcons.angleRight,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isMonthlyView
                        ? "Monthly Sleep Report"
                        : "Weekly Sleep Report",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      if (_isMonthlyView) ...[
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => _changeMonth(-1),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: const TextStyle(fontSize: 14),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                      TextButton(
                        onPressed: _toggleView,
                        child: Text(
                          _isMonthlyView
                              ? "Switch to Weekly"
                              : "Switch to Monthly",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // const SizedBox(height: 10),
              //
              // // -------------------------
              // // Deep sleep duration
              // // -------------------------
              // Obx(
              //   () => Text(
              //     "Deep Sleep: ${sleepController.deepSleepDuration.value == null ? "--" : _fmtDuration(sleepController.deepSleepDuration.value!)}",
              //     style: const TextStyle(fontSize: 18, color: Colors.blue),
              //   ),
              // ),
              const SizedBox(height: 10),

              // ========== SLEEP STATISTICS GRAPH ==========
              SizedBox(
                height: height * 0.2,
                child: Obx(() {
                  final labels =
                      _isMonthlyView
                          ? sleepController.generateMonthLabels(_selectedMonth)
                          : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

                  final points =
                      _isMonthlyView
                          ? sleepController.getMonthlyDeepSleepSpots(
                            _selectedMonth,
                          )
                          : sleepController.deepSleepSpots.toList();
                  return CommonStatGraphWidget(
                    isDarkMode: isDarkMode,
                    yAxisInterval: 2,
                    yAxisMaxValue: 11,
                    height: height,
                    graphTitle: 'Sleep Statistics',
                    points: points,
                    isMonthlyView: _isMonthlyView,
                    gridLineInterval: 2,
                    weekLabels: labels,
                    measureUnit: 'h',
                    isSleepGraph: true,
                  );
                }),
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
          backgroundColor: AppColors.primaryColor,
          buttonName: "Save",
          onTap: () {
            // Check if bedtime and wake time are selected
            if (sleepController.bedtime.value != null &&
                sleepController.waketime.value != null) {
              sleepController.startMonitoring(); // START SERVICE

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Sleep Tracking Started",
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: AppColors.primaryColor,
                ),
              );
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Missing Data : Please select bedtime & wake time.",
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: AppColors.primaryColor,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

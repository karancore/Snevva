import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import '../../Controllers/SleepScreen/sleep_controller.dart';
import '../../Controllers/StepCounter/step_counter_controller.dart';
import '../../common/global_variables.dart';
import '../../common/statement_of_use_bottom_sheet.dart';
import '../../consts/consts.dart';
import '../../views/Information/HydrationScreens/hydration_screen.dart';
import '../../views/Information/Sleep Screen/sleep_bottom_sheet.dart';
import '../../views/Information/Sleep Screen/sleep_tracker.dart';
import '../../views/Information/StepCounter/step_counter.dart';
import '../../views/Information/StepCounter/step_counter_bottom_sheet.dart';
import '../../views/Information/vitals.dart';
import 'dashboard_container_widget.dart';

class DashboardServiceOverviewDynamicWidgets extends StatelessWidget {
  const DashboardServiceOverviewDynamicWidgets({
    super.key,
    required this.width,
    required this.height,
    required this.isDarkMode,
  });

  final double width;
  final double height;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final stepController = Get.find<StepCounterController>();
    final waterController = Get.find<HydrationStatController>();
    final vitalController = Get.find<VitalsController>();
    final sleepController = Get.put(SleepController());
    bool _loaded = false;

    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sleepController.loadDeepSleepData();
      });
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardContainerWidget(
                widgetName: 'Water',
                onTap: () {
                  Get.to(() => HydrationScreen());
                },
                widgetIcon: waterTrackingIcon,
                width: width,
                height: height,
                valueText: Obx(
                  () => RichText(
                    text: TextSpan(
                      text: '${waterController.waterIntake.value} ml',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color ??
                            Colors.black,
                      ),
                    ),
                  ),
                ),
                valuePraisingText: waterController.getHydrationStatus(
                  waterController.waterIntake.value,
                ),

                content: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Image.asset(
                        hydrationEleBottom,
                        height: 80,
                        width: width / 2.3,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 0,
                      left: 0,
                      bottom: 10,
                      child: Image.asset(
                        hydrationDashboardEle,
                        height: 150,
                        width: width / 4,
                      ),
                    ),
                  ],
                ),
                isDarkMode: isDarkMode,
              ),
            ),
            SizedBox(width: defaultSize - 10),
            Expanded(
              child: DashboardContainerWidget(
                isDarkMode: isDarkMode,
                widgetName: 'Heart',
                widgetIcon: vitalIcon,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final isFirstTime = prefs.getBool('isFirstTime') ?? true;

                  if (isFirstTime) {
                    final agreed = await showStatementsOfUseBottomSheet(
                      context,
                    );

                    if (agreed == true) {
                      await prefs.setBool('isFirstTime', false);
                      Get.to(VitalScreen());
                    }
                  } else {
                    Get.to(VitalScreen());
                  }
                },
                width: width,
                height: height,
                valueText: Obx(() {
                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${vitalController.bpm.value}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: ' BPM',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                valuePraisingText: vitalController.getBpmStatus(
                  vitalController.bpm.value,
                ),

                content: Padding(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 10,
                    bottom: 10,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Lottie.asset(
                        'assets/Dashboard/lhWa8wKgs5.json',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: defaultSize - 10),
        Row(
          children: [
            Expanded(
              child: DashboardContainerWidget(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final isGoalSet = prefs.getBool('isStepGoalSet') ?? false;

                  final stepController = Get.find<StepCounterController>();

                  if (!isGoalSet) {
                    final goal = await showStepCounterBottomSheet(
                      context,
                      isDarkMode,
                    );

                    if (goal != null) {
                      await prefs.setBool('isStepGoalSet', true);
                      await prefs.setInt('stepGoalValue', goal);

                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StepCounter(customGoal: goal),
                        ),
                      );

                      Future.microtask(() async {
                        await stepController.updateStepGoal(goal);
                      });
                    }
                  } else {
                    final goal = prefs.getInt('stepGoalValue') ?? 10000;

                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StepCounter(customGoal: goal),
                      ),
                    );
                  }
                },
                isDarkMode: isDarkMode,
                widgetName: 'Steps',
                widgetIcon: stepsTrackingIcon,
                width: width,
                height: height,
                valueText: Obx(() {
                  final steps = stepController.todaySteps.value;
                  return RichText(
                    text: TextSpan(
                      text: steps > -1 ? '$steps' : 'Loading...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color ??
                            Colors.black,
                      ),
                    ),
                  );
                }),
                content: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Image.asset(
                        stepsImgBottom,
                        height: 80,
                        width: width / 2.3,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 10,
                      child: Image.asset(
                        stepImg2,
                        height: 150,
                        width: width / 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: defaultSize - 10),
            Expanded(
              child: DashboardContainerWidget(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final isFirstSleep =
                      prefs.getBool('is_first_time_sleep') ?? true;

                  if (isFirstSleep) {
                    final agreed = await showSleepBottomSheetModal(
                      context: context,
                      isDarkMode: isDarkMode,
                      height: height,
                      isNavigating: true,
                    );

                    if (agreed == true) {
                      await prefs.setBool('is_first_time_sleep', false);
                      Get.to(() => SleepTrackerScreen());
                    }
                  } else {
                    Get.to(() => SleepTrackerScreen());
                  }
                },
                isDarkMode: isDarkMode,
                widgetName: 'Sleep',
                widgetIcon: sleepTrackerIcon,
                width: width,
                valueText: Obx(() {
                  final d = sleepController.deepSleepDuration.value;
                  return RichText(
                    text: TextSpan(
                      text: d == null ? "0h 00m" : fmtDuration(d),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color ??
                            Colors.black,
                      ),
                    ),
                  );
                }),
                valuePraisingText: sleepController.getSleepStatus(
                  sleepController.deepSleepDuration.value,
                ),
                height: height,
                content: Align(
                  alignment: Alignment.bottomCenter,
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Image.asset(
                          sleepEleBottom,
                          height: 80,
                          width: width / 2.3,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Image.asset(
                          sleepEle2,
                          height: 150,
                          width: width / 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

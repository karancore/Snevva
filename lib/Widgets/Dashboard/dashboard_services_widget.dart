import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/Widgets/Dashboard/dashboard_service_widget_items.dart';
import 'package:snevva/views/DietPlan/diet_plan_screen.dart';
import 'package:snevva/views/Information/BMI/bmi_cal.dart';
import 'package:snevva/views/Information/Health%20Tips/health_tips.dart';
import 'package:snevva/views/Information/StepCounter/step_counter_bottom_sheet.dart';
import 'package:snevva/views/Information/mental_wellness_screen.dart';
import 'package:snevva/views/MoodTracker/mood_tracker_screen.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import 'package:snevva/views/WomenHealth/women_health_screen.dart';
import '../../consts/consts.dart';
import '../../views/Information/HydrationScreens/hydration_screen.dart';
import '../../views/Information/Sleep Screen/sleep_bottom_sheet.dart';
import '../../views/Information/Sleep Screen/sleep_tracker.dart';
import '../../views/Information/StepCounter/step_counter.dart';
import '../../views/WomenHealth/women_bottom_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardServicesWidget extends StatefulWidget {
  const DashboardServicesWidget({super.key});

  @override
  State<DashboardServicesWidget> createState() =>
      _DashboardServicesWidgetState();
}

class _DashboardServicesWidgetState extends State<DashboardServicesWidget> {
  String? localGender;
  bool isLoading = true;
  String? selectedGender;
  String? gender;

  @override
  void initState() {
    super.initState();
    _loadGenderFromPreferences();
  }

  Future<void> _loadGenderFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final localGender = prefs.getString('user_gender');

    setState(() {
      // gender = localGender ?? 'Not Specified';
      final signInController = Get.put(SignInController());
      final userInfo = signInController.userProfData ?? {};
      final userData = userInfo['data'];
      gender = (localGender != null) ? localGender : userData['Gender'];
      print("Gender $gender");
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // final signInController = Get.find<SignInController>();
    // final userInfo = signInController.userProfData ?? {};
    // final userData = userInfo['data'];

    final localstorage = Get.find<LocalStorageManager>();
    final userInfo = localstorage.userMap;
    print('userInfo: $userInfo');

    // final userActiveData = signInController.userGoalData ?? {};

    final userActiveData = localstorage.userGoalDataMap;
    print('userActiveData: $userActiveData');
    final womentracking = userActiveData['TrackWomenData'];
    final stepgoal = userActiveData['StepGoalData']?['Count'];
    final SleepGoalData = userActiveData['SleepGoalData'];

    print('userActiveData: $userActiveData');
    // Safe check for userData and gender
    // final gender = selectedGender ?? localgender ?? 'Unknown';
    // gender = (localGender != null) ? localGender : userData['Gender'];

    print('User Gender: $gender');
    // print(userInfo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Health',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // DashboardServiceWidgetItems(
            //   widgetText: 'AI Chat',
            //   widgetImg: aiChatIcon,
            //   onTap: () {
            //     Get.to(() => SnevvaAIChatScreen());
            //   },
            // ),
            // DashboardServiceWidgetItems(
            //   widgetText: 'Report Scan',
            //   widgetImg: aiSymptomIcon,
            //   onTap: () {
            //     Get.to(() => ScanReportScreen());
            //   },
            // ),
            DashboardServiceWidgetItems(
              widgetText: 'Steps Count',
              widgetImg: stepsTrackingIcon,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final isGoalSet = prefs.getBool('isStepGoalSet') ?? false;

                if (stepgoal == null || !isGoalSet) {
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
            ),

            // DashboardServiceWidgetItems(
            //   widgetText: 'Steps Count',
            //   widgetImg: stepsTrackingIcon,
            //   onTap: () {
            //     showStepCounterBottomSheet(context, isDarkMode,);
            //   },
            // ),
            DashboardServiceWidgetItems(
              widgetText: 'Hydration',
              widgetImg: waterTrackingIcon,
              onTap: () {
                Get.to(() => HydrationScreen());
              },
            ),
            DashboardServiceWidgetItems(
              widgetText: 'Diet Plan',
              widgetImg: dietPlanIcon,
              onTap: () {
                Get.to(() => DietPlanScreen());
              },
            ),
            // DashboardServiceWidgetItems(
            //   widgetText: 'Add Reminder',
            //   widgetImg: reminderIcon,
            //   onTap: () {
            //     Get.to(() => Reminder());
            //   },
            // ),
            DashboardServiceWidgetItems(
              widgetText: 'Mood Tracker',
              widgetImg: moodIcon,
              onTap: () {
                Get.to(() => MoodTrackerScreen());
              },
            ),
          ],
        ),
        // SizedBox(height: 20),
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceAround,
        //   children: [
        //
        //     // DashboardServiceWidgetItems(
        //     //   widgetText: 'Vital Tracker',
        //     //   widgetImg: vitalIcon,
        //     //   onTap: () {},
        //     // ),
        //
        //     // DashboardServiceWidgetItems(
        //     //   widgetText: 'Book Doctor',
        //     //   widgetImg: bookDocIcon,
        //     //   onTap: () {
        //     //     Get.to(() => DoctorScreen());
        //     //   },
        //     // ),
        //   ],
        // ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            DashboardServiceWidgetItems(
              widgetText: 'Sleep Tracker',
              widgetImg: sleepTrackerIcon,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final isFirstSleep =
                    prefs.getBool('is_first_time_sleep') ?? false;

                if (isFirstSleep || SleepGoalData == null) {
                  final agreed = await showSleepBottomSheetModal(
                    context: context,
                    isDarkMode: isDarkMode,
                    height: height,
                    isNavigating: true,
                  );

                  if (agreed == true) {
                    Get.to(() => SleepTrackerScreen());
                  }
                } else {
                  // Not first time, go directly
                  Get.to(() => SleepTrackerScreen());
                }
              },
            ),
            DashboardServiceWidgetItems(
              widgetText: 'Mental Wellness',
              widgetImg: mentalWellIcon,
              onTap: () {
                Get.to(() => MentalWellnessScreen());
              },
            ),
            DashboardServiceWidgetItems(
              widgetText: 'Health Tips',
              widgetImg: tipsIcon,
              onTap: () {
                Get.to(() => HealthTipsScreen());
              },
            ),
            if (gender == 'Female')
              DashboardServiceWidgetItems(
                widgetText: 'Women Health',
                widgetImg: womenIcon,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final isFirstWomen =
                      prefs.getBool('is_first_time_women') ?? true;

                  if (womentracking == false ||
                      womentracking == null ||
                      isFirstWomen) {
                    final agreed = await showWomenBottomSheetsModal(
                      context,
                      isDarkMode,
                      width,
                      height,
                    );

                    if (agreed == true) {
                      // 🚫 DO NOT change flag here
                      Get.to(() => WomenHealthScreen());
                    }
                  } else {
                    Get.to(() => WomenHealthScreen());
                  }
                },
              ),

            if (gender != 'Female')
              DashboardServiceWidgetItems(
                widgetText: 'BMI Calculator',
                widgetImg: bmiIcon,
                onTap: () {
                  Get.to(() => BmiCal());
                },
              ),
          ],
        ),
        SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // DashboardServiceWidgetItems(
            //   widgetText: 'Calorie Counter',
            //   widgetImg: calorieIcon,
            //   onTap: () {},
            // ),
            // DashboardServiceWidgetItems(
            //   widgetText: 'Check BMI',
            //   widgetImg: bmiIcon,
            //   onTap: () {
            //     Get.to(() => BmiCal());
            //   },
            // ),

            //SizedBox(height: 80, width: 55),
          ],
        ),
        //   SizedBox(height: 20),
      ],
    );
  }
}

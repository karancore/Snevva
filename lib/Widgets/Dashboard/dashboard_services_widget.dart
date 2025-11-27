import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/Widgets/Dashboard/dashboard_service_widget_items.dart';
import 'package:snevva/views/DietPlan/diet_plan_screen.dart';
import 'package:snevva/views/Information/BMI/bmi_cal.dart';
import 'package:snevva/views/Information/Health%20Tips/health_tips.dart';
import 'package:snevva/views/Information/StepCounter/step_counter_bottom_sheet.dart';
import 'package:snevva/views/Information/mental_wellness_screen.dart';
import 'package:snevva/views/MoodTracker/mood_tracker_screen.dart';
import '../../consts/consts.dart';
import '../../views/Information/HydrationScreens/hydration_screen.dart';
import '../../views/Information/Sleep Screen/sleep_bottom_sheet.dart';
import '../../views/Information/StepCounter/step_counter.dart';
import '../../views/WomenHealth/women_bottom_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardServicesWidget extends StatefulWidget {
  const DashboardServicesWidget({super.key});

  @override
  _DashboardServicesWidgetState createState() =>
      _DashboardServicesWidgetState();
}

class _DashboardServicesWidgetState extends State<DashboardServicesWidget> {
  String? localgender;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGenderFromPreferences();
  }

  Future<void> _loadGenderFromPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      localgender = prefs.getString('user_gender');
      isLoading = false; // Set loading to false once data is loaded
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    final signInController = Get.find<SignInController>();
    final userInfo = signInController.userProfData ?? {};
    final userData = userInfo['data'];

    // Safe check for userData and gender
    final gender =
        (userData != null && userData['Gender'] != null)
            ? userData['Gender']
            : localgender ??
                'Not Specified'; // Fallback to localgender or default value

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
                  print("🔵 Step 1: Widget tapped");
                  final prefs = await SharedPreferences.getInstance();
                  final isGoalSet = prefs.getBool('isStepGoalSet') ?? false;
                  print("🔵 Step 2: isGoalSet = $isGoalSet");

                  final stepController = Get.find<StepCounterController>();

                  if (!isGoalSet) {
                    print("🔵 Step 3: Showing bottom sheet");

                    final goal = await showStepCounterBottomSheet(
                      context,
                      isDarkMode,
                    );

                    print("🔵 Step 4: Bottom sheet returned goal = $goal");

                    if (goal != null) {
                      await prefs.setBool('isStepGoalSet', true);
                      await prefs.setInt('stepGoalValue', goal);

                      print("🔵 Step 5: Navigate FIRST");

                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StepCounter(customGoal: goal),
                        ),
                      );

                      print("🔵 Step 6: Now update goal in BACKGROUND (safe)");

                      Future.microtask(() async {
                        await stepController.updateStepGoal(goal);
                      });
                    }
                  } else {
                    final goal = prefs.getInt('stepGoalValue') ?? 10000;

                    print("🔵 Context mounted: ${context.mounted}");

                    if (!context.mounted) return;

                    print("🔵 Navigating immediately");

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StepCounter(customGoal: goal),
                      ),
                    );
                  }
                }

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
              onTap: () {
                showSleepBottomSheetModal(context, isDarkMode, height);
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
                onTap: () {
                  showWomenBottomSheetsModal(
                    context,
                    isDarkMode,
                    width,
                    height,
                  );
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

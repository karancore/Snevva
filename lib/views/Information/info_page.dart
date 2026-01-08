import 'package:snevva/Controllers/signupAndSignIn/sign_in_controller.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Chat/snevva_ai_chat_screen.dart';
import 'package:snevva/views/DietPlan/diet_plan_screen.dart';
import 'package:snevva/views/Information/BMI/bmi_cal.dart';
import 'package:snevva/views/Information/HydrationScreens/hydration_screen.dart';
import 'package:snevva/views/Information/Health%20Tips/health_tips.dart';
import 'package:snevva/views/Information/Sleep%20Screen/sleep_bottom_sheet.dart';
import 'package:snevva/views/Information/StepCounter/step_counter.dart';
import 'package:snevva/views/Information/StepCounter/step_counter_bottom_sheet.dart';
import 'package:snevva/views/Information/vitals.dart';
import 'package:snevva/views/MoodTracker/mood_tracker_screen.dart';
import 'package:snevva/views/Reminder/reminder_screen.dart';
import 'package:snevva/views/Information/mental_wellness_screen.dart';
import 'package:get/get.dart';
import 'package:snevva/views/WomenHealth/women_health_screen.dart';
import '../../Controllers/StepCounter/step_counter_controller.dart';
import '../../Widgets/CommonWidgets/custom_appbar.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../Widgets/menu_item_widget.dart';
import '../../common/statement_of_use_bottom_sheet.dart';
import '../WomenHealth/women_bottom_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Sleep Screen/sleep_tracker.dart';

class InfoPage extends StatefulWidget {
  final Function(int)? onTabSelected;

  const InfoPage({super.key, this.onTabSelected});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {
  String? gender;
  bool isLoading = true;

  late AnimationController listAnimationController;
  late List<Animation<Offset>> _slideAnimation;

  late final List<MenuItem> menuItems;
  List<MenuItem> filteredMenuItems = [];

  @override
  void initState() {
    super.initState();
    _loadGenderAndInit();
  }

  Future<void> _loadGenderAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    final localGender = prefs.getString('user_gender');

    setState(() {
      // gender = localGender ?? 'Not Specified';
      final signInController = Get.find<SignInController>();
      final userInfo = signInController.userProfData ?? {};
      final userData = userInfo['data'];
      gender = (localGender != null) ? localGender : userData['Gender'];
      isLoading = false;
    });

    _initializeMenuItems();
    _initializeAnimations();
  }

  void _initializeMenuItems() {
    menuItems = [
      MenuItem(
        title: "Sleep Tracker",
        subtitle: "Monitors sleep patterns",
        imagePath: sleepTrackerIcon,
      ),
      MenuItem(
        title: "Hydration",
        subtitle: "Water intake tracker",
        imagePath: waterTrackingIcon,
        navigateTo: HydrationScreen(),
      ),
      MenuItem(
        title: "Mood Tracker",
        subtitle: "Logs daily mood",
        imagePath: moodIcon,
        navigateTo: MoodTrackerScreen(),
      ),
      MenuItem(
        title: "Add A Reminder",
        subtitle: "Medication, meal, hydration alert",
        imagePath: reminderIcon,
        navigateTo: ReminderScreen(),
      ),
      MenuItem(
        title: "Steps Tracker",
        subtitle: "Tracks daily steps",
        imagePath: stepsTrackingIcon,
      ),
      MenuItem(
        title: "BMI Calculator",
        subtitle: "Calculates body mass index",
        imagePath: bmiIcon,
        navigateTo: BmiCal(),
      ),
      MenuItem(
        title: "Vital Monitor",
        subtitle: "Heart rate, SpO₂ tracking",
        imagePath: vitalIcon,
      ),
      MenuItem(
        title: "Mental Wellness",
        subtitle: "Music or therapy support",
        imagePath: mentalWellIcon,
        navigateTo: MentalWellnessScreen(),
      ),
      MenuItem(
        title: "Health Tips",
        subtitle: "Daily health tips",
        imagePath: tipsIcon,
        navigateTo: HealthTipsScreen(),
      ),
      MenuItem(
        title: "Chat With Elly",
        subtitle: "Virtual health companion",
        imagePath: aiChatIcon,
        navigateTo: SnevvaAIChatScreen(),
      ),
      MenuItem(
        title: "AI Symptom Checker",
        subtitle: "AI-based symptom analysis",
        imagePath: aiSymptomIcon,
        isDisabled: true,
      ),
      MenuItem(
        title: "Women's Health",
        subtitle: "Menstrual and pregnancy tracker",
        imagePath: womenIcon,
      ),
      // MenuItem(
      //   title: "Calorie Counter",
      //   subtitle: "Scan food, get calories",
      //   imagePath: calorieIcon,
      // ),
      MenuItem(
        title: "Diet Plan",
        subtitle: "Personalized meal guidance",
        imagePath: dietPlanIcon,
        navigateTo: DietPlanScreen(),
      ),
    ];

    // Filter items based on gender
    filteredMenuItems =
        menuItems.where((item) {
          if (item.title == "Women's Health" && gender != 'Female') {
            return false;
          }
          return true;
        }).toList();
  }

  void _initializeAnimations() {
    listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _slideAnimation = List.generate(filteredMenuItems.length, (index) {
      final start = index * 0.07;
      final end = start + 0.3;
      return Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: listAnimationController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    listAnimationController.forward();
  }

  @override
  void dispose() {
    listAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mediaQuery = MediaQuery.of(
      context,
    ); // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;

    // Map items to sections dynamically
    final sections = <String, List<MenuItem>>{
      "Wellness & Lifestyle Tracking":
          filteredMenuItems
              .where(
                (item) => [
                  "Sleep Tracker",
                  "Hydration",
                  "Mood Tracker",
                  "Add A Reminder",
                  "Steps Tracker",
                ].contains(item.title),
              )
              .toList(),
      "Vital Monitoring":
          filteredMenuItems
              .where(
                (item) =>
                    ["BMI Calculator", "Vital Monitor"].contains(item.title),
              )
              .toList(),
      "Mental Health & Wellness":
          filteredMenuItems
              .where(
                (item) =>
                    ["Mental Wellness", "Health Tips"].contains(item.title),
              )
              .toList(),
      "Medical Support & Diagnosis":
          filteredMenuItems
              .where(
                (item) => [
                  "Chat With Elly",
                  "AI Symptom Checker",
                ].contains(item.title),
              )
              .toList(),
      "Women's Health":
          filteredMenuItems
              .where((item) => item.title == "Women's Health")
              .toList(),
      "Nutrition & Diet":
          filteredMenuItems
              .where((item) => ["Diet Plan"].contains(item.title))
              .toList(),
    };

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Services", showCloseButton: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              sections.entries
                  .where((e) => e.value.isNotEmpty)
                  .map(
                    (entry) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(entry.key),
                        _buildMenuGrid(
                          context,
                          entry.value,
                          filteredMenuItems,
                          _slideAnimation,
                          isDarkMode,
                          height,
                          width,
                        ),
                      ],
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
    ),
  );
}

Widget _buildMenuGrid(
  BuildContext context,
  List<MenuItem> items,
  List<MenuItem> allFilteredItems,
  List<Animation<Offset>> slideAnimations,
  bool isDarkMode,
  double height,
  double width,
) {
  return Column(
    children: List.generate(items.length, (index) {
      final item = items[index];
      final animationIndex = allFilteredItems.indexOf(item);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SlideTransition(
          position: slideAnimations[animationIndex],
          child: MenuItemWidget(
            title: item.title,
            subtitle: item.subtitle,
            imagePath: item.imagePath,
            isDarkMode: isDarkMode,
            onTap: () async {
              print("Tapped on: ${item.title}");

              // Handle Vital Monitor
              if (item.title == "Vital Monitor") {
                final prefs = await SharedPreferences.getInstance();
                final isFirstTime = prefs.getBool('isFirstTime') ?? true;

                if (isFirstTime) {
                  final agreed = await showStatementsOfUseBottomSheet(context);

                  if (agreed == true) {
                    await prefs.setBool('isFirstTime', false);
                    Get.to(() => VitalScreen());
                  }
                } else {
                  Get.to(() => VitalScreen());
                }
              }
              // Handle Sleep Tracker
              else if (item.title == "Sleep Tracker") {
                final prefs = await SharedPreferences.getInstance();
                final isFirstTime =
                    prefs.getBool('is_first_time_sleep') ?? true;

                if (isFirstTime) {
                  final agreed = await showSleepBottomSheetModal(
                    context: context,
                    isDarkMode: isDarkMode,
                    height: height,
                    isNavigating: false,
                  );

                  if (agreed == true) {
                    await prefs.setBool('is_first_time_sleep', false);
                    Get.to(() => SleepTrackerScreen());
                  }
                } else {
                  Get.to(() => SleepTrackerScreen());
                }
              }
              // Handle Steps Tracker
              else if (item.title == "Steps Tracker") {
                final prefs = await SharedPreferences.getInstance();
                final isGoalSet = prefs.getBool('isStepGoalSet') ?? false;

                if (!isGoalSet) {
                  final goal = await showStepCounterBottomSheet(
                    context,
                    isDarkMode,
                  );

                  if (goal != null) {
                    await prefs.setBool('isStepGoalSet', true);
                    await prefs.setInt('stepGoalValue', goal);

                    try {
                      final stepController = Get.find<StepCounterController>();
                      await stepController.updateStepGoal(goal);
                    } catch (e) {
                      print("StepCounterController not found: $e");
                    }

                    Get.to(() => StepCounter(customGoal: goal));
                  }
                } else {
                  final goal = prefs.getInt('stepGoalValue') ?? 10000;
                  Get.to(() => StepCounter(customGoal: goal));
                }
              }
              // Handle Women's Health
              else if (item.title == "Women's Health") {
                final prefs = await SharedPreferences.getInstance();
                final isFirstWomen =
                    prefs.getBool('is_first_time_women') ?? true;

                if (isFirstWomen) {
                  final agreed = await showWomenBottomSheetsModal(
                    context,
                    isDarkMode,
                    width,
                    height,
                  );

                  if (agreed == true) {
                    await prefs.setBool(
                      'is_first_time_women',
                      false,
                    ); // mark as seen
                    Get.to(() => WomenHealthScreen());
                  }
                } else {
                  // Not first time, go directly
                  Get.to(() => WomenHealthScreen());
                }
              }
              // Handle Calorie Counter
              else if (item.title == "Calorie Counter") {
                print("Calorie Counter tapped - implement navigation");
                // TODO: Add calorie counter navigation
              }
              // Handle items with navigateTo
              else if (item.navigateTo != null) {
                Get.to(() => item.navigateTo!);
              }
              // Handle items with onTap callback
              else if (item.onTap != null) {
                item.onTap!();
              }
            },
          ),
        ),
      );
    }),
  );
}

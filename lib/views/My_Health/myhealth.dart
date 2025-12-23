import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/BMI/bmicontroller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/views/Information/BMI/bmi_result.dart';
import 'package:snevva/views/Information/HydrationScreens/hydration_screen.dart';
import 'package:snevva/views/Information/StepCounter/step_counter.dart';
import 'package:snevva/views/Information/vitals.dart';
import 'package:snevva/views/MoodTracker/mood_tracker_screen.dart';
import 'package:snevva/views/WomenHealth/women_health_screen.dart';
import '../../Controllers/Hydration/hydration_stat_controller.dart';
import '../../Controllers/StepCounter/step_counter_controller.dart';
import '../../Controllers/signupAndSignIn/sign_in_controller.dart';

class MyHealthScreen extends StatefulWidget {
  const MyHealthScreen({super.key});

  @override
  State<MyHealthScreen> createState() => _MyHealthScreenState();
}

class _MyHealthScreenState extends State<MyHealthScreen>
    with SingleTickerProviderStateMixin {
  final stepController = Get.find<StepCounterController>();
  final waterController = Get.find<HydrationStatController>();
  final moodController = Get.find<MoodController>();

  String? localGender;
  String? gender;
  bool isLoading = true;
  final vitalcontroller = Get.find<VitalsController>();
  final bmiController = Get.put(Bmicontroller());
  final womenController = Get.put(WomenHealthController());
  final localStorageManager = Get.put(LocalStorageManager());

  final HydrationStatController c = Get.find();

  late AnimationController _listAnimationController;
  late final List<TrackerHealthCard> vitalItems;
  List<TrackerHealthCard> filteredVitalItems = [];
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _loadMoodFromPrefs();
    bmiController.loadUserBMI();
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
    gender =
        (userData != null && userData['Gender'] != null)
            ? userData['Gender']
            : '';
    });

    _initializeVitalItems();
    _initAnimations();
  }

  Future<void> _loadMoodFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMood = prefs.getString('selectedMood');
    if (savedMood != null) {
      final index = moodController.moods.indexOf(savedMood);
      if (index != -1) {
        moodController.selectedMoodIndex.value = index;
        moodController.selectedMood.value = savedMood;
      }
    }
  }

  void _initializeVitalItems() {
    vitalItems = [
      // Tracker Cards
      TrackerHealthCard(
        icon: Icons.water_drop,
        iconColor: Colors.lightBlue,
        cardType: "water",
        title: Obx(
          () => Text(
            '${waterController.waterIntake.value}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ),
        subtitle: Obx(
          () => Text(
            '/ ${waterController.waterGoal.value} ml',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        buttonText: 'Add water',
        onPressed: () => Get.to(() => const HydrationScreen()),
      ),
      TrackerHealthCard(
        icon: Icons.directions_walk,
        cardType: "steps",
        iconColor: Colors.grey,
        title: Obx(
          () => Text(
            '${stepController.todaySteps.value}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ),
        subtitle: Obx(
          () => Text(
            '/ ${stepController.stepGoal.value} steps',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        buttonText: 'Track steps',
        onPressed: () => Get.to(() => const StepCounter()),
      ),
      TrackerHealthCard.noSubtitle(
        icon: Icons.tag_faces,
        cardType: "mood",
        iconColor: Colors.redAccent,
        title: Obx(
          () => Text(
            moodController.selectedMoodIndex.value == -1
                ? 'Happy'
                : moodController.moods[moodController.selectedMoodIndex.value],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        buttonText: 'Track mood',
        onPressed: () => Get.to(() => const MoodTrackerScreen()),
      ),

      // Health Cards
      TrackerHealthCard(
        icon: Icons.favorite,
        iconColor: Colors.red,
        cardType: "bpm",
        title: Obx(
          () => Text(
            '${vitalcontroller.bpm.value}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ),
        subtitle: const Text(
          '/bpm',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        buttonText: 'Add BPM',
        onPressed: () => Get.to(() => VitalScreen()),
      ),
      TrackerHealthCard(
        icon: Icons.accessibility,
        iconColor: Colors.lightBlueAccent,
        cardType: "bmi",
        title: Obx(
          () => Text(
            '${bmiController.bmi.value}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ),
        subtitle: Text(
          bmiController.bmi_text.value,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
        buttonText: 'BMI Result',
        onPressed:
            () => Get.to(
              () => BmiResultPage(bmi: bmiController.bmi.value, age: 24),
            ),
      ),
      TrackerHealthCard(
        icon: Icons.opacity,
        iconColor: Colors.deepOrangeAccent,
        cardType: "sys",
        title: Obx(
          () => Text(
            '${vitalcontroller.sys.value}/${vitalcontroller.dia.value}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ),
        subtitle: const Text(
          'mmHg',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        buttonText: 'Add Vitals',
        onPressed: () => Get.to(() => VitalScreen()),
      ),
      TrackerHealthCard(
        icon: Icons.female,
        cardType: "women",
        iconColor: Colors.pink,
        title: Obx(
          () => Text(
            womenController.nextPeriodDay.value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ),
        buttonText: 'Add Data',
        onPressed: () => Get.to(WomenHealthScreen()),
      ),
    ];

    // Filter items based on gender
    filteredVitalItems =
        vitalItems.where((item) {
          if (item.buttonText == "Add Data" &&
              item.cardType == "women" &&
              gender != 'Female')
            return false;
          return true;
        }).toList();
  }

  void _initAnimations() async {
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Tracker(3) + Health(3)
    _slideAnimations = List.generate(filteredVitalItems.length, (index) {
      final start = index * 0.1;
      final end = start + 0.4;
      return Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _listAnimationController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    _listAnimationController.forward();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = <String, List<TrackerHealthCard>>{
      "Tracker":
          filteredVitalItems
              .where(
                (item) => [
                  "Add water",
                  "Track steps",
                  "Track mood",
                ].contains(item.buttonText),
              )
              .toList(),

      "Health":
          filteredVitalItems
              .where(
                (item) => [
                  "Add BPM",
                  "BMI Result",
                  "Add Vitals",
                  "Add Data",
                ].contains(item.buttonText),
              )
              .toList(),
    };

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(
        appbarText: 'My Health',
        showCloseButton: false,
        showDrawerIcon: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                sections.entries
                    .where((entry) => entry.value.isNotEmpty)
                    .map(
                      (entry) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Title
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Cards inside the section
                          ...List.generate(
                            entry.value.length,
                            (index) => SlideTransition(
                              position:
                                  _slideAnimations[filteredVitalItems.indexOf(
                                    entry.value[index],
                                  )],
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: entry.value[index],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    );
  }
}

class TrackerHealthCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Widget title;
  final Widget? subtitle;
  final String buttonText;
  final String cardType;

  final VoidCallback? onPressed;

  const TrackerHealthCard({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.buttonText,
    required this.cardType,
    required this.onPressed,
  }) : super(key: key);

  const TrackerHealthCard.noSubtitle({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.buttonText,
    required this.cardType,
    required this.onPressed,
  }) : subtitle = null,
       super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.2),
            radius: 20,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                title,
                if (subtitle != null) ...[
                  const SizedBox(width: 4),
                  Flexible(child: subtitle!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

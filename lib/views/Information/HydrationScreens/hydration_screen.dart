import 'package:snevva/views/Information/HydrationScreens/hydration_bottom_sheet.dart';
import 'package:snevva/views/Information/StepCounter/step_counter_bottom_sheet.dart';
import 'package:snevva/views/Reminder/reminder.dart';
import 'package:wheel_picker/wheel_picker.dart';
import '../../../../Widgets/CommonWidgets/custom_appbar.dart';
import '../../../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../../../consts/consts.dart';
import '../../../Controllers/Hydration/hydration_stat_controller.dart';
import '../../../Widgets/Hydration/floating_button_bar.dart';
import 'hydration_statistics.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen>
    with SingleTickerProviderStateMixin {
  final WheelPickerController wheel = WheelPickerController(itemCount: 90);
  final HydrationStatController controller = Get.find<HydrationStatController>();

  late final AnimationController animationController;
  late Animation<double> numberAnimation;
  late final Worker intakeWorker;
  double lastValue = 0.0;

  // Cooldown Timer
  int lastPressTime = 0;
  final int cooldownTime = 2000; // 2-second cooldown

  @override
  void initState() {
    super.initState();
    controller.loadWaterIntake();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    lastValue = controller.waterIntake.value.toDouble();
    numberAnimation = Tween<double>(begin: 0.0, end: lastValue)
        .animate(animationController);
    animationController.forward();

    intakeWorker = ever<double>(controller.waterIntake, (newValue) {
      _animateTo(newValue);
    });
  }

  void _animateTo(double newValue) {
    if (newValue == lastValue) return;

    numberAnimation = Tween<double>(
      begin: numberAnimation.value,
      end: newValue,
    ).animate(animationController);

    animationController
      ..reset()
      ..forward();

    lastValue = newValue;
  }

  @override
  void dispose() {
    animationController.dispose();
    intakeWorker.dispose();
    super.dispose();
  }

  /// ✅ Cooldown-protected Add Water Button
  void _onAddButtonPressed() {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - lastPressTime < cooldownTime) {
      _showCooldownWarning();
      return;
    }

    controller.waterIntake.value += controller.addWaterValue.value;
    controller.saveWaterRecord(controller.addWaterValue.value);
    controller.saveWaterIntakeLocally();

    lastPressTime = currentTime;
  }

  void _showCooldownWarning() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Slow Down!"),
        content: const Text(
          "You're adding water too quickly. Please take a short break to stay safe.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Okay"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: const CustomAppBar(appbarText: 'Hydration'),

      /// ✅ Floating Button Bar
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Obx(
              () => FloatingButtonBar(
            onStatBtnTap: () => Get.to(() => const HydrationStatistics()),
            onReminderBtnTap: () => Get.to(() => const Reminder()),
            onAddBtnTap: _onAddButtonPressed,
            onAddBtnLongTap: () =>
                showHydrationBottomSheetModal(context, isDarkMode, height),
            addWaterValue: controller.addWaterValue.value,
          ),
        ),
      ),

      /// ✅ Main Body
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: SingleChildScrollView(
          child: Column(
            children: [
              /// 💧 Animated Intake Number
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedBuilder(
                    animation: numberAnimation,
                    builder: (context, child) => Text(
                      "${numberAnimation.value.toInt()}",
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'ml',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              Text(
                'Wow, keep going!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500 , color: grey ),
              ),
              const SizedBox(height: 10),

              /// 🎯 Water Goal Display & Update Button
              Obx(
                    () => Column(
                  children: [
                    Text(
                      "Daily Goal: ${controller.waterGoal.value} ml",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit, size: 18 , color: white,),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      label: const Text("Update Water Goal" , style: TextStyle(color: white),),
                      onPressed: () async {
                        await showModalBottomSheet<int>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (_) => StepCounterBottomSheet(
                            unit: "ml",
                            image: "assets/Images/Water/water-glass.svg",
                            heading: "Set your daily water goal",
                            subHeading: "Keep your body hydrated!",
                            multiplier: 250,
                            initialIndex:
                            (controller.waterGoal.value ~/ 250) - 1,
                            onConfirm: (value) async {
                              await controller.updateWaterGoal(value);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              /// 💦 Decorative Hydration Image
              Image.asset(
                hydrationEle,
                height: height * 0.45,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ Optional helper: Show a reusable bottom sheet for water goal
Future<int?> showWaterGoalBottomSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => StepCounterBottomSheet(
      unit: "ml",
      image: "assets/Images/Water/water.svg",
      heading: "Set your daily water goal",
      subHeading: "Keep your body hydrated!",
      multiplier: 250,
      initialIndex: 7, // Default = 2000ml
      onConfirm: (value) {
        print("Water goal set to $value ml");
      },
    ),
  );
}

import 'package:snevva/views/Information/HydrationScreens/hydration_bottom_sheet.dart';
import 'package:snevva/views/Information/HydrationScreens/water_bottom_sheet.dart';
import 'package:snevva/views/Information/StepCounter/step_counter_bottom_sheet.dart';
import 'package:snevva/views/Reminder/reminder_screen.dart';
import 'package:snevva/widgets/Hydration/floating_button_bar.dart';
import 'package:wheel_picker/wheel_picker.dart';
import '../../../../Widgets/CommonWidgets/custom_appbar.dart';
import '../../../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../../../consts/consts.dart';
import '../../../Controllers/Hydration/hydration_stat_controller.dart';
import 'hydration_statistics.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen>
    with SingleTickerProviderStateMixin {
  final WheelPickerController wheel = WheelPickerController(itemCount: 90);
  final HydrationStatController controller =
      Get.find<HydrationStatController>();

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
    // controller.loadWaterIntake();
    controller.loadWaterIntakefromAPI(
      month: DateTime.now().month,
      year: DateTime.now().year,
    );

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    lastValue = controller.waterIntake.value.toDouble();
    numberAnimation = Tween<double>(
      begin: 0.0,
      end: lastValue,
    ).animate(animationController);
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

  void _onAddButtonPressed() {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - lastPressTime < cooldownTime) {
      _showCooldownWarning();
      return;
    }

    controller.waterIntake.value += controller.addWaterValue.value;
    //controller.addWaterToToday(controller.addWaterValue.value);

    controller.saveWaterRecord(controller.addWaterValue.value, context);
    controller.saveWaterIntakeLocally();

    lastPressTime = currentTime;
  }

  void _showCooldownWarning() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
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

  double hp(BuildContext context, double percent) =>
      MediaQuery.of(context).size.height * percent;

  double wp(BuildContext context, double percent) =>
      MediaQuery.of(context).size.width * percent;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: Drawer(
        child: DrawerMenuWidget(height: height, width: wp(context, 1)),
      ),
      appBar: const CustomAppBar(appbarText: 'Hydration'),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wp(context, 0.05),
          vertical: hp(context, 0.015),
        ),
        child: Obx(
          () => FloatingButtonBar(
            onStatBtnTap: () => Get.to(() => const HydrationStatistics()),
            onReminderBtnTap: () => Get.toNamed('/reminder'),
            onAddBtnTap: _onAddButtonPressed,
            onAddBtnLongTap: () async {
              final result = await showHydrationBottomSheetModal(
                context,
                isDarkMode,
                height,
              );
              if (result != null) {
                controller.addWaterValue.value = result;
                _animateTo(controller.waterIntake.value.toDouble());
              }
            },
            addWaterValue: controller.addWaterValue.value,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wp(context, 0.05),
          vertical: hp(context, 0.01),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    SizedBox(height: hp(context, 0.08)), // responsive top space
                    /// Animated Number + Goal Row
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AnimatedBuilder(
                              animation: numberAnimation,
                              builder:
                                  (context, child) => Text(
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
                        SizedBox(height: hp(context, 0.01)),
                        Text(
                          'Wow, keep going!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: grey,
                          ),
                        ),
                        SizedBox(height: hp(context, 0.01)),
                        Obx(
                          () => Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Goal: ${controller.waterGoal.value} ml",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 10),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  await showWaterBottomSheet(
                                    context: context,
                                    isDarkMode: isDarkMode,
                                    onConfirm: (value) async {
                                      await controller.updateWaterGoal(
                                        value,
                                        context,
                                      );
                                    },
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.edit,
                                    size: 22,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    /// Fill remaining space and keep image near bottom
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          hydrationEle,
                          height: hp(context, 0.45),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ✅ Optional helper: Show a reusable bottom sheet for water goal
// Future<int?> showWaterGoalBottomSheet(BuildContext context) {
//   return showModalBottomSheet<int>(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     shape: const RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//     ),
//     builder:
//         (_) => StepCounterBottomSheet(
//           unit: "ml",
//           image: "assets/Images/Water/water.svg",
//           heading: "Set your daily water goal",
//           subHeading: "Keep your body hydrated!",
//           multiplier: 250,
//           initialIndex: 7,
//           // Default = 2000ml
//           onConfirm: (value) {
//             print("Water goal set to $value ml");
//           },
//         ),
//   );
// }

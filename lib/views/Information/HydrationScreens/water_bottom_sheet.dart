import 'package:snevva/consts/consts.dart';
import 'package:wheel_picker/wheel_picker.dart';
import 'package:snevva/Widgets/CommonWidgets/common_question_bottom_sheet.dart';

import '../../../Controllers/Hydration/hydration_stat_controller.dart';

class WaterBottomSheet extends StatefulWidget {
  const WaterBottomSheet({
    super.key,
    this.unit = "ml",
    this.image = "assets/Images/Water/water.svg",
    this.heading = "Set your daily water goal",
    this.subHeading = "Keep your body hydrated!",
    this.multiplier = 250,
    this.initialIndex = 7,
    this.parentContext,
    this.onConfirm,
  });

  final String unit;
  final String image;
  final String heading;
  final String subHeading;
  final int multiplier;
  final int initialIndex;
  final BuildContext? parentContext;
  final Function(int value)? onConfirm;

  @override
  State<WaterBottomSheet> createState() => _WaterBottomSheetState();
}

class _WaterBottomSheetState extends State<WaterBottomSheet> {
  late WheelPickerController wheel;
  final controller = Get.find<HydrationStatController>();

  @override
  void initState() {
    super.initState();

    // Get the latest water goal value
    final currentGoal = controller.waterGoal.value;
    final calculatedIndex = (currentGoal ~/ widget.multiplier) - 1;

    print("Current water goal: $currentGoal");
    print("Calculated wheel index: $calculatedIndex");

    wheel = WheelPickerController(
      itemCount: 20,
      initialIndex: calculatedIndex.clamp(0, 19),
    );
  }

  @override
  void dispose() {
    wheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return CommonQuestionBottomSheet(
      img: widget.image,
      wheel: wheel,
      isDarkMode: isDarkMode,
      unit: widget.unit,
      topPosition: 5,
      width: width,
      rightPadReq: true,
      questionHeading: widget.heading,
      questionSubHeading: widget.subHeading,
      onNext: () async {
        // Try different ways to get the selected value
        print("wheel.selected: ${wheel.selected}");
        print("wheel.initialIndex: ${wheel.initialIndex}");

        // Check if wheel has any other properties
        print("Wheel controller type: ${wheel.runtimeType}");
        print("Wheel toString: ${wheel.toString()}");

        final value = ((wheel.selected + 1) * widget.multiplier) * 4;

        print("Calculated value: $value");

        // Call the onConfirm callback if provided
        if (widget.onConfirm != null) {
          await widget.onConfirm!(value);
        }

        // Close the bottom sheet and return the value
        if (context.mounted) {
          Navigator.of(context).pop(value);
        }
      },
    );
  }
}

Future<int?> showWaterBottomSheet({
  required BuildContext context,
  required bool isDarkMode,
  required Function(int value)? onConfirm,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder:
        (_) => WaterBottomSheet(parentContext: context, onConfirm: onConfirm),
  );
}

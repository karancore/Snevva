import 'package:flutter/material.dart';
import 'package:get/utils.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/common/statement_of_use_bottom_sheet.dart';
import 'package:snevva/consts/consts.dart';
import 'package:wheel_picker/wheel_picker.dart';
import 'package:snevva/Widgets/CommonWidgets/common_question_bottom_sheet.dart';

import '../vitals.dart';

class StepCounterBottomSheet extends StatelessWidget {
  StepCounterBottomSheet({
    super.key,
    this.unit = "Steps",
    this.image = "assets/Images/Steps/walk-ele.svg",
    this.heading = "Set your daily walking goal",
    this.subHeading = "Lorem ipsum dolor sit amet, eiusmod adipi.",
    this.multiplier = 1000,
    this.initialIndex = 8,
    this.onConfirm,
    this.parentContext,
  });

  final String unit;
  final String image;
  final String heading;
  final String subHeading;
  final int multiplier;
  final int initialIndex;
  final Function(int value)? onConfirm;
  final BuildContext? parentContext;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StepCounterController>();
    final wheel = WheelPickerController(
      itemCount: 20,
      initialIndex: (controller.stepGoal.value ~/ multiplier) - 1,
    );

    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return CommonQuestionBottomSheet(
      img: image,
      wheel: wheel,
      isDarkMode: isDarkMode,
      unit: unit,
      topPosition: 5,
      width: width,
      rightPadReq: true,
      questionHeading: heading,
      questionSubHeading: subHeading,
      onNext: () async {
        final value = (wheel.selected + 1) * multiplier;

        if (onConfirm != null) {
          await onConfirm!(value); // wait for controller update
        }

        Future.delayed(Duration(milliseconds: 100), () {
          if (context.mounted) {
            Navigator.of(context).pop(value);
          }
        });
      },
    );
  }
}

Future<int?> showStepCounterBottomSheet(BuildContext context, bool isDarkMode) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => StepCounterBottomSheet(parentContext: context),
  );
}

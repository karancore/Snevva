import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Widgets/HeightAndWeight/weight_scale.dart';
import 'package:snevva/models/queryParamViewModels/height_vm.dart';
import 'package:snevva/models/queryParamViewModels/weight_vm.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/questionnaire_screen.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../Controllers/ProfileSetupAndQuestionnare/height_and_weight_controller.dart';
import '../../Widgets/HeightAndWeight/input_bottom_sheet.dart';
import '../../consts/consts.dart';

class HeightWeightScreen extends StatefulWidget {
  final String gender;

  const HeightWeightScreen({super.key, required this.gender});

  @override
  State<HeightWeightScreen> createState() => _HeightWeightScreenState();
}

class _HeightWeightScreenState extends State<HeightWeightScreen> {
  final controller = Get.put(HeightWeightController());

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Height/Weight",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: IconButton(
            onPressed: () => Get.back(),
            icon: Icon(
              FontAwesomeIcons.arrowLeft,
              color: isDarkMode ? white.withAlpha(200) : black.withAlpha(200),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
          child: Obx(() {
            final heightInFeet = controller.heightInFeet;
            return Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              height: height / 2.5,
                              child: SfLinearGauge(
                                minimum: 3,
                                maximum: 7,
                                interval: 1,
                                orientation: LinearGaugeOrientation.vertical,
                                markerPointers: [
                                  LinearShapePointer(
                                    value: heightInFeet,
                                    onChanged:
                                        (value) =>
                                            controller.updateFromFeet(value),
                                  ),
                                ],
                                barPointers: [
                                  LinearBarPointer(
                                    value: heightInFeet,
                                    color: AppColors.primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: height / 2.5,
                              child: SfLinearGauge(
                                minimum: 91.4,
                                maximum: 213,
                                interval: 25,
                                isMirrored: true,
                                orientation: LinearGaugeOrientation.vertical,
                                showAxisTrack: true,
                                numberFormat: NumberFormat.compact(),
                                markerPointers: [
                                  LinearShapePointer(
                                    value: controller.heightInCm.value,

                                    onChanged:
                                        (value) =>
                                            controller.updateFromCm(value),
                                  ),
                                ],
                                barPointers: [
                                  LinearBarPointer(
                                    value: controller.heightInCm.value,
                                    color: AppColors.primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // SVG on top
                    Positioned(
                      bottom: 0,
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => {showHeightWeightSheet(context)},
                            focusColor: mediumGrey,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Obx(() {
                                    return Text(
                                      "${controller.correctedFeet} ft ${controller.inches} in / ${controller.heightInCm.value.toStringAsFixed(2)} cm",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                      ),
                                    );
                                  }),

                                  SizedBox(width: 8),

                                  SvgPicture.asset(editIcon, height: 18),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: defaultSize - 20),

                          SvgPicture.asset(
                            widget.gender == 'Male' ? heightMale : heightFemale,
                            height: controller.heightInCm.value + 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                height > 800
                    ? SizedBox(height: (height * 0.04).clamp(12.0, 36.0))
                    : SizedBox.shrink(),

                Stack(
                  children: [
                    WeightScale(),
                    Positioned(
                      top: width > 400 ? 0 : 40,
                      left: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () => showHeightWeightSheet(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Obx(() {
                                return Text(
                                  '${controller.weightInKg.toStringAsFixed(1)} kg',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }),
                              SizedBox(width: 8),
                              SvgPicture.asset(editIcon, height: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 44,
                      right: 0,
                      left: 0,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: width > 400 ? 115 : 80,
                          width: width > 400 ? 225 : 160,
                          padding: EdgeInsets.only(top: width > 400 ? 50 : 25),
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? scaffoldColorDark
                                    : scaffoldColorLight,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(120),
                              topRight: Radius.circular(120),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 180,
                      bottom: 14,
                      right: 0,
                      left: 0,
                      child: Center(
                        child: Material(
                          color:
                              isDarkMode
                                  ? scaffoldColorDark
                                  : scaffoldColorLight,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(50),
                            focusColor: mediumGrey,
                            onTap: () async {
                              final heightModel = HeightVM(
                                day: DateTime.now().day,
                                month: DateTime.now().month,
                                year: DateTime.now().year,
                                time: TimeOfDay.now().format(context),
                                // e.g., "14:30"
                                value: controller.heightInCm.value,
                              );

                              final weightModel = WeightVM(
                                day: DateTime.now().day,
                                month: DateTime.now().month,
                                year: DateTime.now().year,
                                time: TimeOfDay.now().format(context),
                                // e.g., "14:30"
                                value: controller.weightInKg.value,
                              );
                              print(heightModel);
                              print(weightModel);

                              await controller.saveData(
                                heightModel,
                                weightModel,
                                context,
                              );

                              if (context.mounted) {
                                Get.to(() => QuestionnaireScreen());
                              }
                            },

                            child: Padding(
                              padding: const EdgeInsets.all(5.0),
                              child: SvgPicture.asset(
                                circularArrowButton,
                                height: 54,
                                width: 54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

void showHeightWeightSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const InputBottomSheet(),
  );
}

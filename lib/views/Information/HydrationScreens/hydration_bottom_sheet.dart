import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';
import 'package:wheel_picker/wheel_picker.dart';
import '../../../consts/consts.dart';

class HydrationBottomSheet extends StatefulWidget {
  final double height;
  final bool isDarkMode;

  const HydrationBottomSheet({
    super.key,
    required this.height,
    required this.isDarkMode,
  });


  @override
  State<HydrationBottomSheet> createState() => _HydrationBottomSheetState();
}

class _HydrationBottomSheetState extends State<HydrationBottomSheet> {
  final WheelPickerController hourController = WheelPickerController(
    itemCount: 12,
    initialIndex: 5,
  );
  final WheelPickerController minuteController = WheelPickerController(
    itemCount: 60,
    initialIndex: 30,
  );
  final WheelPickerController periodController = WheelPickerController(
    itemCount: 2,
  );
  // final WheelPickerController waterController = WheelPickerController(
  //   itemCount: 9,
  //   initialIndex: 3,
  // );

  late final WheelPickerController waterController;

  @override
  void initState() {
    super.initState();
    final int currentValue = controller.addWaterValue.value;
    final int initialWaterIndex = ((currentValue - 100) ~/ 50).clamp(0, 8);

    waterController = WheelPickerController(
      itemCount: 9,
      initialIndex: initialWaterIndex,
    );
  }


  WheelPickerStyle defaultWheelPickerStyle = WheelPickerStyle(
    itemExtent: 30,
    squeeze: 1.2,
    diameterRatio: 0.9,
    surroundingOpacity: 0.25,
    magnification: 1.3,
  );
  final HydrationStatController controller = Get.find<HydrationStatController>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
       //   const Text(
       //     'Set Time',
        //    style: TextStyle(fontSize: 14 , fontWeight: FontWeight.bold),
        //  ),
          // SizedBox(
          //   width: double.infinity,
          //   child: Stack(
          //     alignment: Alignment.center,
          //     children: [
          //       Positioned(
          //        left: 0,
          //         right: 0,
          //         child: Container(
          //           padding: EdgeInsets.only(right: defaultSize),
          //           height: 30,
          //           decoration: BoxDecoration(
          //             borderRadius: BorderRadius.circular(4),
          //             color: mediumGrey.withValues(alpha: 0.15),
          //           ),
          //         ),
          //       ),
          //       SizedBox(
          //         height: widget.height * 0.12,
          //         child: Row(
          //           mainAxisAlignment: MainAxisAlignment.center,
          //           children: [
          //             Flexible(
          //               flex: 1,
          //               child: WheelPicker(
          //                 controller: hourController,
          //                 builder:
          //                     (context, index) => Center(
          //                       child: Text(
          //                         "${index + 1}",
          //                         style: const TextStyle(fontSize: 14),
          //                       ),
          //                     ),
          //                 looping: false,
          //                 selectedIndexColor:
          //                     widget.isDarkMode ? Colors.white : Colors.black,
          //                 style: defaultWheelPickerStyle,
          //               ),
          //             ),
          //
          //             const Text(":", style: TextStyle(fontSize: 16)),
          //
          //             // Minute picker (00–59)
          //             Flexible(
          //               flex: 1,
          //               child: WheelPicker(
          //                 controller: minuteController,
          //                 builder:
          //                     (context, index) => Center(
          //                       child: Text(
          //                         index.toString().padLeft(2, '0'),
          //                         style: const TextStyle(fontSize: 14),
          //                       ),
          //                     ),
          //                 looping: true,
          //                 selectedIndexColor:
          //                     widget.isDarkMode ? Colors.white : Colors.black,
          //                 style: defaultWheelPickerStyle,
          //               ),
          //             ),
          //
          //             // AM/PM picker
          //             Flexible(
          //               flex: 1,
          //               child: WheelPicker(
          //                 controller: periodController,
          //                 builder:
          //                     (context, index) => Center(
          //                       child: Text(
          //                         index == 0 ? "AM" : "PM",
          //                         style: const TextStyle(fontSize: 14),
          //                       ),
          //                     ),
          //                 looping: false,
          //                 selectedIndexColor:
          //                     widget.isDarkMode ? Colors.white : Colors.black,
          //                 style: defaultWheelPickerStyle,
          //               ),
          //             ),
          //           ],
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
         // Divider(color: mediumGrey, thickness: border04px),
          SizedBox(height: 10,),
          const Text(
            'Water Intake(ml)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                 left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(right: defaultSize),
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: mediumGrey.withValues(alpha: 0.15),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'ml',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: widget.height * 0.12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: 1,
                        child: WheelPicker(
                          controller: waterController,
                          onIndexChanged: (index, _) =>
                          {controller.getWaterInMl(100 + index * 50),
                              },
                          builder: (context, index) {
                            int value = 100 + index * 50;
                            return Center(
                              child: Text(
                                '$value',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          },
                          looping: false,
                          selectedIndexColor:
                              widget.isDarkMode ? Colors.white : Colors.black,
                          style: defaultWheelPickerStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: mediumGrey),
                onPressed: () {
                  Get.back();
                },
                child: const Text("Cancel", style: TextStyle(color: white)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                ),
                onPressed: () {
                  // final int hour = hourController.selected + 1;
                  // final int minute = minuteController.selected;
                  // final String period = periodController.selected == 0 ? "AM" : "PM";
                  // final String formattedTime = "$hour:${minute.toString().padLeft(2, '0')} $period";
                  Get.back();
                },
                child: const Text("Save", style: TextStyle(color: white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void showHydrationBottomSheetModal(
  BuildContext context,
  bool isDarkMode,
  double height,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDarkMode ? darkGray : scaffoldColorLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder:
        (_) => HydrationBottomSheet(height: height, isDarkMode: isDarkMode),
  ).then((selectedTime) {
    if (selectedTime != null) {
      //  print("Selected time: $selectedTime");
    }
  });
}

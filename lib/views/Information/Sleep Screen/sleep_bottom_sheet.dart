import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/views/Information/Sleep%20Screen/sleep_tracker.dart';
import 'package:wheel_picker/wheel_picker.dart';
import '../../../../consts/consts.dart';

class SleepBottomSheet extends StatefulWidget {
  final double height;
  final bool isDarkMode;

  const SleepBottomSheet({
    super.key,
    required this.height,
    required this.isDarkMode,
  });

  @override
  State<SleepBottomSheet> createState() => _SleepBottomSheetState();
}

class _SleepBottomSheetState extends State<SleepBottomSheet> {
  final SleepController controller = Get.find<SleepController>();

  final WheelPickerController hourController = WheelPickerController(
    itemCount: 12,
    initialIndex: 9,
  );
  final WheelPickerController wakeUpHourController = WheelPickerController(
    itemCount: 12,
    initialIndex: 5,
  );
  final WheelPickerController minuteController = WheelPickerController(
    itemCount: 60,
    initialIndex: 30,
  );
  final WheelPickerController wakeUpMinuteController = WheelPickerController(
    itemCount: 60,
    initialIndex: 40,
  );
  final WheelPickerController periodController = WheelPickerController(
    initialIndex: 1,
    itemCount: 2,
  );
  final WheelPickerController wakeUpPeriodController = WheelPickerController(
    itemCount: 2,
  );

  WheelPickerStyle defaultWheelPickerStyle = WheelPickerStyle(
    itemExtent: 30,
    squeeze: 1.2,
    diameterRatio: 0.9,
    surroundingOpacity: 0.25,
    magnification: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    // final height = mediaQuery.size.height;
    final isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Set Sleeping Time',
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
                          controller: hourController,
                          builder:
                              (context, index) => Center(
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                          looping: false,
                          selectedIndexColor:
                              widget.isDarkMode ? Colors.white : Colors.black,
                          style: defaultWheelPickerStyle,
                        ),
                      ),

                      const Text(":", style: TextStyle(fontSize: 16)),

                      // Minute picker (00–59)
                      Flexible(
                        flex: 1,
                        child: WheelPicker(
                          controller: minuteController,
                          builder:
                              (context, index) => Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                          looping: true,
                          selectedIndexColor:
                              widget.isDarkMode ? Colors.white : Colors.black,
                          style: defaultWheelPickerStyle,
                        ),
                      ),

                      // AM/PM picker
                      Flexible(
                        flex: 1,
                        child: WheelPicker(
                          controller: periodController,
                          builder:
                              (context, index) => Center(
                                child: Text(
                                  index == 0 ? "AM" : "PM",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
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
          Divider(color: mediumGrey, thickness: border04px),
          SizedBox(height: 10),
          const Text(
            'Set Wake Up Time',
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
                          controller: wakeUpHourController,
                          builder:
                              (context, index) => Center(
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                          looping: false,
                          selectedIndexColor:
                              widget.isDarkMode ? Colors.white : Colors.black,
                          style: defaultWheelPickerStyle,
                        ),
                      ),

                      const Text(":", style: TextStyle(fontSize: 16)),

                      // Minute picker (00–59)
                      Flexible(
                        flex: 1,
                        child: WheelPicker(
                          controller: wakeUpMinuteController,
                          builder:
                              (context, index) => Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                          looping: true,
                          selectedIndexColor:
                              widget.isDarkMode ? Colors.white : Colors.black,
                          style: defaultWheelPickerStyle,
                        ),
                      ),

                      // AM/PM picker
                      Flexible(
                        flex: 1,
                        child: WheelPicker(
                          controller: wakeUpPeriodController,
                          builder:
                              (context, index) => Center(
                                child: Text(
                                  index == 0 ? "AM" : "PM",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
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
          SizedBox(height: 10),
          CustomOutlinedButton(
            width: width,
            isDarkMode: isDarkMode,
            backgroundColor: AppColors.primaryColor,
            buttonName: "Next",
            onTap: () async {
              // --- SLEEP TIME ---
              int sleepHour = hourController.selected + 1;
              int sleepMinute = minuteController.selected;
              int sleepPeriodIndex = periodController.selected;

              if (sleepPeriodIndex == 1 && sleepHour < 12) {
                // PM, add 12 to hour
                sleepHour += 12;
              } else if (sleepPeriodIndex == 0 && sleepHour == 12) {
                // 12 AM should be 0
                sleepHour = 0;
              }

              TimeOfDay sleepTime = TimeOfDay(
                hour: sleepHour,
                minute: sleepMinute,
              );
              final now = DateTime.now();
              DateTime st = DateTime(
                now.year,
                now.month,
                now.day,
                sleepTime.hour,
                sleepTime.minute,
              );
              controller.setBedtime(st);

              // --- WAKE-UP TIME ---
              int wakeHour = wakeUpHourController.selected + 1;
              int wakeMinute = wakeUpMinuteController.selected;
              int wakePeriodIndex = wakeUpPeriodController.selected;

              if (wakePeriodIndex == 1 && wakeHour < 12) {
                wakeHour += 12;
              } else if (wakePeriodIndex == 0 && wakeHour == 12) {
                wakeHour = 0;
              }

              TimeOfDay wakeTime = TimeOfDay(
                hour: wakeHour,
                minute: wakeMinute,
              );

              DateTime wt = DateTime(
                now.year,
                now.month,
                now.day,
                wakeTime.hour,
                wakeTime.minute,
              );
              controller.setWakeTime(wt);

              // controller.bedTime.value = sleepTime;
              // controller.wakeupTime.value = wakeTime;

              //controller.updateSleepTimes(sleepTime, wakeTime);

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_first_time_sleep', false);

              Get.to(() => SleepTrackerScreen());
            },
          ),
        ],
      ),
    );
  }
}

Future<bool?> showSleepBottomSheetModal(
  BuildContext context,
  bool isDarkMode,
  double height,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDarkMode ? darkGray : scaffoldColorLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SleepBottomSheet(height: height, isDarkMode: isDarkMode),
  );
}

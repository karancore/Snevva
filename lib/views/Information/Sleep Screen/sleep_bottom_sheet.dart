import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/views/Information/Sleep%20Screen/sleep_tracker_screen.dart';
import 'package:wheel_picker/wheel_picker.dart';
import '../../../../consts/consts.dart';
import '../../../common/custom_snackbar.dart';
import '../../../common/global_variables.dart';
import '../../../services/notification_service.dart';

class SleepBottomSheet extends StatefulWidget {
  final double height;
  final bool isDarkMode;
  final bool isNavigating;

  const SleepBottomSheet({
    super.key,
    required this.height,
    required this.isDarkMode,
    required this.isNavigating,
  });

  @override
  State<SleepBottomSheet> createState() => _SleepBottomSheetState();
}

class _SleepBottomSheetState extends State<SleepBottomSheet> {
  // Reuse the existing SleepController instead of creating a new one.
  final SleepController controller = Get.find<SleepController>();

  final notificationService = NotificationService();

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
  final WheelPickerStyle defaultWheelPickerStyle = WheelPickerStyle(
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
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
              debugPrint("👉 Sleep/Wake onTap tapped, oyee!");

              // --- SLEEP TIME ---
              int sleepHour = hourController.selected + 1;
              int sleepMinute = minuteController.selected;
              int sleepPeriodIndex = periodController.selected;

              debugPrint(
                "😴 Raw Sleep -> hourIndex: ${hourController.selected}, minute: $sleepMinute, periodIndex: $sleepPeriodIndex",
              );

              if (sleepPeriodIndex == 1 && sleepHour < 12) {
                sleepHour += 12;
              } else if (sleepPeriodIndex == 0 && sleepHour == 12) {
                sleepHour = 0;
              }

              debugPrint("😴 Converted Sleep Hour (24h): $sleepHour");

              TimeOfDay sleepTime = TimeOfDay(
                hour: sleepHour,
                minute: sleepMinute,
              );

              // DateTime st = DateTime(
              //   now.year,
              //   now.month,
              //   now.day,
              //   sleepTime.hour,
              //   sleepTime.minute,
              // );

              debugPrint("🛏️ Final Sleep DateTime: $sleepTime");

              controller.setBedtime(sleepTime);

              // --- WAKE-UP TIME ---
              int wakeHour = wakeUpHourController.selected + 1;
              int wakeMinute = wakeUpMinuteController.selected;
              int wakePeriodIndex = wakeUpPeriodController.selected;

              debugPrint(
                "⏰ Raw Wake -> hourIndex: ${wakeUpHourController.selected}, minute: $wakeMinute, periodIndex: $wakePeriodIndex",
              );

              if (wakePeriodIndex == 1 && wakeHour < 12) {
                wakeHour += 12;
              } else if (wakePeriodIndex == 0 && wakeHour == 12) {
                wakeHour = 0;
              }

              debugPrint("⏰ Converted Wake Hour (24h): $wakeHour");

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

              debugPrint("🌅 Final Wake DateTime: $wakeTime");

              controller.setWakeTime(wakeTime);

              debugPrint("Sleep monitoring started at sleep bottom sheet");
              await controller.startMonitoring();
              debugPrint("Alarm scheduled for wake time at sleep bottom sheet");
              await notificationService.scheduleWakeNotification(dateTime: wt);

              CustomSnackbar.showSnackbar(
                context: context,
                title: "Sleep Monitoring Started",
                message: '',
              );

              debugPrint(
                "📡 Sending SleepTime: $sleepTime | WakeTime: $wakeTime to server",
              );
              controller.updateSleepTimestoServer(sleepTime, wakeTime);

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_first_time_sleep', false);

              debugPrint("💾 is_first_time_sleep set to false");

              if (widget.isNavigating) {
                debugPrint("➡️ Navigating to SleepTrackerScreen");
                Navigator.pop(context);
                Get.to(() => SleepTrackerScreen());
              } else {
                debugPrint("⬅️ Going back");
                Get.back();
              }
            },
          ),
        ],
      ),
    );
  }
}

Future<bool?> showSleepBottomSheetModal({
  required BuildContext context,
  required bool isDarkMode,
  required double height,
  required bool isNavigating,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDarkMode ? darkGray : scaffoldColorLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder:
        (_) => SleepBottomSheet(
          height: height,
          isDarkMode: isDarkMode,
          isNavigating: isNavigating,
        ),
  );
}

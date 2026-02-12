import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/views/Information/Sleep%20Screen/sleep_tracker_screen.dart';
import 'package:wheel_picker/wheel_picker.dart';
import '../../../../consts/consts.dart';
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
  final SleepController controller = Get.find<SleepController>();
  final notificationService = NotificationService();
  final _service = FlutterBackgroundService();

  // Sleep goal picker controllers
  final WheelPickerController goalHourController = WheelPickerController(
    itemCount: 13, // 0-12 hours
    initialIndex: 8, // Default 8 hours
  );
  final WheelPickerController goalMinuteController = WheelPickerController(
    itemCount: 4, // 0, 15, 30, 45
    initialIndex: 0, // Default 0 minutes
  );

  final WheelPickerStyle defaultWheelPickerStyle = WheelPickerStyle(
    itemExtent: 30,
    squeeze: 1.2,
    diameterRatio: 0.9,
    surroundingOpacity: 0.25,
    magnification: 1.3,
  );

  bool _isSleeping = false;
  Duration _currentSleepDuration = Duration.zero;
  Duration _sleepGoal = Duration(hours: 8);
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadySleeping();
    _setupSleepListeners();
  }

  Future<void> _checkIfAlreadySleeping() async {
    final prefs = await SharedPreferences.getInstance();
    final isSleeping = prefs.getBool("is_sleeping") ?? false;

    if (isSleeping) {
      final startString = prefs.getString("sleep_start_time");
      final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;

      if (startString != null) {
        final start = DateTime.parse(startString);
        final elapsed = DateTime.now().difference(start);

        setState(() {
          _isSleeping = true;
          _currentSleepDuration = elapsed;
          _sleepGoal = Duration(minutes: goalMinutes);
          _progress = (elapsed.inMinutes / goalMinutes).clamp(0.0, 1.0);
        });
      }
    }
  }

  void _setupSleepListeners() {
    // Listen to sleep updates from background service
    _service.on("sleep_update").listen((event) {
      if (event != null && mounted) {
        final elapsedMinutes = event['elapsed_minutes'] as int? ?? 0;
        final goalMinutes = event['goal_minutes'] as int? ?? 480;
        final sleeping = event['is_sleeping'] as bool? ?? false;

        setState(() {
          _isSleeping = sleeping;
          _currentSleepDuration = Duration(minutes: elapsedMinutes);
          _sleepGoal = Duration(minutes: goalMinutes);
          _progress = (elapsedMinutes / goalMinutes).clamp(0.0, 1.0);
        });
      }
    });

    // Listen to sleep saved event
    _service.on("sleep_saved").listen((event) {
      if (event != null && mounted) {
        setState(() {
          _isSleeping = false;
          _currentSleepDuration = Duration.zero;
          _progress = 0.0;
        });

        // Reload sleep data
        controller.loadDeepSleepData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isSleeping) {
      // Show sleep tracking UI
      return _buildSleepTrackingUI(width, isDarkMode);
    } else {
      // Show sleep goal picker UI
      return _buildSleepGoalPickerUI(width, isDarkMode);
    }
  }

  Widget _buildSleepTrackingUI(double width, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Sleep Tracking Active',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Sleep progress indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 160,
                width: 160,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 12,
                  backgroundColor: mediumGrey.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryColor,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDuration(_currentSleepDuration),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'of ${_formatDuration(_sleepGoal)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Stop button
          CustomOutlinedButton(
            width: width,
            isDarkMode: isDarkMode,
            backgroundColor: Colors.red,
            buttonName: "Stop Sleep",
            onTap: () async {
              // Stop sleep tracking
              _service.invoke("stop_sleep");

              Get.snackbar(
                'Sleep Stopped',
                'Your sleep has been recorded',
                snackPosition: SnackPosition.TOP,
                backgroundColor: AppColors.primaryColor,
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
              );

              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSleepGoalPickerUI(double width, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Set Sleep Goal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'How long do you plan to sleep?',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Sleep goal picker
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
                      // Hours picker
                      Flexible(
                        flex: 1,
                        child: WheelPicker(
                          controller: goalHourController,
                          builder: (context, index) => Center(
                            child: Text(
                              "$index",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          looping: false,
                          selectedIndexColor:
                              widget.isDarkMode ? Colors.white : Colors.black,
                          style: defaultWheelPickerStyle,
                        ),
                      ),
                      const Text(
                        " h  ",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),

                      // Minutes picker (0, 15, 30, 45)
                      Flexible(
                        flex: 1,
                        child: WheelPicker(
                          controller: goalMinuteController,
                          builder: (context, index) {
                            final minutes = index * 15; // 0, 15, 30, 45
                            return Center(
                              child: Text(
                                "$minutes",
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          },
                          looping: true,
                          selectedIndexColor:
                              widget.isDarkMode ? Colors.white : Colors.black,
                          style: defaultWheelPickerStyle,
                        ),
                      ),
                      const Text(
                        " m",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Start sleep button
          SafeArea(
            child: CustomOutlinedButton(
              width: width,
              isDarkMode: isDarkMode,
              backgroundColor: AppColors.primaryColor,
              buttonName: "Start Sleep",
              onTap: () async {
                final goalHours = goalHourController.selected;
                final goalMinutes = goalMinuteController.selected * 15;

                if (goalHours == 0 && goalMinutes == 0) {
                  Get.snackbar(
                    'Invalid Goal',
                    'Please set a sleep goal greater than 0',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                  return;
                }

                final totalGoalMinutes = (goalHours * 60) + goalMinutes;

                // Start sleep tracking via background service
                _service.invoke("start_sleep", {
                  "goal_minutes": totalGoalMinutes,
                });

                Get.snackbar(
                  'Sleep Tracking Started',
                  'Goal: ${goalHours}h ${goalMinutes}m',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: AppColors.primaryColor,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );

                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('sleepGoalbool', true);

                Navigator.pop(context);

                if (widget.isNavigating) {
                  Navigator.pop(context);
                  Get.to(() => SleepTrackerScreen());
                } else {
                  Get.back();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
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
    builder: (_) => SleepBottomSheet(
      height: height,
      isDarkMode: isDarkMode,
      isNavigating: isNavigating,
    ),
  );
}
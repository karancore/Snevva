import 'dart:async';
import 'package:flutter/material.dart';
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
  StreamSubscription? _sleepUpdateSub;
  StreamSubscription? _sleepSavedSub;

  // Bedtime picker controllers - will be initialized after loading schedule
  late WheelPickerController bedHourController;
  late WheelPickerController bedMinuteController;
  late WheelPickerController wakeHourController;
  late WheelPickerController wakeMinuteController;

  final WheelPickerStyle defaultWheelPickerStyle = WheelPickerStyle(
    itemExtent: 30,
    squeeze: 1.2,
    diameterRatio: 0.9,
    surroundingOpacity: 0.25,
    magnification: 1.3,
  );

  bool _isSleeping = false;
  bool _isStarting = false;
  Duration _currentSleepDuration = Duration.zero;
  Duration _sleepGoal = Duration(hours: 8);
  double _progress = 0.0;
  bool _hasExistingSchedule = false;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _checkIfAlreadySleeping();
    await _initializeControllers();
    _setupSleepListeners();
  }

  Future<void> _initializeControllers() async {
    final prefs = await SharedPreferences.getInstance();
    final bedtimeMin = prefs.getInt('user_bedtime_ms');
    final waketimeMin = prefs.getInt('user_waketime_ms');
    final manuallyStopped = prefs.getBool('manually_stopped') ?? false;

    int bedHour = 22; // Default 10 PM
    int bedMinuteIndex = 0; // Default 0 minutes
    int wakeHour = 6; // Default 6 AM
    int wakeMinuteIndex = 0; // Default 0 minutes

    if (bedtimeMin != null && waketimeMin != null) {
      bedHour = bedtimeMin ~/ 60;
      bedMinuteIndex = (bedtimeMin % 60) ~/ 15;
      wakeHour = waketimeMin ~/ 60;
      wakeMinuteIndex = (waketimeMin % 60) ~/ 15;
      _hasExistingSchedule = true;
    }

    if (!mounted) return;

    setState(() {
      bedHourController = WheelPickerController(
        itemCount: 24,
        initialIndex: bedHour,
      );
      bedMinuteController = WheelPickerController(
        itemCount: 4,
        initialIndex: bedMinuteIndex,
      );
      wakeHourController = WheelPickerController(
        itemCount: 24,
        initialIndex: wakeHour,
      );
      wakeMinuteController = WheelPickerController(
        itemCount: 4,
        initialIndex: wakeMinuteIndex,
      );
      _controllersInitialized = true;
    });

    // Auto-start only if not manually stopped and conditions met
    if (!manuallyStopped && _isWindowActive() && !_isSleeping && !_isStarting) {
      _isStarting = true;
      _startSleepTrackingFromWindow();
    }
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

  // New: Check if current time is within the sleep window
  bool _isWindowActive() {
    final bed = controller.bedtime.value;
    final wake = controller.waketime.value;
    if (bed == null || wake == null) return false;

    final now = TimeOfDay.fromDateTime(DateTime.now());
    final bedMinutes = bed.hour * 60 + bed.minute;
    final wakeMinutes = wake.hour * 60 + wake.minute;
    final nowMinutes = now.hour * 60 + now.minute;

    // Handle case where wake time is next day
    if (bedMinutes < wakeMinutes) {
      return nowMinutes >= bedMinutes && nowMinutes <= wakeMinutes;
    } else {
      return nowMinutes >= bedMinutes || nowMinutes <= wakeMinutes;
    }
  }

  // New: Start tracking automatically if window is active
  Future<void> _startSleepTrackingFromWindow() async {
    final bed = controller.bedtime.value;
    final wake = controller.waketime.value;
    if (bed == null || wake == null) return;

    final goalMinutes = _calculateSleepGoalMinutes(
      bed.hour,
      bed.minute,
      wake.hour,
      wake.minute,
    );

    Get.find<SleepController>().sleepGoal.value = Duration(minutes: goalMinutes);

    _service.invoke("start_sleep", {
      "goal_minutes": goalMinutes,
      "bedtime_minutes": bed.hour * 60 + bed.minute,
      "waketime_minutes": wake.hour * 60 + wake.minute,
    });

    if (mounted) {
      setState(() {
        _isSleeping = true;
        _sleepGoal = Duration(minutes: goalMinutes);
        _progress = 0.0;
      });
    }

    print("🌙 Auto-started sleep tracking (window active)");
  }

  void _setupSleepListeners() {
    // Listen to sleep updates from background service
    _sleepUpdateSub = _service.on("sleep_update").listen((event) async {
      if (event != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final manuallyStopped = prefs.getBool('manually_stopped') ?? false;

        // If user manually stopped tracking, ignore background updates for this session
        if (manuallyStopped) {
          if (_isSleeping) {
            setState(() {
              _isSleeping = false;
              _currentSleepDuration = Duration.zero;
              _progress = 0.0;
            });
          }
          return;
        }

        final elapsedMinutes = event['elapsed_minutes'] as int? ?? 0;
        final goalMinutes = event['goal_minutes'] as int? ?? 480;
        final sleeping = event['is_sleeping'] as bool? ?? false;

        if (!mounted) return;

        setState(() {
          _isSleeping = sleeping;
          _currentSleepDuration = Duration(minutes: elapsedMinutes);
          _sleepGoal = Duration(minutes: goalMinutes);
          _progress =
              goalMinutes > 0
                  ? (elapsedMinutes / goalMinutes).clamp(0.0, 1.0)
                  : 0.0;
        });
      }
    });

    // Listen to sleep saved event
    _sleepSavedSub = _service.on("sleep_saved").listen((event) {
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
  void dispose() {
    if (_controllersInitialized) {
      bedHourController.dispose();
      bedMinuteController.dispose();
      wakeHourController.dispose();
      wakeMinuteController.dispose();
    }
    _sleepUpdateSub?.cancel();
    _sleepSavedSub?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Show loading while controllers are being initialized
    if (!_controllersInitialized) {
      return Padding(
        padding: const EdgeInsets.all(40.0),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryColor),
        ),
      );
    }

    print("isSleeping $_isSleeping");

    // Updated: Show tracking UI if sleeping or window is active
    if (_isSleeping) {
      return _buildSleepTrackingUI(width, isDarkMode);
    } else {
      return _buildSleepScheduleSetupUI(width, isDarkMode);
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
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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

          const SizedBox(height: 20),

          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Auto-tracking screen off time during your sleep window',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Stop button
          CustomOutlinedButton(
            width: width,
            isDarkMode: isDarkMode,
            backgroundColor: Colors.red,
            buttonName: "Stop & Save Sleep",
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(
                'manually_stopped',
                true,
              ); // <-- Mark as manually stopped

              if (mounted) {
                setState(() {
                  _isSleeping = false;
                  _currentSleepDuration = Duration.zero;
                  _progress = 0.0;
                });
              }
              _service.invoke("stop_sleep");

              Get.snackbar(
                'Sleep Saved',
                'Your sleep data has been recorded',
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

  Widget _buildSleepScheduleSetupUI(double width, bool isDarkMode) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _hasExistingSchedule
                  ? 'Update Sleep Schedule'
                  : 'Set Sleep Schedule',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Set your bedtime and wake time for automatic sleep tracking',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Bedtime Picker
            _buildTimePicker(
              'Bed Time',
              bedHourController,
              bedMinuteController,
              isDarkMode,
            ),

            const SizedBox(height: 20),

            // Wake Time Picker
            _buildTimePicker(
              'Wake Time',
              wakeHourController,
              wakeMinuteController,
              isDarkMode,
            ),

            //
            // const SizedBox(height: 20),
            //
            // // Calculated sleep goal display
            // _buildSleepGoalDisplay(isDarkMode),
            const SizedBox(height: 18),

            // Start tracking button
            SafeArea(
              child: Column(
                children: [
                  CustomOutlinedButton(
                    width: width,
                    isDarkMode: isDarkMode,
                    backgroundColor: AppColors.primaryColor,
                    buttonName:
                        _hasExistingSchedule
                            ? "Update & Start Tracking"
                            : "Start Sleep Tracking",
                    onTap: () async {
                      await _startSleepTracking();
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_hasExistingSchedule)
                    TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('user_bedtime_ms');
                        await prefs.remove('user_waketime_ms');

                        // Dispose old controllers
                        bedHourController.dispose();
                        bedMinuteController.dispose();
                        wakeHourController.dispose();
                        wakeMinuteController.dispose();

                        // Reinitialize with defaults
                        setState(() {
                          _hasExistingSchedule = false;
                          bedHourController = WheelPickerController(
                            itemCount: 24,
                            initialIndex: 22, // Default 10 PM
                          );
                          bedMinuteController = WheelPickerController(
                            itemCount: 4,
                            initialIndex: 0,
                          );
                          wakeHourController = WheelPickerController(
                            itemCount: 24,
                            initialIndex: 6, // Default 6 AM
                          );
                          wakeMinuteController = WheelPickerController(
                            itemCount: 4,
                            initialIndex: 0,
                          );
                        });

                        Get.snackbar(
                          'Schedule Cleared',
                          'Sleep schedule has been reset',
                          snackPosition: SnackPosition.TOP,
                        );
                      },
                      child: const Text('Clear Sleep Schedule'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(
    String label,
    WheelPickerController hourController,
    WheelPickerController minuteController,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Container(
          height: 120, // <-- Add this to constrain height
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: mediumGrey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hours picker
              Flexible(
                flex: 1,
                child: WheelPicker(
                  controller: hourController,
                  builder:
                      (context, index) => Center(
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  looping: true,
                  selectedIndexColor: isDarkMode ? Colors.white : Colors.black,
                  style: defaultWheelPickerStyle,
                ),
              ),
              const Text(
                " : ",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              // Minutes picker
              Flexible(
                flex: 1,
                child: WheelPicker(
                  controller: minuteController,
                  builder: (context, index) {
                    final minutes = index * 15;
                    return Center(
                      child: Text(
                        minutes.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                  looping: true,
                  selectedIndexColor: isDarkMode ? Colors.white : Colors.black,
                  style: defaultWheelPickerStyle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSleepGoalDisplay(bool isDarkMode) {
    final bedHour = bedHourController.selected;
    final bedMinute = bedMinuteController.selected * 15;
    final wakeHour = wakeHourController.selected;
    final wakeMinute = wakeMinuteController.selected * 15;

    final goalMinutes = _calculateSleepGoalMinutes(
      bedHour,
      bedMinute,
      wakeHour,
      wakeMinute,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Sleep Goal:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            _formatGoalDuration(goalMinutes),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateSleepGoalMinutes(
    int bedHour,
    int bedMinute,
    int wakeHour,
    int wakeMinute,
  ) {
    int bedTotalMinutes = bedHour * 60 + bedMinute;
    int wakeTotalMinutes = wakeHour * 60 + wakeMinute;

    // If wake time is earlier than bed time, it means next day
    if (wakeTotalMinutes <= bedTotalMinutes) {
      wakeTotalMinutes += 24 * 60;
    }

    return wakeTotalMinutes - bedTotalMinutes;
  }

  Future<void> _startSleepTracking() async {
    final bedHour = bedHourController.selected;
    final bedMinute = bedMinuteController.selected * 15;
    final wakeHour = wakeHourController.selected;
    final wakeMinute = wakeMinuteController.selected * 15;

    final goalMinutes = _calculateSleepGoalMinutes(
      bedHour,
      bedMinute,
      wakeHour,
      wakeMinute,
    );

    if (goalMinutes <= 0) {
      Get.snackbar(
        'Invalid Schedule',
        'Please set a valid sleep schedule',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('manually_stopped', false);

    // Save sleep schedule
    final bedtimeMinutes = bedHour * 60 + bedMinute;
    final waketimeMinutes = wakeHour * 60 + wakeMinute;

    await prefs.setInt('user_bedtime_ms', bedtimeMinutes);
    await prefs.setInt('user_waketime_ms', waketimeMinutes);

    // Update the controller's bedtime and waketime (this also saves locally)
    final bedTime = TimeOfDay(hour: bedHour, minute: bedMinute);
    final wakeTime = TimeOfDay(hour: wakeHour, minute: wakeMinute);
    controller.setBedtime(bedTime);
    controller.setWakeTime(wakeTime);

    // Start sleep tracking
    _service.invoke("start_sleep", {
      "goal_minutes": goalMinutes,
      "bedtime_minutes": bedtimeMinutes,
      "waketime_minutes": waketimeMinutes,
    });

    setState(() {
      _isSleeping = true; // <-- Direct assignment
    });

    Get.snackbar(
      'Sleep Tracking Started',
      'Automatic tracking active from ${_formatTime(bedHour, bedMinute)} to ${_formatTime(wakeHour, wakeMinute)}',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.primaryColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    await prefs.setBool('sleepGoalbool', true);

    Navigator.pop(context);

    if (widget.isNavigating) {
      Get.back(); // close sheet
      Get.to(() => SleepTrackerScreen());
    } else {
      Get.back();
    }
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
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

  String _formatGoalDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
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
    builder:
        (_) => SleepBottomSheet(
          height: height,
          isDarkMode: isDarkMode,
          isNavigating: isNavigating,
        ),
  );
}

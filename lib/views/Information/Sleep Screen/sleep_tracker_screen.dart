import 'dart:async';
import 'dart:math';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Information/Sleep%20Screen/sleep_bottom_sheet.dart';
import '../../../Controllers/SleepScreen/sleep_controller.dart';
import '../../../Widgets/CommonWidgets/common_stat_graph_widget.dart';
import '../../../common/global_variables.dart';

enum StatViewMode { weekly, monthly }

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key});

  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen> {
  TimeOfDay? selectedTime;
  int daysSinceMonday = 0;
  int todayDate = 1;

  DateTime _selectedMonth = DateTime.now();
  TimeOfDay? start = TimeOfDay.now();
  TimeOfDay? end = TimeOfDay.fromDateTime(
    DateTime.now().add(Duration(hours: 8)),
  );

  bool _loaded = false;

  final sleepController = Get.find<SleepController>();
  final _service = FlutterBackgroundService();

  // Real-time sleep tracking state
  bool _isSleeping = false;
  Duration _currentSleepDuration = Duration.zero;
  Duration _sleepGoal = Duration(hours: 8);
  double _progress = 0.0;

  StreamSubscription? _sleepUpdateSubscription;
  StreamSubscription? _sleepSavedSubscription;
  StreamSubscription? _goalReachedSubscription;

  @override
  void initState() {
    super.initState();

    toggleSleepCard();
    _checkIfAlreadySleeping();
    _setupSleepListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await sleepController.loadDeepSleepData();
      sleepController.loadUserSleepTimes();
    });
  }

  @override
  void dispose() {
    _sleepUpdateSubscription?.cancel();
    _sleepSavedSubscription?.cancel();
    _goalReachedSubscription?.cancel();
    super.dispose();
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
    // Listen to sleep progress updates
    _sleepUpdateSubscription = _service.on("sleep_update").listen((
      event,
    ) async {
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

        setState(() {
          _isSleeping = sleeping;
          _currentSleepDuration = Duration(minutes: elapsedMinutes);
          _sleepGoal = Duration(minutes: goalMinutes);
          _progress = (elapsedMinutes / goalMinutes).clamp(0.0, 1.0);
        });

        print("💤 Sleep update in UI: ${elapsedMinutes}m / ${goalMinutes}m");
      }
    });

    // Listen to sleep saved event
    _sleepSavedSubscription = _service.on("sleep_saved").listen((event) async {
      if (event != null && mounted) {
        final duration = event['duration'] as int? ?? 0;

        setState(() {
          _isSleeping = false;
          _currentSleepDuration = Duration.zero;
          _progress = 0.0;
        });

        // Reload sleep data
        await sleepController.loadDeepSleepData();
        sleepController.updateDeepSleepSpots();

        Get.snackbar(
          '😴 Sleep Recorded',
          'You slept for ${_formatDuration(Duration(minutes: duration))}',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    });

    // Listen to goal reached event
    _goalReachedSubscription = _service.on("sleep_goal_reached").listen((
      event,
    ) {
      if (event != null && mounted) {
        Get.snackbar(
          '🎉 Goal Reached!',
          'You\'ve completed your sleep goal!',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    });
  }

  Future<void> toggleSleepCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sleepGoalbool', true);
  }

  String _fmt(TimeOfDay? dt) {
    if (dt == null) return "Not Set";
    int hour = dt.hour;
    String ampm = hour >= 12 ? "PM" : "AM";

    hour = hour % 12;
    if (hour == 0) hour = 12;

    String minute = dt.minute.toString().padLeft(2, '0');

    return "$hour:$minute $ampm";
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

  double getDeepSleepPercent(Duration? duration) {
    if (duration == null) return 0.0;

    const maxDeepSleepMinutes = 120;
    double minutes = duration.inMinutes.toDouble();

    return (minutes / maxDeepSleepMinutes).clamp(0.0, 1.0);
  }

  void _toggleView() async {
    sleepController.isMonthlyView.value = !sleepController.isMonthlyView.value;

    if (sleepController.isMonthlyView.value) {
      await sleepController.loadSleepfromAPI(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );
    } else {
      sleepController.updateDeepSleepSpots();
    }
  }

  void _changeMonth(int delta) async {
    final newMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + delta,
      1,
    );

    setState(() => _selectedMonth = newMonth);

    await sleepController.loadSleepfromAPI(
      month: newMonth.month,
      year: newMonth.year,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double size = 210;
    final double center = size / 2;
    final double radius = center - 20;

    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sleepController.loadDeepSleepData();
      });
    }

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: 'Sleep Tracker'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              //========== SLEEP TRACKING INDICATOR ==========
              SizedBox(
                child: Stack(
                  children: [
                    // Clock numbers
                    for (int i = 1; i <= 12; i++)
                      Positioned(
                        left:
                            center +
                            radius * cos((i * 30 - 90) * pi / 180) +
                            10,
                        top:
                            center + radius * sin((i * 30 - 90) * pi / 180) + 5,
                        child: Text(
                          '$i',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),

                    // Main circular indicator
                    _isSleeping
                        ? _buildActiveSleepIndicator()
                        : _buildInactiveSleepIndicator(),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              //========== SLEEP/WAKE TIME CARD ==========
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? darkGray : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Image(
                              image: AssetImage(bedIcon),
                              height: 30,
                              width: 30,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Bedtime",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Obx(
                          () => Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _fmt(sleepController.bedtime.value),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await showSleepBottomSheetModal(
                                    context: context,
                                    isDarkMode: isDarkMode,
                                    height: height,
                                    isNavigating: false,
                                  );
                                },
                                icon: Icon(
                                  FontAwesomeIcons.angleRight,
                                  size: 20,
                                  color: _isSleeping ? Colors.grey : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Divider(thickness: border04px, color: mediumGrey),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Image(
                              image: AssetImage(clockIcon),
                              height: 30,
                              width: 30,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Wake Up",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Obx(
                          () => Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _fmt(sleepController.waketime.value),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await showSleepBottomSheetModal(
                                    context: context,
                                    isDarkMode: isDarkMode,
                                    height: height,
                                    isNavigating: false,
                                  );
                                },
                                icon: Icon(
                                  FontAwesomeIcons.angleRight,
                                  size: 20,
                                  color: _isSleeping ? Colors.grey : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              //========== WEEKLY/MONTHLY TOGGLE ==========
              Obx(() {
                final isMonthly = sleepController.isMonthlyView.value;

                return Column(
                  children: [
                    Text(
                      isMonthly
                          ? "Monthly Sleep Report"
                          : "Weekly Sleep Report",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (isMonthly) ...[
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => _changeMonth(-1),
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(_selectedMonth),
                              style: const TextStyle(fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => _changeMonth(1),
                            ),
                          ],
                          TextButton(
                            onPressed: _toggleView,
                            child: Text(
                              isMonthly
                                  ? "Switch to Weekly"
                                  : "Switch to Monthly",
                              style: TextStyle(color: AppColors.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),

              const SizedBox(height: 10),

              //========== SLEEP GRAPH ==========
              SizedBox(
                height: height * 0.41,
                child: Obx(() {
                  final labels =
                      sleepController.isMonthlyView.value
                          ? generateMonthLabels(_selectedMonth)
                          : generateShortWeekdays();

                  final points =
                      sleepController.isMonthlyView.value
                          ? sleepController.getMonthlyDeepSleepSpots(now)
                          : sleepController.deepSleepSpots
                              .take(daysSinceMonday + 1)
                              .toList();

                  final double rawMax =
                      points.isEmpty
                          ? 0
                          : points
                              .map((e) => e.y)
                              .reduce((a, b) => a > b ? a : b);

                  final double maxY = getNiceSleepMaxY(rawMax);
                  final double interval = getNiceSleepInterval(maxY);

                  return CommonStatGraphWidget(
                    isDarkMode: isDarkMode,
                    height: height,
                    graphTitle: 'Sleep Statistics',
                    points: points,
                    maxXForWeek: daysSinceMonday,
                    isMonthlyView: sleepController.isMonthlyView.value,
                    weekLabels: labels,
                    yAxisMaxValue: maxY,
                    yAxisInterval: interval,
                    gridLineInterval: interval,
                    measureUnit: 'h',
                    isSleepGraph: true,
                    isWaterGraph: false,
                  );
                }),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSleepIndicator() {
    return CircularPercentIndicator(
      radius: 120,
      lineWidth: 20,
      percent: _progress,
      progressColor: AppColors.primaryColor,
      backgroundColor: mediumGrey.withValues(alpha: 0.3),
      circularStrokeCap: CircularStrokeCap.round,
      center: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bedtime, size: 40, color: AppColors.primaryColor),
          const SizedBox(height: 8),
          Text(
            _formatDuration(_currentSleepDuration),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            'of ${_formatDuration(_sleepGoal)}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveSleepIndicator() {
    return Obx(() {
      final d = sleepController.deepSleepDuration.value;
      final deepMin = d.inMinutes.toDouble();
      final idealMin =
          (sleepController.idealWakeupDuration?.inMinutes ?? 720).toDouble();
      final percent =
          idealMin <= 0 ? 0.0 : (deepMin / idealMin).clamp(0.0, 1.0);

      return CircularPercentIndicator(
        radius: 120,
        lineWidth: 20,
        percent: percent,
        progressColor: AppColors.primaryColor,
        backgroundColor: mediumGrey.withValues(alpha: 0.3),
        circularStrokeCap: CircularStrokeCap.round,
        center: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            (d.inMinutes > 0)
                ? Text(
                  fmtDuration(d),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                )
                : const Text(
                  "No Data",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
            const SizedBox(height: 8),
            Text(
              sleepController.getSleepStatus(d),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    });
  }

  List<String> generateShortWeekdays() {
    List<String> shortWeekdays = [];
    DateTime now = DateTime.now();

    daysSinceMonday = (now.weekday - DateTime.monday);

    DateTime startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysSinceMonday));

    for (int i = 0; i <= daysSinceMonday; i++) {
      DateTime date = startOfWeek.add(Duration(days: i));
      String dayName = DateFormat('E').format(date);

      shortWeekdays.add(dayName);
    }

    return shortWeekdays;
  }
}

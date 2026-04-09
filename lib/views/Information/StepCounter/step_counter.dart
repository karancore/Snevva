import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Information/StepCounter/step_counter_bottom_sheet.dart';
import 'package:snevva/widgets/semi_circular_progress.dart';

import '../../../common/global_variables.dart';
import '../../../widgets/CommonWidgets/custom_appbar.dart';
import '../../../widgets/CommonWidgets/step_stat_graph_widget.dart';
import '../../../widgets/Drawer/drawer_menu_wigdet.dart';

class StepCounter extends StatefulWidget {
  final int? customGoal;

  const StepCounter({super.key, this.customGoal});

  @override
  State<StepCounter> createState() => _StepCounterState();
}

class _StepCounterState extends State<StepCounter> with WidgetsBindingObserver {
  final stepController = Get.find<StepCounterController>();

  List<FlSpot> _points = [];
  int daysSinceMonday = 0;
  int todayDate = 1;
  DateTime _selectedMonth = DateTime.now();
  bool _isMonthlyView = false;

  Position? _currentPosition;
  StreamSubscription<Position>? _locationSub;

  Timer? _uiRefreshTimer;

  String _dayKey(DateTime d) => "${d.year}-${d.month}-${d.day}";

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);




  // final service = FlutterBackgroundService();
  // StreamSubscription? _serviceSub;

  Timer? _debounce;
  int _secretTapCount = 0;
  Timer? _secretResetTimer;

  @override
  void initState() {
    super.initState();

    // Ensure we observe app lifecycle to refresh on resume
    WidgetsBinding.instance.addObserver(this);

    // Start the MethodChannel listener + file poller so this screen receives
    // live step updates from the native StepCounterService immediately.
    stepController.activateRealtimeTracking();

    // Load whatever is already in the daily file so the UI shows steps right away.
    stepController.loadTodayStepsFromFile();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _uiRefreshTimer?.cancel();
    _debounce?.cancel();
    _secretResetTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Signal controller that this screen is no longer the active consumer.
    // (MethodChannel handler stays alive in the controller for background updates.)
    stepController.deactivateRealtimeTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Force reload from Hive and prefs when app returns to foreground
      debugPrint('🔁 App resumed - reloading steps from file');
      stepController.loadTodayStepsFromFile();
    }
  }

  Future<void> toggleStepsCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isStepGoalSet', true);
  }

  //   Future<void> _loadWeeklyData() async {
  //
  //   final start = _startOfDay(now).subtract(const Duration(days: 6));

  //   final pts = <FlSpot>[];
  //   int maxSteps = 0;

  //   for (int i = 0; i < 7; i++) {
  //     final day = start.add(Duration(days: i));
  //     final key = _dayKey(day);
  //     final steps = _box.get(key)?.steps ?? 0;

  //     if (steps > maxSteps) maxSteps = steps;

  //     // Use raw step counts (Option B)
  //     pts.add(FlSpot(i.toDouble(), steps.toDouble()));
  //   }

  //   if (!mounted) return;
  //   setState(() {
  //     _points = pts;
  //     _graphMaxY = maxSteps * 1.1; // add 10% padding
  //   });

  //   debugPrint("📈 Weekly data loaded: $_points");
  // }

  //   Future<void> _loadMonthlyData(DateTime month) async {
  //   final start = DateTime(month.year, month.month, 1);
  //   final days = DateTime(month.year, month.month + 1, 0).day;

  //   final pts = <FlSpot>[];
  //   int maxSteps = 0;

  //   for (int i = 0; i < days; i++) {
  //     final day = start.add(Duration(days: i));
  //     final key = _dayKey(day);
  //     final steps = _box.get(key)?.steps ?? 0;

  //     if (steps > maxSteps) maxSteps = steps;

  //     pts.add(FlSpot(i.toDouble(), steps.toDouble())); // raw steps
  //   }

  //   if (!mounted) return;
  //   setState(() {
  //     _points = pts;
  //     _graphMaxY = maxSteps * 1.1; // 10% padding
  //   });
  // }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
    }

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      return;

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _currentPosition = pos);
    });
  }

  // ===== LABELS =====
  //
  // List<String> _weekLabels() {
  //
  //   final start = _startOfDay(now).subtract(const Duration(days: 6));
  //   return List.generate(7, (i) {
  //     final d = start.add(Duration(days: i));
  //     return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.weekday % 7];
  //   });
  // }
  //
  // List<String> _monthLabels(DateTime month) {
  //   final days = DateTime(month.year, month.month + 1, 0).day;
  //   return List.generate(days, (i) => "${i + 1}");
  // }

  // ===== SWITCH VIEWS =====

  void _toggleView() async {
    setState(() => _isMonthlyView = !_isMonthlyView);

    if (_isMonthlyView) {
      await stepController.loadStepsfromAPI(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );
    }
  }

  void _changeMonth(int delta) async {
    final newMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + delta,
      1,
    );

    setState(() => _selectedMonth = newMonth);

    await stepController.loadStepsfromAPI(
      month: newMonth.month,
      year: newMonth.year,
    );
  }

  // ===== BUILD =====

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final height = media.size.height;
    final width = media.size.width;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Step Counter"),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ===== STEP PROGRESS =====
              Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    children: [
                      Image.asset(run, width: 80, height: 80),
                      const SizedBox(height: 50),
                    ],
                  ),

                  /// ✅ PROGRESS RING (smooth, no reset)
                  Obx(() {
                    final goal = stepController.stepGoal.value;
                    final percent =
                        goal == 0
                            ? 0.0
                            : (stepController.todaySteps.value / goal).clamp(
                              0.0,
                              1.0,
                            );

                    return TweenAnimationBuilder<double>(
                      key: ValueKey(stepController.todaySteps.value),
                      tween: Tween<double>(
                        begin: stepController.lastPercent,
                        end: percent,
                      ),
                      duration: const Duration(milliseconds: 500),
                      builder:
                          (_, val, __) => SemiCircularProgress(
                            percent: val,
                            radius: width / 3,
                            strokeWidth: 12,
                            color: AppColors.primaryColor,
                            backgroundColor: Colors.grey.withOpacity(0.3),
                          ),
                    );
                  }),

                  Column(
                    children: [
                      const SizedBox(height: 90),

                      /// ✅ STEP COUNTER (incremental animation)
                      Obx(() {
                        // Use reactive lastStepsRx so this Obx rebuilds when the
                        // starting value for the animation changes (enables smooth
                        // animation when steps update from background/Hive).
                        final begin = stepController.lastStepsRx.value;
                        final end = stepController.todaySteps.value;

                        return TweenAnimationBuilder<int>(
                          key: ValueKey(end),
                          tween: IntTween(begin: begin, end: end),
                          duration: const Duration(milliseconds: 400),
                          builder:
                              (_, val, __) => Text(
                                "$val",
                                style: const TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        );
                      }),

                      GestureDetector(
                        onTap: () {
                          _secretTapCount++;

                          _secretResetTimer?.cancel();
                          _secretResetTimer = Timer(
                            const Duration(seconds: 2),
                            () {
                              _secretTapCount = 0;
                            },
                          );

                          if (_secretTapCount == 7) {
                            debugPrint("🕵️ Secret API push activated");
                            stepController.saveStepRecordToServer();
                            _secretTapCount = 0;
                          }
                        },
                        child: Text(
                          "Steps",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Obx(
                            () =>
                                Text('Goal: ${stepController.stepGoal.value}'),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              final updated = await showStepCounterBottomSheet(
                                context,
                                isDarkMode,
                              );
                              if (updated != null) {
                                stepController.updateStepGoal(updated);
                              }
                            },
                            child: SvgPicture.asset(
                              pen,
                              color: AppColors.primaryColor,
                              width: 18,
                              height: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // ===== STATS =====
              Obx(() {
                final steps = stepController.todaySteps.value;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _infoItem(dis, '${(steps * 0.0008).toStringAsFixed(2)} km'),
                    _infoItem(cal, '${(steps * 0.04).toStringAsFixed(0)} cal'),
                    _infoItem(time, '${(steps / 100).toStringAsFixed(0)} min'),
                  ],
                );
              }),

              const SizedBox(height: 25),

              // ===== GRAPH HEADER =====
              Column(
                children: [
                  Text(
                    _isMonthlyView ? "Monthly Step Stats" : "Weekly Step Stats",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_isMonthlyView)
                          Row(
                            children: [
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
                          ),
                        TextButton(
                          onPressed: _toggleView,
                          child: Text(
                            _isMonthlyView
                                ? "Switch to Weekly"
                                : "Switch to Monthly",
                            style: TextStyle(color: AppColors.primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ===== GRAPH =====
              SizedBox(
                height: height * 0.41,
                child: Obx(() {
                  final labels =
                      _isMonthlyView
                          ? generateMonthLabels(_selectedMonth)
                          : generateShortWeekdays();

                  final points =
                      _isMonthlyView
                          ? stepController.getMonthlyStepsSpots(_selectedMonth)
                          : stepController.stepSpots
                              .take(daysSinceMonday + 1)
                              .toList();

                  // ✅ Calculate maxY from actual data
                  final double maxSteps =
                      points.isEmpty
                          ? 1000
                          : points
                              .map((e) => e.y)
                              .reduce((a, b) => a > b ? a : b);

                  // ✅ Add padding + minimum scale
                  // final double maxY = (maxSteps * 1.2).clamp(1000, double.infinity);
                  final double rawMax =
                      points.isEmpty
                          ? 0
                          : points
                              .map((e) => e.y)
                              .reduce((a, b) => a > b ? a : b);

                  final double maxY = getDynamicMaxY(rawMax);
                  final double interval = getDynamicInterval(maxY);

                  return StepStatGraphWidget(
                    isDarkMode: isDarkMode,
                    height: height,
                    points: points,

                    weekLabels: labels,
                    yAxisMaxValue: maxY,
                    maxXForWeek: daysSinceMonday,
                    isMonthlyView: _isMonthlyView,
                    graphTitle: 'Steps',
                    maxY: maxY,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int getTodayDayNumber() {
    todayDate = DateTime.now().day;
    return todayDate;
  }

  double getNiceMaxY(double value) {
    if (value <= 1000) return 1000;
    if (value <= 5000) return 5000;
    if (value <= 10000) return 10000;
    if (value <= 20000) return 20000;
    if (value <= 50000) return 50000;
    return (value / 10000).ceil() * 10000;
  }

  double getNiceInterval(double maxY) {
    if (maxY <= 5000) return 1000;
    if (maxY <= 10000) return 2000;
    if (maxY <= 20000) return 5000;
    return 10000;
  }

  double getDynamicMaxY(double value, {double paddingFactor = 1.2}) {
    if (value <= 0) return 1000; // Minimum fallback

    // Apply padding
    double rawMax = value * paddingFactor;

    // Round to nearest "nice" step: 1, 2, 5, 10, 20, 50, 100, 1000, etc.
    double magnitude = pow(10, rawMax.floor().toString().length - 1).toDouble();
    double normalized = rawMax / magnitude;

    double niceNormalized;
    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }

    return niceNormalized * magnitude;
  }

  /// Returns a "nice" interval for Y-axis based on maxY
  double getDynamicInterval(double maxY, {int targetSteps = 5}) {
    if (maxY <= 0) return 1000;

    double rawInterval = maxY / targetSteps;

    // Round to nearest "nice" number (1, 2, 5, 10, etc.)
    double magnitude =
        pow(10, rawInterval.floor().toString().length - 1).toDouble();
    double normalized = rawInterval / magnitude;

    double niceNormalized;
    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }

    return niceNormalized * magnitude;
  }

  List<String> generateShortWeekdays() {
    List<String> shortWeekdays = [];
    DateTime now = DateTime.now();

    daysSinceMonday = (now.weekday - DateTime.monday);

    // Remove time part to avoid carrying 12:48:xx everywhere
    DateTime startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysSinceMonday));

    // 🔥 CHANGE IS HERE
    for (int i = 0; i <= daysSinceMonday; i++) {
      DateTime date = startOfWeek.add(Duration(days: i));
      String dayName = DateFormat('E').format(date);
      shortWeekdays.add(dayName);
    }

    return shortWeekdays;
  }

  // Info Row UI
  Widget _infoItem(String icon, String text) =>
      Column(children: [Image.asset(icon, width: 30, height: 30), Text(text)]);
}

import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/Widgets/CommonWidgets/common_stat_graph_widget.dart';
import 'package:snevva/Widgets/semi_circular_progress.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/steps_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:snevva/views/Information/StepCounter/step_counter_bottom_sheet.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../common/global_variables.dart';

class StepCounter extends StatefulWidget {
  final int? customGoal;

  const StepCounter({super.key, this.customGoal});

  @override
  State<StepCounter> createState() => _StepCounterState();
}

class _StepCounterState extends State<StepCounter> {
  final stepController = Get.find<StepCounterController>();
  final Box<StepEntry> _box = Hive.box<StepEntry>('step_history');

  List<FlSpot> _points = [];
  DateTime _selectedMonth = DateTime.now();
  bool _isMonthlyView = false;

  Position? _currentPosition;
  StreamSubscription<Position>? _locationSub;

  Timer? _uiRefreshTimer;

  double _graphMaxY = 10;

  String _dayKey(DateTime d) => "${d.year}-${d.month}-${d.day}";

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  late final StreamSubscription<BoxEvent> _hiveSub;
  // final service = FlutterBackgroundService();
  // StreamSubscription? _serviceSub;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // _startAndAttachService();
    stepController.loadStepsfromAPI(
      month: DateTime.now().month,
      year: DateTime.now().year,
    );
  }

  // Future<void> _startAndAttachService() async {
  //   final isRunning = await service.isRunning();

  //   if (!isRunning) {
  //     await service.startService();
  //   }

  //   /// Wait for service to be ready
  //   await Future.delayed(const Duration(milliseconds: 300));

  //   // Load data - controller will handle the streaming
  //   stepController.loadGoal();
  //   stepController.loadTodayStepsFromHive();

  //   _loadWeeklyData();
  // }

  // void _onStepsUpdated(dynamic event) {
  //   if (event == null) return;
  //
  //   final newSteps = event["steps"] as int;
  //   final oldSteps = stepController.todaySteps.value;
  //
  //   if (newSteps > oldSteps) {
  //     stepController.incrementSteps(newSteps - oldSteps);
  //   }
  // }

  @override
  void dispose() {
    // No need to cancel _serviceSub anymore
    super.dispose();
  }

  Future<void> toggleStepsCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isStepGoalSet', true);
  }

  Future<void> _loadWeeklyData() async {
    final now = DateTime.now();
    final start = _startOfDay(now).subtract(const Duration(days: 6));

    final pts = <FlSpot>[];
    int maxSteps = 0;

    for (int i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final key = _dayKey(day);
      final steps = _box.get(key)?.steps ?? 0;
      if (steps > maxSteps) maxSteps = steps;
      pts.add(FlSpot(i.toDouble(), steps / 1000.0));
    }

    if (!mounted) return;
    setState(() {
      _points = pts;
      _graphMaxY = ((maxSteps / 1000).ceil() + 2).toDouble();
    });
  }

  Future<void> _loadMonthlyData(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;

    final pts = <FlSpot>[];
    int maxSteps = 0;

    for (int i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      final key = _dayKey(day);
      final steps = _box.get(key)?.steps ?? 0;

      if (steps > maxSteps) maxSteps = steps;

      pts.add(FlSpot(i.toDouble(), steps / 1000.0));
    }

    if (!mounted) return;

    setState(() {
      _points = pts;
      _graphMaxY = ((maxSteps / 1000).ceil() + 2).toDouble();
    });
  }

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
  //   final now = DateTime.now();
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

    // 🔥 LOAD DATA FOR SELECTED MONTH
    await stepController.loadStepsfromAPI(
      month: newMonth.month,
      year: newMonth.year,
    );
  }

  // ===== BUILD =====

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDarkMode = media.platformBrightness == Brightness.dark;
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
                        return TweenAnimationBuilder<int>(
                          key: ValueKey(stepController.todaySteps.value),
                          tween: IntTween(
                            begin: stepController.lastSteps,
                            end: stepController.todaySteps.value,
                          ),
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

                      const Text('Steps', style: TextStyle(fontSize: 16)),

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
                              editIcon,
                              width: 15,
                              height: 15,
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
                height: height * 0.34,
                child: Obx(() {
                  final labels =
                      _isMonthlyView
                          ? generateMonthLabels(_selectedMonth)
                          : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
                  final points =
                      _isMonthlyView
                          ? stepController.getMonthlyStepsSpots(_selectedMonth)
                          : stepController.stepSpots.toList();
                  return CommonStatGraphWidget(
                    isDarkMode: isDarkMode,
                    height: height,
                    isWaterGraph: false,
                    graphTitle: '',
                    isSleepGraph: false,
                    yAxisInterval: 2,
                    yAxisMaxValue: 11,
                    gridLineInterval: 2,
                    measureUnit: 'K',
                    points: points,
                    weekLabels: labels,
                    isMonthlyView: _isMonthlyView,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Info Row UI
  Widget _infoItem(String icon, String text) =>
      Column(children: [Image.asset(icon, width: 30, height: 30), Text(text)]);
}

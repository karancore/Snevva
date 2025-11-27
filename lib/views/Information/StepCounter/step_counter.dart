import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pedometer/pedometer.dart';
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
  int? _lastRaw;
  DateTime _currentDay = DateTime.now();
  DateTime _selectedMonth = DateTime.now();

  bool _isMonthlyView = false;

  Position? _currentPosition;
  Stream<Position>? _positionStream;
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<Position>? _locationSub;
  Timer? _stepSyncTimer;

  double _graphMaxY = 10;

  String _dayKey(DateTime d) => "${d.year}-${d.month}-${d.day}";

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    stepController.loadStepGoal();
    _loadTodaySteps();
    _stepSub = Pedometer.stepCountStream.listen(onStepCount);
    _loadWeeklyData();
    _initLocationTracking();
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _locationSub?.cancel();
    _stepSyncTimer?.cancel();
    super.dispose();
  }

  // ===== LOADERS =====

  Future<void> _loadTodaySteps() async {
    final todayKey = _dayKey(_startOfDay(DateTime.now()));
    final entry = _box.get(todayKey);
    if (!mounted) return;
    setState(() {
      stepController.todaySteps.value = entry?.steps ?? 0;
    });
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
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final pts = <FlSpot>[];
    int maxSteps = 0;

    for (int i = 0; i < daysInMonth; i++) {
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
    if (!serviceEnabled) await Geolocator.openLocationSettings();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    _locationSub = _positionStream!.listen((pos) {
      if (!mounted) return;
      setState(() => _currentPosition = pos);
    });
  }

  // ===== STEP EVENT =====

  void onStepCount(StepCount event) async {
    final now = DateTime.now();
    final today = _startOfDay(now);
    final todayKey = _dayKey(today);

    if (_startOfDay(_currentDay) != today) {
      _currentDay = today;
      stepController.todaySteps.value = 0;
      _lastRaw = event.steps;
      await _box.put(todayKey, StepEntry(date: today, steps: 0));
      await _loadWeeklyData();
      return;
    }

    if (_lastRaw == null) {
      _lastRaw = event.steps;
      return;
    }

    int inc = event.steps - _lastRaw!;
    if (inc < 0) inc = 0;

    stepController.todaySteps.value += inc;
    _lastRaw = event.steps;

    await _box.put(
      todayKey,
      StepEntry(date: today, steps: stepController.todaySteps.value),
    );
    stepController.savetodayStepsLocally();

    _stepSyncTimer?.cancel();
    _stepSyncTimer = Timer(const Duration(hours: 4), () {
      stepController.saveStepRecord(stepController.todaySteps.value);
    });

    if (_isMonthlyView) {
      await _loadMonthlyData(_selectedMonth);
    } else {
      await _loadWeeklyData();
    }
  }

  // ===== LABELS =====

  List<String> _weekLabels() {
    final now = DateTime.now();
    final start = _startOfDay(now).subtract(const Duration(days: 6));
    return List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.weekday % 7];
    });
  }

  List<String> _monthLabels(DateTime month) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    return List.generate(days, (i) => (i + 1).toString());
  }

  // ===== SWITCH VIEWS =====

  void _toggleView() async {
    setState(() => _isMonthlyView = !_isMonthlyView);
    if (_isMonthlyView) {
      await _loadMonthlyData(_selectedMonth);
    } else {
      await _loadWeeklyData();
    }
  }

  void _changeMonth(int delta) async {
    final newMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + delta,
      1,
    );
    setState(() => _selectedMonth = newMonth);
    await _loadMonthlyData(newMonth);
  }

  // ===== BUILD =====

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool isDarkMode = media.platformBrightness == Brightness.dark;
    final height = media.size.height;
    final width = media.size.width;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(
        appbarText: "Step Counter",
        onClose: () {
          // Use Navigator.pop with context check
          print("🟢 Close button tapped");
          print("🟢 Can pop: ${Navigator.canPop(context)}");
          print("🟢 Context mounted: ${context.mounted}");

          try {
            Navigator.of(context).pop();
            print("🟢 Pop successful");
          } catch (e) {
            print("🔴 Pop error: $e");
          }
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // const SizedBox(height: 20),
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
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: (stepController.todaySteps.value /
                            stepController.stepsgoals.value)
                        .clamp(0.0, 1.0),
                  ),
                  duration: const Duration(milliseconds: 800),
                  builder:
                      (_, val, __) => SemiCircularProgress(
                        percent: val,
                        radius: width / 3,
                        strokeWidth: 12,
                        color: AppColors.primaryColor,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                      ),
                ),
                Column(
                  children: [
                    const SizedBox(height: 90),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(
                        begin: 0,
                        end: stepController.todaySteps.value,
                      ),
                      duration: const Duration(milliseconds: 600),
                      builder:
                          (_, val, __) => Text(
                            "$val",
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                    const Text('Steps', style: TextStyle(fontSize: 16)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Obx(
                          () =>
                              Text('Goal: ${stepController.stepsgoals.value}'),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _infoItem(
                  dis,
                  '${(stepController.todaySteps.value * 0.0008).toStringAsFixed(2)} km',
                ),
                _infoItem(
                  cal,
                  '${(stepController.todaySteps.value * 0.04).toStringAsFixed(0)} cal',
                ),
                _infoItem(
                  time,
                  '${(stepController.todaySteps.value / 100).toStringAsFixed(0)} min',
                ),
              ],
            ),

            const SizedBox(height: 25),

            // ===== GRAPH HEADER =====
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isMonthlyView ? "Monthly Step Stats" : "Weekly Step Stats",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
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
              ],
            ),

            const SizedBox(height: 10),

            // ===== GRAPH =====
            Expanded(
              child: CommonStatGraphWidget(
                isDarkMode: isDarkMode,
                height: 20,
                graphTitle: '',
                yAxisInterval: (_graphMaxY / 5).ceilToDouble(),
                yAxisMaxValue: _graphMaxY,
                gridLineInterval: (_graphMaxY / 5).ceilToDouble(),
                points: _points,
                measureUnit: 'K',
                weekLabels:
                    _isMonthlyView
                        ? _monthLabels(_selectedMonth)
                        : _weekLabels(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String icon, String text) =>
      Column(children: [Image.asset(icon, width: 30, height: 30), Text(text)]);
}

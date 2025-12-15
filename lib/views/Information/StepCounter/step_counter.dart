import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/Widgets/CommonWidgets/common_stat_graph_widget.dart';
import 'package:snevva/Widgets/semi_circular_progress.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/steps_model.dart';
import 'package:snevva/views/Information/StepCounter/step_counter_bottom_sheet.dart';

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

  double _graphMaxY = 10;

  String _dayKey(DateTime d) => "${d.year}-${d.month}-${d.day}";
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
    // _initLocationTracking(); // optional
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  // ===== LOADERS =====
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
    return List.generate(days, (i) => "${i + 1}");
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
    final newMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    setState(() => _selectedMonth = newMonth);
    await _loadMonthlyData(newMonth);
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

                // semi-circle progress
                Obx(() {
                  final percent =
                      (stepController.todaySteps.value / stepController.stepGoal.value)
                          .clamp(0.0, 1.0);

                  return SemiCircularProgress(
                    percent: percent,
                    radius: width / 3,
                    strokeWidth: 12,
                    color: AppColors.primaryColor,
                    backgroundColor: Colors.grey.withOpacity(0.3),
                  );
                }),

                // Steps text & goal
                Column(
                  children: [
                    const SizedBox(height: 90),
                    Obx(() => Text(
                          "${stepController.todaySteps.value}",
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                          ),
                        )),
                    const Text('Steps', style: TextStyle(fontSize: 16)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Obx(() => Text('Goal: ${stepController.stepGoal.value}')),
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
                          child: SvgPicture.asset(editIcon, width: 15, height: 15),
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
                        _isMonthlyView ? "Switch to Weekly" : "Switch to Monthly",
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
                weekLabels: _isMonthlyView
                    ? _monthLabels(_selectedMonth)
                    : _weekLabels(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Info Row UI
  Widget _infoItem(String icon, String text) =>
      Column(children: [Image.asset(icon, width: 30, height: 30), Text(text)]);
}

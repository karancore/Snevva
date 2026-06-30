import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/widgets/CommonWidgets/step_stat_graph_widget.dart';

import '../../../widgets/Drawer/drawer_menu_wigdet.dart';

class StepReportScreen extends StatefulWidget {
  const StepReportScreen({super.key});

  @override
  State<StepReportScreen> createState() => _StepReportScreenState();
}

class _StepReportScreenState extends State<StepReportScreen> {
  final stepController = Get.find<StepCounterController>();

  /// 0 = current week, 1 = last week, etc.
  int _weekOffset = 0;
  DateTime _selectedMonth = DateTime.now();
  bool _isMonthlyView = false;
  bool _showingAverage = false;

  // Plain (non-Rx) display state — driven by setState
  int _displaySteps = 0;
  String _displayLabel = '';

  // ───────── week helpers ─────────

  DateTime _mondayOfWeek(int offset) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    return monday.subtract(Duration(days: offset * 7));
  }

  int _daysInWeek(int offset) =>
      offset == 0 ? DateTime
          .now()
          .weekday : 7;

  List<String> _weekLabelsForOffset(int offset) {
    final monday = _mondayOfWeek(offset);
    return List.generate(_daysInWeek(offset), (i) {
      return DateFormat('E').format(monday.add(Duration(days: i)));
    });
  }

  List<FlSpot> _weekSpotsForOffset(int offset) {
    final monday = _mondayOfWeek(offset);
    // Read directly from the map snapshot — no reactive read inside build
    final mapSnapshot = Map<String, int>.from(
        stepController.stepsHistoryByDate);
    return List.generate(_daysInWeek(offset), (i) {
      final d = monday.add(Duration(days: i));
      final key =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day
          .toString()
          .padLeft(2, '0')}";
      return FlSpot(i.toDouble(), (mapSnapshot[key] ?? 0).toDouble());
    });
  }

  String _weekRangeLabel(int offset) {
    final monday = _mondayOfWeek(offset);
    final last = monday.add(Duration(days: _daysInWeek(offset) - 1));
    final fmt = DateFormat('d MMM');
    return "${fmt.format(monday)} – ${fmt.format(last)}";
  }

  // ───────── average helpers ─────────

  int _weekAverage(int offset) {
    final spots = _weekSpotsForOffset(offset);
    if (spots.isEmpty) return 0;
    return (spots.fold<double>(0, (s, p) => s + p.y) / spots.length).round();
  }

  int _monthAverage(DateTime month) {
    final spots = stepController.getMonthlyStepsSpots(month);
    final nonZero = spots.where((p) => p.y > 0).toList();
    if (nonZero.isEmpty) return 0;
    return (nonZero.fold<double>(0, (s, p) => s + p.y) / nonZero.length)
        .round();
  }

  // ───────── actions ─────────

  void _setAverage() {
    if (_isMonthlyView) {
      setState(() {
        _showingAverage = true;
        _displaySteps = _monthAverage(_selectedMonth);
        _displayLabel =
        "Avg – ${DateFormat('MMMM yyyy').format(_selectedMonth)}";
      });
    } else {
      setState(() {
        _showingAverage = true;
        _displaySteps = _weekAverage(_weekOffset);
        _displayLabel = "Avg – ${_weekRangeLabel(_weekOffset)}";
      });
    }
  }

  void _toggleView() async {
    setState(() => _isMonthlyView = !_isMonthlyView);
    if (_isMonthlyView) {
      await stepController.loadStepsfromAPI(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );
    }
    _setAverage();
  }

  void _changeMonth(int delta) async {
    final newMonth =
    DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    setState(() => _selectedMonth = newMonth);
    await stepController.loadStepsfromAPI(
      month: newMonth.month,
      year: newMonth.year,
    );
    _setAverage();
  }

  void _changeWeek(int delta) {
    setState(() => _weekOffset = (_weekOffset + delta).clamp(0, 52));
    _setAverage();
  }

  // ───────── lifecycle ─────────

  Worker? _mapWorker;

  @override
  void initState() {
    super.initState();
    // Rebuild graph when HealthKit data arrives asynchronously (iOS).
    _mapWorker = ever(stepController.stepsHistoryByDate, (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setAverage();
    });
  }

  @override
  void dispose() {
    _mapWorker?.dispose();
    super.dispose();
  }

  // ───────── graph data (pure, no reactive reads) ─────────

  double _dynamicMaxY(double value) {
    if (value <= 0) return 1000;
    final rawMax = value * 1.2;
    final magnitude =
    pow(10, rawMax
        .floor()
        .toString()
        .length - 1).toDouble();
    final normalized = rawMax / magnitude;
    final nice =
    normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
    return nice * magnitude;
  }

  // ───────── UI helpers ─────────

  Widget _buildKeyPointCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required String iconPath,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? darkGray : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(iconPath, width: 36, height: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────── build ─────────

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Resolve graph data once per build (plain reads, no Obx needed)
    final List<String> labels;
    final List<FlSpot> points;
    final int highlightIdx;

    if (_isMonthlyView) {
      labels = generateMonthLabels(_selectedMonth);
      // getMonthlyStepsSpots reads stepsHistoryList — plain getter, safe here
      points = stepController.getMonthlyStepsSpots(_selectedMonth);
      highlightIdx =
      (_selectedMonth.year == DateTime
          .now()
          .year &&
          _selectedMonth.month == DateTime
              .now()
              .month)
          ? getCurrentDateIndex()
          : -1;
    } else {
      labels = _weekLabelsForOffset(_weekOffset);
      points = _weekSpotsForOffset(_weekOffset);
      highlightIdx = _weekOffset == 0 ? (DateTime
          .now()
          .weekday - 1) : -1;
    }

    final double rawMax = points.isEmpty
        ? 0
        : points.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final double maxY = _dynamicMaxY(rawMax);

    // Metric card values
    final int steps = _displaySteps;
    final String distanceKm = (steps * 0.0008).toStringAsFixed(2);
    final String calories = (steps * 0.04).toStringAsFixed(0);
    final String durationMins = (steps / 100).toStringAsFixed(0);
    final int goal = stepController.stepGoal.value; // plain read, fine here
    final String progressPct =
        '${(goal > 0 ? (steps / goal * 100) : 0).toStringAsFixed(0)}%';

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: const CustomAppBar(appbarText: 'Step Report'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Text(
                _displayLabel.isNotEmpty ? _displayLabel : "Step Analysis",
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                "$steps steps",
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold),
              ),

              // ── Navigation row ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (!_isMonthlyView) ...[
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: "Previous week",
                        onPressed: () => _changeWeek(1),
                      ),
                      Text(_weekRangeLabel(_weekOffset),
                          style: const TextStyle(fontSize: 13)),
                      IconButton(
                        icon: Icon(Icons.chevron_right,
                            color: _weekOffset == 0
                                ? Colors.grey.shade400
                                : null),
                        onPressed:
                        _weekOffset == 0 ? null : () => _changeWeek(-1),
                      ),
                    ],
                    if (_isMonthlyView) ...[
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _changeMonth(-1),
                      ),
                      Text(DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: const TextStyle(fontSize: 14)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _changeMonth(1),
                      ),
                    ],
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

              const SizedBox(height: 8),

              // ── Graph (pure setState widget, no Obx) ──
              SizedBox(
                height: height * 0.37,
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final dx = details.primaryVelocity ?? 0;
                    if (_isMonthlyView) {
                      if (dx > 300) _changeMonth(-1);
                      if (dx < -300) _changeMonth(1);
                    } else {
                      if (dx > 300) _changeWeek(1);
                      if (dx < -300 && _weekOffset > 0) _changeWeek(-1);
                    }
                  },
                  child: StepStatGraphWidget(
                    isDarkMode: isDarkMode,
                    height: height,
                    graphTitle: 'Step Statistics',
                    points: points,
                    maxXForWeek: _isMonthlyView ? 0 : highlightIdx,
                    isMonthlyView: _isMonthlyView,
                    weekLabels: labels,
                    yAxisMaxValue: maxY,
                    maxY: maxY,
                    selectedMonthForHeader:
                    _isMonthlyView ? _selectedMonth : null,
                    highlightIndex: highlightIdx,
                    onBarTouched: (index, spot) {
                      DateTime tappedDate;
                      if (_isMonthlyView) {
                        tappedDate = DateTime(_selectedMonth.year,
                            _selectedMonth.month, index + 1);
                      } else {
                        tappedDate =
                            _mondayOfWeek(_weekOffset).add(Duration(
                                days: index));
                      }
                      setState(() {
                        _showingAverage = false;
                        _displaySteps = spot.y.toInt();
                        _displayLabel =
                        "${tappedDate.day}-${tappedDate.month}-${tappedDate
                            .year}";
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Highlights label ──
              Text(
                _showingAverage ? "Average Highlights" : "Step Highlights",
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              // ── Metric cards (pure setState, no Obx) ──
              Row(
                children: [
                  Expanded(
                    child: _buildKeyPointCard(
                      title: 'Progress',
                      value: progressPct,
                      subtitle: '/goal',
                      color: Colors.blue,
                      iconPath: run,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKeyPointCard(
                      title: 'Calories',
                      value: calories,
                      subtitle: 'cal',
                      color: Colors.orange,
                      iconPath: cal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildKeyPointCard(
                      title: 'Distance',
                      value: distanceKm,
                      subtitle: 'km',
                      color: Colors.teal,
                      iconPath: dis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKeyPointCard(
                      title: 'Duration',
                      value: durationMins,
                      subtitle: 'min',
                      color: Colors.deepPurple,
                      iconPath: time,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
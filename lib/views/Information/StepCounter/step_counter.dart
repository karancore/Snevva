import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/common/common_tips_controller.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Information/StepCounter/step_counter_bottom_sheet.dart';
import 'package:snevva/widgets/common/common_tip_widget.dart';
import 'package:snevva/widgets/semi_circular_progress.dart';

import '../../../common/global_variables.dart';
import '../../../widgets/CommonWidgets/custom_appbar.dart';
import '../../../widgets/CommonWidgets/step_stat_graph_widget.dart';
import '../../../widgets/Drawer/drawer_menu_wigdet.dart';
import 'step_report_screen.dart';

class StepCounter extends StatefulWidget {
  final int? customGoal;

  const StepCounter({super.key, this.customGoal});

  @override
  State<StepCounter> createState() => _StepCounterState();
}

class _StepCounterState extends State<StepCounter> with WidgetsBindingObserver {
  final stepController = Get.find<StepCounterController>();

  /// 0 = current week, 1 = previous week, etc.
  int _weekOffset = 0;

  DateTime _selectedMonth = DateTime.now();
  bool _isMonthlyView = false;

  Timer? _uiRefreshTimer;
  Timer? _debounce;
  int _secretTapCount = 0;
  Timer? _secretResetTimer;

  late CommonTipsController commonTipsController;
  final ScrollController _scrollController = ScrollController();

  // ───────── week helpers ─────────

  DateTime _mondayOfWeek(int offset) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    return monday.subtract(Duration(days: offset * 7));
  }

  int _daysInWeek(int offset) {
    if (offset == 0) return DateTime.now().weekday; // Mon=1…Sun=7
    return 7;
  }

  List<String> _weekLabelsForOffset(int offset) {
    final monday = _mondayOfWeek(offset);
    final count = _daysInWeek(offset);
    return List.generate(count, (i) {
      final d = monday.add(Duration(days: i));
      return DateFormat('E').format(d);
    });
  }

  List<FlSpot> _weekSpotsForOffset(int offset) {
    final monday = _mondayOfWeek(offset);
    final count = _daysInWeek(offset);
    final spots = <FlSpot>[];
    for (int i = 0; i < count; i++) {
      final d = monday.add(Duration(days: i));
      final key =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      final steps = stepController.stepsHistoryByDate[key] ?? 0;
      spots.add(FlSpot(i.toDouble(), steps.toDouble()));
    }
    return spots;
  }

  String _weekRangeLabel(int offset) {
    final monday = _mondayOfWeek(offset);
    final lastDay = monday.add(Duration(days: _daysInWeek(offset) - 1));
    final fmt = DateFormat('d MMM');
    return "${fmt.format(monday)} – ${fmt.format(lastDay)}";
  }

  void _changeWeek(int delta) {
    setState(() {
      _weekOffset = (_weekOffset + delta).clamp(0, 52);
    });
  }

  // ───────── month helpers ─────────

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

  // ───────── lifecycle ─────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    commonTipsController = Get.find<CommonTipsController>();
    _scrollController.addListener(_onTipsScroll);
    commonTipsController.getCommonTips(context: context, tag: 'Steps');
    stepController.activateRealtimeTracking();
    stepController.loadTodayStepsFromFile();
  }

  void _onTipsScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      commonTipsController.loadMoreCommonTips(context);
    }
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _debounce?.cancel();
    _secretResetTimer?.cancel();
    _scrollController.removeListener(_onTipsScroll);
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    stepController.deactivateRealtimeTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔁 App resumed - reloading steps from file');
      stepController.loadTodayStepsFromFile();
    }
  }

  Future<void> toggleStepsCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isStepGoalSet', true);
  }

  // ───────── dynamic Y helpers ─────────

  double getDynamicMaxY(double value, {double paddingFactor = 1.2}) {
    if (value <= 0) return 1000;
    double rawMax = value * paddingFactor;
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

  double getDynamicInterval(double maxY, {int targetSteps = 5}) {
    if (maxY <= 0) return 1000;
    double rawInterval = maxY / targetSteps;
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

  // ───────── build ─────────

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
          controller: _scrollController,
          child: Column(
            children: [
              // ── Progress ring ──
              Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    children: [
                      Image.asset(run, width: 80, height: 80),
                      const SizedBox(height: 50),
                    ],
                  ),
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
                          (_, val, _) => SemiCircularProgress(
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
                      Obx(() {
                        final begin = stepController.lastStepsRx.value;
                        final end = stepController.todaySteps.value;
                        return TweenAnimationBuilder<int>(
                          key: ValueKey(end),
                          tween: IntTween(begin: begin, end: end),
                          duration: const Duration(milliseconds: 400),
                          builder:
                              (_, val, _) => Text(
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
                            () => _secretTapCount = 0,
                          );
                          if (_secretTapCount == 7) {
                            debugPrint("🕵️ Secret API push activated");
                            stepController.saveStepRecordToServer();
                            _secretTapCount = 0;
                          }
                        },
                        child: const Text(
                          "Steps",
                          style: TextStyle(fontSize: 16),
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

              // ── Stats row ──
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

              // ── Graph header ──
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
                        // Week navigation
                        if (!_isMonthlyView) ...[
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            tooltip: "Previous week",
                            onPressed: () => _changeWeek(1),
                          ),
                          Text(
                            _weekRangeLabel(_weekOffset),
                            style: const TextStyle(fontSize: 13),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.chevron_right,
                              color:
                                  _weekOffset == 0
                                      ? Colors.grey.shade400
                                      : null,
                            ),
                            onPressed:
                                _weekOffset == 0 ? null : () => _changeWeek(-1),
                          ),
                        ],
                        // Month navigation
                        if (_isMonthlyView) ...[
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

              // ── Graph ──
              SizedBox(
                height: height * 0.37,
                child: Obx(() {
                  final List<String> labels;
                  final List<FlSpot> points;
                  final int maxXForWeek;

                  if (_isMonthlyView) {
                    labels = generateMonthLabels(_selectedMonth);
                    points = stepController.getMonthlyStepsSpots(
                      _selectedMonth,
                    );
                    maxXForWeek = 0;
                  } else {
                    labels = _weekLabelsForOffset(_weekOffset);
                    points = _weekSpotsForOffset(_weekOffset);
                    maxXForWeek = _daysInWeek(_weekOffset) - 1;
                  }

                  final double rawMax =
                      points.isEmpty
                          ? 0
                          : points
                              .map((e) => e.y)
                              .reduce((a, b) => a > b ? a : b);
                  final double maxY = getDynamicMaxY(rawMax);

                  return GestureDetector(
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
                      points: points,
                      weekLabels: labels,
                      yAxisMaxValue: maxY,
                      maxXForWeek: maxXForWeek,
                      isMonthlyView: _isMonthlyView,
                      graphTitle: 'Steps',
                      maxY: maxY,
                      selectedMonthForHeader:
                          _isMonthlyView ? _selectedMonth : null,
                      highlightIndex:
                          _isMonthlyView
                              ? (_selectedMonth.year == DateTime.now().year &&
                                      _selectedMonth.month ==
                                          DateTime.now().month
                                  ? getCurrentDateIndex()
                                  : -1)
                              : (_weekOffset == 0
                                  ? (DateTime.now().weekday - 1)
                                  : -1),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // ── Step Report nav card ──
              GestureDetector(
                onTap: () => Get.to(() => const StepReportScreen()),
                child: Container(
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.analytics_outlined,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "View Step Report",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Detailed analysis of your steps",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
              CommonTipsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(String icon, String text) =>
      Column(children: [Image.asset(icon, width: 30, height: 30), Text(text)]);
}

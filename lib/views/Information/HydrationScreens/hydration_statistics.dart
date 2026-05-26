import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/widgets/CommonWidgets/common_stat_graph_widget.dart';

import '../../../Controllers/common/common_tips_controller.dart';
import '../../../common/global_variables.dart';
import '../../../consts/consts.dart';
import '../../../models/water_history_model.dart';
import '../../../widgets/common/common_tip_widget.dart';

class HydrationStatistics extends StatefulWidget {
  const HydrationStatistics({super.key});

  @override
  State<HydrationStatistics> createState() => _HydrationStatisticsState();
}

class _HydrationStatisticsState extends State<HydrationStatistics> {
  final controller = Get.find<HydrationStatController>();
  late CommonTipsController commonTipsController;
  final ScrollController _scrollController = ScrollController();

  // ── view state ──────────────────────────────────────────────────
  bool _isMonthlyView = false;
  DateTime _selectedMonth = DateTime.now();
  int _weekOffset = 0; // 0 = current week, -1 = last week, etc.

  // ── display values (pure setState, no Rx) ───────────────────────
  int _displayMl = 0; // ml to show in header
  String _displayLabel = ''; // e.g. "Avg – May 2026" or "12-5-2026"
  bool _showingAverage = false; // true = avg mode, false = tapped-bar mode

  // ── cached graph data ────────────────────────────────────────────
  List<FlSpot> _graphSpots = [];
  List<String> _graphLabels = [];
  double _maxY = 3;
  double _interval = 1;
  int _highlightIndex = -1;

  // ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    commonTipsController = Get.find<CommonTipsController>();
    _scrollController.addListener(_onTipsScroll);
    commonTipsController.getCommonTips(context: context, tag: 'Water');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.loadWaterIntakefromAPI(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );
      _rebuildGraph();
      _setAverage();
    });
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
    _scrollController.removeListener(_onTipsScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ── Monday of the displayed week ────────────────────────────────
  DateTime _mondayOfWeek() {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    return monday.add(Duration(days: 7 * _weekOffset));
  }

  // ── Week spots for _weekOffset ───────────────────────────────────
  List<FlSpot> _weekSpotsForOffset() {
    final monday = _mondayOfWeek();
    final now = DateTime.now();
    final isCurrentWeek = _weekOffset == 0;
    final history = Map<String, int>.from(controller.waterHistoryByDate);
    final List<FlSpot> spots = [];

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      if (isCurrentWeek && date.isAfter(now)) break;
      // Controller key format: "yyyy-M-d" (no zero-padding)
      final key = '${date.year}-${date.month}-${date.day}';
      final ml = history[key] ?? 0;
      spots.add(FlSpot(i.toDouble(), ml / 1000.0));
    }
    return spots;
  }

  List<String> _weekLabelsForOffset() {
    final monday = _mondayOfWeek();
    final now = DateTime.now();
    final isCurrentWeek = _weekOffset == 0;
    final labels = <String>[];
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      if (isCurrentWeek && date.isAfter(now)) break;
      labels.add(DateFormat('E').format(date));
    }
    return labels;
  }

  String _weekRangeLabel() {
    final monday = _mondayOfWeek();
    final sunday = monday.add(const Duration(days: 6));
    return '${DateFormat('d MMM').format(monday)} – ${DateFormat('d MMM').format(sunday)}';
  }

  // ── Rebuild cached graph data ────────────────────────────────────
  void _rebuildGraph() {
    final spots =
        _isMonthlyView
            ? controller.getMonthlyWaterSpots(_selectedMonth)
            : _weekSpotsForOffset();

    final labels =
        _isMonthlyView
            ? generateMonthLabels(_selectedMonth)
            : _weekLabelsForOffset();

    final rawMax =
        spots.isEmpty
            ? 0.0
            : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxY = getNiceHydrationMaxY(rawMax);
    final interval = getNiceHydrationInterval(maxY);

    // Highlight: current week → today's column; past week / monthly → none
    int highlight = -1;
    if (!_isMonthlyView && _weekOffset == 0) {
      final now = DateTime.now();
      highlight = now.weekday - DateTime.monday; // 0=Mon … 6=Sun
      if (highlight >= labels.length) highlight = labels.length - 1;
    }

    setState(() {
      _graphSpots = spots;
      _graphLabels = labels;
      _maxY = maxY == 0 ? 3 : maxY;
      _interval = interval == 0 ? 1 : interval;
      _highlightIndex = highlight;
    });
  }

  // ── Average for current view ─────────────────────────────────────
  void _setAverage() {
    final nonZero = _graphSpots.where((s) => s.y > 0).toList();

    if (nonZero.isEmpty) {
      setState(() {
        _displayMl = 0;
        _displayLabel =
            _isMonthlyView
                ? 'Avg – ${DateFormat('MMMM yyyy').format(_selectedMonth)}'
                : 'Avg – ${_weekRangeLabel()}';
        _showingAverage = true;
      });
      return;
    }

    final avgMl =
        (nonZero.map((s) => s.y).reduce((a, b) => a + b) /
                nonZero.length *
                1000)
            .round();

    setState(() {
      _displayMl = avgMl;
      _displayLabel =
          _isMonthlyView
              ? 'Avg – ${DateFormat('MMMM yyyy').format(_selectedMonth)}'
              : 'Avg – ${_weekRangeLabel()}';
      _showingAverage = true;
    });
  }

  // ── Toggle weekly / monthly ──────────────────────────────────────
  Future<void> _toggleView() async {
    final next = !_isMonthlyView;
    if (next) {
      await controller.loadWaterIntakefromAPI(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );
    }
    setState(() => _isMonthlyView = next);
    _rebuildGraph();
    _setAverage();
  }

  // ── Month navigation ─────────────────────────────────────────────
  Future<void> _changeMonth(int delta) async {
    final newMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + delta,
      1,
    );
    setState(() => _selectedMonth = newMonth);
    await controller.loadWaterIntakefromAPI(
      month: newMonth.month,
      year: newMonth.year,
    );
    _rebuildGraph();
    _setAverage();
  }

  // ── Week navigation ──────────────────────────────────────────────
  Future<void> _changeWeek(int delta) async {
    final next = _weekOffset + delta;
    if (next > 0) return;
    setState(() => _weekOffset = next);

    // If the displayed week falls in a different month, fetch that month's data
    final monday = _mondayOfWeek();
    if (monday.month != DateTime.now().month ||
        monday.year != DateTime.now().year) {
      await controller.loadWaterIntakefromAPI(
        month: monday.month,
        year: monday.year,
      );
    }
    _rebuildGraph();
    _setAverage();
  }

  // ── Swipe handler ────────────────────────────────────────────────
  void _onHorizontalDrag(DragEndDetails details) {
    const kVelocityThreshold = 300.0;
    final vx = details.primaryVelocity ?? 0;
    if (vx.abs() < kVelocityThreshold) return;

    if (_isMonthlyView) {
      if (vx > 0) {
        _changeMonth(-1);
      } else {
        if (_selectedMonth.year < DateTime.now().year ||
            _selectedMonth.month < DateTime.now().month) {
          _changeMonth(1);
        }
      }
    } else {
      if (vx > 0) {
        _changeWeek(-1);
      } else {
        _changeWeek(1);
      }
    }
  }

  // ── Bar touched ──────────────────────────────────────────────────
  void _onBarTouched(int index, FlSpot spot) {
    DateTime tappedDate;
    if (_isMonthlyView) {
      tappedDate = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        index + 1,
      );
    } else {
      tappedDate = _mondayOfWeek().add(Duration(days: index));
    }

    setState(() {
      _displayMl = (spot.y * 1000).round();
      _displayLabel =
          '${tappedDate.day}-${tappedDate.month}-${tappedDate.year}';
      _showingAverage = false;
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────
  List<WaterHistoryModel> _filterForDay(
    List<WaterHistoryModel> historyList,
    DateTime day,
  ) {
    return historyList.where((entry) {
      return entry.year == day.year &&
          entry.month == day.month &&
          entry.day == day.day;
    }).toList();
  }

  Widget _buildKeyPointCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyStateContainer(double height, bool isDarkMode) {
    return Container(
      height: height * 0.3,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: mediumGrey, width: border04px),
      ),
      child: Text(
        _isMonthlyView
            ? 'No data available for this month.'
            : 'No data available for this week.',
        style: const TextStyle(color: Colors.grey, fontSize: 14),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Hydration highlight values derived from _displayMl
    final intakeLiters = _displayMl / 1000.0;
    final goalLiters = controller.waterGoal.value / 1000.0;
    final progressPercent =
        goalLiters > 0
            ? ((_displayMl / controller.waterGoal.value) * 100)
                .clamp(0, 100)
                .toStringAsFixed(0)
            : '0';
    final cups = (_displayMl / 240).toStringAsFixed(1);

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: const CustomAppBar(appbarText: 'Hydration Statistics'),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: selected intake ─────────────────────────
              Text(
                _showingAverage ? _displayLabel : 'Hydration on $_displayLabel',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_displayMl ml',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // ── Navigation bar ─────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Week nav
                    if (!_isMonthlyView) ...[
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _changeWeek(-1),
                      ),
                      Text(
                        _weekRangeLabel(),
                        style: const TextStyle(fontSize: 13),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: _weekOffset < 0 ? null : Colors.grey,
                        ),
                        onPressed:
                            _weekOffset < 0 ? () => _changeWeek(1) : null,
                      ),
                    ],
                    // Month nav
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
                            ? 'Switch to Weekly'
                            : 'Switch to Monthly',
                        style: const TextStyle(color: AppColors.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Graph (swipeable) ───────────────────────────────
              // isLoading is Obx-safe here — we only read it to show a loader,
              // the graph itself is pure setState so no bad-Obx risk.
              Obx(() {
                if (controller.isLoading.value) {
                  return SizedBox(
                    height: height * 0.37,
                    child: const AppLoader(),
                  );
                }
                return const SizedBox.shrink();
              }),

              // Graph rendered from pure setState data — no Obx wrapper
              if (!controller.isLoading.value)
                GestureDetector(
                  onHorizontalDragEnd: _onHorizontalDrag,
                  child: SizedBox(
                    height: height * 0.37,
                    child:
                        _graphSpots.isEmpty
                            ? _emptyStateContainer(height, isDarkMode)
                            : CommonStatGraphWidget(
                              isMonthlyView: _isMonthlyView,
                              isWaterGraph: true,
                              isDarkMode: isDarkMode,
                              height: height,
                              graphTitle: 'Hydration Statistics',
                              yAxisInterval: _interval,
                              yAxisMaxValue: _maxY,
                              gridLineInterval: _interval,
                              points: _graphSpots,
                              weekLabels: _graphLabels,
                              measureUnit: 'L',
                              isSleepGraph: false,
                              highlightIndex: _highlightIndex,
                              selectedMonthForHeader: _selectedMonth,
                              onBarTouched: _onBarTouched,
                            ),
                  ),
                ),

              const SizedBox(height: 24),

              // ── Section title ──────────────────────────────────
              Text(
                _showingAverage ? 'Average Highlights' : 'Hydration Highlights',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // ── Metric cards (pure setState values) ────────────
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildKeyPointCard(
                          title: 'Intake',
                          value: _displayMl.toString(),
                          subtitle: 'ml',
                          color: Colors.blue,
                          icon: Icons.water_drop_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKeyPointCard(
                          title: 'In Liters',
                          value: intakeLiters.toStringAsFixed(2),
                          subtitle: 'L',
                          color: Colors.teal,
                          icon: Icons.local_drink_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKeyPointCard(
                          title: 'Goal Progress',
                          value: progressPercent,
                          subtitle: '%',
                          color: Colors.green,
                          icon: Icons.flag_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKeyPointCard(
                          title: 'Cups (240ml)',
                          value: cups,
                          subtitle: 'cups',
                          color: Colors.deepPurple,
                          icon: Icons.coffee_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const CommonTipsList(),
            ],
          ),
        ),
      ),
    );
  }
}

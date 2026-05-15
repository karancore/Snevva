import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/widgets/CommonWidgets/common_stat_graph_widget.dart';
import 'package:snevva/widgets/CommonWidgets/custom_appbar.dart';

import '../../../Controllers/SleepScreen/sleep_controller.dart';
import '../../../Widgets/Drawer/drawer_menu_wigdet.dart';

class SleepReportScreen extends StatefulWidget {
  const SleepReportScreen({super.key});

  @override
  State<SleepReportScreen> createState() => _SleepReportScreenState();
}

class _SleepReportScreenState extends State<SleepReportScreen> {
  final sleepController = Get.find<SleepController>();

  // ── view state ──────────────────────────────────────────────────
  bool _isMonthlyView = false;
  DateTime _selectedMonth = DateTime.now();
  int _weekOffset = 0; // 0 = current week, -1 = last week, etc.

  // ── display values (plain state, no Rx) ─────────────────────────
  int _displayMinutes = 0; // total minutes to show in header
  String _displayLabel = ''; // e.g. "Avg – May 2026" or "12-5-2026"
  bool _showingAverage = false; // true = avg mode, false = tapped-bar mode

  // ── cached graph data ────────────────────────────────────────────
  List<FlSpot> _weekSpots = [];
  List<String> _weekLabels = [];
  List<FlSpot> _monthSpots = [];
  List<String> _monthLabels = [];
  double _maxY = 8;
  double _interval = 2;
  int _highlightIndex = -1;

  // ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (sleepController.weeklyDeepSleepHistory.isEmpty) {
        await sleepController.loadDeepSleepData();
      }
      _rebuildGraph();
      _setAverage();
    });
  }

  // ── Monday of the displayed week ────────────────────────────────
  DateTime _mondayOfWeek() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    return monday.add(Duration(days: 7 * _weekOffset));
  }

  // ── Build week spots for the current _weekOffset ─────────────────
  List<FlSpot> _weekSpotsForOffset() {
    final monday = _mondayOfWeek();
    final history =
    Map<String, Duration>.from(sleepController.weeklyDeepSleepHistory)
      ..addAll(Map<String, Duration>.from(
          sleepController.monthlyDeepSleepHistory));

    final List<FlSpot> spots = [];
    final now = DateTime.now();
    final isCurrentWeek = _weekOffset == 0;

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      // For current week, don't show future days
      if (isCurrentWeek && date.isAfter(now)) break;
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day
          .toString().padLeft(2, '0')}';
      final minutes = history[key]?.inMinutes ?? 0;
      spots.add(FlSpot(i.toDouble(), minutes / 60.0));
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
    return '${DateFormat('d MMM').format(monday)} – ${DateFormat('d MMM')
        .format(sunday)}';
  }

  // ── Rebuild all cached graph data (call after any nav change) ────
  void _rebuildGraph() {
    final spots = _isMonthlyView
        ? (sleepController.monthlySleepSpots.isNotEmpty
        ? sleepController.monthlySleepSpots.toList()
        : <FlSpot>[])
        : _weekSpotsForOffset();

    final labels = _isMonthlyView
        ? generateMonthLabels(_selectedMonth)
        : _weekLabelsForOffset();

    final rawMax = spots.isEmpty
        ? 0.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxY = getNiceSleepMaxY(rawMax);
    final interval = getNiceSleepInterval(maxY);

    // Highlight: current week → today's column; past week / monthly → nothing
    int highlight = -1;
    if (!_isMonthlyView && _weekOffset == 0) {
      final now = DateTime.now();
      highlight = now.weekday - DateTime.monday; // 0=Mon … 6=Sun
      if (highlight >= labels.length) highlight = labels.length - 1;
    }

    setState(() {
      _weekSpots = spots;
      _weekLabels = labels;
      _monthSpots = spots;
      _monthLabels = labels;
      _maxY = maxY == 0 ? 8 : maxY;
      _interval = interval == 0 ? 2 : interval;
      _highlightIndex = highlight;
    });
  }

  // ── Compute and display average for the current view ─────────────
  void _setAverage() {
    final spots = _isMonthlyView ? _monthSpots : _weekSpots;
    final nonZero = spots.where((s) => s.y > 0).toList();

    if (nonZero.isEmpty) {
      setState(() {
        _displayMinutes = 0;
        _displayLabel = _isMonthlyView
            ? 'Avg – ${DateFormat('MMMM yyyy').format(_selectedMonth)}'
            : 'Avg – ${_weekRangeLabel()}';
        _showingAverage = true;
      });
      return;
    }

    final avgMinutes =
    (nonZero.map((s) => s.y).reduce((a, b) => a + b) / nonZero.length *
        60)
        .round();

    setState(() {
      _displayMinutes = avgMinutes;
      _displayLabel = _isMonthlyView
          ? 'Avg – ${DateFormat('MMMM yyyy').format(_selectedMonth)}'
          : 'Avg – ${_weekRangeLabel()}';
      _showingAverage = true;
    });
  }

  // ── Toggle weekly / monthly ──────────────────────────────────────
  Future<void> _toggleView() async {
    final next = !_isMonthlyView;
    if (next) {
      await sleepController.loadMonthlySleep(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );
    } else {
      await sleepController.loadDeepSleepData();
    }
    setState(() => _isMonthlyView = next);
    _rebuildGraph();
    _setAverage();
  }

  // ── Month navigation ─────────────────────────────────────────────
  Future<void> _changeMonth(int delta) async {
    final newMonth =
    DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    setState(() => _selectedMonth = newMonth);
    await sleepController.loadMonthlySleep(
      month: newMonth.month,
      year: newMonth.year,
    );
    _rebuildGraph();
    _setAverage();
  }

  // ── Week navigation ──────────────────────────────────────────────
  Future<void> _changeWeek(int delta) async {
    final next = _weekOffset + delta;
    // Don't go into the future
    if (next > 0) return;
    setState(() => _weekOffset = next);

    // When navigating to a past week we may need to fetch that month's data
    final monday = _mondayOfWeek();
    if (monday.month != DateTime
        .now()
        .month ||
        monday.year != DateTime
            .now()
            .year) {
      await sleepController.loadMonthlySleep(
        month: monday.month,
        year: monday.year,
      );
    }
    _rebuildGraph();
    _setAverage();
  }

  // ── Swipe handler (wraps both graph sections) ────────────────────
  void _onHorizontalDrag(DragEndDetails details) {
    const kVelocityThreshold = 300.0;
    final vx = details.primaryVelocity ?? 0;
    if (vx.abs() < kVelocityThreshold) return;

    if (_isMonthlyView) {
      // swipe right = older month, left = newer month
      if (vx > 0) {
        _changeMonth(-1);
      } else {
        if (_selectedMonth.year < DateTime
            .now()
            .year ||
            _selectedMonth.month < DateTime
                .now()
                .month) {
          _changeMonth(1);
        }
      }
    } else {
      // swipe right = older week, left = newer week
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
      tappedDate =
          DateTime(_selectedMonth.year, _selectedMonth.month, index + 1);
    } else {
      tappedDate = _mondayOfWeek().add(Duration(days: index));
    }

    setState(() {
      _displayMinutes = (spot.y * 60).round();
      _displayLabel =
      '${tappedDate.day}-${tappedDate.month}-${tappedDate.year}';
      _showingAverage = false;
    });
  }

  // ── helpers ──────────────────────────────────────────────────────
  String _fmtMinutes(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
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

  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final currentSpots = _isMonthlyView ? _monthSpots : _weekSpots;
    final currentLabels = _isMonthlyView ? _monthLabels : _weekLabels;

    // Sleep highlights from displayed minutes
    final totalMinutes = _displayMinutes;
    final deepMinutes = (totalMinutes * 0.20).toInt();
    final remMinutes = (totalMinutes * 0.25).toInt();
    final coreMinutes = (totalMinutes * 0.55).toInt();
    final interruptions =
    totalMinutes > 0 ? (totalMinutes / 120).round() + 1 : 0;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: const CustomAppBar(appbarText: 'Sleep Report'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: sleep duration ──────────────────────────
              Text(
                _showingAverage ? _displayLabel : 'Sleep on $_displayLabel',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _displayMinutes > 0 ? _fmtMinutes(_displayMinutes) : '--',
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
                    // Week chevrons (weekly view)
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
                        onPressed: _weekOffset < 0
                            ? () => _changeWeek(1)
                            : null,
                      ),
                    ],
                    // Month chevrons (monthly view)
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
                        style:
                        const TextStyle(color: AppColors.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Graph (with swipe gesture) ─────────────────────
              GestureDetector(
                onHorizontalDragEnd: _onHorizontalDrag,
                child: SizedBox(
                  height: height * 0.37,
                  child: CommonStatGraphWidget(
                    isDarkMode: isDarkMode,
                    height: height,
                    graphTitle: 'Sleep Statistics',
                    points: currentSpots,
                    isMonthlyView: _isMonthlyView,
                    weekLabels: currentLabels,
                    yAxisMaxValue: _maxY,
                    yAxisInterval: _interval,
                    gridLineInterval: _interval,
                    measureUnit: 'h',
                    isSleepGraph: true,
                    isWaterGraph: false,
                    selectedMonthForHeader: _selectedMonth,
                    highlightIndex: _highlightIndex,
                    onBarTouched: _onBarTouched,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Section title ──────────────────────────────────
              Text(
                _showingAverage ? 'Average Highlights' : 'Sleep Highlights',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // ── Metric cards ───────────────────────────────────
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildKeyPointCard(
                          title: 'Deep Sleep',
                          value: _fmtMinutes(deepMinutes),
                          subtitle: '',
                          color: Colors.deepPurple,
                          icon: Icons.nightlight_round,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKeyPointCard(
                          title: 'REM Sleep',
                          value: _fmtMinutes(remMinutes),
                          subtitle: '',
                          color: Colors.blue,
                          icon: Icons.waves,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKeyPointCard(
                          title: 'Core Sleep',
                          value: _fmtMinutes(coreMinutes),
                          subtitle: '',
                          color: Colors.teal,
                          icon: Icons.wb_twilight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKeyPointCard(
                          title: 'Interruptions',
                          value: interruptions.toString(),
                          subtitle: '',
                          color: Colors.orange,
                          icon: Icons.notifications_active_outlined,
                        ),
                      ),
                    ],
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
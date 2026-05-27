import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/services/notification_service.dart';
import 'package:snevva/views/Information/Sleep%20Screen/sleep_bottom_sheet.dart';
import 'package:snevva/views/Information/Sleep%20Screen/sleep_report_screen.dart';
import 'package:snevva/widgets/CommonWidgets/common_stat_graph_widget.dart';
import 'package:snevva/widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/widgets/Drawer/drawer_menu_wigdet.dart';

import '../../../Controllers/SleepScreen/sleep_controller.dart';
import '../../../Controllers/common/common_tips_controller.dart';
import '../../../widgets/common/common_tip_widget.dart';

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key});

  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen> {
  final sleepController = Get.find<SleepController>();
  late CommonTipsController commonTipsController;
  final ScrollController _scrollController = ScrollController();
  final _service = FlutterBackgroundService();

  // ── real-time tracking ──────────────────────────────────────────
  bool _isSleeping = false;
  Duration _currentSleepDuration = Duration.zero;
  Duration _sleepGoal = const Duration(hours: 8);
  double _progress = 0.0;

  // ── graph / view state ──────────────────────────────────────────
  bool _isMonthlyView = false;
  DateTime _selectedMonth = DateTime.now();
  int _weekOffset = 0; // 0 = current week, -1 = last week …

  List<FlSpot> _graphSpots = [];
  List<String> _graphLabels = [];
  double _maxY = 8;
  double _interval = 2;
  int _highlightIndex = -1;

  StreamSubscription? _sleepUpdateSubscription;
  StreamSubscription? _sleepSavedSubscription;
  StreamSubscription? _goalReachedSubscription;
  int _secretTapCount = 0;
  bool _loaded = false;

  // ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    commonTipsController = Get.find<CommonTipsController>();
    _scrollController.addListener(_onTipsScroll);
    commonTipsController.getCommonTips(context: context, tag: 'Sleep');
    toggleSleepCard();
    _checkIfAlreadySleeping();
    _setupSleepListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await sleepController.loadDeepSleepData();
      sleepController.loadUserSleepTimes();
      _checkBatteryOptimizations();
      _rebuildGraph();
    });
  }

  @override
  void dispose() {
    _sleepUpdateSubscription?.cancel();
    _sleepSavedSubscription?.cancel();
    _goalReachedSubscription?.cancel();
    _scrollController.removeListener(_onTipsScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTipsScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      commonTipsController.loadMoreCommonTips(context);
    }
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

  // ── Build week spots for _weekOffset ────────────────────────────
  List<FlSpot> _weekSpotsForOffset() {
    final monday = _mondayOfWeek();
    final history = Map<String, Duration>.from(
      sleepController.weeklyDeepSleepHistory,
    )..addAll(
      Map<String, Duration>.from(sleepController.monthlyDeepSleepHistory),
    );

    final now = DateTime.now();
    final isCurrentWeek = _weekOffset == 0;
    final List<FlSpot> spots = [];

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      if (isCurrentWeek && date.isAfter(now)) break;
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
    return '${DateFormat('d MMM').format(monday)} – ${DateFormat('d MMM').format(sunday)}';
  }

  // ── Rebuild cached graph data ────────────────────────────────────
  void _rebuildGraph() {
    final spots =
        _isMonthlyView
            ? (sleepController.monthlySleepSpots.isNotEmpty
                ? sleepController.monthlySleepSpots.toList()
                : <FlSpot>[])
            : _weekSpotsForOffset();

    final labels =
        _isMonthlyView
            ? generateMonthLabels(_selectedMonth)
            : _weekLabelsForOffset();

    final rawMax =
        spots.isEmpty
            ? 0.0
            : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxY = getNiceSleepMaxY(rawMax);
    final interval = getNiceSleepInterval(maxY);

    int highlight = -1;
    if (!_isMonthlyView && _weekOffset == 0) {
      final now = DateTime.now();
      highlight = now.weekday - DateTime.monday;
      if (highlight >= labels.length) highlight = labels.length - 1;
    }

    setState(() {
      _graphSpots = spots;
      _graphLabels = labels;
      _maxY = maxY == 0 ? 8 : maxY;
      _interval = interval == 0 ? 2 : interval;
      _highlightIndex = highlight;
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
  }

  // ── Month navigation ─────────────────────────────────────────────
  Future<void> _changeMonth(int delta) async {
    final newMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + delta,
      1,
    );
    setState(() => _selectedMonth = newMonth);
    await sleepController.loadMonthlySleep(
      month: newMonth.month,
      year: newMonth.year,
    );
    _rebuildGraph();
  }

  // ── Week navigation ──────────────────────────────────────────────
  Future<void> _changeWeek(int delta) async {
    final next = _weekOffset + delta;
    if (next > 0) return;
    setState(() => _weekOffset = next);

    final monday = _mondayOfWeek();
    if (monday.month != DateTime.now().month ||
        monday.year != DateTime.now().year) {
      await sleepController.loadMonthlySleep(
        month: monday.month,
        year: monday.year,
      );
    }
    _rebuildGraph();
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

  // ── Battery check (Android only — iOS has no battery optimization setting) ──
  Future<void> _checkBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted && mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Keep Tracking Alive'),
              content: const Text(
                'To ensure sleep is tracked automatically overnight, please disable battery optimizations for Snevva.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Later'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Permission.ignoreBatteryOptimizations.request();
                  },
                  child: const Text('Allow'),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _checkIfAlreadySleeping() async {
    final prefs = await SharedPreferences.getInstance();
    final isSleeping = prefs.getBool('is_sleeping') ?? false;
    if (isSleeping) {
      final startString = prefs.getString('sleep_start_time');
      final goalMinutes = prefs.getInt('sleep_goal_minutes') ?? 480;
      if (startString != null) {
        setState(() {
          _isSleeping = true;
          _currentSleepDuration = Duration.zero;
          _sleepGoal = Duration(minutes: goalMinutes);
          _progress = 0.0;
        });
      }
    }
  }

  void _setupSleepListeners() {
    _sleepUpdateSubscription = _service.on('sleep_update').listen((
      event,
    ) async {
      if (event != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final manuallyStopped = prefs.getBool('manually_stopped') ?? false;
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
      }
    });

    _sleepSavedSubscription = _service.on('sleep_saved').listen((event) async {
      if (event != null && mounted) {
        final duration = event['duration'] as int? ?? 0;
        setState(() {
          _isSleeping = false;
          _currentSleepDuration = Duration.zero;
          _progress = 0.0;
        });
        await sleepController.loadDeepSleepData();
        _rebuildGraph();

        Get.snackbar(
          '😴 Sleep Recorded',
          'You slept for ${_formatDuration(Duration(minutes: duration))}',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    });

    _goalReachedSubscription = _service.on('sleep_goal_reached').listen((
      event,
    ) {
      if (event != null && mounted) {
        sleepController.stopSleep();
        NotificationService().showInstantNotification(
          id: WAKE_NOTIFICATION_ID + 1,
          title: '🎉 Goal Reached!',
          body: 'You\'ve completed your sleep goal!',
        );
      }
    });
  }

  Future<void> toggleSleepCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sleepGoalbool', true);
  }

  String _fmt(TimeOfDay? dt) {
    if (dt == null) return 'Not Set';
    int hour = dt.hour;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  void _handleSecretSleepPush() {
    _secretTapCount++;
    if (_secretTapCount != 7) return;
    final bedTime = sleepController.bedtime.value;
    final wakeTime = sleepController.waketime.value;
    if (bedTime == null || wakeTime == null) {
      Get.snackbar(
        'Sleep times missing',
        'Set both bedtime and wake time first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      _secretTapCount = 0;
      return;
    }
    final now = DateTime.now();
    sleepController.uploadsleepdatatoServer(
      DateTime(now.year, now.month, now.day, bedTime.hour, bedTime.minute),
      DateTime(now.year, now.month, now.day, wakeTime.hour, wakeTime.minute),
    );
    _secretTapCount = 0;
  }

  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const double size = 210;
    const double center = size / 2;
    final double radius = center - 20;

    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await sleepController.loadDeepSleepData();
        _rebuildGraph();
      });
    }

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: const CustomAppBar(appbarText: 'Sleep Tracker'),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // ── Clock + progress indicator ──────────────────────
              SizedBox(
                child: Stack(
                  children: [
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
                    _isSleeping
                        ? _buildActiveSleepIndicator()
                        : _buildInactiveSleepIndicator(),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Bedtime / Wake card ─────────────────────────────
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
                            GestureDetector(
                              onTap: _handleSecretSleepPush,
                              child: const Text(
                                'Bedtime',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
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
                                style: const TextStyle(
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
                            const Text(
                              'Wake Up',
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
                                style: const TextStyle(
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

              // ── View toggle + week/month nav ────────────────────
              Column(
                children: [
                  Text(
                    _isMonthlyView
                        ? 'Monthly Sleep Report'
                        : 'Weekly Sleep Report',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                            style: const TextStyle(
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Graph (swipeable) ───────────────────────────────
              GestureDetector(
                onHorizontalDragEnd: _onHorizontalDrag,
                child: SizedBox(
                  height: height * 0.37,
                  child: CommonStatGraphWidget(
                    isDarkMode: isDarkMode,
                    height: height,
                    graphTitle: 'Sleep Statistics',
                    points: _graphSpots,
                    isMonthlyView: _isMonthlyView,
                    weekLabels: _graphLabels,
                    yAxisMaxValue: _maxY,
                    yAxisInterval: _interval,
                    gridLineInterval: _interval,
                    measureUnit: 'h',
                    isSleepGraph: true,
                    isWaterGraph: false,
                    selectedMonthForHeader: _selectedMonth,
                    highlightIndex: _highlightIndex,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Sleep report CTA ────────────────────────────────
              GestureDetector(
                onTap: () => Get.to(() => const SleepReportScreen()),
                child: Container(
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.1),
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
                              'View Sleep Report',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Detailed analysis of your sleep stages',
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
              const CommonTipsList(),
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
            d.inMinutes > 0
                ? Text(
                  fmtDuration(d),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                )
                : const Text(
                  'No sleep yet',
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
}

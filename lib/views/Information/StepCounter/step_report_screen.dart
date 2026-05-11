import 'dart:math';

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
  int daysSinceMonday = 0;
  DateTime _selectedMonth = DateTime.now();
  final Rx<int?> selectedSteps = Rx<int?>(null);
  final RxString selectedDateLabel = "".obs;
  bool _isMonthlyView = false;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey = "${yesterday.year}-${yesterday.month
          .toString()
          .padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

      final yesterdaySteps = stepController.stepsHistoryByDate[yesterdayKey] ??
          0;

      selectedSteps.value = yesterdaySteps;
      selectedDateLabel.value =
      "${yesterday.day}-${yesterday.month}-${yesterday.year}";
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

  double getDynamicMaxY(double value, {double paddingFactor = 1.2}) {
    if (value <= 0) return 1000;
    double rawMax = value * paddingFactor;
    double magnitude = pow(10, rawMax.floor().toString().length - 1).toDouble();
    double normalized = rawMax / magnitude;
    double niceNormalized;
    if (normalized <= 1) niceNormalized = 1;
    else if (normalized <= 2) niceNormalized = 2;
    else if (normalized <= 5) niceNormalized = 5;
    else niceNormalized = 10;
    return niceNormalized * magnitude;
  }

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
                    const SizedBox(width: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: const CustomAppBar(appbarText: 'Step Report'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() {
                final steps = selectedSteps.value ?? stepController.todaySteps.value;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedDateLabel.value.isNotEmpty ? "Steps on ${selectedDateLabel.value}" : "Step Analysis",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$steps steps",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }),
              Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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
              const SizedBox(height: 16),
              SizedBox(
                height: height * 0.37,
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

                  final double rawMax =
                      points.isEmpty
                          ? 0
                          : points
                              .map((e) => e.y)
                              .reduce((a, b) => a > b ? a : b);

                  final double maxY = getDynamicMaxY(rawMax);

                  return StepStatGraphWidget(
                    isDarkMode: isDarkMode,
                    height: height,
                    graphTitle: 'Step Statistics',
                    points: points,
                    maxXForWeek: daysSinceMonday,
                    isMonthlyView: _isMonthlyView,
                    weekLabels: labels,
                    yAxisMaxValue: maxY,
                    maxY: maxY,
                    selectedMonthForHeader: _selectedMonth,
                    onBarTouched: (index, spot) {
                      selectedSteps.value = spot.y.toInt();

                      DateTime tappedDate;

                      if (_isMonthlyView) {
                        tappedDate = DateTime(_selectedMonth.year, _selectedMonth.month, index + 1);
                      } else {
                        final now = DateTime.now();
                        final startOfWeek = DateTime(now.year, now.month, now.day)
                            .subtract(Duration(days: now.weekday - DateTime.monday));
                        tappedDate = startOfWeek.add(Duration(days: index));
                      }

                      selectedDateLabel.value =
                      "${tappedDate.day}-${tappedDate.month}-${tappedDate.year}";
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),
              const Text(
                "Step Highlights",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              Obx(() {
                final steps = selectedSteps.value ?? stepController.todaySteps.value;
                
                final distanceKm = (steps * 0.0008).toStringAsFixed(2);
                final calories = (steps * 0.04).toStringAsFixed(0);
                final durationMins = (steps / 100).toStringAsFixed(0);

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildKeyPointCard(
                            title: 'Progress',
                            value: '${(stepController.stepGoal.value > 0
                                ? (steps / stepController.stepGoal.value * 100)
                                : 0).toStringAsFixed(0)}%',
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
                  ],
                );
              }),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

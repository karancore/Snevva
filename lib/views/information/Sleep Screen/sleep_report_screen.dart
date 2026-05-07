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
  int daysSinceMonday = 0;
  DateTime _selectedMonth = DateTime.now();
  final Rx<Duration?> selectedSleepDuration = Rx<Duration?>(null);
  final RxString selectedDateLabel = "".obs;

  void _toggleView() async {
    final nextIsMonthly = !sleepController.isMonthlyView.value;
    sleepController.isMonthlyView.value = nextIsMonthly;

    if (nextIsMonthly) {
      await sleepController.loadMonthlySleep(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );
      return;
    }

    sleepController.updateDeepSleepSpots();
  }

  void _changeMonth(int delta) async {
    final newMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + delta,
      1,
    );

    setState(() => _selectedMonth = newMonth);

    if (sleepController.isMonthlyView.value) {
      await sleepController.loadMonthlySleep(
        month: newMonth.month,
        year: newMonth.year,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (sleepController.deepSleepSpots.isEmpty) {
        sleepController.loadDeepSleepData();
      }

      final spots = sleepController.deepSleepSpots;
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      if (spots.isNotEmpty) {
        // Take second-to-last spot (yesterday), fallback to last if only 1 entry
        final yesterdaySpot = spots.length >= 2 ? spots[spots.length - 2] : spots.last;
        selectedSleepDuration.value = Duration(minutes: (yesterdaySpot.y * 60).round());
        selectedDateLabel.value = "${yesterday.day}-${yesterday.month}-${yesterday.year}";
      } else {
        selectedSleepDuration.value = sleepController.deepSleepDuration.value;
        selectedDateLabel.value = "${yesterday.day}-${yesterday.month}-${yesterday.year}";
      }
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
      appBar: const CustomAppBar(appbarText: 'Sleep Report'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() {
                final duration = selectedSleepDuration.value ?? sleepController.deepSleepDuration.value;
                final totalMinutes = duration.inMinutes;
                final hours = totalMinutes ~/ 60;
                final minutes = totalMinutes % 60;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedDateLabel.value.isNotEmpty ? "Sleep on ${selectedDateLabel.value}" : "Sleep Analysis",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hours > 0 ? "${hours}h ${minutes}m" : "${minutes}m",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }),
              Obx(() {
                final isMonthly = sleepController.isMonthlyView.value;

                return Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isMonthly) ...[
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
                              isMonthly
                                  ? "Switch to Weekly"
                                  : "Switch to Monthly",
                              style: TextStyle(color: AppColors.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                height: height * 0.37,
                child: Obx(() {
                  final labels =
                      sleepController.isMonthlyView.value
                          ? generateMonthLabels(_selectedMonth)
                          : generateShortWeekdays();

                  final points =
                      sleepController.isMonthlyView.value
                          ? (sleepController.monthlySleepSpots.isEmpty
                              ? <FlSpot>[]
                              : sleepController.monthlySleepSpots.toList())
                          : sleepController.deepSleepSpots
                              .take(daysSinceMonday + 1)
                              .toList();

                  final double rawMax =
                      points.isEmpty
                          ? 0
                          : points
                              .map((e) => e.y)
                              .reduce((a, b) => a > b ? a : b);

                  final double maxY = getNiceSleepMaxY(rawMax);
                  final double interval = getNiceSleepInterval(maxY);

                  return CommonStatGraphWidget(
                    isDarkMode: isDarkMode,
                    height: height,
                    graphTitle: 'Sleep Statistics',
                    points: points,
                    maxXForWeek: daysSinceMonday,
                    isMonthlyView: sleepController.isMonthlyView.value,
                    weekLabels: labels,
                    yAxisMaxValue: maxY,
                    yAxisInterval: interval,
                    gridLineInterval: interval,
                    measureUnit: 'h',
                    isSleepGraph: true,
                    isWaterGraph: false,
                    selectedMonthForHeader: _selectedMonth,
                    onBarTouched: (index, spot) {
                      selectedSleepDuration.value = Duration(minutes: (spot.y * 60).round());

                      DateTime tappedDate;

                      if (sleepController.isMonthlyView.value) {
                        // index = day of month (0-based → day 1, 2, 3...)
                        tappedDate = DateTime(_selectedMonth.year, _selectedMonth.month, index + 1);
                      } else {
                        // index = days offset from Monday of current week
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
                "Sleep Highlights",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              Obx(() {
                // Mock logic to extract percentages from actual sleep duration
                final duration = selectedSleepDuration.value ?? sleepController.deepSleepDuration.value;
                final totalMinutes = duration.inMinutes;
                
                // Typical sleep cycle approximation: 
                // Deep: ~20%, REM: ~25%, Core (Light): ~55%
                final deepMinutes = (totalMinutes * 0.20).toInt();
                final remMinutes = (totalMinutes * 0.25).toInt();
                final coreMinutes = (totalMinutes * 0.55).toInt();
                
                // Mock interruptions based on total sleep
                final interruptions = totalMinutes > 0 ? (totalMinutes / 120).round() + 1 : 0;
                
                String formatMins(int mins) {
                  final h = mins ~/ 60;
                  final m = mins % 60;
                  if (h > 0) return '${h}h ${m}m';
                  return '${m}m';
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildKeyPointCard(
                            title: 'Deep Sleep',
                            value: formatMins(deepMinutes),
                            subtitle: '',
                            color: Colors.deepPurple,
                            icon: Icons.nightlight_round,
                          ),
                        ),
                        const SizedBox(width: 12), // 👈 width, not height
                        Expanded(
                          child: _buildKeyPointCard(
                            title: 'REM Sleep',
                            value: formatMins(remMinutes),
                            subtitle: '',
                            color: Colors.blue,
                            icon: Icons.waves,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12), // 👈 between rows, outside Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildKeyPointCard(
                            title: 'Core Sleep',
                            value: formatMins(coreMinutes),
                            subtitle: '',
                            color: Colors.teal,
                            icon: Icons.wb_twilight,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKeyPointCard(
                            title: 'Interruption',
                            value: interruptions.toString(),
                            subtitle: '',
                            color: Colors.orange,
                            icon: Icons.notifications_active_outlined,
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

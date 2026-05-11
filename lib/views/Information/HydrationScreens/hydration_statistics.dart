import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:intl/intl.dart';

import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';

import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';

import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';

import '../../../Widgets/CommonWidgets/common_stat_graph_widget.dart';

import '../../../common/global_variables.dart';

import '../../../consts/consts.dart';

import '../../../models/water_history_model.dart';

class HydrationStatistics extends StatefulWidget {
  const HydrationStatistics({super.key});

  @override
  State<HydrationStatistics> createState() => _HydrationStatisticsState();
}

class _HydrationStatisticsState extends State<HydrationStatistics> {
  final controller = Get.find<HydrationStatController>();

  bool _isMonthlyView = false;

  DateTime _selectedMonth = DateTime.now();

  int daysSinceMonday = 0;

  // ── Same pattern as StepReportScreen ──

  final Rx<int?> selectedIntake = Rx<int?>(null);

  final RxString selectedDateLabel = "".obs;

  @override
  void initState() {
    super.initState();

    controller.loadWaterIntakefromAPI(
      month: DateTime.now().month,

      year: DateTime.now().year,
    );

    // Auto-select yesterday's value, just like StepReportScreen

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final spots = controller.waterSpots;

      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      if (spots.isNotEmpty) {
        final spot = spots.length >= 2 ? spots[spots.length - 2] : spots.last;

        selectedIntake.value = (spot.y * 1000).toInt();
      } else {
        selectedIntake.value = _filterForDay(
          controller.waterHistoryList,

          yesterday,
        ).fold(0, (sum, item) => sum! + (item.value ?? 0));
      }

      selectedDateLabel.value =
          "${yesterday.day}-${yesterday.month}-${yesterday.year}";
    });
  }

  // ── Helpers ──

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

  void _toggleView() async {
    setState(() => _isMonthlyView = !_isMonthlyView);

    if (_isMonthlyView) {
      await controller.loadWaterIntakefromAPI(
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

    await controller.loadWaterIntakefromAPI(
      month: newMonth.month,

      year: newMonth.year,
    );
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

      shortWeekdays.add(DateFormat('E').format(date));
    }

    return shortWeekdays;
  }

  // ── Highlight card (mirrors _buildKeyPointCard in StepReportScreen) ──

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

                    const SizedBox(width: 4),

                    Text(
                      subtitle,

                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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

  // ── Empty state ──

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
            ? "No data available for this month."
            : "No data available for the last 7 days.",

        style: const TextStyle(color: Colors.grey, fontSize: 14),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    final height = mediaQuery.size.height;

    final width = mediaQuery.size.width;

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),

      appBar: const CustomAppBar(appbarText: 'Hydration Statistics'),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ── HEADER: selected date + value ──
              Obx(() {
                final intake =
                    selectedIntake.value ??
                    _filterForDay(
                      controller.waterHistoryList,

                      DateTime.now(),
                    ).fold(0, (sum, item) => sum! + (item.value ?? 0));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      selectedDateLabel.value.isNotEmpty
                          ? "Hydration on ${selectedDateLabel.value}"
                          : "Hydration Analysis",

                      style: const TextStyle(
                        fontSize: 14,

                        color: Colors.grey,

                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      "$intake ml",

                      style: const TextStyle(
                        fontSize: 32,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }),

              // ── VIEW TOGGLE + MONTH NAVIGATION ──
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

              // ── GRAPH ──
              SizedBox(
                height: height * 0.37,

                child: Obx(() {
                  if (controller.isLoading.value) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryColor,
                      ),
                    );
                  }

                  final labels =
                      _isMonthlyView
                          ? generateMonthLabels(_selectedMonth)
                          : generateShortWeekdays();

                  final points =
                      _isMonthlyView
                          ? controller.getMonthlyWaterSpots(_selectedMonth)
                          : controller.waterSpots
                              .take(daysSinceMonday + 1)
                              .toList();

                  if (points.isEmpty) {
                    return _emptyStateContainer(height, isDarkMode);
                  }

                  final double rawMax = points
                      .map((e) => e.y)
                      .reduce((a, b) => a > b ? a : b);

                  final double maxY = getNiceHydrationMaxY(rawMax);

                  final double interval = getNiceHydrationInterval(maxY);

                  return CommonStatGraphWidget(
                    isMonthlyView: _isMonthlyView,

                    isWaterGraph: true,

                    isDarkMode: isDarkMode,

                    height: height,

                    graphTitle: 'Hydration Statistics',

                    yAxisInterval: interval,

                    yAxisMaxValue: maxY,

                    gridLineInterval: interval,

                    maxXForWeek: daysSinceMonday,

                    points: points,

                    weekLabels: labels,

                    measureUnit: 'L',

                    isSleepGraph: false,

                    onBarTouched: (index, spot) {
                      selectedIntake.value = (spot.y * 1000).toInt();

                      DateTime tappedDate;

                      if (_isMonthlyView) {
                        tappedDate = DateTime(
                          _selectedMonth.year,

                          _selectedMonth.month,

                          index + 1,
                        );
                      } else {
                        final now = DateTime.now();

                        final startOfWeek = DateTime(
                          now.year,

                          now.month,

                          now.day,
                        ).subtract(
                          Duration(days: now.weekday - DateTime.monday),
                        );

                        tappedDate = startOfWeek.add(Duration(days: index));
                      }

                      selectedDateLabel.value =
                          "${tappedDate.day}-${tappedDate.month}-${tappedDate.year}";
                    },
                  );
                }),
              ),

              const SizedBox(height: 24),

              // ── HIGHLIGHTS SECTION ──
              const Text(
                "Hydration Highlights",

                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 16),

              Obx(() {
                final intakeMl = selectedIntake.value ?? 0;

                final intakeLiters = intakeMl / 1000;

                final goalLiters = (controller.waterGoal.value / 1000);

                final progressPercent =
                    goalLiters > 0
                        ? ((intakeLiters / goalLiters) * 100)
                            .clamp(0, 100)
                            .toStringAsFixed(0)
                        : "0";

                // Rough estimate: avg 8 oz (240 ml) cups

                final cups = (intakeMl / 240).toStringAsFixed(1);

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildKeyPointCard(
                            title: 'Intake',

                            value: intakeMl.toString(),

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
                );
              }),

              const SizedBox(height: 24),

              // ── TODAY'S LOG (kept from original) ──
              Obx(() {
                final todayEntries = _filterForDay(
                  controller.waterHistoryList,

                  DateTime.now(),
                );

                if (controller.isLoading.value) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryColor,
                    ),
                  );
                }

                if (todayEntries.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),

                    child: Text(
                      "No water intake logged today.",

                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      "Today's Record (${todayEntries.length} "
                      "entr${todayEntries.length == 1 ? 'y' : 'ies'})",

                      style: const TextStyle(
                        fontSize: 18,

                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 15),

                    ListView.separated(
                      shrinkWrap: true,

                      physics: const NeverScrollableScrollPhysics(),

                      itemCount: todayEntries.length,

                      separatorBuilder:
                          (_, __) => Divider(
                            color: Colors.grey.withOpacity(0.4),

                            thickness: 0.6,
                          ),

                      itemBuilder: (context, index) {
                        final entry = todayEntries[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),

                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              SizedBox(
                                width: 80,

                                child: Text(
                                  entry.time ?? '--:--',

                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,

                                    fontSize: 13,

                                    color:
                                        isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                  ),
                                ),
                              ),

                              Expanded(
                                child: Text(
                                  "${entry.value ?? 0} ml",

                                  style: TextStyle(
                                    fontSize: 14,

                                    color:
                                        isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

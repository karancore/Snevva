import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../../Widgets/CommonWidgets/common_stat_graph_widget.dart';
import '../../../common/global_variables.dart';
import '../../../consts/consts.dart';
import '../../../models/water_history_model.dart';
import 'package:intl/intl.dart';

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
  int todayDate = 1;

  @override
  void initState() {
    super.initState();
    // controller.fetchWaterRecordsfromAPI();
    controller.loadWaterIntakefromAPI(
      month: DateTime.now().month,
      year: DateTime.now().year,
    );
    // optionally load monthly data now if needed
  }

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

  List<WaterHistoryModel> _aggregateByDay(List<WaterHistoryModel> allData) {
    final Map<String, int> grouped = {};
    for (var entry in allData) {
      final key = "${entry.year}-${entry.month}-${entry.day}";
      grouped.update(
        key,
        (v) => v + (entry.value ?? 0),
        ifAbsent: () => entry.value ?? 0,
      );
    }
    return grouped.entries.map((e) {
      final parts = e.key.split('-');
      return WaterHistoryModel(
        year: int.parse(parts[0]),
        month: int.parse(parts[1]),
        day: int.parse(parts[2]),
        value: e.value,
      );
    }).toList();
  }

  List<WaterHistoryModel> _getLastWeekData(List<WaterHistoryModel> allData) {
    final aggregated = _aggregateByDay(allData);
    aggregated.sort(
      (a, b) => DateTime(
        a.year,
        a.month,
        a.day,
      ).compareTo(DateTime(b.year, b.month, b.day)),
    );
    if (aggregated.length > 7) {
      return aggregated.sublist(aggregated.length - 7);
    }
    return aggregated;
  }

  List<WaterHistoryModel> _getMonthData(
    List<WaterHistoryModel> allData,
    DateTime month,
  ) {
    final List<WaterHistoryModel> filtered =
        allData.where((entry) {
          return entry.year == month.year && entry.month == month.month;
        }).toList();
    final grouped = <String, int>{};
    for (var entry in filtered) {
      final key = "${entry.year}-${entry.month}-${entry.day}";
      grouped.update(
        key,
        (v) => v + (entry.value ?? 0),
        ifAbsent: () => entry.value ?? 0,
      );
    }
    final List<WaterHistoryModel> result =
        grouped.entries.map((e) {
          final parts = e.key.split('-');
          return WaterHistoryModel(
            year: int.parse(parts[0]),
            month: int.parse(parts[1]),
            day: int.parse(parts[2]),
            value: e.value,
          );
        }).toList();
    result.sort(
      (a, b) => DateTime(
        a.year,
        a.month,
        a.day,
      ).compareTo(DateTime(b.year, b.month, b.day)),
    );
    return result;
  }

  // List<String> _weekLabels(List<WaterHistoryModel> data) {
  //   return data.map((e) => e.day.toString()).toList();
  // }
  //
  // List<String> _monthLabels(DateTime month, List<WaterHistoryModel> data) {
  //   final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  //   return List.generate(daysInMonth, (i) => (i + 1).toString());
  // }

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

    // 🔥 IMPORTANT: reload data for new month
    await controller.loadWaterIntakefromAPI(
      month: newMonth.month,
      year: newMonth.year,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final width = media.size.width;

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: const CustomAppBar(appbarText: 'Hydration Statistics'),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header with toggle & month navigation if monthly view
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isMonthlyView
                        ? "Monthly Hydration Report"
                        : "Weekly Hydration Report",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
              const SizedBox(height: 10),

              Obx(() {
                if (controller.isLoading.value) {
                  return SizedBox(
                    height: height * 0.3,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryColor,
                      ),
                    ),
                  );
                }

                List<WaterHistoryModel> displayData;
                List<String> labels;
                // if (_isMonthlyView) {
                //   displayData = _getMonthData(
                //     controller.waterHistoryList,
                //     _selectedMonth,
                //   );
                //   if (displayData.isEmpty) {
                //     return _emptyStateContainer(height, isDarkMode);
                //   }
                //   labels = _monthLabels(_selectedMonth, displayData);
                // } else {
                //   displayData = _getLastWeekData(controller.waterHistoryList);
                //   if (displayData.isEmpty) {
                //     return _emptyStateContainer(height, isDarkMode);
                //   }
                //   labels = _weekLabels(displayData);
                // }

                // final points = List<FlSpot>.generate(displayData.length, (i) {
                //   final intakeMl = displayData[i].value?.toDouble() ?? 0;
                //   return FlSpot(i.toDouble(), intakeMl / 1000);
                // });
                //
                // final goalLiters = controller.waterGoal.value / 1000;
                // double maxIntakeLiters = points
                //     .map((p) => p.y)
                //     .fold(0.0, (prev, val) => val > prev ? val : prev);
                // double maxY =
                //     ((maxIntakeLiters > goalLiters
                //                 ? maxIntakeLiters
                //                 : goalLiters) *
                //             1.25)
                //         .ceilToDouble();
                // double interval = (maxY / 5).ceilToDouble();

                return SizedBox(
                  height: height * 0.41,
                  child: Obx(() {
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

                    // 🔥 Find max intake in liters
                    final double rawMax =
                        points.isEmpty
                            ? 0
                            : points
                                .map((e) => e.y)
                                .reduce((a, b) => a > b ? a : b);

                    // 🔥 Apply nice scaling
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
                    );
                  }),
                );
              }),

              const SizedBox(height: 25),

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
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "No water intake logged today.",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      "Today's Record (${todayEntries.length} entr${todayEntries.length == 1 ? 'y' : 'ies'})",
                      maxLines: 1,
                      maxFontSize: 20,
                      minFontSize: 10,
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
                        final formattedTime = entry.time ?? '--:--';
                        final value = "${entry.value ?? 0} ml";

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  formattedTime,
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
                                  value,
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
            ],
          ),
        ),
      ),
    );
  }

  List<String> generateShortWeekdays() {
    List<String> shortWeekdays = [];
    DateTime now = DateTime.now();

    daysSinceMonday = (now.weekday - DateTime.monday);

    // Remove time part to avoid carrying 12:48:xx everywhere
    DateTime startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysSinceMonday));

    // 🔥 CHANGE IS HERE
    for (int i = 0; i <= daysSinceMonday; i++) {
      DateTime date = startOfWeek.add(Duration(days: i));
      String dayName = DateFormat('E').format(date);
      shortWeekdays.add(dayName);
    }

    return shortWeekdays;
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
            ? "No data available for this month."
            : "No data available for the last 7 days.",
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
    );
  }
}

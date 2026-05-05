import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../common/global_variables.dart';
import '../../consts/consts.dart';

class CommonStatGraphWidget extends StatelessWidget {
  const CommonStatGraphWidget({
    super.key,
    required this.isDarkMode,
    required this.height,
    required this.graphTitle,
    required this.yAxisInterval,
    required this.yAxisMaxValue,
    required this.points,
    required this.gridLineInterval,
    required this.measureUnit,
    required this.isMonthlyView,
    required this.isSleepGraph,
    required this.isWaterGraph,
    this.maxXForWeek,
    this.weekLabels,
    this.selectedMonthForHeader,
  });

  final bool isDarkMode;
  final double height;
  final int? maxXForWeek;
  final String graphTitle;
  final double yAxisInterval;
  final double gridLineInterval;
  final double yAxisMaxValue;
  final String measureUnit;
  final bool isMonthlyView;
  final bool isSleepGraph;
  final bool isWaterGraph;
  final List<FlSpot> points;
  final List<String>? weekLabels;
  final DateTime? selectedMonthForHeader;

  // ✅ Dynamic bar width based on point count
  double get _dynamicBarWidth {
    final count = points.length;
    if (count <= 3) return 40;
    if (count <= 5) return 40;
    if (count <= 7) return 40;
    if (count <= 15) return 30;
    if (count <= 20) return 30;
    return 30;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> fixedWeekLabels = const [
      "Mon",
      "Tue",
      "Wed",
      "Thu",
      "Fri",
      "Sat",
      "Sun",
    ];

    final labels = weekLabels ?? fixedWeekLabels;
    final bool isMonthly = isMonthlyView;

    int todayIndex = -1;
    if (!isMonthly && labels.isNotEmpty) {
      final int resolvedIndex = maxXForWeek ?? (labels.length - 1);
      todayIndex = resolvedIndex.clamp(0, labels.length - 1).toInt();
    }

    final now = DateTime.now();
    DateTime headerDate = now;
    if (isMonthlyView && selectedMonthForHeader != null) {
      final selected = selectedMonthForHeader!;
      final isCurrentMonth =
          selected.year == now.year && selected.month == now.month;
      headerDate =
          isCurrentMonth
              ? DateTime(now.year, now.month, now.day)
              : DateTime(selected.year, selected.month + 1, 0);
    }

    final String formattedDate = DateFormat('d MMM, yyyy').format(headerDate);

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: mediumGrey, width: border04px),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Header =====
            Row(
              children: [
                SvgPicture.asset(statisticIcon, height: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    graphTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: mediumGrey, width: border04px),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // ===== Graph =====
            isMonthlyView
                ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildChart(
                    labels: labels,
                    points: points,
                    context: context,
                    isMonthly: isMonthly,
                    todayIndex: todayIndex,
                  ),
                )
                : _buildChart(
                  labels: labels,
                  context: context,
                  maxXForWeek: maxXForWeek,
                  points: points,
                  isMonthly: isMonthly,
                  todayIndex: todayIndex,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart({
    required List<String> labels,
    required List<FlSpot> points,
    required bool isMonthly,
    required int todayIndex,
    required BuildContext context,
    int? maxXForWeek,
  }) {
    if (points.isEmpty || labels.isEmpty) {
      return SizedBox(
        height: height * 0.28,
        child: const Center(
          child: Text(
            'No data available',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    double chartWidth = max(
      labels.length * 42.0,
      MediaQuery.of(context).size.width - 40,
    );
    if (isMonthly) chartWidth += 1;

    // ✅ Convert FlSpot list → BarChartGroupData list
    final barGroups = List.generate(labels.length, (index) {
      final spot = points.firstWhere(
        (p) => p.x.toInt() == index,
        orElse: () => FlSpot(index.toDouble(), 0),
      );

      final bool isToday =
          !isMonthly && todayIndex != -1 && index == todayIndex;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: spot.y,
            width: _dynamicBarWidth, // ✅ dynamic width
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            gradient: LinearGradient(
              colors:
                  isToday
                      ? [AppColors.primaryColor, AppColors.primaryColor]
                      : [
                        AppColors.primaryColor.withOpacity(0.5),
                        AppColors.primaryColor,
                      ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ],
      );
    });

    return Container(
      padding: const EdgeInsets.only(top: 52),
      height: height * 0.28,
      width: chartWidth,
      child: RepaintBoundary(
        child: BarChart(
          key: ValueKey(isMonthlyView),
          BarChartData(
            minY: 0,
            maxY: yAxisMaxValue,
            barGroups: barGroups,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, _) {
                    final int index = value.toInt();
                    if (index >= 0 && index < labels.length) {
                      final bool isToday =
                          !isMonthly && todayIndex != -1 && index == todayIndex;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color:
                                isToday
                                    ? AppColors.primaryColor
                                    : Colors.grey.shade600,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: yAxisInterval,
                  getTitlesWidget:
                      (value, _) => Text(
                        value % 1 == 0
                            ? '${value.toInt()}$measureUnit'
                            : '${value.toStringAsFixed(1)}$measureUnit',
                        style: const TextStyle(fontSize: 9),
                      ),
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              horizontalInterval: gridLineInterval,
              drawVerticalLine: false,
              getDrawingHorizontalLine:
                  (_) => const FlLine(color: mediumGrey, strokeWidth: 0.8),
            ),
            borderData: FlBorderData(
              show: true,
              border: const Border(
                bottom: BorderSide(color: mediumGrey, width: 0.6),
                left: BorderSide(color: Colors.transparent),
                right: BorderSide(color: Colors.transparent),
                top: BorderSide(color: Colors.transparent),
              ),
            ),
            // ✅ Tooltip — sleep ya water ke hisaab se format
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.primaryColor,
                tooltipPadding: const EdgeInsets.all(8),
                tooltipBorderRadius: BorderRadius.circular(24),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  String label;
                  if (isSleepGraph) {
                    final int minutes = (rod.toY * 60).round();
                    label = formatDurationToHM(Duration(minutes: minutes));
                  } else {
                    // water graph
                    label = '${(rod.toY * 1000).round()} ml';
                  }
                  return BarTooltipItem(
                    label,
                    const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== Helper functions (unchanged) =====

double getNiceHydrationMaxY(double value) {
  if (value <= 1) return 1;
  if (value <= 2) return 2;
  if (value <= 3) return 3;
  if (value <= 4) return 4;
  if (value <= 5) return 5;
  if (value <= 6) return 6;
  if (value <= 8) return 8;
  return (value / 2).ceil() * 2;
}

double getNiceHydrationInterval(double maxY) {
  if (maxY <= 2) return 0.5;
  if (maxY <= 4) return 1;
  if (maxY <= 6) return 1;
  if (maxY <= 8) return 2;
  return 2;
}

double getNiceSleepMaxY(double value) {
  if (value <= 4) return 4;
  if (value <= 5) return 5;
  if (value <= 6) return 6;
  if (value <= 7) return 8;
  if (value <= 8) return 8;
  if (value <= 9) return 10;
  if (value <= 10) return 10;
  if (value <= 12) return 12;
  return (value / 2).ceil() * 2;
}

double getNiceSleepInterval(double maxY) {
  if (maxY <= 5) return 1;
  if (maxY <= 8) return 2;
  if (maxY <= 12) return 2;
  return 2;
}
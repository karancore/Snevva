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
  final List<FlSpot> points; // Data points for the graph
  final List<String>?
  weekLabels; // Can be days (Mon-Sun) or month days (1,5,10...)

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

    // Use provided labels, or default weekly labels
    final labels = weekLabels ?? fixedWeekLabels;

    // If labels > 7, treat it as monthly data
    //final bool isMonthly = labels.length > 7;
    final bool isMonthly = isMonthlyView;

    // Weekly labels are often partial (Mon..today), so highlight by the
    // provided weekly max index instead of assuming 7 labels are present.
    int todayIndex = -1;
    if (!isMonthly && labels.isNotEmpty) {
      final int resolvedIndex = maxXForWeek ?? (labels.length - 1);
      todayIndex = resolvedIndex.clamp(0, labels.length - 1).toInt();
    }

    final String formattedDate = DateFormat(
      'd MMM, yyyy',
    ).format(DateTime.now());

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
            // ===== Header Section =====
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

            // ===== Graph Section =====
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
    String formatted = '';
    final double safeMaxX =
        isMonthly
            ? max(1, labels.length).toDouble()
            : max(1, (maxXForWeek ?? labels.length)).toDouble();

    double chartWidth = max(
      labels.length * 42.0,
      MediaQuery.of(context).size.width - 40,
    );

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

    return Container(
      padding: const EdgeInsets.only(top: 52),
      height: height * 0.28,
      width: chartWidth,
      child: RepaintBoundary(
        child: LineChart(
          key: ValueKey(isMonthlyView),
          LineChartData(
            minX: 0,
            maxX: safeMaxX,
            // use dynamic maxX
            minY: 0,
            maxY: yAxisMaxValue,

            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
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
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            lineBarsData: [
              LineChartBarData(
                spots: points,
                isCurved: true,
                preventCurveOverShooting: true,

                color: AppColors.primaryColor,
                barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    if (spot.y == 0) {
                      return FlDotCirclePainter(
                        radius: 0, // 👈 invisible
                        color: Colors.transparent,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      );
                    }

                    return FlDotCirclePainter(
                      radius: 4,
                      color: white,
                      strokeWidth: 2,
                      strokeColor: AppColors.primaryColor,
                    );
                  },
                ),

                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor.withOpacity(0.3),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) => AppColors.primaryColor,
                tooltipPadding: const EdgeInsets.all(8),
                tooltipBorderRadius: BorderRadius.circular(24),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    if (isSleepGraph) {
                      final int minutes = (spot.y * 60).round();
                      formatted = formatDurationToHM(
                        Duration(minutes: minutes),
                      );
                    }

                    return LineTooltipItem(
                      isSleepGraph
                          ? formatted
                          : '${(spot.y * 1000).round()} ml',
                      const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  // if (value <= 0) return 0;
  // if (value <= 1) return 1;
  // if (value <= 2) return 2;
  // if (value <= 3) return 3;

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

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../common/global_variables.dart';
import '../../consts/consts.dart';

class StepStatGraphWidget extends StatelessWidget {
  const StepStatGraphWidget({
    super.key,
    required this.isDarkMode,
    required this.height,
    required this.points,
    required this.isMonthlyView,
    this.weekLabels,
    this.graphTitle = '',
  });

  final bool isDarkMode;
  final double height;
  final List<FlSpot> points;
  final bool isMonthlyView;
  final List<String>? weekLabels;
  final String graphTitle;

  // ---- STEP GRAPH CONSTANTS ----
  static const double _yMax = 12000;
  static const double _yInterval = 2000;
  static const double _gridInterval = 2000;

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat(
      'd MMM, yyyy',
    ).format(DateTime.now());

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
    final bool isMonthly = labels.length > 7;

    int todayIndex = 0;
    if (!isMonthly && labels.length == 7) {
      todayIndex = DateTime.now().weekday - 1;
    }

    // Clamp Y values safely
    final clampedPoints =
        points.map((p) {
          final y = p.y > _yMax ? _yMax : p.y;
          return FlSpot(p.x, y);
        }).toList();

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
            // ===== HEADER =====
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

            // ===== GRAPH =====
            isMonthlyView
                ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildChart(
                    labels: labels,
                    points: clampedPoints,
                    isMonthly: true,
                    todayIndex: todayIndex,
                  ),
                )
                : _buildChart(
                  labels: labels,
                  points: clampedPoints,
                  isMonthly: false,
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
  }) {
    return Container(
      padding: const EdgeInsets.only(top: 52),
      height: height * 0.25,
      width: isMonthly ? labels.length * 41 : null,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: isMonthly ? labels.length - 1 : 6,
          minY: 0,
          maxY: _yMax,

          // ===== AXES =====
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: isMonthly ? 5 : 1,
                reservedSize: 24,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index >= 0 && index < labels.length) {
                    final isToday = !isMonthly && index == todayIndex;
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
                interval: _yInterval,
                getTitlesWidget:
                    (value, _) => Text(
                      '${(value / 1000).round()}',
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

          // ===== GRID =====
          gridData: FlGridData(
            show: true,
            horizontalInterval: _gridInterval,
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

          // ===== LINE =====
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              color: AppColors.primaryColor,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter:
                    (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.primaryColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
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

          // ===== TOOLTIP =====
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.primaryColor,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipBorderRadius: BorderRadius.circular(24),
              getTooltipItems: (spots) {
                return spots
                    .map(
                      (spot) => LineTooltipItem(
                        '${spot.y.round()} Steps',
                        const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                    .toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

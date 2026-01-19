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
    this.maxXForWeek,
    this.weekLabels,
    this.graphTitle = '',
    required this.maxY,
  });

  final bool isDarkMode;
  final double height;
  final List<FlSpot> points;
  final bool isMonthlyView;
  final List<String>? weekLabels;
  final int? maxXForWeek;
  final String graphTitle;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat(
      'd MMM, yyyy',
    ).format(DateTime.now());

    final labels =
        weekLabels ?? const ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    final bool isMonthly = labels.length > 7;

    // Clamp points so they never exceed maxY
    final clampedPoints =
        points.map((p) {
          return FlSpot(p.x, p.y > maxY ? maxY : p.y);
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
                  ),
                )
                : _buildChart(
                  labels: labels,
                  points: clampedPoints,
                  isMonthly: false,
                  maxXForWeek: maxXForWeek,
                ),
          ],
        ),
      ),
    );
  }

  double getNiceMaxY(double value) {
    if (value <= 1000) return 1000;
    if (value <= 5000) return 5000;
    if (value <= 10000) return 10000;
    if (value <= 20000) return 20000;
    if (value <= 50000) return 50000;
    return (value / 10000).ceil() * 10000;
  }

  double getNiceInterval(double maxY) {
    if (maxY <= 5000) return 1000;
    if (maxY <= 10000) return 2000;
    if (maxY <= 20000) return 5000;
    return 10000;
  }

  Widget _buildChart({
    required List<String> labels,
    required List<FlSpot> points,
    required bool isMonthly,
    int? maxXForWeek,
  }) {
    // final double interval = maxY / 5;
    final double interval = getNiceInterval(maxY);

    final double resolvedMaxX =
        isMonthly
            ? (labels.length - 1).toDouble()
            : (maxXForWeek ?? labels.length - 1).toDouble();

    return Container(
      padding: const EdgeInsets.only(top: 52),
      height: height * 0.28,
      width: isMonthly ? labels.length * 42 : null,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: resolvedMaxX,
          minY: 0,
          maxY: maxY,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 24,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }

                  final isToday = !isMonthly && index == maxXForWeek;

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
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                getTitlesWidget:
                    (value, _) => Text(
                      NumberFormat.compact().format(value.toInt()),
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
            horizontalInterval: interval,
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
                getDotPainter: (spot, _, __, ___) {
                  if (spot.y == 0) {
                    return FlDotCirclePainter(radius: 0);
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
        ),
      ),
    );
  }
}

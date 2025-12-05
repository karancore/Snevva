import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
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
    this.weekLabels,
  });

  final bool isDarkMode;
  final double height;
  final String graphTitle;
  final double yAxisInterval;
  final double gridLineInterval;
  final double yAxisMaxValue;
  final String measureUnit;
  final List<FlSpot> points; // Data points for the graph
  final List<String>?
  weekLabels; // Can be days (Mon-Sun) or month days (1,5,10...)

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

    // Use provided labels, or default weekly labels
    final labels = weekLabels ?? fixedWeekLabels;

    // If labels > 7, treat it as monthly data
    final bool isMonthly = labels.length > 7;

    // Handle "today" index highlighting only for weekly data
    int todayIndex = 0;
    if (!isMonthly && labels.length == 7) {
      todayIndex = DateTime.now().weekday - 1; // Mon = 1
    }

    // Clamp Y values to graph max
    final clampedPoints =
        points.map((p) {
          double y = p.y;
          if (y > yAxisMaxValue) y = yAxisMaxValue;
          // if (y < 0) y = 0;
          return FlSpot(
            double.parse(p.x.toStringAsFixed(2)),
            double.parse(y.toStringAsFixed(2)),
          );
        }).toList();

    // Compute X-axis limits dynamically
    final double maxX =
        clampedPoints.isNotEmpty
            ? clampedPoints.map((e) => e.x).reduce((a, b) => a > b ? a : b)
            : 6;

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
      child: Container(
        height: height * 0.1,
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
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,

                  maxX: 6,

                  minY: 0,
                  maxY: yAxisMaxValue,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: isMonthly ? 5 : 1, // space labels for month
                        getTitlesWidget: (value, _) {
                          final int index = value.toInt();

                          // Use fixed weekly labels only when not monthly
                          final List<String> activeLabels =
                              isMonthly ? labels : fixedWeekLabels;

                          if (index >= 0 && index < activeLabels.length) {
                            final label = activeLabels[index];
                            final bool isToday =
                                !isMonthly && index == todayIndex;

                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight:
                                      isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
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
                        getTitlesWidget: (value, _) {
                          return Text(
                            '${value.toInt()}$measureUnit',
                            style: const TextStyle(fontSize: 9),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: gridLineInterval,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine:
                        (_) =>
                            const FlLine(color: mediumGrey, strokeWidth: 0.8),
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
                      spots: clampedPoints,
                      isCurved: true,
                      color: AppColors.primaryColor,
                      barWidth: 2,
                      dotData: FlDotData(show: true),
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
            ),
          ],
        ),
      ),
    );
  }
}

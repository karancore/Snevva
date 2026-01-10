import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/WomenHealth/bottom_sheet_controller.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';
import 'package:snevva/consts/consts.dart';
import '../../Controllers/WomenHealth/calender_controller.dart';

class CalendarWidget extends StatelessWidget {
  final CalendarController controller = Get.put(CalendarController());
  final WomenHealthController womenController =
      Get.find<WomenHealthController>();
  final BottomSheetController bottomsheetcontroller =
      Get.find<BottomSheetController>();

  final List<String> weekDays = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  /// Generate all cycles for a given range (past + future months)
  List<Map<String, dynamic>> generateCycles({
    required DateTime lastPeriodDate,
    required int cycleLength,
    required int periodLength,
    int monthsForward = 12,
    int monthsBackward = 12,
  }) {
    final List<Map<String, dynamic>> cycles = [];

    for (int i = -monthsBackward; i <= monthsForward; i++) {
      final cycleStart = lastPeriodDate.add(Duration(days: i * cycleLength));
      final periodRange = DateTimeRange(
        start: cycleStart,
        end: cycleStart.add(Duration(days: periodLength - 1)),
      );

      final ovulationDay = cycleStart.add(Duration(days: cycleLength - 14));
      final fertileWindow = DateTimeRange(
        start: ovulationDay.subtract(const Duration(days: 5)),
        end: ovulationDay.add(const Duration(days: 1)),
      );

      cycles.add({
        'periodRange': periodRange,
        'ovulationDay': ovulationDay,
        'fertileWindow': fertileWindow,
      });
    }

    return cycles;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final DateTime today = DateTime.now();

    return Obx(() {
      final month = controller.currentMonth.value;
      final days = _getCalendarDays(month);
      final formatter = DateFormat('MMMM yyyy');

      final firstWeekday =
          DateTime(month.year, month.month, 1).weekday % 7; // Sunday = 0
      final totalCells = firstWeekday + days.length;

      // Parse user inputs
      final int periodLength =
          int.tryParse(womenController.periodDays.value) ?? 5;
      final int cycleLength =
          int.tryParse(womenController.periodCycleDays.value) ?? 28;

      // Parse last period date
      DateTime? lastPeriodDate;
      try {
        final parts = womenController.periodLastPeriodDay.value.split('/');
        if (parts.length == 3) {
          lastPeriodDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (e) {
        lastPeriodDate = null;
      }

      // Pre-compute all cycles (backward + forward months)
      List<Map<String, dynamic>> cycles = [];
      if (lastPeriodDate != null) {
        cycles = generateCycles(
          lastPeriodDate: lastPeriodDate,
          cycleLength: cycleLength,
          periodLength: periodLength,
          monthsBackward: 12,
          monthsForward: 12,
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: controller.prevMonth,
                ),
                Text(
                  formatter.format(month),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: controller.nextMonth,
                ),
              ],
            ),
          ),

          // Weekday Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children:
                  weekDays
                      .map(
                        (day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return Container();
              }

              final day = days[index - firstWeekday];
              Color bgColor = Colors.transparent;
              String emoji = '';
              Color textColor = isDarkMode ? white : black;


              // Check against all cycle ranges
              for (final cycle in cycles) {
                final periodRange = cycle['periodRange'] as DateTimeRange;
                final ovulationDay = cycle['ovulationDay'] as DateTime;
                final fertileWindow = cycle['fertileWindow'] as DateTimeRange;

                // Period days
                if (!day.isBefore(periodRange.start) &&
                    !day.isAfter(periodRange.end)) {
                  textColor = periodHighlighted;
                  bgColor = periodHighlighted.withOpacity(0.2);
                }

                // Fertile window
                if (!day.isBefore(fertileWindow.start) &&
                    !day.isAfter(fertileWindow.end)) {
                  bgColor = Colors.green.withOpacity(0.2);
                  textColor = Colors.green.withOpacity(0.9);
                  emoji = cyclePhaseIcon2;
                }

                // Ovulation day (overrides fertile)
                if (day.year == ovulationDay.year &&
                    day.month == ovulationDay.month &&
                    day.day == ovulationDay.day) {
                  bgColor = yellow.withOpacity(0.2);
                  emoji = cyclePhaseIcon3;
                  textColor = yellow.withOpacity(0.9);
                }
              }

              // Today highlight
              if (day.day == today.day &&
                  day.month == today.month &&
                  day.year == today.year) {
                textColor = AppColors.primaryColor;
                bgColor = AppColors.primaryColor.withOpacity(0.2);
              }

              return InkWell(
  onTap: () {
    final selected = DateTime(day.year, day.month, day.day);
    bottomsheetcontroller.setSelectedDate(selected);

  },
  child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(color: textColor),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 4,
                      child:
                          emoji.isNotEmpty
                              ? SvgPicture.asset(emoji, height: 12, width: 12)
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ));
            },
          ),

          const SizedBox(height: 20),
        ],
      );
    });
  }

  /// Get all days in a month
  List<DateTime> _getCalendarDays(DateTime month) {
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    return List.generate(
      lastDayOfMonth.day,
      (index) => DateTime(month.year, month.month, index + 1),
    );
  }
}

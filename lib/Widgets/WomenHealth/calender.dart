import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/WomenHealth/bottom_sheet_controller.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';
import 'package:snevva/consts/consts.dart';

import '../../Controllers/WomenHealth/calender_controller.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  // ✅ Plain instance — NOT registered in GetX.
  // Obx still reacts to Rx fields regardless of registration.
  // This avoids tag conflicts when two screens both embed CalendarWidget.
  late final CalendarController controller;
  late final WomenHealthController womenController;
  late final BottomSheetController bottomsheetcontroller;

  final List<String> weekDays = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
  ];

  @override
  void initState() {
    super.initState();
    controller = CalendarController();
    controller.onInit(); // manually kick off PageController creation
    womenController = Get.find<WomenHealthController>();
    bottomsheetcontroller = Get.find<BottomSheetController>();
  }

  @override
  void dispose() {
    controller.onClose(); // disposes PageController
    super.dispose();
  }

  // ─── Cycle generation ────────────────────────────────────────────────────
  List<Map<String, dynamic>> _generateCycles({
    required DateTime lastPeriodDate,
    required int cycleLength,
    required int periodLength,
    int monthsForward = 12,
    int monthsBackward = 12,
  }) {
    final cycles = <Map<String, dynamic>>[];
    for (int i = -monthsBackward; i <= monthsForward; i++) {
      final cycleStart = lastPeriodDate.add(Duration(days: i * cycleLength));
      final ovulationDay = cycleStart.add(Duration(days: cycleLength - 14));
      cycles.add({
        'periodRange': DateTimeRange(
          start: cycleStart,
          end: cycleStart.add(Duration(days: periodLength - 1)),
        ),
        'ovulationDay': ovulationDay,
        'fertileWindow': DateTimeRange(
          start: ovulationDay.subtract(const Duration(days: 5)),
          end: ovulationDay.add(const Duration(days: 1)),
        ),
      });
    }
    return cycles;
  }

  List<DateTime> _getCalendarDays(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0);
    return List.generate(
      lastDay.day,
      (i) => DateTime(month.year, month.month, i + 1),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final DateTime today = DateTime.now();

    // ✅ One Obx wraps the entire calendar.
    //    Reacts to:
    //    • controller.currentMonth  → swipe or < > buttons
    //    • womenController.periodLastPeriodDay / hasPeriodData / etc.
    //      → period date updated via the + button
    return Obx(() {
      // ── Read period data reactively ──────────────────────────────────────
      final int periodLength =
          int.tryParse(womenController.periodDays.value) ?? 5;
      final int cycleLength =
          int.tryParse(womenController.periodCycleDays.value) ?? 28;

      DateTime? lastPeriodDate;
      if (womenController.hasPeriodData.value &&
          womenController.periodDataStartDay.value != 0 &&
          womenController.periodDataStartMonth.value != 0 &&
          womenController.periodDataStartYear.value != 0) {
        lastPeriodDate = DateTime(
          womenController.periodDataStartYear.value,
          womenController.periodDataStartMonth.value,
          womenController.periodDataStartDay.value,
        );
      } else {
        try {
          final parts = womenController.periodLastPeriodDay.value.split('/');
          if (parts.length == 3) {
            lastPeriodDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } catch (_) {}
      }

      final cycles = lastPeriodDate != null
          ? _generateCycles(
              lastPeriodDate: lastPeriodDate,
              cycleLength: cycleLength,
              periodLength: periodLength,
            )
          : <Map<String, dynamic>>[];

      // ── Current displayed month (reactive) ───────────────────────────────
      final DateTime displayMonth = controller.currentMonth.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Month header with < > buttons ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  // ✅ Writes to Rx → Obx rebuilds header instantly
                  onPressed: controller.prevMonth,
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(displayMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: controller.nextMonth,
                ),
              ],
            ),
          ),

          // ── Weekday row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: weekDays
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          // ── Swipeable PageView ───────────────────────────────────────────
          SizedBox(
            height: 300,
            child: PageView.builder(
              controller: controller.pageController,
              // ✅ Writing to Rx inside onPageChanged triggers Obx rebuild
              //    → month name in header updates immediately on swipe
              onPageChanged: controller.onPageChanged,
              itemBuilder: (context, pageIndex) {
                final offset = pageIndex - CalendarController.initialPage;
                final pageMonth = DateTime(
                  DateTime.now().year,
                  DateTime.now().month + offset,
                );

                final days = _getCalendarDays(pageMonth);
                final firstWeekday =
                    DateTime(pageMonth.year, pageMonth.month, 1).weekday % 7;
                final totalCells = firstWeekday + days.length;

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalCells,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                  ),
                  itemBuilder: (context, gridIndex) {
                    if (gridIndex < firstWeekday) {
                      return const SizedBox.shrink();
                    }

                    final day = days[gridIndex - firstWeekday];
                    Color bgColor = Colors.transparent;
                    String emoji = '';
                    Color textColor = isDarkMode ? white : black;

                    for (final cycle in cycles) {
                      final periodRange =
                          cycle['periodRange'] as DateTimeRange;
                      final ovulationDay = cycle['ovulationDay'] as DateTime;
                      final fertileWindow =
                          cycle['fertileWindow'] as DateTimeRange;

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

                      // Ovulation (highest priority among cycle markers)
                      if (day.year == ovulationDay.year &&
                          day.month == ovulationDay.month &&
                          day.day == ovulationDay.day) {
                        bgColor = yellow.withOpacity(0.2);
                        emoji = cyclePhaseIcon3;
                        textColor = yellow.withOpacity(0.9);
                      }
                    }

                    // Today (absolute highest priority)
                    if (day.day == today.day &&
                        day.month == today.month &&
                        day.year == today.year) {
                      textColor = AppColors.primaryColor;
                      bgColor = AppColors.primaryColor.withOpacity(0.2);
                    }

                    return InkWell(
                      onTap: () => bottomsheetcontroller.setSelectedDate(
                        DateTime(day.year, day.month, day.day),
                      ),
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
                              child: emoji.isNotEmpty
                                  ? SvgPicture.asset(
                                      emoji,
                                      height: 12,
                                      width: 12,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 20),
        ],
      );
    });
  }
}

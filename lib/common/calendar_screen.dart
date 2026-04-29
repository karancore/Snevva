import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/common/calendar_widget.dart';
import 'package:snevva/models/mood_model.dart';

import '../consts/colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState(); // ✅ private, correct
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<MoodModel> moodData = [];

  // ✅ Key points to CustomCalendar's state — that's where the scroll lives
  final GlobalKey<CustomCalendarState> _calendarKey =
      GlobalKey<CustomCalendarState>();

  @override
  void initState() {
    super.initState();
    getMood();
  }

  Future<void> getMood() async {
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    moodData = await Get.find<MoodController>().loadMoodFromAPI(
      month: currentMonth,
      year: currentYear,
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double scale = MediaQuery
        .of(context)
        .size
        .width / 360;

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? black : white,
      body: Padding(
        padding: const EdgeInsets.only(top: 59.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? black : white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    isDarkMode
                        ? white.withOpacity(0.15)
                        : black.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 15.0,
              vertical: 16.0,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Close button
                    Container(
                      height: 24 * scale,
                      width: 24 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDarkMode ? black : white,
                        boxShadow: [
                          BoxShadow(
                            color:
                                isDarkMode
                                    ? white.withOpacity(0.28)
                                    : black.withOpacity(0.28),
                            offset: const Offset(2, 2),
                            blurRadius: 2,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () => Get.back(),
                        child: const Icon(Icons.close, size: 18),
                      ),
                    ),
                    const Spacer(flex: 10),
                    const Text(
                      "Mood Tracker",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(flex: 6),

                    // ✅ Today button — calls scrollToCurrentMonth() on CustomCalendar
                    InkWell(
                      onTap: () =>
                          _calendarKey.currentState?.scrollToCurrentMonth(),
                      child: Container(
                        height: 24 * scale,
                        width: 76 * scale,
                        decoration: BoxDecoration(
                          color: isDarkMode ? black : white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  isDarkMode
                                      ? white.withOpacity(0.26)
                                      : black.withOpacity(0.26),
                              offset: const Offset(1, 1),
                              blurRadius: 4,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "Today",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18 * scale),

                // ✅ Key passed here — this is the widget the key controls
                Expanded(
                  child: CustomCalendar(
                    key: _calendarKey,
                    year: DateTime
                        .now()
                        .year,
                    mood: moodData,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:snevva/Widgets/WomenHealth/calender.dart';
import 'package:snevva/common/calendar_widget.dart';

import '../consts/colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    double scale = screenWidth / 360;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 59.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: Offset(0, -3), // ✅ shadow on top
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 15.0,
              vertical: 33.0,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      height: 24 * scale,
                      width: 24 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.28),
                            offset: Offset(2, 2),
                            blurRadius: 2,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          Get.back();
                        },
                        child: Icon(Icons.close, size: 18),
                      ),
                    ),
                    Spacer(flex: 10),
                    Text(
                      "Mood Tracker",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(flex: 6),
                    Container(
                      height: 24 * scale,
                      width: 76 * scale,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.26),
                            offset: Offset(1, 1),
                            blurRadius: 4,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "Today",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30 * scale),

                Expanded(child: CustomCalendar(year: 2025)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

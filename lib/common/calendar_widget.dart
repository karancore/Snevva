import 'package:flutter/material.dart';
import 'package:snevva/models/mood_model.dart';

import '../consts/images.dart';
import '../views/MoodTracker/mood_details_card.dart';

class CustomCalendar extends StatefulWidget {
  final int year;
  final List<MoodModel> mood; // Map of date to mood

  const CustomCalendar({super.key, required this.year, required this.mood});

  @override
  State<CustomCalendar> createState() => _CustomCalendarState();
}

int getDaysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

int getFirstWeekday(int year, int month) {
  return DateTime(year, month, 1).weekday;
}

DateTime normalize(DateTime d) {
  return DateTime(d.year, d.month, d.day);
}

String monthName(int month) {
  const months = [
    "",
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  return months[month];
}

class _CustomCalendarState extends State<CustomCalendar> {
  final ScrollController _controller = ScrollController();

  final double monthHeight = 300;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentMonth = DateTime.now().month;

      final screenHeight = MediaQuery.of(context).size.height;

      final double topUIHeight = 150;

      double adjustment = screenHeight * 0.25; // tweak 0.2 - 0.3

      final targetOffset =
          (currentMonth - 1) * monthHeight -
              ((screenHeight - topUIHeight) / 2) +
              (monthHeight / 2) +
              adjustment;
      _controller.jumpTo(
        targetOffset.clamp(0, _controller.position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    final int daysInMonth = getDaysInMonth(widget.year, DateTime.now().month);
    final int firstWeekday = getFirstWeekday(widget.year, DateTime.now().month);

    double scale = screenWidth / 360;
    // Adjust so Sunday = 0
    final int startOffset = firstWeekday % 7;

    final int totalItems = daysInMonth + startOffset;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            double totalWidth = constraints.maxWidth;

            // same spacing as grid
            double spacing = 12;

            // calculate each cell width exactly like GridView
            double itemWidth = (totalWidth - (6 * spacing)) / 7;

            return Row(
              children: List.generate(7, (index) {
                final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

                return Padding(
                  padding: EdgeInsets.only(right: index == 6 ? 0 : spacing),
                  child: SizedBox(
                    width: itemWidth,
                    child: Center(
                      child: Text(
                        days[index][0],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        Expanded(
          child: ListView.builder(
            controller: _controller,
            padding: const EdgeInsets.only(top: 12),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              print("📅 Building month: $month");
              return buildMonth(month);
            },
          ),
        ),
      ],
    );
  }

  String getImage(String mood) {
    switch (mood) {
      case 'Pleasant':
        return pleasant;
      case 'Good':
        return neutral;
      case 'Unpleasant':
        return unpleasant;
      default:
        return neutral;
    }
  }

  Widget buildMonth(int month) {
    final int daysInMonth = getDaysInMonth(widget.year, month);
    final int firstWeekday = getFirstWeekday(widget.year, month);

    double screenWidth = MediaQuery.of(context).size.width;
    double scale = screenWidth / 360;

    final int startOffset = firstWeekday % 7;
    final int totalItems = daysInMonth + startOffset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            monthName(month),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 8),

        Stack(
          children: [
            /// 🔹 LINE GRID
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: totalItems,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 12,
                mainAxisExtent: 40,
              ),
              itemBuilder: (context, index) {
                if (index < startOffset) return const SizedBox();

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(height: 1, color: const Color(0xff828282)),
                );
              },
            ),

            /// 🔹 CIRCLE GRID
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: totalItems,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 40,
              ),
              itemBuilder: (context, index) {
                if (index < startOffset) return const SizedBox();

                final int day = index - startOffset + 1;
                final currentDate = DateTime(widget.year, month, day);


                MoodModel? matchedMood;

                for (var m in widget.mood) {
                  final apiDate = DateTime(m.year, m.month, m.day);

                  if (apiDate.year == currentDate.year &&
                      apiDate.month == currentDate.month &&
                      apiDate.day == currentDate.day) {
                    debugPrint("✅ MATCH FOUND");
                    matchedMood = m;
                    break;
                  }
                }

                if (matchedMood == null) {
                  debugPrint(" No match for $day-$month-${widget.year}");
                }

                String? imagePath;

                if (matchedMood != null) {
                  imagePath = getImage(matchedMood.mood);
                }

                return Center(
                  child: Container(
                    width: 26 * scale,
                    height: 26 * scale,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child:
                    imagePath != null
                        ? InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withOpacity(0.3),
                          builder: (context) {
                            return MoodDetailsCard(mood: widget.mood[index]);
                          },
                        );
                      },
                      child: ClipOval(
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                        : Container(
                      decoration: const BoxDecoration(
                        color: Color(0xffD9D9D9),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          day.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

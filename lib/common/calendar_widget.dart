import 'package:flutter/material.dart';

class CustomCalendar extends StatefulWidget {
  final int year;

  const CustomCalendar({super.key, required this.year});

  @override
  State<CustomCalendar> createState() => _CustomCalendarState();
}

int getDaysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

int getFirstWeekday(int year, int month) {
  return DateTime(year, month, 1).weekday;
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
                final days = [
                  'Sun',
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                ];

                return Padding(
                  padding: EdgeInsets.only(
                    right: index == 6 ? 0 : spacing,
                  ),
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
              return buildMonth(month);
            },
          ),
        ),
      ],
    );
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

                return Center(
                  child: Container(
                    width: 22 * scale,
                    height: 22 * scale,
                    decoration: const BoxDecoration(
                      color: Color(0xffD9D9D9),
                      shape: BoxShape.circle,
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

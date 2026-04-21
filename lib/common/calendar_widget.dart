import 'package:flutter/material.dart';
import 'package:snevva/models/mood_model.dart';
import '../consts/images.dart';
import '../views/MoodTracker/mood_details_card.dart';

class CustomCalendar extends StatefulWidget {
  final int year;
  final List<MoodModel> mood;

  const CustomCalendar({super.key, required this.year, required this.mood});

  @override
  State<CustomCalendar> createState() => _CustomCalendarState();
}

// ─── Pure helpers (top-level, never rebuilt) ────────────────────────────────

int getDaysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

int getFirstWeekday(int year, int month) => DateTime(year, month, 1).weekday;

String monthName(int month) {
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return months[month];
}

const _weekDayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

// ─── Image resolver (top-level, avoids closure allocation per cell) ──────────

String _moodImage(String mood) {
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

// ────────────────────────────────────────────────────────────────────────────

class _CustomCalendarState extends State<CustomCalendar> {
  final ScrollController _scrollController = ScrollController();
  static const double _monthHeight = 300;

  /// KEY FIX: O(1) lookup map, rebuilt only when mood list actually changes.
  late Map<DateTime, MoodModel> _moodMap;

  @override
  void initState() {
    super.initState();
    _moodMap = _buildMoodMap(widget.mood);

    WidgetsBinding.instance.addPostFrameCallback((_) =>
        _scrollToCurrentMonth());
  }

  /// Rebuild the map when the parent passes a new mood list.
  @override
  void didUpdateWidget(CustomCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _moodMap = _buildMoodMap(widget.mood);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Build the map once → O(N) total, instead of O(N) per cell
  Map<DateTime, MoodModel> _buildMoodMap(List<MoodModel> moods) {
    return {
      for (final m in moods) DateTime(m.year, m.month, m.day): m,
    };
  }

  void _scrollToCurrentMonth() {
    if (!_scrollController.hasClients) return;
    final currentMonth = DateTime
        .now()
        .month;
    final screenHeight = MediaQuery
        .of(context)
        .size
        .height;
    const double topUIHeight = 150;
    final double adjustment = screenHeight * 0.25;

    final targetOffset =
        (currentMonth - 1) * _monthHeight -
            ((screenHeight - topUIHeight) / 2) +
            (_monthHeight / 2) +
            adjustment;

    _scrollController.jumpTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WeekDayHeader(), // const widget — never rebuilds
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 12),
            itemCount: 12,
            itemBuilder: (_, index) =>
                _MonthGrid(
                  year: widget.year,
                  month: index + 1,
                  moodMap: _moodMap, // pass the pre-built map, NOT the list
                ),
          ),
        ),
      ],
    );
  }
}

// ─── Stateless week-day header ───────────────────────────────────────────────
// Extracted so it NEVER rebuilds when mood data changes.

class _WeekDayHeader extends StatelessWidget {
  const _WeekDayHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const double spacing = 12;
      final double itemWidth = (constraints.maxWidth - 6 * spacing) / 7;

      return Row(
        children: List.generate(7, (i) {
          return Padding(
            padding: EdgeInsets.only(right: i == 6 ? 0 : spacing),
            child: SizedBox(
              width: itemWidth,
              child: Center(
                child: Text(
                  _weekDayLabels[i],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      );
    });
  }
}

// ─── Per-month grid (stateless) ──────────────────────────────────────────────
// Extracted into its own widget so Flutter can skip rebuilding months
// that haven't changed (when only one month's data updates).

class _MonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final Map<DateTime, MoodModel> moodMap; // O(1) lookup

  const _MonthGrid({
    required this.year,
    required this.month,
    required this.moodMap,
  });

  @override
  Widget build(BuildContext context) {
    final double scale = MediaQuery
        .of(context)
        .size
        .width / 360;
    final int days = getDaysInMonth(year, month);
    final int startOffset = getFirstWeekday(year, month) % 7;
    final int totalItems = days + startOffset;

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
            if (index < startOffset) return const SizedBox.shrink();

            final int day = index - startOffset + 1;
            final DateTime date = DateTime(year, month, day);

            // ✅ O(1) lookup — no loop here
            final MoodModel? matched = moodMap[date];

            if (matched != null) {
              final String imagePath = _moodImage(matched.mood);
              return _MoodCell(
                imagePath: imagePath,
                mood: matched,
                scale: scale,
              );
            }

            return _EmptyCell(day: day, scale: scale);
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── Leaf cells (stateless, minimal rebuild surface) ────────────────────────

class _MoodCell extends StatelessWidget {
  final String imagePath;
  final MoodModel mood;
  final double scale;

  const _MoodCell({
    required this.imagePath,
    required this.mood,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Center(
            child: InkWell(
              onTap: () =>
                  showDialog(
                    context: context,
                    barrierColor: Colors.black26,
                    builder: (_) => MoodDetailsCard(mood: mood),
                  ),
              child: SizedBox(
                width: 26 * scale,
                height: 26 * scale,
                child: ClipOval(
                  child: Image.asset(imagePath, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
        Container(height: 1, color: const Color(0xff828282)),
      ],
    );
  }
}

class _EmptyCell extends StatelessWidget {
  final int day;
  final double scale;

  const _EmptyCell({required this.day, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Center(
            child: SizedBox(
              width: 20 * scale,
              height: 20 * scale,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xffD9D9D9),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(height: 1, color: const Color(0xff828282)),
      ],
    );
  }
}
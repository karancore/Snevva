import 'dart:ui';

import 'package:intl/intl.dart';

import '../../Controllers/MoodTracker/mood_controller.dart';
import '../../consts/consts.dart';
import '../../models/mood_model.dart';

String formatDate(int day, int month, int year) {
  DateTime date = DateTime(year, month, day);
  return DateFormat('d MMMM, y').format(date);
}

class AddGlucoseCard extends StatelessWidget {
  const AddGlucoseCard({super.key});

  @override
  Widget build(BuildContext context) {
    MoodModel? mood;
    double screenWidth = MediaQuery.of(context).size.width;

    final moodController = Get.find<MoodController>();

    double scale = screenWidth / 360;

    double itemHeight = 42 * scale;

    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0), // required
          ),
        ),

        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 360 * scale,
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: [
                    Color(0xffC793FF), // lighter
                    Color(0xffB475FF), // base
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),

              child: Stack(
                children: [
                  /// ✨ Decorative Glow Circle (background)
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// 🔹 HEADER
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                formatDate(
                                  mood?.day ?? 0,
                                  mood?.month ?? 0,
                                  mood?.year ?? 0,
                                ),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 30), // balance alignment
                        ],
                      ),

                      SizedBox(height: 20),

                      /// 🌟 HERO MOOD IMAGE (with glow)
                      Container(
                        padding: EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                        child: Image.asset(
                          glucoseDrop,
                          width: 120 * scale,
                          height: 120 * scale,
                        ),
                      ),

                      SizedBox(height: 20),

                      /// 🧠 MOOD TITLE
                      Text(
                        mood?.mood ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 6),

                      /// ⏱ TIME
                      Text(
                        mood?.time ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),

                      SizedBox(height: 20),

                      /// 📦 INFO CARD (instead of ListTile)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              child: Image.asset(
                                glucoseDrop,
                                width: 18,
                                height: 18,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Add your glucose",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 10),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

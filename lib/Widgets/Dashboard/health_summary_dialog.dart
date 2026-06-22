import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../Controllers/Hydration/hydration_stat_controller.dart';
import '../../Controllers/MoodTracker/mood_controller.dart';
import '../../Controllers/SleepScreen/sleep_controller.dart';
import '../../Controllers/StepCounter/step_counter_controller.dart';
import '../../Controllers/dashboard/health_score_controller.dart';

class HealthSummaryDialogHelper {
  static void show(BuildContext context, bool isDarkMode) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Health Summary',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => HealthSummaryDialog(isDarkMode: isDarkMode),
      transitionBuilder:
          (_, anim, __, child) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
    );
  }
}

class HealthSummaryDialog extends StatelessWidget {
  final bool isDarkMode;

  const HealthSummaryDialog({Key? key, required this.isDarkMode})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HealthScoreController>();
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final scale = w / 400.0; // scale factor for responsiveness

    DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    String formattedDate = DateFormat('MMMM d, yyyy').format(yesterday);

    // Attempt to grab actual data for UI realism
    int waterCurrent = 0, waterGoal = 2000;
    int stepCurrent = 0, stepGoal = 8000;
    int sleepMins = 0, sleepGoalMins = 480;
    String moodCurrent = 'Good';

    if (Get.isRegistered<HydrationStatController>()) {
      final h = Get.find<HydrationStatController>();
      String key = "${yesterday.year}-${yesterday.month}-${yesterday.day}";
      waterCurrent = h.waterHistoryByDate[key] ?? 0;
      waterGoal = h.waterGoal.value > 0 ? h.waterGoal.value : 2000;
    }

    if (Get.isRegistered<StepCounterController>()) {
      final s = Get.find<StepCounterController>();
      String key =
          "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      stepCurrent = s.stepsHistoryByDate[key] ?? 0;
      stepGoal = s.stepGoal.value > 0 ? s.stepGoal.value : 8000;
    }

    if (Get.isRegistered<SleepController>()) {
      final sl = Get.find<SleepController>();
      String key =
          "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      Duration? d = sl.weeklySleepHistory[key];
      if (d != null) sleepMins = d.inMinutes;
      sleepGoalMins =
          sl.sleepGoal.value.inMinutes > 0 ? sl.sleepGoal.value.inMinutes : 480;
    }

    if (Get.isRegistered<MoodController>()) {
      final m = Get.find<MoodController>();
      moodCurrent =
          m.selectedMood.value.isNotEmpty ? m.selectedMood.value : 'Good';
    }

    double waterPct = (waterCurrent / waterGoal).clamp(0.0, 1.0);
    double stepPct = (stepCurrent / stepGoal).clamp(0.0, 1.0);
    double sleepPct = (sleepMins / sleepGoalMins).clamp(0.0, 1.0);
    double moodPct =
        moodCurrent == 'Pleasant' || moodCurrent == 'Good'
            ? 1.0
            : (moodCurrent == 'Unpleasant' ? 0.3 : 0.8);

    Color bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDarkMode ? Colors.white : const Color(0xFF1C1C1E);
    Color textSubColor = isDarkMode ? Colors.white70 : const Color(0xFF8E8E93);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: w * 0.92,
          constraints: BoxConstraints(maxHeight: size.height * 0.85),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.all(20 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sun Icon
                    Container(
                      padding: EdgeInsets.all(8 * scale),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wb_sunny_rounded,
                        color: Colors.orange,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Your Daily Health Summary",
                            style: TextStyle(
                              fontSize: 18 * scale,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            "Yesterday • $formattedDate",
                            style: TextStyle(
                              fontSize: 13 * scale,
                              color: textSubColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Circular Score
                    Container(
                      width: 60 * scale,
                      height: 60 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green.withOpacity(0.2),
                          width: 4,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${controller.overallHealthScore.value.toInt()}",
                            style: TextStyle(
                              fontSize: 22 * scale,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            "Overall",
                            style: TextStyle(
                              fontSize: 9 * scale,
                              color: textSubColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16 * scale),

                // Motivational Quote
                Text(
                  "Great job! You stayed consistent and made healthy choices yesterday. 🎉",
                  style: TextStyle(
                    fontSize: 14 * scale,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 24 * scale),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatCol(
                      scale: scale,
                      icon: Icons.water_drop_rounded,
                      iconColor: Colors.blue,
                      title: "Water Intake",
                      value: "${(waterCurrent / 1000).toStringAsFixed(1)} L",
                      goal: "Goal: ${(waterGoal / 1000).toStringAsFixed(1)} L",
                      progress: waterPct,
                      pctText: "${(waterPct * 100).toInt()}%",
                      textColor: textColor,
                      textSubColor: textSubColor,
                    ),
                    _buildStatCol(
                      scale: scale,
                      icon: Icons.directions_run_rounded,
                      iconColor: Colors.green,
                      title: "Steps",
                      value: "${NumberFormat('#,###').format(stepCurrent)}",
                      goal: "Goal: ${NumberFormat('#,###').format(stepGoal)}",
                      progress: stepPct,
                      pctText: "${(stepPct * 100).toInt()}%",
                      textColor: textColor,
                      textSubColor: textSubColor,
                    ),
                    _buildStatCol(
                      scale: scale,
                      icon: Icons.nights_stay_rounded,
                      iconColor: Colors.deepPurple,
                      title: "Sleep",
                      value: "${sleepMins ~/ 60}h ${sleepMins % 60}m",
                      goal: "Goal: ${sleepGoalMins ~/ 60}h",
                      progress: sleepPct,
                      pctText: "${(sleepPct * 100).toInt()}%",
                      textColor: textColor,
                      textSubColor: textSubColor,
                    ),
                    _buildStatCol(
                      scale: scale,
                      icon: Icons.sentiment_satisfied_rounded,
                      iconColor: Colors.orange,
                      title: "Mood",
                      value: moodCurrent,
                      goal: "Goal: Positive",
                      progress: moodPct,
                      pctText: "${(moodPct * 100).toInt()}%",
                      textColor: textColor,
                      textSubColor: textSubColor,
                    ),
                    _buildStatCol(
                      scale: scale,
                      icon: Icons.favorite_rounded,
                      iconColor: Colors.red,
                      title: "Vitals",
                      value: "Good",
                      goal: "All in range",
                      progress: 1.0,
                      pctText: "100%",
                      textColor: textColor,
                      textSubColor: textSubColor,
                      isDots: true,
                    ),
                  ],
                ),
                SizedBox(height: 24 * scale),

                // Side-by-side Cards
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(12 * scale),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode
                                  ? Colors.green.withOpacity(0.15)
                                  : const Color(0xFFF2FBF4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.green,
                                  size: 20 * scale,
                                ),
                                SizedBox(width: 6 * scale),
                                Text(
                                  "What went well",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12 * scale,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8 * scale),
                            Text(
                              "Great sleep and vitals! You're building strong healthy habits.",
                              style: TextStyle(
                                fontSize: 11 * scale,
                                color:
                                    isDarkMode
                                        ? Colors.green.shade100
                                        : Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(12 * scale),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode
                                  ? Colors.blue.withOpacity(0.15)
                                  : const Color(0xFFF4F8FC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.track_changes_rounded,
                                  color: Colors.blue,
                                  size: 20 * scale,
                                ),
                                SizedBox(width: 6 * scale),
                                Text(
                                  "Focus for today",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12 * scale,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8 * scale),
                            Text(
                              "Try to drink a little more water to hit your goal!",
                              style: TextStyle(
                                fontSize: 11 * scale,
                                color:
                                    isDarkMode
                                        ? Colors.blue.shade100
                                        : Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16 * scale),

                // Health Insight
                _buildFullWidthCard(
                  scale: scale,
                  isDarkMode: isDarkMode,
                  bgColor:
                      isDarkMode
                          ? Colors.purple.withOpacity(0.15)
                          : const Color(0xFFF8F5FC),
                  icon: Icons.auto_graph_rounded,
                  iconColor: Colors.deepPurple,
                  title: "Health Insight",
                  content:
                      "You walk more on days when you sleep well. Keep it up—great sleep fuels your activity!",
                ),
                SizedBox(height: 12 * scale),

                // Personalized Recommendation
                _buildFullWidthCard(
                  scale: scale,
                  isDarkMode: isDarkMode,
                  bgColor:
                      isDarkMode
                          ? Colors.lightBlue.withOpacity(0.15)
                          : const Color(0xFFF4F8FC),
                  icon: Icons.lightbulb_outline_rounded,
                  iconColor: Colors.lightBlue,
                  title: "Personalized Recommendation",
                  content:
                      "A 10-minute evening walk can boost your step count and improve sleep quality.",
                ),
                SizedBox(height: 20 * scale),

                // Streaks Section
                Container(
                  padding: EdgeInsets.all(16 * scale),
                  decoration: BoxDecoration(
                    color:
                        isDarkMode
                            ? Colors.orange.withOpacity(0.1)
                            : const Color(0xFFFFFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      // Left - Streaks
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Colors.orange,
                                  size: 20 * scale,
                                ),
                                SizedBox(width: 6 * scale),
                                Text(
                                  "Streaks",
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14 * scale,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16 * scale),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStreakItem(
                                  scale,
                                  Icons.water_drop_rounded,
                                  Colors.blue,
                                  "5",
                                  "days",
                                  "Water",
                                  textColor,
                                  textSubColor,
                                ),
                                _buildStreakItem(
                                  scale,
                                  Icons.directions_run_rounded,
                                  Colors.green,
                                  "12",
                                  "days",
                                  "Steps",
                                  textColor,
                                  textSubColor,
                                ),
                                _buildStreakItem(
                                  scale,
                                  Icons.nights_stay_rounded,
                                  Colors.deepPurple,
                                  "9",
                                  "days",
                                  "Sleep",
                                  textColor,
                                  textSubColor,
                                ),
                                _buildStreakItem(
                                  scale,
                                  Icons.favorite_rounded,
                                  Colors.red,
                                  "8",
                                  "days",
                                  "Vitals",
                                  textColor,
                                  textSubColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Divider
                      Container(
                        height: 60 * scale,
                        width: 1,
                        color: Colors.orange.withOpacity(0.3),
                        margin: EdgeInsets.symmetric(horizontal: 12 * scale),
                      ),

                      // Right - Keep going
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Keep going!",
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 13 * scale,
                              ),
                            ),
                            SizedBox(height: 6 * scale),
                            Text(
                              "Consistency today creates a healthier tomorrow.",
                              style: TextStyle(
                                fontSize: 10 * scale,
                                color:
                                    isDarkMode
                                        ? Colors.orange.shade100
                                        : Colors.orange.shade900,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Icon(
                                Icons.favorite_outline_rounded,
                                color: Colors.orange.shade300,
                                size: 20 * scale,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCol({
    required double scale,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String goal,
    required double progress,
    required String pctText,
    required Color textColor,
    required Color textSubColor,
    bool isDots = false,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8 * scale),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24 * scale),
        ),
        SizedBox(height: 8 * scale),
        Text(
          title,
          style: TextStyle(
            fontSize: 10 * scale,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4 * scale),
        Text(
          value,
          style: TextStyle(
            fontSize: 14 * scale,
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(goal, style: TextStyle(fontSize: 9 * scale, color: textSubColor)),
        SizedBox(height: 8 * scale),

        if (isDots)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              7,
              (index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 1.5 * scale),
                width: 4 * scale,
                height: 4 * scale,
                decoration: BoxDecoration(
                  color: index < 7 ? iconColor : Colors.grey.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          )
        else
          Container(
            width: 40 * scale,
            height: 4 * scale,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.centerLeft,
            child: Container(
              width: (40 * scale) * progress,
              height: 4 * scale,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

        SizedBox(height: 6 * scale),
        Text(
          pctText,
          style: TextStyle(
            fontSize: 10 * scale,
            color: iconColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFullWidthCard({
    required double scale,
    required bool isDarkMode,
    required Color bgColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 14 * scale,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8 * scale),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22 * scale),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13 * scale,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 11 * scale,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8 * scale),
          Align(
            alignment: Alignment.centerRight,
            child: Icon(
              Icons.chevron_right_rounded,
              color: isDarkMode ? Colors.white54 : Colors.black45,
              size: 24 * scale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakItem(
    double scale,
    IconData icon,
    Color iconColor,
    String count,
    String unit,
    String label,
    Color textColor,
    Color textSubColor,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 14 * scale),
            SizedBox(width: 2 * scale),
            Text(
              count,
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        Text(unit, style: TextStyle(fontSize: 9 * scale, color: textSubColor)),
        SizedBox(height: 2 * scale),
        Text(label, style: TextStyle(fontSize: 9 * scale, color: textColor)),
      ],
    );
  }
}

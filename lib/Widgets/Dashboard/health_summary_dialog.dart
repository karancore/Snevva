import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../Controllers/Hydration/hydration_stat_controller.dart';
import '../../Controllers/MoodTracker/mood_controller.dart';
import '../../Controllers/SleepScreen/sleep_controller.dart';
import '../../Controllers/StepCounter/step_counter_controller.dart';
import '../../Controllers/dashboard/health_score_controller.dart';
import '../../consts/colors.dart';
import '../../consts/images.dart';

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

class HealthSummaryDialog extends StatefulWidget {
  final bool isDarkMode;

  const HealthSummaryDialog({super.key, required this.isDarkMode});

  @override
  State<HealthSummaryDialog> createState() => _HealthSummaryDialogState();
}

class _HealthSummaryDialogState extends State<HealthSummaryDialog> {
  @override
  void initState() {
    super.initState();
    Get.put(HealthScoreController());
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HealthScoreController>();
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final scale = w / 400.0; // scale factor for responsiveness
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final double cardScale = width / 360;

    DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    String formattedDate = DateFormat('MMMM d, yyyy').format(yesterday);

    // Attempt to grab actual data for UI realism
    int waterCurrent = 0, waterGoal = 2000;
    int stepCurrent = 0, stepGoal = 8000;
    int sleepMins = 0, sleepGoalMins = 480;
    String moodCurrent = '';

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
      moodCurrent = m.selectedMood.value.isNotEmpty ? m.selectedMood.value : '';
    }

    double waterPct = (waterCurrent / waterGoal).clamp(0.0, 1.0);
    double stepPct = (stepCurrent / stepGoal).clamp(0.0, 1.0);
    double sleepPct = (sleepMins / sleepGoalMins).clamp(0.0, 1.0);
    double moodPct =
        moodCurrent == 'Pleasant' || moodCurrent == 'Good'
            ? 1.0
            : (moodCurrent == 'Unpleasant' ? 0.3 : 0.8);

    bool isConsistent = controller.overallHealthScore.value >= 70;

    String dynamicInsight = "";
    String dynamicFocusTitle = "Focus for today";
    String dynamicFocusContent = "";
    IconData dynamicFocusIcon = Icons.track_changes_rounded;
    Color dynamicFocusColor = Colors.blue;

    if (waterCurrent == 0 && stepCurrent == 0 && sleepMins == 0) {
      dynamicInsight =
      "It looks like you didn't log many metrics yesterday. Tracking your habits is the first step to improving them!";
      dynamicFocusContent =
      "Try logging your water intake and steps today. Every little bit counts.";
      dynamicFocusIcon = Icons.assignment_rounded;
      dynamicFocusColor = Colors.blue;
    } else if (waterCurrent == 0) {
      dynamicInsight =
      "You didn't log any water yesterday. Staying hydrated is crucial for your overall health and energy levels.";
      dynamicFocusContent =
      "Focus on drinking at least a few glasses of water today.";
      dynamicFocusIcon = Icons.water_drop_rounded;
      dynamicFocusColor = Colors.blue;
    } else if (stepCurrent == 0) {
      dynamicInsight =
      "No steps were recorded yesterday. Movement helps keep your body and mind feeling fresh.";
      dynamicFocusContent =
      "Try to take a short 10-minute walk today to get your body moving.";
      dynamicFocusIcon = Icons.directions_run_rounded;
      dynamicFocusColor = Colors.green;
    } else if (sleepMins == 0) {
      dynamicInsight =
      "You didn't log your sleep last night. Tracking sleep helps you understand your energy patterns.";
      dynamicFocusContent =
      "Remember to log your sleep tonight so we can help you rest better.";
      dynamicFocusIcon = Icons.nights_stay_rounded;
      dynamicFocusColor = Colors.deepPurple;
    } else {
      Map<String, double> metrics = {
        'water': waterPct,
        'steps': stepPct,
        'sleep': sleepPct,
      };
      var lowestMetric = metrics.entries.reduce(
            (a, b) => a.value < b.value ? a : b,
      );

      if (lowestMetric.value >= 0.8) {
        dynamicInsight =
        "You are doing amazing! All your metrics from yesterday were excellent. Keep it up!";
        dynamicFocusTitle = "What went well";
        dynamicFocusContent =
        "Great sleep, hydration, and activity! You're building strong healthy habits.";
        dynamicFocusIcon = Icons.check_circle_outline_rounded;
        dynamicFocusColor = Colors.green;
      } else {
        if (lowestMetric.key == 'water') {
          dynamicInsight =
          "You missed your hydration goal yesterday. Drinking water consistently improves energy levels!";
          dynamicFocusContent =
          "Try carrying a water bottle today to remind yourself to drink more.";
          dynamicFocusIcon = Icons.water_drop_rounded;
          dynamicFocusColor = Colors.blue;
        } else if (lowestMetric.key == 'steps') {
          dynamicInsight =
          "Your step count was a bit low yesterday. A short walk can do wonders for your mood and health.";
          dynamicFocusContent =
          "Try taking a 15-minute walk during your break today to get those steps in!";
          dynamicFocusIcon = Icons.directions_run_rounded;
          dynamicFocusColor = Colors.green;
        } else if (lowestMetric.key == 'sleep') {
          dynamicInsight =
          "You didn't get enough sleep yesterday. Lack of sleep can impact your recovery and focus.";
          dynamicFocusContent =
          "Try going to bed 30 minutes earlier tonight to get better rest.";
          dynamicFocusIcon = Icons.nights_stay_rounded;
          dynamicFocusColor = Colors.deepPurple;
        }
      }
    }

    Color bgColor = widget.isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;
    Color textColor =
    widget.isDarkMode ? Colors.white : const Color(0xFF1C1C1E);
    Color textSubColor =
    widget.isDarkMode ? Colors.white70 : const Color(0xFF8E8E93);
    Color primaryPurple = const Color(0xFFA95BFF);

    return Center(
      child: Material(
        color: Colors.transparent,

        child: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            width: w * 0.92,
            constraints: BoxConstraints(maxHeight: size.height * 0.85),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: Image.asset(yellowTop),
                ),
                Padding(
                  padding: EdgeInsets.all(
                    24 * scale,

                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Header
                        Row(
                          children: [
                            Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                "Good Morning",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 22 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 78 * scale),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Card(
                              elevation: 4,
                              color: Colors.white,
                              margin: EdgeInsets.zero,
                              shape: WaveTopCardShape(
                                borderRadius: 20,
                                dipStart: 0.47 * cardScale,
                                dipEnd: 0.85 * cardScale,
                                dipDepth: 24,
                              ),
                              child: SizedBox(
                                height: 170 * scale,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                    6.0),
                                                child: FaIcon(
                                                  FontAwesomeIcons.heartbeat,
                                                  size: 16,
                                                  color: white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Overall Health",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -110 * scale,
                              // 👈 card ke top edge se upar nikalta hai
                              right: 24 * scale,
                              // 👈 right side, dip ke area mein
                              child: Image.asset(
                                helloElly,
                                height: 140 * scale,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12 * scale),

                        // Metrics Section (Compact Pills)
                        Wrap(
                          spacing: 12 * scale,
                          runSpacing: 12 * scale,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildMetricPill(
                              scale,
                              Icons.water_drop_rounded,
                              Colors.blue,
                              "Water",
                              "${(waterCurrent / 1000).toStringAsFixed(1)}L",
                              waterPct,
                              widget.isDarkMode,
                            ),
                            _buildMetricPill(
                              scale,
                              Icons.directions_run_rounded,
                              Colors.green,
                              "Steps",
                              NumberFormat('#,###').format(stepCurrent),
                              stepPct,
                              widget.isDarkMode,
                            ),
                            _buildMetricPill(
                              scale,
                              Icons.nights_stay_rounded,
                              Colors.deepPurple,
                              "Sleep",
                              "${sleepMins ~/ 60}h ${sleepMins % 60}m",
                              sleepPct,
                              widget.isDarkMode,
                            ),
                            _buildMetricPill(
                              scale,
                              Icons.sentiment_satisfied_rounded,
                              Colors.orange,
                              "Mood",
                              moodCurrent,
                              moodPct,
                              widget.isDarkMode,
                            ),
                          ],
                        ),

                        SizedBox(height: 24 * scale),

                        // AI Insight Section
                        _buildInsightCard(
                          scale,
                          widget.isDarkMode,
                          primaryPurple,
                          textColor,
                          dynamicInsight,
                        ),

                        SizedBox(height: 16 * scale),

                        // Achievement Section (Focus / Went Well)
                        _buildAchievementCard(
                          scale,
                          widget.isDarkMode,
                          dynamicFocusTitle,
                          dynamicFocusContent,
                          dynamicFocusIcon,
                          dynamicFocusColor,
                          textColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroScore(double scale,
      double score,
      String category,
      bool isDarkMode,
      Color textColor,
      Color subColor,) {
    Color scoreColor;
    if (score >= 80)
      scoreColor = Colors.green;
    else if (score >= 60)
      scoreColor = Colors.orange;
    else
      scoreColor = Colors.red;

    return Column(
      children: [
        SizedBox(
          width: 180 * scale,
          height: 90 * scale, // Half height for semi-circle roughly
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${score.toInt()}",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 48 * scale,
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                    height: 1.0,
                  ),
                ),
                Text(
                  "out of 100",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12 * scale,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16 * scale),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 6 * scale,
          ),
          decoration: BoxDecoration(
            color: scoreColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            category,
            style: TextStyle(
              fontFamily: 'Inter',
              color: scoreColor,
              fontWeight: FontWeight.bold,
              fontSize: 14 * scale,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricPill(double scale,
      IconData icon,
      Color color,
      String title,
      String value,
      double progress,
      bool isDarkMode,) {
    // Roughly half width minus spacing
    double w = 140 * scale;

    return Container(
      width: w,
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: isDarkMode ? color.withOpacity(0.1) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18 * scale),
              SizedBox(width: 6 * scale),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12 * scale,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16 * scale,
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8 * scale),
          Container(
            height: 4 * scale,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(double scale,
      bool isDarkMode,
      Color primaryColor,
      Color textColor,
      String insightText,) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color:
        isDarkMode
            ? primaryColor.withOpacity(0.15)
            : primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8 * scale),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: primaryColor,
              size: 20 * scale,
            ),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Snevva Insight",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  insightText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13 * scale,
                    color: textColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(double scale,
      bool isDarkMode,
      String title,
      String content,
      IconData icon,
      Color iconColor,
      Color textColor,) {
    Color cardColor =
    isDarkMode ? iconColor.withOpacity(0.15) : iconColor.withOpacity(0.05);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18 * scale),
              SizedBox(width: 8 * scale),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          Text(
            content,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12 * scale,
              color: isDarkMode ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class WaveTopCardShape extends ShapeBorder {
  final double borderRadius;
  final double dipStart; // fraction of width jaha se dip start hoti hai (0-1)
  final double dipEnd; // fraction of width jaha dip khatam hoti hai (0-1)
  final double dipDepth; // kitna neeche jaana hai

  const WaveTopCardShape({
    this.borderRadius = 20,
    this.dipStart = 0.55,
    this.dipEnd = 0.88,
    this.dipDepth = 28,
  });

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    final r = borderRadius;
    final w = rect.width;

    final dipStartX = rect.left + w * dipStart;
    final dipEndX = rect.left + w * dipEnd;
    final top = rect.top;
    final dipWidth = dipEndX - dipStartX;

    // top-left corner
    path.moveTo(rect.left, rect.top + r);
    path.quadraticBezierTo(rect.left, top, rect.left + r, top);

    // straight top edge till dip start
    path.lineTo(dipStartX, top);

    // Curvy S — control points khud curvature dete hain, koi rise/transition nahi
    path.cubicTo(
      dipStartX + dipWidth * 0.25, top, // seedhi line se tangent match
      dipStartX + dipWidth * 0.25, top + dipDepth,
      // yahin se neeche khinchna shuru
      dipStartX + dipWidth * 0.5,
      top + dipDepth, // dip ka sabse neeche wala point
    );
    path.cubicTo(
      dipStartX + dipWidth * 0.75, top + dipDepth, // dip ke bottom se
      dipEndX - dipWidth * 0.25, top, // wapas seedhi line ke tangent tak
      dipEndX, top,
    );

    // remaining straight top edge to top-right corner
    path.lineTo(rect.right - r, top);
    path.quadraticBezierTo(rect.right, top, rect.right, top + r);

    // right edge
    path.lineTo(rect.right, rect.bottom - r);
    path.quadraticBezierTo(
        rect.right, rect.bottom, rect.right - r, rect.bottom);

    // bottom edge
    path.lineTo(rect.left + r, rect.bottom);
    path.quadraticBezierTo(rect.left, rect.bottom, rect.left, rect.bottom - r);

    path.close();
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(0);

  @override
  ShapeBorder scale(double t) => this;
}

class InwardTopCardClipper extends CustomClipper<Path> {
  final double curveDepth; // kitna andar dhasega

  InwardTopCardClipper({this.curveDepth = 30});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0); // top-left
    // top edge: seedha jaake beech me andar dip karke wapas
    path.quadraticBezierTo(
      size.width / 2,
      curveDepth, // control point (neeche = andar bend)
      size.width,
      0, // end point top-right
    );
    path.lineTo(size.width, size.height); // right edge
    path.lineTo(0, size.height); // bottom edge
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ElephantCard extends StatelessWidget {
  const ElephantCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 40, // card ko thoda neeche push karo taaki elephant upar dikhe
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: InwardTopCardClipper(curveDepth: 35),
              child: Container(
                height: 180,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
                child: const Text('Card content here'),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Image.asset(helloElly, height: 100, width: 100),
          ),
        ],
      ),
    );
  }
}

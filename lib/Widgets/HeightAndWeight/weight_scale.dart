import 'dart:math';
import '../../Controllers/ProfileSetupAndQuestionnare/height_and_weight_controller.dart';
import '../../consts/consts.dart';

class WeightScale extends StatefulWidget {
  const WeightScale({super.key});


  @override
  State<WeightScale> createState() => _WeightScaleState();

}
class _WeightScaleState extends State<WeightScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  double _needleWeight = 0; // start at 0
  final double minWeight = 0;
  final double maxWeight = 150;

  final HeightWeightController controller = Get.find();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // needle animation duration
    );

    // Delay needle animation by 1 second to simulate "scale starting"
    Future.delayed(const Duration(seconds: 1), () {
      animateNeedleToWeight(controller.weightInKg.value);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void animateNeedleToWeight(double targetWeight) {
    _animation = Tween<double>(begin: _needleWeight, end: targetWeight)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ))
      ..addListener(() {
        setState(() {
          _needleWeight = _animation.value;
        });
      });

    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Center(
      child: CustomPaint(
        size: const Size(300, 300),
        painter: WeightPainter(
          _needleWeight, // needle moves, actual weight stays fixed
          minWeight,
          maxWeight,
          isDarkMode,
          width,
        ),
      ),
    );
  }
}




class WeightPainter extends CustomPainter {
  final double selectedWeight;
  final double minWeight;
  final double maxWeight;
  final bool isDarkMode;
  final double width;

  WeightPainter(
    this.selectedWeight,
    this.minWeight,
    this.maxWeight,
    this.isDarkMode,
    this.width,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = width > 400 ? (size.width / 2) : (size.width / 2.6);

    final arcPaint =
        Paint()
          ..color = mediumGrey.withAlpha(50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 48;

    final tickPaint =
        Paint()
          ..color = isDarkMode ? white : black
          ..strokeWidth = 2;

    final textStyle = TextStyle(
      color: isDarkMode ? white : black,
      fontSize: 12,
    );

    int step = 10;
    int totalSteps = ((maxWeight - minWeight) / step).round();

    // 1. Draw the arc at the top
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 12),
      pi,
      pi,
      false,
      arcPaint,
    );

    for (int i = 0; i <= totalSteps; i++) {
      double weightValue = minWeight + (i * step);
      double angle = pi + (i / totalSteps) * pi;

      bool isMajor = weightValue % 20 == 0;
      double arcTop = radius + 24; // Just below the arc
      double tickLength = isMajor ? 12 : 6;

      // 2. Tick marks below the arc
      double x1 = center.dx + (arcTop - tickLength) * cos(angle);
      double y1 = center.dy + (arcTop - tickLength) * sin(angle);
      double x2 = center.dx + arcTop * cos(angle);
      double y2 = center.dy + arcTop * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);

      // 3. Labels below the tick marks
      if (isMajor) {
        final label = weightValue.toStringAsFixed(0);
        final span = TextSpan(text: label, style: textStyle);
        final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
        tp.layout();

        double labelRadius = arcTop + 12;
        double tx = center.dx + labelRadius * cos(angle) - tp.width / 2;
        double ty = center.dy + labelRadius * sin(angle) - tp.height / 2;

        tp.paint(canvas, Offset(tx, ty));
      }
    }

    // 4. Draw the needle over everything
    double selectedAngle =
        pi + ((selectedWeight - minWeight) / (maxWeight - minWeight)) * pi;

    double needleLength = radius + 8;
    double needleX = center.dx + needleLength * cos(selectedAngle);
    double needleY = center.dy + needleLength * sin(selectedAngle);

    final needlePaint =
        Paint()
          ..color = AppColors.primaryColor
          ..strokeWidth = 4;

    final needleTip = Offset(needleX, needleY);
    final needleBase = center;

    canvas.drawLine(needleBase, needleTip, needlePaint);

    // --- Arrowhead logic added here ---

    const double arrowHeadSize = 20;
    const double arrowAngle = pi / 8; // ~22.5 degrees

    final leftWing = Offset(
      needleX - arrowHeadSize * cos(selectedAngle - arrowAngle),
      needleY - arrowHeadSize * sin(selectedAngle - arrowAngle),
    );

    final rightWing = Offset(
      needleX - arrowHeadSize * cos(selectedAngle + arrowAngle),
      needleY - arrowHeadSize * sin(selectedAngle + arrowAngle),
    );

    final arrowPaint = Paint()..color = AppColors.primaryColor;

    final path =
        Path()
          ..moveTo(needleTip.dx, needleTip.dy)
          ..lineTo(leftWing.dx, leftWing.dy)
          ..lineTo(rightWing.dx, rightWing.dy)
          ..close();

    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

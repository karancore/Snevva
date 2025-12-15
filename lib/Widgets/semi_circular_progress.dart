import 'dart:math' as math;
import 'package:flutter/material.dart';

class SemiCircularProgress extends StatefulWidget {
  final double percent;
  final double radius;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;
  final Duration duration;

  const SemiCircularProgress({
    required this.percent,
    this.radius = 100,
    this.strokeWidth = 10,
    this.color = Colors.blue,
    this.backgroundColor = Colors.grey,
    this.duration = const Duration(seconds: 1),
    super.key,
  });

  @override
  State<SemiCircularProgress> createState() => _SemiCircularProgressState();
}

class _SemiCircularProgressState extends State<SemiCircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);

    _animation = Tween<double>(
      begin: 0,
      end: widget.percent,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant SemiCircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.percent != widget.percent) {
      _animation = Tween<double>(
        begin: 0,
        end: widget.percent,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.radius * 2, widget.radius),
          painter: _SemiCirclePainter(
            percent: _animation.value,
            strokeWidth: widget.strokeWidth,
            color: widget.color,
            backgroundColor: widget.backgroundColor,
          ),
        );
      },
    );
  }
}

class _SemiCirclePainter extends CustomPainter {
  final double percent, strokeWidth;
  final Color color, backgroundColor;

  _SemiCirclePainter({
    required this.percent,
    required this.strokeWidth,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint =
        Paint()
          ..color = backgroundColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final fgPaint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    const startAngle = math.pi;
    const totalSweep = math.pi;
    const paddingAngle = 0.02;

    canvas.drawArc(
      rect,
      startAngle + paddingAngle,
      totalSweep - 2 * paddingAngle,
      false,
      bgPaint,
    );

    canvas.drawArc(rect, startAngle, totalSweep * percent, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _SemiCirclePainter old) =>
      old.percent != percent ||
      old.color != color ||
      old.backgroundColor != backgroundColor ||
      old.strokeWidth != strokeWidth;
}

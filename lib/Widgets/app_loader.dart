import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AppLoader extends StatelessWidget {
  static const String assetPath = 'assets/lottie/app_loader.json';
  static const double defaultSize = 120;

  const AppLoader({
    super.key,
    this.size = defaultSize,
    this.fullscreen = false,
    this.backgroundOpacity = 0,
    this.message,
    this.semanticsLabel = 'Loading',
  });

  final double size;
  final bool fullscreen;
  final double backgroundOpacity;
  final String? message;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final loader = Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity, child: child);
        },
        child: Semantics(
          label: message?.isNotEmpty == true ? message : semanticsLabel,
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ConstrainedLottieLoader(size: size),
              if (message?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final opacity = backgroundOpacity.clamp(0.0, 1.0).toDouble();
    final content = fullscreen ? SafeArea(child: loader) : loader;
    final background = opacity <= 0
        ? content
        : DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(opacity),
            ),
            child: content,
          );

    if (!fullscreen) return background;

    return SizedBox.expand(child: background);
  }
}

class LoaderOverlay extends StatelessWidget {
  const LoaderOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.size = AppLoader.defaultSize,
    this.backgroundOpacity = 0.42,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final double size;
  final double backgroundOpacity;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: AppLoader(
                fullscreen: true,
                size: size,
                backgroundOpacity: backgroundOpacity,
                message: message,
                semanticsLabel: 'Loading overlay',
              ),
            ),
          ),
      ],
    );
  }
}

class AppLoadingButton extends StatelessWidget {
  const AppLoadingButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.child,
    this.style,
    this.loaderSize = 28,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final double loaderSize;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: AppLoadingButtonChild(
        isLoading: isLoading,
        loaderSize: loaderSize,
        child: child,
      ),
    );
  }
}

class AppLoadingButtonChild extends StatelessWidget {
  const AppLoadingButtonChild({
    super.key,
    required this.isLoading,
    required this.child,
    this.loaderSize = 28,
  });

  final bool isLoading;
  final Widget child;
  final double loaderSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: isLoading
          ? SizedBox.square(
              key: const ValueKey('app-button-loader'),
              dimension: loaderSize,
              child: AppLoader(
                size: loaderSize,
                semanticsLabel: 'Button loading',
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('app-button-child'),
              child: child,
            ),
    );
  }
}

class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.value,
    required this.size,
    required this.strokeWidth,
    required this.color,
    required this.backgroundColor,
    this.child,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value.clamp(0.0, 1.0).toDouble();

    return Semantics(
      label: 'Progress',
      value: '${(normalizedValue * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _AppProgressRingPainter(
                value: normalizedValue,
                strokeWidth: strokeWidth,
                color: color,
                backgroundColor: backgroundColor,
              ),
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _ConstrainedLottieLoader extends StatelessWidget {
  const _ConstrainedLottieLoader({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : double.infinity;
        final availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : double.infinity;
        final availableSide = math.min(availableWidth, availableHeight);
        final double resolvedSize = availableSide.isFinite
            ? math.max(16.0, math.min(size, availableSide))
            : size;

        return RepaintBoundary(
          child: SizedBox.square(
            dimension: resolvedSize,
            child: Lottie.asset(
              AppLoader.assetPath,
              repeat: true,
              animate: true,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}

class _AppProgressRingPainter extends CustomPainter {
  const _AppProgressRingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.backgroundColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AppProgressRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

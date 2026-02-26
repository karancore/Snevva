import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:snevva/performance/refresh_rate_bootstrap.dart';

class HighFpsDemoScreen extends StatefulWidget {
  const HighFpsDemoScreen({super.key});

  @override
  State<HighFpsDemoScreen> createState() => _HighFpsDemoScreenState();
}

class _HighFpsDemoScreenState extends State<HighFpsDemoScreen>
    with SingleTickerProviderStateMixin {
  static const AssetImage _avatarAsset = AssetImage('assets/Images/avatar1.webp');

  late final AnimationController _controller;
  late final ValueNotifier<double> _progress;
  bool _showDeferredSection = false;
  bool _didPrecache = false;

  @override
  void initState() {
    super.initState();

    // Quantize animation duration to an integer number of frames for the
    // active refresh rate so animation progression stays frame-consistent.
    final duration = RefreshRateBootstrap.quantizeDuration(
      const Duration(milliseconds: 720),
    );

    // ValueNotifier keeps updates scoped to listening widgets only.
    _progress = ValueNotifier<double>(0.0);

    _controller = AnimationController(vsync: this, duration: duration)
      ..addListener(() {
        _progress.value = _controller.value;
      })
      ..repeat(reverse: true);

    // Defer heavy UI to avoid competing with first frame rasterization.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      RefreshRateBootstrap.updateFromContext(context);
      setState(() => _showDeferredSection = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;

    // Pre-cache image to avoid decode/upload work during animation frames.
    precacheImage(_avatarAsset, context);
  }

  @override
  void dispose() {
    _controller.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = RefreshRateBootstrap.profile;
    final contextRefreshRate =
        RefreshRateBootstrap.readContextRefreshRate(context) ??
        profile.detectedRefreshRateHz;

    return Scaffold(
      appBar: AppBar(title: const Text('120 FPS Performance Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatsCard(
            detectedRefreshRateHz: contextRefreshRate,
            targetFrameRateHz: profile.targetFrameRateHz,
            frameBudgetMs: 1000.0 / profile.targetFrameRateHz,
            supportsHighRefresh: profile.supportsHighRefresh,
          ),
          const SizedBox(height: 16),
          const Text(
            'Animated ring (isolated repaints)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Center(
            child: ValueListenableBuilder<double>(
              valueListenable: _progress,
              child: const SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: Text(
                    'RepaintBoundary\n+ ValueListenableBuilder',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              builder: (context, progress, child) {
                return RepaintBoundary(
                  child: CustomPaint(
                    size: const Size.square(200),
                    painter: _PulsePainter(progress: progress),
                    child: child,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const _StaticTips(),
          const SizedBox(height: 16),
          const Text(
            'Pre-cached image (no decode spikes during animation)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              child: Image(
                image: _avatarAsset,
                height: 120,
                width: 120,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_showDeferredSection)
            const _DeferredGrid()
          else
            const SizedBox(
              height: 140,
              child: Center(
                child: Text('Deferring heavy section until after first frame...'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final double detectedRefreshRateHz;
  final double targetFrameRateHz;
  final double frameBudgetMs;
  final bool supportsHighRefresh;

  const _StatsCard({
    required this.detectedRefreshRateHz,
    required this.targetFrameRateHz,
    required this.frameBudgetMs,
    required this.supportsHighRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Runtime refresh profile',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Detected: ${detectedRefreshRateHz.toStringAsFixed(1)} Hz | '
              'Target: ${targetFrameRateHz.toStringAsFixed(0)} FPS',
            ),
            Text('Frame budget: ${frameBudgetMs.toStringAsFixed(2)} ms'),
            Text(
              supportsHighRefresh
                  ? 'High refresh supported (90+ Hz)'
                  : 'Fallback mode: optimized for 60 FPS',
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticTips extends StatelessWidget {
  const _StaticTips();

  @override
  Widget build(BuildContext context) {
    // Keeping static subtrees const reduces layout/build work each frame.
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Low-jank checklist', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('1. Keep per-frame work under ~8.33 ms on 120 Hz screens.'),
            Text('2. Use RepaintBoundary to isolate expensive repaints.'),
            Text('3. Minimize rebuild scope with listenable/state selectors.'),
            Text('4. Precache assets and defer non-critical initialization.'),
          ],
        ),
      ),
    );
  }
}

class _DeferredGrid extends StatelessWidget {
  const _DeferredGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deferred heavy section',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        RepaintBoundary(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 24,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.35,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Tile ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;

  _PulsePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide * 0.42;

    final bgPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = const Color(0xFFE5E7EB);
    canvas.drawCircle(center, maxRadius, bgPaint);

    final sweep = 2 * math.pi * progress;
    final activePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 8
          ..color = const Color(0xFF0EA5E9);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      -math.pi / 2,
      sweep,
      false,
      activePaint,
    );

    final glowPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0x330EA5E9);
    canvas.drawCircle(center, maxRadius * (0.4 + (0.2 * progress)), glowPaint);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

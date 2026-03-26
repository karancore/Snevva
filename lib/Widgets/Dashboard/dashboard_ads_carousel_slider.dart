import 'dart:math' as math;

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/views/Dashboard/dashboard.dart';
import 'package:snevva/views/Information/BMI/bmi_cal.dart';
import 'package:snevva/views/Information/StepCounter/step_counter.dart';
import 'package:snevva/views/MoodTracker/mood_tracker_screen.dart';
import 'package:snevva/views/Reminder/add_reminder_screen.dart';

import '../../consts/consts.dart';

class DashboardAdsCarouselSlider extends StatefulWidget {
  const DashboardAdsCarouselSlider({super.key});

  @override
  State<DashboardAdsCarouselSlider> createState() =>
      _DashboardAdsCarouselSliderState();
}

final items = [adImg5, adImg1, adImg2, adImg3, adImg4];
final List<AssetImage> _adImages = items
    .map((path) => AssetImage(path))
    .toList(growable: false);

class _DashboardAdsCarouselSliderState
    extends State<DashboardAdsCarouselSlider> {
  static const double _maxHeight = 200.0;
  static const double _adAspectRatio = 1360 / 768;
  static const double _horizontalInset = 5.0;
  static const double _cornerRadius = 20.0;
  final CarouselSliderController controller = CarouselSliderController();
  int activeIndex = 0;
  bool _didPrecache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    for (final image in _adImages) {
      precacheImage(image, context);
    }
  }

  final List<Widget> _adPages = [
    const StepCounter(),
    const AddReminderScreen(),
    const BmiCal(),
    const MoodTrackerScreen(),
  ];

  void handleTap(int index) {
    if (index == 0) return;
    final pageIndex = index - 1;
    if (pageIndex < _adPages.length) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => _adPages[pageIndex]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTabActive = TickerMode.of(context);
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width =
            constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : media.size.width;
        final double height = math.min(_maxHeight, media.size.height * 0.2);
        final double idealWidth = height * _adAspectRatio;
        final double displayWidth =
            (width.isFinite ? width : idealWidth) - (_horizontalInset * 2);
        final int cacheWidthPx =
            (displayWidth * media.devicePixelRatio).round();
        final int cacheHeightPx = (height * media.devicePixelRatio).round();
        final double indicatorBottom = (height * 0.12).clamp(8.0, 18.0);

        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            CarouselSlider(
              carouselController: controller,
              options: CarouselOptions(
                height: height,
                aspectRatio: _adAspectRatio,
                autoPlay: isTabActive,
                viewportFraction: 1.0,
                enlargeCenterPage: false,
                onPageChanged: (index, reason) {
                  setState(() {
                    activeIndex = index;
                  });
                },
              ),
              items: List<Widget>.generate(_adImages.length, (index) {
                return Builder(
                  builder: (BuildContext context) {
                    return GestureDetector(
                      onTap: () {
                        handleTap(index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _horizontalInset,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_cornerRadius),
                          child: SizedBox(
                            width: double.infinity,
                            height: height,
                            child: Image(
                              image: ResizeImage(
                                _adImages[index],
                                width: cacheWidthPx,
                                height: cacheHeightPx,
                              ),
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
            Positioned(
              bottom: indicatorBottom,
              child: AnimatedSmoothIndicator(
                activeIndex: activeIndex,
                count: _adImages.length,
                effect: const SwapEffect(
                  dotHeight: 10,
                  type: SwapType.yRotation,
                  dotWidth: 10,
                  activeDotColor: AppColors.primaryColor,
                ),
                onDotClicked: (index) => controller.animateToPage(index),
              ),
            ),
          ],
        );
      },
    );
  }
}

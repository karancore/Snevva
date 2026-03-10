import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../consts/consts.dart';

class DashboardAdsCarouselSlider extends StatefulWidget {
  const DashboardAdsCarouselSlider({super.key});

  @override
  State<DashboardAdsCarouselSlider> createState() =>
      _DashboardAdsCarouselSliderState();
}

final items = [adImg1, adImg1, adImg1, adImg1, adImg1];
final List<AssetImage> _adImages =
    items.map((path) => AssetImage(path)).toList(growable: false);

class _DashboardAdsCarouselSliderState
    extends State<DashboardAdsCarouselSlider> {
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

  @override
  Widget build(BuildContext context) {
    final bool isTabActive = TickerMode.of(context);
    final media = MediaQuery.of(context);
    final int cacheWidthPx = (media.size.width * media.devicePixelRatio).round();
    final int cacheHeightPx = (124.0 * media.devicePixelRatio).round();

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider(
          carouselController: controller,
          options: CarouselOptions(
            height: 124.0,
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
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
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
                );
              },
            );
          }),
        ),
        Positioned(
          bottom: 0,
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
  }
}

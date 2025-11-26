import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../consts/consts.dart';

class DashboardAdsCarouselSlider extends StatefulWidget {
  const DashboardAdsCarouselSlider({
    super.key,
  });

  @override
  State<DashboardAdsCarouselSlider> createState() => _DashboardAdsCarouselSliderState();
}

final items = [adImg1,adImg1,adImg1,adImg1,adImg1];

class _DashboardAdsCarouselSliderState extends State<DashboardAdsCarouselSlider> {

  final CarouselSliderController controller = CarouselSliderController();
  int activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider(
          carouselController: controller,
          options: CarouselOptions(
            height: 124.0,
            autoPlay: true,
            viewportFraction: 1.0,
            enlargeCenterPage: false,
            onPageChanged: (index, reason) {
              setState(() {
                activeIndex = index;
              });
            },
          ),
          items: items.map((i) {
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
                      child: Image(image: AssetImage(i),fit: BoxFit.cover,)),
                );
              },
            );
          }).toList(),
        ),
        Positioned(
          bottom: 0,
          child: AnimatedSmoothIndicator(
            activeIndex: activeIndex,
            count: 5,
            effect: const SwapEffect(
              dotHeight: 10,
              type: SwapType.yRotation,
              dotWidth: 10,
              activeDotColor: AppColors.primaryColor,
            ),
            onDotClicked: (index) =>
                controller.animateToPage(index),
          ),
        ),
      ],
    );
  }
}

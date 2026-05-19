import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:snevva/Controllers/BMI/bmi_updatecontroller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/consts/colors.dart';
import 'package:snevva/consts/images.dart';
import 'package:snevva/models/common_tips_response.dart';
import 'package:snevva/views/Information/BMI/bmi_updateCal.dart';
import 'package:snevva/widgets/app_loader.dart';

import '../../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../Health Tips/Nutrition_tips.dart/nutrition_tips.dart';

class BMIUpdateResultScreen extends StatefulWidget {
  final double bmi;
  final int age;

  const BMIUpdateResultScreen({
    super.key,
    required this.bmi,
    required this.age,
  });

  @override
  State<BMIUpdateResultScreen> createState() => _BMIUpdateResultScreenState();
}

String getStatus(double bmi) {
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25) return 'Great-Shape';
  if (bmi < 30) return 'Overweight';
  return 'Obese';
}

class _BMIUpdateResultScreenState extends State<BMIUpdateResultScreen> {
  late final BmiUpdateController controller;

  final scrollController = ScrollController();
  bool _showAppBar = true;

  String getImg(double bmi) {
    if (bmi < 18.5) return skinny;
    if (bmi < 25) return bmiEle;
    if (bmi < 30) return fatty;
    return fatty;
  }

  Color getStatusColor(double bmi) {
    if (bmi < 18.5) return Colors.yellow;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }

  double getSliderPosition(double bmi) {
    if (bmi < 12) return 0;
    if (bmi > 40) return 1;
    return (bmi - 12) / (40 - 12);
  }

  @override
  void initState() {
    super.initState();
    controller = Get.find<BmiUpdateController>();
    controller.age.value = widget.age;
    controller.bmi_text.value = getStatus(widget.bmi);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadAllHealthTips(context);
    });
    scrollController.addListener(() {
      if (scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (_showAppBar) {
          setState(() {
            _showAppBar = false;
          });
        }
      } else if (scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (!_showAppBar) {
          setState(() {
            _showAppBar = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;

    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final status = getStatus(widget.bmi);
    final statusColor = getStatusColor(widget.bmi);
    final imagePath = getImg(widget.bmi);

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),

      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_showAppBar ? kToolbarHeight : 0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _showAppBar ? 1.0 : 0.0,
          child: CustomAppBar(appbarText: "BMI Result"),
        ),
      ),
      body: SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              SizedBox(height: height * 0.02165842),
              // 2.165842% of screen height

              // Elephant Image
              Image.asset(
                imagePath, // Replace with your image path
                height: 150,
              ),

              const SizedBox(height: 20),

              // BMI Value Card
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.bmi.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Color-coded BMI Indicator Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 6,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.yellow,
                            Colors.green,
                            Colors.orange,
                            Colors.red,
                          ],
                          stops: [0.25, 0.5, 0.75, 1],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                    Positioned(
                      left:
                          getSliderPosition(widget.bmi) *
                          MediaQuery.of(context).size.width *
                          0.8,
                      child: const Icon(
                        Icons.arrow_drop_down,
                        size: 30,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Status Text
              Text(
                status,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),

              const SizedBox(height: 10),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
                ),
                onPressed: () {
                  Get.to(() => BmiUpdatecal());
                },
                child: Text(
                  "Update BMI",
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? white : white,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Suggestions Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Suggestion",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Obx(() {
                final tips = controller.randomTips;

                if (controller.isLoading.value) {
                  return const AppLoader();
                }

                if (tips.isEmpty) {
                  return const Text("No suggestions found.");
                }

                debugPrint(
                  "Image URL: ${tips[0]['ThumbnailMedia']?['CdnUrl']}",
                );

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children:
                      tips.map((tipData) {
                        final tip = CommonTip.fromJson(tipData);

                        return SizedBox(
                          width: (width - 56) / 2,
                          child: _buildTipCard(
                            heading: tip.heading ?? '',
                            title: tip.title ?? '',
                            image: "https://${tip.thumbnailMedia?.cdnUrl}",
                            isDarkMode: isDarkMode,
                            onButtonTap:
                                () => Get.to(
                                  () => NutritionTipsPage(commonTip: tip),
                                ),
                          ),
                        );
                      }).toList(),
                );
              }),

              Obx(
                () =>
                    controller.isLoadingMore.value
                        ? const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: AppLoader(size: 36),
                        )
                        : const SizedBox.shrink(),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required String image,
    required String heading,
    required String title,
    required VoidCallback onButtonTap,
    required bool isDarkMode,
  }) {
    return Card(
      elevation: 4,
      color: isDarkMode ? darkGray : white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              image,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 120,
                  color: Colors.grey[200],
                  child: const AppLoader(size: 40),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              heading,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 2.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 6,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  minimumSize: const Size(75, 18),

                  // OR fixedSize: const Size(90, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),

                  // Inner spacing
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                onPressed: onButtonTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Know More",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 14,
                      width: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDarkMode ? darkGray.withOpacity(0.9) : white,
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: 135 * math.pi / 180,
                            child: Icon(
                              Icons.arrow_back,
                              size: 10,
                              color: isDarkMode ? white : black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _suggestionCard({
  //   required String title,
  //   required width,
  //   required String subtitle,
  //   required String imagePath,
  //   required bool isDarkMode,
  // }) {
  //   return SizedBox(
  //     width: width / 2.38,
  //     height: 220,
  //     child: Card(
  //       color: isDarkMode? darkGray : white,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //       elevation: 4,
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           ClipRRect(
  //             borderRadius: const BorderRadius.vertical(
  //               top: Radius.circular(12),
  //             ),
  //             child: Image.asset(
  //               imagePath,
  //               height: 100,
  //               width: double.infinity,
  //               fit: BoxFit.cover,
  //             ),
  //           ),
  //           SizedBox(height: 10,),
  //           Column(
  //             children: [
  //               Text(
  //                 title,
  //                 style: const TextStyle(fontWeight: FontWeight.bold),
  //               ),
  //               Text(
  //                 textAlign: TextAlign.center,
  //                 subtitle,
  //                 style: const TextStyle(color: Colors.grey, fontSize: 12),
  //               ),
  //             ],
  //           ),
  //           // SizedBox(height: 10,),
  //           Align(
  //             alignment: Alignment.bottomCenter,
  //             child: TextButton(
  //               style: TextButton.styleFrom(
  //                 foregroundColor: AppColors.primaryColor,
  //                 padding: EdgeInsets.zero,
  //               ),
  //               onPressed: () {},
  //               child: Padding(
  //                 padding: const EdgeInsets.symmetric(horizontal: 8),
  //                 child: const Text("Know More"),
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}

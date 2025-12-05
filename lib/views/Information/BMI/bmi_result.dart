import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:snevva/Controllers/BMI/bmicontroller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/colors.dart';
import 'package:snevva/consts/images.dart';

import '../../../Controllers/HealthTips/healthtips_controller.dart';
import '../Health Tips/Nutrition_tips.dart/nutrition_tips.dart';

class BmiResultPage extends StatelessWidget {
  final double bmi;
  final int age;


  const BmiResultPage({super.key, required this.bmi, required this.age});

  String getStatus(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Great Shape';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }
  
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
  Widget build(BuildContext context) {

    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final controller = Get.put(Bmicontroller());
    controller.age.value = age;
    controller.bmi_text.value = getStatus(bmi);

    controller.loadAllHealthTips(context);

    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
    final status = getStatus(bmi);
    final statusColor = getStatusColor(bmi);
    final imagePath = getImg(bmi);

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      extendBodyBehindAppBar: true,

      appBar: CustomAppBar(appbarText: "BMI Result"),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 90),
        
              // Elephant Image
              Image.asset(
                imagePath, // Replace with your image path
                height: 150,
              ),
        
              const SizedBox(height: 20),
        
              // BMI Value Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  bmi.toStringAsFixed(2),
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
                          getSliderPosition(bmi) *
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

              const SizedBox(height: 30),
        
              // Suggestions Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Suggestion",
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
        
              const SizedBox(height: 12),

              Obx(() {
                final tips = controller.randomTips;

                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (tips.isEmpty) {
                  return const Text("No suggestions found.");
                }

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: tips.map((tip) {
                    return SizedBox(
                      width: (width - 56) / 2,
                      child: _buildTipCard(
                        heading: tip['Heading'] ?? '',
                        title: tip['Title'] ?? '',
                        image: tip['ThumbnailMedia']?['CdnUrl'] ?? "https://d3byuuhm0bg21i.cloudfront.net/derivatives/c3d47d00-8a25-46ef-bba3-ec5609c49b08/thumb.webp",
                        isDarkMode: isDarkMode,
                          onButtonTap: () => Get.to(() => NutritionTipsPage(), arguments: tip),
                      ),
                    );
                  }).toList(),
                );
              }),


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
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.broken_image)),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 120,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
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
            padding: const EdgeInsets.fromLTRB(8.0,2.0,8.0,2.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding:
                  const EdgeInsets.fromLTRB(10.0,0.0,10.0,0.0),
                ),
                onPressed: onButtonTap,
                child: const Text(
                  "Know More",
                  style: TextStyle(color: Colors.white, fontSize: 12),
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

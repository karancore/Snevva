import 'package:snevva/Controllers/HealthTips/healthtips_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Information/Health%20Tips/Nutrition_tips.dart/nutrition_tips.dart';

class HealthTipsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
    final controller = Get.put(HealthTipsController());

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Health Tips"),
      body: Obx(() {
        final count = controller.randomTips.length;
        final numRows = (count / 2).ceil();
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.hasError.value) {
          return const Center(child: Text('Failed to load health tips. Please try again.'));
        }

        if (controller.randomTips.isEmpty && controller.randomTip == null) {
          return const Center(child: Text('No health tips available at the moment.'));
        }


        final randomTip = controller.randomTip;
        final List<dynamic> randomTips = controller.randomTips;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Top Image with heading/title
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0,14.0,16.0,8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      randomTip?["ThumbnailMedia"]?["CdnUrl"] ??
                          "https://d3byuuhm0bg21i.cloudfront.net/derivatives/c3d47d00-8a25-46ef-bba3-ec5609c49b08/thumb.webp" ,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        height: 200,
                        child: const Center(
                            child: Icon(Icons.broken_image, size: 40)),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 200,
                          color: Colors.grey[100],
                          child: const Center(
                              child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // ✅ Tip Title & Subtitle
              Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    randomTip?["Heading"] ?? "No Heading",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    randomTip?['Title'] ?? "No Title",
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Keep Fit Stay Healthy",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),

              // ✅ Tip Cards (Dynamic from API)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children:

                  List.generate(numRows, (rowIndex) {
                    final firstIndex = rowIndex * 2;
                    final secondIndex = firstIndex + 1;

                    final firstTip = count > firstIndex ? controller.randomTips[firstIndex] : null;
                    final secondTip = count > secondIndex ? controller.randomTips[secondIndex] : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: firstTip != null
                                ? _buildTipCard(
                              image: firstTip["ThumbnailMedia"]?["CdnUrl"] ?? "",
                              heading: firstTip["Heading"] ?? "",
                              title : firstTip["Title"] ?? "",
                              onButtonTap: () => Get.to(() => NutritionTipsPage(), arguments: firstTip),
                              isDarkMode: isDarkMode,
                            )
                                : const SizedBox(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: secondTip != null
                                ? _buildTipCard(
                              image: secondTip["ThumbnailMedia"]?["CdnUrl"] ?? "",
                              heading: secondTip["Heading"] ?? "",
                              title : secondTip["Title"] ?? "",
                              onButtonTap: () => Get.to(() => NutritionTipsPage(), arguments: secondTip),
                              isDarkMode: isDarkMode,
                            )
                                : const SizedBox(),
                          ),
                        ],
                      ),
                    );


                  }),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  /// ✅ Tip Card Builder
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
}
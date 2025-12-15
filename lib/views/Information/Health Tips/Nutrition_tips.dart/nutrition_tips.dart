import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:flutter/material.dart';
import 'package:snevva/consts/colors.dart';
import 'package:snevva/consts/images.dart';

class NutritionTipsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> tipData = Get.arguments;
    final List<String> steps = List<String>.from(tipData['Steps'] ?? []);
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      // appBar: CustomAppBar(
      //   appbarText: tipData['Heading']?? "Sleep Well",
      //   isWhiteRequired: true,
      // ),
      appBar: AppBar(
        backgroundColor: transparent,
        centerTitle: true,
        title: Text(
          tipData['Heading'] ?? "Sleep Well",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: white,
          ),
        ),

        // Conditionally show leading drawer icon
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: SvgPicture.asset(drawerIcon, color: white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),

        // Conditionally show close (cross) icon
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: SizedBox(
                height: 24,
                width: 24,
                child: Icon(
                  Icons.clear,
                  size: 21,
                  color: white, // Adapt to theme
                ),
              ),
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          // Purple curved background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(660),
                  bottomRight: Radius.circular(660),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // ✅ Important
                  children: [
                    const SizedBox(height: 20),

                    // Circular Image
                    Center(
                      child: ClipOval(
                        child: Image.network(
                          tipData["ThumbnailMedia"]?["CdnUrl"] ??
                              "https://d3byuuhm0bg21i.cloudfront.net/derivatives/c3d47d00-8a25-46ef-bba3-ec5609c49b08/thumb.webp",
                          height: 220,
                          width: 220,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 220,
                              width: 220,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 220,
                              width: 220,
                              color: Colors.grey[300],
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, size: 40),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Title
                    Text(
                      tipData['Title'] ?? "",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Short Description
                    AutoSizeText(
                      tipData['ShortDescription'] ?? "",
                      textAlign: TextAlign.justify,
                      style: const TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 40),

                    // Steps Heading
                    if (steps.isNotEmpty)
                      const Text(
                        "Steps",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Steps List (dynamically built)
                    ...steps.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final step = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AutoSizeText(
                          " $index: $step",
                          textAlign: TextAlign.left,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

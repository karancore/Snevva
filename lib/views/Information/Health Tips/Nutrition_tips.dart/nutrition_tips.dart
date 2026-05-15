import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/colors.dart';
import 'package:snevva/consts/images.dart';
import 'package:snevva/models/common_tips_response.dart';
import 'package:snevva/widgets/app_loader.dart';

class NutritionTipsPage extends StatefulWidget {
  const NutritionTipsPage({super.key, this.commonTip});

  final CommonTip? commonTip;

  @override
  State<NutritionTipsPage> createState() => _NutritionTipsPageState();
}

class _NutritionTipsPageState extends State<NutritionTipsPage> {
  List<String?> commonSteps = [];

  String commonImageUrl = '';

  @override
  void initState() {
    super.initState();

    final tipData = widget.commonTip;
    commonSteps = List<String>.from(widget?.commonTip?.steps ?? []);
    commonImageUrl = 'https://${widget.commonTip?.thumbnailMedia?.cdnUrl}';
    commonImageUrl ??= placeHolderImage;
  }

  @override
  Widget build(BuildContext context) {
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
          widget.commonTip?.heading ?? "Sleep Well",
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
                        child: CachedNetworkImage(
                          imageUrl: commonImageUrl,
                          height: 220,
                          width: 220,
                          fit: BoxFit.cover,
                          errorWidget:
                              (context, error, stackTrace) => Container(
                                height: 120,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                              ),
                          placeholder: (context, url) {
                            return Container(
                              height: 120,
                              color: Colors.grey[200],
                              child: const AppLoader(size: 40),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Title
                    Text(
                      widget.commonTip?.title ?? "",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Short Description
                    AutoSizeText(
                      widget.commonTip?.shortDescription ?? "",
                      textAlign: TextAlign.justify,
                      style: const TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 40),

                    // Steps Heading
                    if (commonSteps.isNotEmpty)
                      const Text(
                        "Tips",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Steps List (dynamically built)
                    ...commonSteps.asMap().entries.map((entry) {
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

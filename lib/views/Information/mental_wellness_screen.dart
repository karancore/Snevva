import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:snevva/Controllers/MentalWellness/mental_wellness_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/MentalWellness/mental_wellness_footer_widget.dart';
import 'package:snevva/env/env.dart';
import '../../Widgets/MentalWellness/mental_wellness_header_widget.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../common/global_variables.dart';
import '../../common/loader.dart';
import '../../consts/consts.dart';

class MentalWellnessScreen extends StatefulWidget {
  @override
  State<MentalWellnessScreen> createState() => _MentalWellnessScreenState();
}

class _MentalWellnessScreenState extends State<MentalWellnessScreen> {
  final controller = Get.find<MentalWellnessController>();

  @override
  void initState() {
    super.initState();
    if (!controller.hasCachedMusic) {
      debugPrint("🟢 MentalWellnessScreen initState called - fetching music");
      controller.fetchMusic(context).then((_) {
        debugPrint("✅ Music fetch completed in initState");
      });
    }
  }

  String _pickFallback(List<String> images, int index) {
    if (images.isEmpty) return '';
    return images[index % images.length];
  }

  String _resolveArtwork({
    required String? thumbnail,
    required List<String> fallbackImages,
    required int index,
  }) {
    final String cleaned = (thumbnail ?? '').trim();
    if (cleaned.isNotEmpty) return cleaned;
    return _pickFallback(fallbackImages, index);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Mental Wellness"),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: Loader());
        }

        if (controller.hasError.value) {
          return const Text("Error loading music");
        }

        final generalMusic = controller.generalMusic;
        final meditationMusic = controller.meditationMusic;
        final natureMusic = controller.natureMusic;

        if (generalMusic.isEmpty) {
          return Center(
            child: Text(
              "No suggestions available right now. \n Please try again later",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            ),
          );
        }

        final generalItemCount =
            generalMusic.length +
            (controller.isGeneralLoadingMore.value ? 1 : 0);
        final meditationItemCount =
            meditationMusic.length +
            (controller.isMeditationLoadingMore.value ? 1 : 0);
        final natureItemCount =
            natureMusic.length + (controller.isNatureLoadingMore.value ? 1 : 0);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =================== General Music ===================
              SizedBox(
                height: 180 * heightFactor,
                child: ListView.separated(
                  controller: controller.generalScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: generalItemCount,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    if (index >= generalMusic.length) {
                      return const Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    final item = generalMusic[index];
                    return MentalWellnessHeaderWidget(
                      height: 180 * heightFactor,
                      musicItem: item,
                      width: 280 * widthFactor,
                      playText: '',
                      wellnessContainerImage: _resolveArtwork(
                        thumbnail: item.thumbnailMedia,
                        fallbackImages: generalImageUrls,
                        index: index,
                      ),
                      heading: item.title,
                      subHeading:
                          item.artistName == "Unknown" ? "" : item.artistName,
                      boxFit: BoxFit.cover,
                    );
                  },
                ),
              ),

              // =================== Meditation Section ===================
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      ' Meditation for You',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 189 * heightFactor,
                      child: ListView.separated(
                        controller: controller.meditationScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: meditationItemCount,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          if (index >= meditationMusic.length) {
                            return const Center(
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }

                          final item = meditationMusic[index];
                          return MentalWellnessHeaderWidget(
                            height: 189 * heightFactor,
                            musicItem: item,
                            width: 353 * widthFactor,
                            playText: "Play",
                            wellnessContainerImage: _resolveArtwork(
                              thumbnail: item.thumbnailMedia,
                              fallbackImages: meditationImageUrls,
                              index: index,
                            ),
                            heading: item.title,
                            subHeading:
                                item.artistName == "Unknown"
                                    ? ""
                                    : item.artistName,
                            boxFit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Nature Sounds',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // =================== Nature Sounds ===================
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: SizedBox(
                  height: 130,
                  child: ListView.separated(
                    controller: controller.natureScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: natureItemCount,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      if (index >= natureMusic.length) {
                        return const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final item = natureMusic[index];
                      return MentalWellnessFooterWidget(
                        musicItem: item,
                        wellnessContainerImage: _resolveArtwork(
                          thumbnail: item.thumbnailMedia,
                          fallbackImages: natureImageUrls,
                          index: index,
                        ),
                        heading: item.title,
                        subHeading:
                            item.artistName == "Unknown" ? "" : item.artistName,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

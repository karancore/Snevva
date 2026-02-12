import 'dart:math';

import 'package:snevva/Controllers/MentalWellness/mental_wellness_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/MentalWellness/mental_wellness_footer_widget.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/music/music_response.dart';
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
  final controller = Get.put(MentalWellnessController());

  @override
  void initState() {
    super.initState();
    debugPrint("🟢 MentalWellnessScreen initState called - fetching music");
    controller.fetchMusic(context).then((_) {
      debugPrint("✅ Music fetch completed in initState");
    });
  }

  Stream<String> emitBackgroundImages({int delaySeconds = 3}) async* {
    int index = 0;
    while (true) {
      yield backgroundImageUrls[index];
      index = (index + 1) % backgroundImageUrls.length;
      await Future.delayed(Duration(seconds: delaySeconds));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;

    final width = mediaQuery.size.width;
    print("height is $height ");
    print("width is $width ");

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    debugPrint("🌓 Theme mode: ${isDarkMode ? "Dark" : "Light"}");

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Mental Wellness"),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================== General Music ===================
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),

              child: Obx(() {
                debugPrint("🔄 Obx triggered for generalMusic list");

                if (controller.isLoading.value) {
                  debugPrint("⏳ Loading music...");
                  return Center(child: const Loader());
                }
                if (controller.hasError.value) {
                  debugPrint("❌ Error occurred while fetching music");
                  return const Text("Error loading music");
                }

                final generalMusic = controller.generalMusic;
                debugPrint("🎵 generalMusic length: ${generalMusic.length}");

                if (generalMusic.isEmpty) {
                  debugPrint("⚠️ generalMusic list is empty");
                  return const Text("No suggestions");
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(generalMusic.length, (index) {
                      final item = generalMusic[index];

                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == generalMusic.length - 1 ? 0 : 16,
                        ),
                        child: InkWell(
                          child: MentalWellnessHeaderWidget(
                            height: 180 * heightFactor,
                            musicItem: item,
                            width: 280 * widthFactor,
                            playText: '',
                            wellnessContainerImage:
                                generalMusic[index].thumbnailMedia ??
                                generalImageUrls[Random().nextInt(index + 1)],
                            heading: generalMusic[index].title,
                            subHeading:
                                generalMusic[index].artistName == "Unknown"
                                    ? ""
                                    : generalMusic[index].artistName,
                            boxFit: BoxFit.cover,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),

            // =================== Meditation Section ===================
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    ' Meditation for You',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 18),
                  Obx(() {
                    final meditationMusic = controller.meditationMusic;
                    debugPrint(
                      "🎵 meditationMusic: ${meditationMusic.runtimeType}",
                    );
                    if (controller.isLoading.value) {
                      debugPrint("⏳ Loading music...");
                      return Center(child: const Loader());
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(meditationMusic.length, (
                          index,
                        ) {
                          final item = meditationMusic[index];

                          return Padding(
                            padding: EdgeInsets.only(
                              right:
                                  index == meditationMusic.length - 1 ? 0 : 16,
                            ),
                            child: MentalWellnessHeaderWidget(
                              height: 189 * heightFactor,
                              musicItem: item,
                              width: 353 * widthFactor,
                              playText: "Play",
                              wellnessContainerImage:
                                  meditationMusic[index].thumbnailMedia ??
                                  meditationImageUrls[Random().nextInt(
                                    index + 3,
                                  )],
                              heading: meditationMusic[index].title,
                              subHeading:
                                  meditationMusic[index].artistName == "Unknown"
                                      ? ""
                                      : meditationMusic[index].artistName,
                              boxFit: BoxFit.cover,
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                  SizedBox(height: 18),
                  const Text(
                    'Nature Sounds',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // =================== Nature Sounds ===================
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Obx(() {
                final natureMusic = controller.natureMusic;
                debugPrint("🎵 natureMusic length: ${natureMusic.length}");

                if (controller.isLoading.value) {
                  debugPrint("⏳ Loading music...");
                  return Center(child: const Loader());
                }
                if (controller.hasError.value) {
                  debugPrint("❌ Error occurred while fetching music");
                  return const Text("Error loading music");
                }

                if (natureMusic.isEmpty) {
                  debugPrint("⚠️ natureMusic list is empty");
                  return const Text("No suggestions");
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 16,
                    children:
                        natureMusic.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return MentalWellnessFooterWidget(
                            musicItem: item,
                            wellnessContainerImage:
                                item.thumbnailMedia ??
                                natureImageUrls[Random().nextInt(index + 2)],
                            heading: item.title,
                            subHeading:
                                item.artistName == "Unknown"
                                    ? ""
                                    : item.artistName,
                          );
                        }).toList(),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../consts/consts.dart';
import '../../Widgets/MoodTracker/animated_circle_widget.dart';
import 'mood_questionnaire.dart';

class MoodTrackerScreen extends StatelessWidget {
  const MoodTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;

    final controller = Get.find<MoodController>();

    final pageController = PageController(
      initialPage: controller.selectedMoodIndex.value,
      viewportFraction: 0.7, // shows a bit of next/previous circles
    );

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Mood Tracker"),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: AutoSizeText(
                'How are you feeling today?',
                textAlign: TextAlign.center,
                minFontSize: 20,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 40),

            // Carousel for moods
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: controller.moods.length,
                onPageChanged: (index) {
                  controller.selectMood(index);
                },
                itemBuilder: (context, index) {
                  return Obx(() {
                    final isSelected =
                        controller.selectedMoodIndex.value == index;

                    Gradient gradient;
                    Color shadow1;
                    Color shadow2;
                    String text;

                    if (index == 0) {
                      gradient = mood1;
                      shadow1 = contColor1;
                      shadow2 = contColor2;
                      text = 'Pleasant';
                    } else if (index == 1) {
                      gradient = mood2;
                      shadow1 = contColor21;
                      shadow2 = contColor22;
                      text = 'Unpleasant';
                    } else {
                      gradient = mood3;
                      shadow1 = contColor31;
                      shadow2 = contColor32;
                      text = 'Good';
                    }

                    return AnimatedScale(
                      scale: isSelected ? 1.0 : 0.85,
                      duration: const Duration(milliseconds: 300),
                      child: GestureDetector(
                        onTap: () => controller.selectMood(index),
                        child: Center(
                          child: AnimatedShadowCircle(
                            gradientColor:
                                isSelected
                                    ? gradient
                                    : LinearGradient(
                                      colors: [
                                        (gradient.colors.first).withOpacity(
                                          0.4,
                                        ),
                                        (gradient.colors.last).withOpacity(0.4),
                                      ],
                                    ),
                            shadowColor1: shadow1,
                            shadowColor2: shadow2,
                            size: isSelected ? height * 0.22 : height * 0.18,
                            hideText: false,
                            text: text,
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
            //
            // // Selected mood info
            // Obx(
            //   () => Padding(
            //     padding: const EdgeInsets.symmetric(vertical: 20),
            //     child: Text(
            //       controller.selectedMoodIndex.value == -1
            //           ? "No mood selected. Swipe or tap to choose."
            //           : "Selected mood: ${controller.moods[controller.selectedMoodIndex.value]}",
            //       style: const TextStyle(
            //         fontSize: 18,
            //         fontWeight: FontWeight.w500,
            //       ),
            //     ),
            //   ),
            // ),

            // Save button
            ElevatedButton(
              onPressed: () {
                controller.updateMood(context);

                Get.to(() => MoodQuestionnaire());
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 70,
                ),
                backgroundColor: Colors.purpleAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Mood',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

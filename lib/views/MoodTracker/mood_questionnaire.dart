import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/consts/images.dart';

import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../common/calendar_screen.dart';
import '../../consts/colors.dart';

class MoodQuestionnaire extends StatefulWidget {
  const MoodQuestionnaire({super.key});

  @override
  State<MoodQuestionnaire> createState() => _MoodQuestionnaireState();
}

class _MoodQuestionnaireState extends State<MoodQuestionnaire> {
  String getCurrentDay() {
    final now = DateTime.now();
    return DateFormat('dd MMM').format(now);
  }

  final moodController = Get.find<MoodController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      moodController.loadTodayMoods();
    });
  }
  // Example mood entries

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    double scale = screenWidth / 360;

    double itemHeight = 42 * scale;

    final media = MediaQuery.of(context);
    final bool isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;
    final height = media.size.height;
    final width = media.size.width;
    return Scaffold(
      appBar: CustomAppBar(appbarText: "Mood Journal"),
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Today, ${getCurrentDay()}",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    Spacer(),
                    Container(
                      height: 38,
                      width: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: white,
                        borderRadius: BorderRadius.circular(6),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          // Navigate to calendar screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CalendarScreen(),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.calendar_month_outlined,
                          size: 26,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22.0),
                  child: Container(
                    width: 360 * scale,
                    height: 372 * scale,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xff912DFF),
                          Color(0xffae65ff).withOpacity(0.64),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Obx(() {
                      return Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              "DAILY MOOD",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: white,
                              ),
                            ),
                            moodController.moodEntries.isNotEmpty
                                ? Image.asset(
                              face,
                              width: 164 * scale,
                              height: 164 * scale,
                              fit: BoxFit.contain,
                            )
                                : Image.asset(
                              noEntries,
                              width: 282 * scale,
                              height: 282 * scale,
                              fit: BoxFit.contain,
                            ),
                            moodController.moodEntries.isNotEmpty
                                ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Momentary Emotions",
                                  style: const TextStyle(
                                    color: white,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                SizedBox(height: 6,
                                    child: Divider(
                                        color: white, thickness: 2.5)),
                              ],
                            )
                                : SizedBox.shrink(),
                            moodController.moodEntries.isNotEmpty
                                ? SizedBox(
                              height: itemHeight * 3,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: moodController.moodEntries.length,
                                itemBuilder: (context, index) {
                                  final mood = moodController
                                      .moodEntries[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    leading: Image.asset(
                                      moodController.getImage(
                                          moodController.selectedUserMood),
                                      width: 28 * scale,
                                      height: 28 * scale,
                                      fit: BoxFit.contain,
                                    ),
                                    title: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          mood['Mood'] ?? '',
                                          style: TextStyle(
                                            color: white.withOpacity(0.8),
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          mood['Time'] ?? '',
                                          style: TextStyle(
                                            color: white.withOpacity(0.8),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            )
                                : SizedBox.shrink(),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                Text(
                  "About Mood Tracker",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,

                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Take a moment for yourself.\n Log your mood and reflect.\n Your feelings matter—every single day.",
                  style: const TextStyle(
                    fontSize: 14,

                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 15 * scale),
                Align(
                  alignment: Alignment.center,
                  child: Image.asset(
                    girlMood,
                    width: 177 * scale,
                    height: 173 * scale,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

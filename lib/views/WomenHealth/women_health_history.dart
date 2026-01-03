import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:snevva/Widgets/WomenHealth/calender.dart';
import 'package:snevva/views/WomenHealth/symptoms_bottom_sheet.dart';

import '../../Controllers/WomenHealth/women_health_controller.dart';
import '../../Widgets/CommonWidgets/custom_appbar.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../consts/consts.dart';

class WomenHealthHistory extends StatelessWidget {
  WomenHealthHistory({super.key});

  final WomenHealthController womenController =
      Get.find<WomenHealthController>();

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String formattedDate = DateFormat('d MMM').format(DateTime.now());

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: 'History'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(child: CalendarWidget()),
            Transform.translate(
              offset: Offset(0, -10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    SvgPicture.asset(calenderIcon),
                    SizedBox(width: 5),
                    Text(formattedDate),
                    const Spacer(),
                    Material(
                      color:
                          isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap:
                            () => showSymptomsBottomSheet(
                              context,
                              isDarkMode,
                              height,
                            ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: yellow.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Image.asset(symptomsIcon, height: 20),
                              SizedBox(width: 5),
                              Text('Symptoms'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    // Container(
                    //   padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    //   decoration: BoxDecoration(
                    //     color: periodHighlighted.withValues(alpha: 0.2),
                    //     borderRadius: BorderRadius.circular(20),
                    //   ),
                    //   child: Row(
                    //     children: [
                    //       Image.asset(periodsIcon, height: 20),
                    //       SizedBox(width: 5),
                    //       Text('Periods'),
                    //     ],
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Material(
                elevation: 2,
                color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      getSymptoms(
                        "Symptoms",
                        "Back Pain , Bloating, Nausea, Constipation, Joint pain, Muscle pain ",
                      ),
                      getDivider(),
                      getSymptoms("Period", "No Period Data"),
                      getDivider(),
                      getSymptoms("Notes", "No Period Data"),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: getSymptoms(
                "Recomendations",
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Column getSymptoms(String heading, String subheading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        SizedBox(height: 5),
        AutoSizeText(
          subheading,
          style: TextStyle(fontSize: 14, color: mediumGrey),
        ),
      ],
    );
  }

  Column getDivider() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Divider(thickness: border04px, color: mediumGrey),
        const SizedBox(height: 10),
      ],
    );
  }
}

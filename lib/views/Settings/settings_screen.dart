import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/utils/theme_controller.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../Widgets/Setting/setting_item_widget.dart';
import '../../consts/consts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final themeController = Get.put(ThemeController());
  bool _notificationsToggle = false;
  bool _themeToggle = false;
  double _volume = 0.5;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(appbarText: "Settings", showCloseButton: false ),
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              "Theme",
              style: TextStyle(
                color: grey,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Dark Mode",
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
                CupertinoSwitch(
                  value: themeController.isDarkMode.value,
                  activeColor: AppColors.activeSwitch,
                  onChanged: (value) {
                    themeController.toggleTheme(value);
                    setState(() {});
                  },
                )
              ],
            ),
            SizedBox(height: height * 0.0188),
            Divider(thickness: 1.5, color: mediumGrey),
            SizedBox(height: height * 0.0188),
            Text(
              "Volume & Access",
              style: TextStyle(
                color: grey,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
            SizedBox(height: height * 0.0117),
            Text(
              "Media",
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            SizedBox(height: height * 0.004),
            Slider(
              value: _volume,

              thumbColor: AppColors.primaryColor,
              activeColor: AppColors.primaryColor,
              inactiveColor: AppColors.primaryColor.withOpacity(0.3),

              padding: EdgeInsets.zero,
              onChanged: (double value) {
                setState(() {
                  _volume = value;
                });
              },
            ),

            SizedBox(height: height * 0.0188),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Push Notifications",
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
                CupertinoSwitch(
                  value: _notificationsToggle,
                  activeColor: AppColors.activeSwitch,
                  onChanged: (bool value) {
                    setState(() {
                      _notificationsToggle = value;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: height * 0.0188),
            Divider(thickness: 1.0, color: mediumGrey),
            // Divider(thickness: 1.0, color: mediumGrey),
            SizedBox(height: height * 0.0188),
            Text(
              "About",
              style: TextStyle(
                color: grey,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
            SizedBox(height: height * 0.0117),
            Text(
              "About app",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            SizedBox(height: height * 0.0164),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                buildTile('Version', 'Tap to check for updates'),
                Spacer(),
                AutoSizeText(
                  'v1.0.0',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            buildTile('Rate App', 'Tap to rate app'),
            buildTile('Contact Us', 'Feedbacks Appreciated!'),
          ],
        ),
      ),
    );
  }

  Column buildTile(String heading, String subheading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(
          heading,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),

        AutoSizeText(
          subheading,
          maxFontSize: 14,
          minFontSize: 8,
          style: TextStyle(fontWeight: FontWeight.w400, color: mediumGrey),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

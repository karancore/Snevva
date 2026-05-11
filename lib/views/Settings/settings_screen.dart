import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:snevva/utils/push_notifications_controller.dart';
import 'package:snevva/utils/theme_controller.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../consts/consts.dart';
import 'about_screen.dart';
import 'debug_period_sync_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ThemeController themeController = Get.find<ThemeController>();
  final PushNotificationsController pushNotificationsController =
      Get.find<PushNotificationsController>();

  bool _notificationsToggle = false;
  double _volume = 0.5;

  String appVersion = '1.0.0';

  Future<void> launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'snevvaofficial@gmail.com',
      queryParameters: {'subject': 'Subject', 'body': 'Body'},
    );

    if (!await canLaunchUrl(emailUri)) {
      throw 'No email app found on this device';
    }

    await launchUrl(emailUri, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();

    fetchAppVersion();
  }

  Future<void> fetchAppVersion() async {
    String version = await getAppVersion();
    appVersion = version;
  }

  Future<String> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();

    String version = packageInfo.version; // e.g. 1.0.0
    String buildNumber = packageInfo.buildNumber; // e.g. 1

    return version;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,

        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        scrolledUnderElevation: 0.0,

        title: Text(
          "Settings",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),

        leading: Builder(
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.only(left: 12),
              child: IconButton(
                iconSize: 200.0,
                icon: SvgPicture.asset(drawerIcon),
                onPressed: () {
                  final scaffold = Scaffold.maybeOf(context);

                  if (scaffold != null) {
                    scaffold.openDrawer();
                  }
                },
              ),
            );
          },
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              child: SizedBox(
                height: 24,
                width: 24,
                child: Icon(
                  Icons.clear,
                  size: 21,
                  color: isDarkMode ? white : black,
                ),
              ),
            ),
          ),
        ],
      ),
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
                color: Theme.of(context).hintColor,
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
                Obx(
                  () => CupertinoSwitch(
                    value: themeController.isDarkMode.value,
                    activeColor: AppColors.activeSwitch,
                    onChanged: (_) => themeController.toggleTheme(),
                  ),
                ),
              ],
            ),
            SizedBox(height: height * 0.0188),
            const Divider(thickness: border04px, color: mediumGrey),
            SizedBox(height: height * 0.0188),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Do Not Disturb",
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
                Obx(
                      () =>
                      CupertinoSwitch(
                        value: pushNotificationsController
                            .isNotificationEnabled.value,

                    activeColor: AppColors.activeSwitch,

                        onChanged: pushNotificationsController
                            .isUpdatingNotification.value
                            ? null
                            : (value) {
                          pushNotificationsController
                              .disableNotifications(value);
                    },
                  ),
                )
              ],
            ),
            SizedBox(height: height * 0.0188),
            // Text(
            //   "Volume & Access",
            //   style: TextStyle(
            //     color: Theme.of(context).hintColor,
            //     fontWeight: FontWeight.w400,
            //     fontSize: 14,
            //   ),
            // ),
            // SizedBox(height: height * 0.0117),
            // Text(
            //   "Media",
            //   style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            // ),
            // SizedBox(height: height * 0.004),
            // Slider(
            //   value: _volume,
            //
            //   thumbColor: AppColors.primaryColor,
            //   activeColor: AppColors.primaryColor,
            //   inactiveColor: AppColors.primaryColor.withOpacity(0.3),
            //
            //   padding: EdgeInsets.zero,
            //   onChanged: (double value) {
            //     setState(() {
            //       _volume = value;
            //     });
            //   },
            // ),
            //
            // SizedBox(height: height * 0.0188),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     Text(
            //       "Push Notifications",
            //       style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            //     ),
            //     CupertinoSwitch(
            //       value: _notificationsToggle,
            //       activeColor: AppColors.activeSwitch,
            //       onChanged: (bool value) {
            //         setState(() {
            //           _notificationsToggle = value;
            //         });
            //       },
            //     ),
            //   ],
            // ),
            // SizedBox(height: height * 0.0188),
            // const Divider(thickness: border04px, color: mediumGrey),
            // // Divider(thickness: 1.0, color: mediumGrey),
            // SizedBox(height: height * 0.0188),
            // Text(
            //   "About",
            //   style: TextStyle(
            //     color: Theme.of(context).hintColor,
            //     fontWeight: FontWeight.w400,
            //     fontSize: 14,
            //   ),
            // ),
            // SizedBox(height: height * 0.0117),
            InkWell(
              onTap: () {
                Get.to(() => AboutScreen());
              },
              child: Text(
                "About app",
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
            ),
            SizedBox(height: height * 0.0164),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                buildTile('Version', 'Tap to check for updates'),
                const Spacer(),
                AutoSizeText(
                  'v$appVersion',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),

            buildTile('Rate App', 'Tap to rate app'),

            InkWell(
              onTap: launchEmail,
              child: buildTile('Contact Us', 'Feedbacks Appreciated!'),
            ),

            const SizedBox(height: 10),
            const Divider(thickness: border04px, color: mediumGrey),
            const SizedBox(height: 20),

            Text(
              "Developer Debug",
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            InkWell(
              onTap: () {
                Get.to(() => const DebugPeriodSyncScreen());
              },
              child: buildTile(
                'Period Sync Logs',
                'View background sync logs & API responses',
              ),
            ),
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
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: Theme.of(context).hintColor,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

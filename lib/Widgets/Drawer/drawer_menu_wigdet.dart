import 'package:flutter_svg/svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'package:snevva/Controllers/localStorageManager.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/views/EmergencyContact/emergency_contact.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/edit_profile_screen.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_screen.dart';
import 'package:snevva/views/ReportScan/scan_report_screen.dart';
import 'package:snevva/views/Settings/settings_screen.dart';
import 'package:snevva/views/Sign%20Up/sign_in_screen.dart';
import '../../consts/consts.dart';
import 'drawer_menu_item.dart';

class DrawerMenuWidget extends StatelessWidget {
  const DrawerMenuWidget({
    super.key,
    required this.height,
    required this.width,
  });

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final localStorageManager = Get.put(LocalStorageManager());
    final initialProfileController = Get.put(ProfileSetupController());

    return Column(
      children: [
        Container(
          padding: EdgeInsets.only(left: 20),
          height: height / 4,
          width: double.infinity,
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
          child: Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Obx(() {
                  final pickedFile = initialProfileController.pickedImage.value;

                  return ClipOval(
                    child:
                        pickedFile != null
                            ? Image.file(
                              pickedFile,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            )
                            : Image.asset(
                              profileMainImg,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            ),
                  );
                }),
                const SizedBox(height: 8),
                Text(
                  localStorageManager.userMap['Name']?.toString() ?? 'User',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 40),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        DrawerMenuItem(
                          menuIcon: homeIcon,
                          itemName: 'Home',
                          onWidgetTap:
                              () => {Get.back(), Get.to(() => HomeWrapper())},
                        ),

                        DrawerMenuItem(
                          menuIcon: profileIcon,
                          itemName: 'Profile',
                          onWidgetTap:
                              () => {
                                Get.back(),
                                Get.to(() => EditProfileScreen()),
                              },
                        ),

                        // DrawerMenuItem(
                        //   menuIcon: addEmergencyContactIcon,
                        //   itemName: 'Emergency Contact',
                        //   onWidgetTap:
                        //       () => {Get.back(), Get.to(()=>EmergencyContact())},
                        // ),
                        DrawerMenuItem(
                          menuIcon: scannerIcon,
                          itemName: 'Scan Report ',
                          isDisabled: true,
                          onWidgetTap: () {}, // ignored because disabled
                        ),

                        // DrawerMenuItem(
                        //   menuIcon: appointmentIcon,
                        //   itemName: 'Appointment',
                        //   onWidgetTap:
                        //       () => {Get.back(), Get.to(()=>DocHaveAppointment())},
                        // ),
                        DrawerMenuItem(
                          menuIcon: gearIcon,
                          itemName: 'Setting',
                          onWidgetTap:
                              () => {
                                Get.back(),
                                Get.to(() => SettingsScreen()),
                              },
                        ),

                        DrawerMenuItem(
                          menuIcon:
                              invitefriend, // or another icon if not added yet
                          itemName: 'Invite a Friend',
                          onWidgetTap: () async {
                            Get.back();
                            const shareMessage =
                                '🎉 Hey! Check out this awesome app — Snevva! Download it here: https://play.google.com/store/apps/details?id=com.yourapp.id';
                            await Share.share(
                              shareMessage,
                              subject: 'Join me on Snevva!',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                SafeArea(
                  child: Container(
                    margin: EdgeInsets.only(top: 20, bottom: 10),
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.18),
                          blurRadius: 12,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                    child: OutlinedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(
                          'is_first_time_sleep',
                          true,
                        );
                        await prefs.setBool(
                          'isStepGoalSet',
                          true,
                        );

                        await prefs.clear();

                        final localStorageManager =
                            Get.find<LocalStorageManager>();
                        localStorageManager.userMap.clear();

                        // Clear all navigation history and go to SignInScreen
                        Get.offAll(() => SignInScreen());
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Color(0xFFF0E5FF),
                        side: BorderSide(color: Colors.transparent),
                        fixedSize: Size(width, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(logoutIcon, width: 24, height: 24),
                          SizedBox(width: 10),
                          Text(
                            "Log Out",
                            style: TextStyle(
                              fontSize: 18,
                              foreground:
                                  Paint()
                                    ..shader = AppColors.primaryGradient
                                        .createShader(
                                          Rect.fromLTWH(0, 0, 200, 70),
                                        ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

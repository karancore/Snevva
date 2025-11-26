import 'package:flutter_svg/flutter_svg.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/edit_profile_screen.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';

import '../../Controllers/localStorageManager.dart';
import '../../Widgets/CommonWidgets/custom_outlined_button.dart';
import '../../consts/consts.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
    final localStorageManager = Get.put(LocalStorageManager());

    return SafeArea(
      child: Scaffold(
        drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
        appBar: CustomAppBar(appbarText: "Profile"),
        bottomNavigationBar: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: CustomOutlinedButton(
          buttonName: "Edit Profile",
          width: width,
          isDarkMode: isDarkMode,
          onTap: () {
            Get.to(() => EditProfileScreen());
          },
        ),),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      SizedBox(
                        height: height * 0.15,
                        width: width * 0.3,
                        child:  CircleAvatar(
                          radius: 50,
                          backgroundImage:
                          initialProfileController.pickedImage.value != null
                              ? FileImage(
                            initialProfileController.pickedImage.value!,
                          )
                              : AssetImage(profileMainImg) as ImageProvider,
                        ),
                      ),
                      // Positioned(
                      //   bottom: -6,
                      //   right: -8,
                      //   child: IconButton(
                      //     onPressed: () {},
                      //     icon: Image.asset(profileIcon2),
                      //   ),
                      // ),
                    ],
                  ),
                ),
                SizedBox(height: defaultSize + 10),
                Row(
                  children: [
                    SvgPicture.asset(userIcon),
                    SizedBox(width: 8),
                    Text('UserName'),
                    Spacer(),
                    Text(localStorageManager.userMap['Name']?.toString() ?? '__',),
                  ],
                ),
                SizedBox(height: 10),
                Divider(color: Colors.grey),
                SizedBox(height: 10),
                Row(
                  children: [
                    SvgPicture.asset(aboutIcon),
                    SizedBox(width: 8),
                    Text('Email'),
                    Spacer(),
                    Text(localStorageManager.userMap['Email']?.toString() ?? '__',),
                  ],
                ),
                SizedBox(height: 10),
                Divider(color: Colors.grey),
                SizedBox(height: 10),
                Row(
                  children: [
                    SvgPicture.asset(phoneIcon, color: AppColors.primaryColor,),
                    SizedBox(width: 8),
                    Text('Phone'),
                    Spacer(),
                    Text(localStorageManager.userMap['PhoneNumber']?.toString() ?? '__',),
                  ],
                ),
                SizedBox(height: 10),
                Divider(color: Colors.grey),
                SizedBox(height: 10),
                Row(
                  children: [
                    SvgPicture.asset(calenderIcon),
                    SizedBox(width: 8),
                    Text('Date of birth'),
                    Spacer(),
                    Text(
                      "${localStorageManager.userMap['DayOfBirth'] ?? '--'}/"
                          "${localStorageManager.userMap['MonthOfBirth'] ?? '--'}/"
                          "${localStorageManager.userMap['YearOfBirth'] ?? '----'}",
                      style: const TextStyle(fontSize: 16),
                    ),
      
                  ],
                ),
                // SizedBox(height: 10),
                // Divider(color: Colors.grey),
                // SizedBox(height: 10),
                // Row(
                //   children: [
                //     SvgPicture.asset(addressIcon),
                //     SizedBox(width: 8),
                //     Text('Address'),
                //     Spacer(),
                //     Text(localStorageManager.userMap['AddressByUser']?.toString() ?? 'India',),
                //   ],
                // ),
                // SizedBox(height: 10),
                // Divider(color: Colors.grey),
                // SizedBox(height: 10),
                // Row(
                //   children: [
                //     SvgPicture.asset(userIcon),
                //     SizedBox(width: 8),
                //     Text('UserName'),
                //     Spacer(),
                //     Text('UserName'),
                  // ],
                // ),
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}

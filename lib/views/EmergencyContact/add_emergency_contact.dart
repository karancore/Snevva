import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';

import '../../consts/consts.dart';

class AddEmergencyContact extends StatelessWidget {
  const AddEmergencyContact({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Add Member", isWhiteRequired: true),
      body: Column(
        children: [
          SizedBox(
            height: height * 0.40,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: height * 0.25,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                ),

                Positioned(
                  right: 0,
                  left: 0,
                  top: height * 0.17,
                  child: Container(
                    height: 140,
                    width: 140,
                    decoration: BoxDecoration(
                      image: DecorationImage(image: AssetImage(emergencyPic1)),
                    ),
                  ),
                ),
                Positioned(
                  bottom: height * 0.068,
                  right: width * 0.32,
                  child: IconButton(
                    onPressed: () {},
                    icon: Image.asset(profileIcon2),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Transform.translate(
                  offset: Offset(0, -60),
                  child: AutoSizeText(
                    'Robert Hook',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 24,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(4),
                  color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                  clipBehavior: Clip.antiAlias,
                  child: TextFormField(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      hintText: 'Enter Snevva Id',
                      hintStyle: const TextStyle(color: mediumGrey),
                    ),
                  ),
                ),

                SizedBox(height: defaultSize - 10),
                Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(4),
                  color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                  clipBehavior: Clip.antiAlias,
                  child: TextFormField(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      hintText: 'Enter Name',
                      hintStyle: const TextStyle(color: mediumGrey),
                    ),
                  ),
                ),

                SizedBox(height: defaultSize - 10),
                Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(4),
                  color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                  clipBehavior: Clip.antiAlias,
                  child: TextFormField(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      hintText: 'Relation',
                      hintStyle: const TextStyle(color: mediumGrey),
                    ),
                  ),
                ),

                SizedBox(height: defaultSize - 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Material(
                      elevation: 1,
                      borderRadius: BorderRadius.circular(4),
                      color:
                          isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        width: width / 5,
                        decoration: BoxDecoration(),
                        child: TextFormField(
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 2,
                            ),
                            hintText: '15',
                            hintStyle: const TextStyle(color: mediumGrey),
                          ),
                        ),
                      ),
                    ),
                    Material(
                      elevation: 1,
                      borderRadius: BorderRadius.circular(4),
                      color:
                          isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        width: width / 3,
                        decoration: BoxDecoration(),
                        child: TextFormField(
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 2,
                            ),
                            hintText: 'March',
                            hintStyle: const TextStyle(color: mediumGrey),
                          ),
                        ),
                      ),
                    ),
                    Material(
                      elevation: 1,
                      borderRadius: BorderRadius.circular(4),
                      color:
                          isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        width: width / 3.5,
                        decoration: BoxDecoration(),
                        child: TextFormField(
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 2,
                            ),
                            hintText: '1986',
                            hintStyle: const TextStyle(color: mediumGrey),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: defaultSize - 10),

                Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(4),
                  color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                  clipBehavior: Clip.antiAlias,
                  child: TextFormField(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      hintText:
                          AppLocalizations.of(context)!.pleaseEnterYourName,
                      hintStyle: const TextStyle(color: mediumGrey),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: CustomOutlinedButton(
              width: width,
              backgroundColor: AppColors.primaryColor,
              isDarkMode: isDarkMode,
              buttonName: "Save",
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

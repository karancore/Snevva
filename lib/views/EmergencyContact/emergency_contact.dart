import 'package:flutter_svg/flutter_svg.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/views/EmergencyContact/add_emergency_contact.dart';
import '../../Widgets/Emergency/emergency_contact_widget.dart';
import '../../consts/consts.dart';

class EmergencyContact extends StatelessWidget {
  const EmergencyContact({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;

    // final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Emergency"),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: vividRed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Press 3 times to',
                        style: TextStyle(
                          fontSize: 20,
                          color: white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Emergency Contact',
                        style: TextStyle(
                          fontSize: 20,
                          color: white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: defaultSize - 15),
                      Text(
                        'Get ambulance in just 10 min',
                        style: TextStyle(
                          fontSize: 12,
                          color: white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: defaultSize - 20),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 0,
                          ),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset(locationPin),

                            SizedBox(width: 5),

                            Text(
                              'Track Now',
                              style: TextStyle(
                                color: vividRed,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      InkWell(
                        onTap: () {},
                        child: SvgPicture.asset(
                          emergencyButton,
                          height: height / 7,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: defaultSize),
            Row(
              children: [
                InkWell(
                  onTap: () {
                    Get.to(AddEmergencyContact());
                  },
                  borderRadius: BorderRadius.circular(40),
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: SvgPicture.asset(addCircularContainer, height: 64),
                  ),
                ),

                SizedBox(width: 20),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Member',
                      style: TextStyle(
                        fontSize: 20,
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Add emergency contact',
                      style: TextStyle(
                        fontSize: 16,
                        color: mediumGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: defaultSize),

            EmergencyContactWidget(
              name: 'Robert Hook',
              img: emergencyPic1,
              phone: '+91 7793200123',
              relation: 'Father',
            ),
            Divider(),
            EmergencyContactWidget(
              name: 'Skye Hook',
              img: emergencyPic2,
              phone: '+91 9864565523',
              relation: 'Mother',
            ),
            Divider(),
            EmergencyContactWidget(
              name: 'Crista',
              img: emergencyPic3,
              phone: '+91 5432653423',
              relation: 'Sister',
            ),
            Divider(),
            EmergencyContactWidget(
              name: 'John',
              img: emergencyPic4,
              phone: '+91 8765355343',
              relation: 'Brother',
            ),
          ],
        ),
      ),
    );
  }
}

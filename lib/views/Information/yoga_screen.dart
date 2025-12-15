import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';

import '../../Widgets/YogaScreen/yoga_screen_footer.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../consts/consts.dart';

class YogaScreen extends StatelessWidget {
  const YogaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      extendBodyBehindAppBar: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CustomOutlinedButton(
          width: width,
          backgroundColor: AppColors.primaryColor,
          isDarkMode: isDarkMode,
          buttonName: "Start",
          onTap: () {},
        ),
      ),
      appBar: CustomAppBar(appbarText: "Yoga Screen"),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 230,
              child: Image.asset(yogaScreenImg1, fit: BoxFit.fill),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yoga With Elly',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ut enim ad minima veniam, quis nostrum exetionem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi quisquam est, qui dolorem ipsum quia dolor sit amet minima veniam.',
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image(image: AssetImage(yogaIcon)),
                          const SizedBox(width: 5),
                          const Text(
                            '4',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      Row(
                        children: [
                          Image(image: AssetImage(starIcon)),
                          const SizedBox(width: 5),
                          const Text(
                            '4.5',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      Row(
                        children: [
                          Image(image: AssetImage(timerIcon)),
                          const SizedBox(width: 5),
                          const Text(
                            '4 min',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  YogaScreenFooterWidget(
                    containerText:
                        'Est, qui dolorem ipsum quia dolor sit amet minima veniam.',
                    containerImg: yogaScreenImg2,
                  ),
                  YogaScreenFooterWidget(
                    containerText:
                        'Est, qui dolorem ipsum quia dolor sit amet minima veniam.',
                    containerImg: yogaScreenImg3,
                  ),
                  YogaScreenFooterWidget(
                    containerText:
                        'est, qui dolorem ipsum quia dolor sit amet minima veniam.',
                    containerImg: yogaScreenImg4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:snevva/Controllers/MentalWellness/mentalwellnesscontroller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/MentalWellness/mental_wellness_footer_widget.dart';
import '../../Widgets/MentalWellness/mental_wellness_header_widget.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../consts/consts.dart';

class MentalWellnessScreen extends StatefulWidget {
  @override
  State<MentalWellnessScreen> createState() => _MentalWellnessScreenState();
}

class _MentalWellnessScreenState extends State<MentalWellnessScreen> {
  final controller = Get.find<MentalWellnesscontroller>();

  @override
  void initState() {
    super.initState();
    controller.fetchMusic(context);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;

    //final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Mental Wellness"),
      body: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: Row(
                    children: [
                      MentalWellnessHeaderWidget(
                        height: height / 4,
                        width: width / 1.5,
                        heading: 'Make Yourself',
                        subHeading: 'Relax',
                        wellnessContainerImage: wellnessContainerImg1,
                        boxFit: BoxFit.cover,
                      ),
                      SizedBox(width: 20),
                      MentalWellnessHeaderWidget(
                        height: height / 4,
                        width: width / 1.5,
                        heading: 'Heal Via',
                        subHeading: 'Sitara',
                        wellnessContainerImage: wellnessContainerImg1,
                        boxFit: BoxFit.cover,
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meditation for You',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 18),
                    MentalWellnessHeaderWidget(
                      height: height / 4,
                      width: width / 0.3,
                      heading: 'Make It With',
                      subHeading: 'Meditation',
                      wellnessContainerImage: wellnessContainerImg2,
                      boxFit: BoxFit.fill,
                      playText: 'Play',
                      containerPadding: 10,
                    ),
                    SizedBox(height: 18),
                    const Text(
                      'Nature Sounds',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    children: [
                      MentalWellnessFooterWidget(
                        wellnessContainerImage: wellnessContainerImg3,
                        heading: 'Wind',
                        subHeading: 'Waves',
                      ),
                      MentalWellnessFooterWidget(
                        wellnessContainerImage: wellnessContainerImg4,
                        heading: 'Ocean',
                        subHeading: 'Breeze',
                      ),
                      MentalWellnessFooterWidget(
                        wellnessContainerImage: wellnessContainerImg5,
                        heading: 'Gentle',
                        subHeading: 'Rain',
                      ),
                      MentalWellnessFooterWidget(
                        wellnessContainerImage: wellnessContainerImg6,
                        heading: 'Mountain',
                        subHeading: 'Breeze',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

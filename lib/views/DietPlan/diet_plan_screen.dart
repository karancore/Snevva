import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/views/DietPlan/celebrity_diet_plan.dart';

import '../../consts/consts.dart';

class DietPlanScreen extends StatelessWidget {
  const DietPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Diet Plan"),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: defaultSize - 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Material(
                elevation: 1,
                color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                borderRadius: BorderRadius.circular(4),
                child: TextFormField(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixIcon: const Icon(Icons.search),
                    hintText: 'Search Available Diet Plans',
                    hintStyle: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
            SizedBox(height: defaultSize),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AutoSizeText(
                'Suggestions',
                minFontSize: 20,
                maxLines: 1,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: defaultSize - 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  dietContainer(
                    width,
                    'Next Best Step',
                    'Your body’s doing great...',
                    dietImg1,
                    isDarkMode,
                  ),
                  dietContainer(
                    width,
                    'Stay on Track',
                    'Keep healthy habits going...',
                    dietImg1,
                    isDarkMode,
                  ),
                ],
              ),
            ),
            SizedBox(height: defaultSize - 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AutoSizeText(
                'Category',
                minFontSize: 20,
                maxLines: 1,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: defaultSize - 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  dietCategoryIcons(width, 'Ketogenic', dietIcon1),
                  dietCategoryIcons(width, 'Non-Veg', dietIcon2),
                  dietCategoryIcons(width, 'Vegan', dietIcon3),
                  dietCategoryIcons(width, 'Fasting', dietIcon4),
                  dietCategoryIcons(width, 'Dash Diet', dietIcon5),
                  dietCategoryIcons(width, 'Gluten-Free', dietIcon6),
                ],
              ),
            ),
            SizedBox(height: defaultSize - 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AutoSizeText(
                'Most Liked',
                minFontSize: 20,
                maxLines: 1,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: defaultSize - 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  dietContainer(
                    width,
                    'Katrina Kaif',
                    '15-Day Katrina Kaif-Inspire...',
                    katImg,
                    isDarkMode,
                  ),
                  dietContainer(
                    width,
                    'Shilpa Shetty',
                    '15-Day Shilpa Shetty-Inspire....',
                    shilpaImg,
                    isDarkMode,
                  ),
                ],
              ),
            ),
            SizedBox(height: defaultSize - 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  dietContainer(
                    width,
                    'Virat Kohli',
                    '15-Day Virat Kohli-Inspire....',
                    virImg,
                    isDarkMode,
                  ),
                  dietContainer(
                    width,
                    'Akshay Kumar',
                    '15-Day Akshay Kumar-Inspire...',
                    akImg,
                    isDarkMode,
                  ),
                ],
              ),
            ),
            SizedBox(height: defaultSize),
          ],
        ),
      ),
    );
  }

  Padding dietCategoryIcons(double width, String categoryText, String icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: SizedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(icon, height: width * 0.1, fit: BoxFit.cover),
            SizedBox(height: 5),
            AutoSizeText(
              categoryText,
              minFontSize: 10,
              maxLines: 2,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  Material dietContainer(
    double width,
    String heading,
    String subHeading,
    String dietImg,
    bool isDarkMode,
  ) {
    return Material(
      color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
      elevation: 1,
      borderRadius: BorderRadius.circular(4),
      child: GestureDetector(
        onTap: () => Get.to(CelebrityDietPlan(title: heading, img: dietImg)),
        child: Container(
          width: width * 0.43,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            border: Border.all(width: border04px, color: mediumGrey),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(dietImg, height: 120,  width: width * 0.43, fit: BoxFit.cover),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      heading,
                      minFontSize: 10,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    AutoSizeText(
                      subHeading,
                      minFontSize: 10,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: mediumGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

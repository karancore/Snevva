import 'package:cached_network_image/cached_network_image.dart';
import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/views/DietPlan/celebrity_diet_plan.dart';

import '../../common/loader.dart';
import '../../consts/consts.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  final dietController = Get.put(DietPlanController());
  late double height;
  late double width;
  late bool isDarkMode;
  final popularDiets = [
    ["Katrina Kaif", "15-Day Katrina Kaif-Inspire...", katImg],
    ["Shilpa Shetty", "15-Day Shilpa Shetty-Inspire....", shilpaImg],
    ["Virat Kohli", "15-Day Virat Kohli-Inspired a million ", virImg],
    ["Akshay Kumar", "15-Day Akshay Kumar-Inspire...", akImg],
  ];
  final categoryDiets = [
    ['Vegetarian', dietIcon1],
    ['Non-Vegetarian', dietIcon2],
    ['Vegan', dietIcon3],
    ['Fasting', dietIcon4],
    ['Gluten-Free', dietIcon6],
  ];

  final Map<int, List<List<String>>> mostLikedByCategory = {
    0: [
      ["Katrina Kaif", "Keto Inspired Plan", katImg],
      ["Virat Kohli", "High Fat Keto", virImg],
      ["Akshay Kumar", "Low Carb Keto", akImg],
      ["Shilpa Shetty", "Clean Keto Diet", shilpaImg],
    ],
    1: [
      ["Virat Kohli", "High Protein Non-Veg", virImg],
      ["Akshay Kumar", "Muscle Gain Diet", akImg],
      ["Katrina Kaif", "Lean Body Plan", katImg],
      ["Shilpa Shetty", "Balanced Diet", shilpaImg],
    ],
    2: [
      ["Shilpa Shetty", "Vegan Cleanse", shilpaImg],
      ["Katrina Kaif", "Plant Based Glow", katImg],
      ["Virat Kohli", "Vegan Athlete", virImg],
      ["Akshay Kumar", "Green Energy Diet", akImg],
    ],
  };

  @override
  void initState() {
    super.initState();
    fetchSuggestions();

    // // Load default/general diets when screen opens
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //
    // });
  }
  Future<void> fetchSuggestions() async {
    final result = await dietController.getAllSuggestions(context);
    debugPrint(result.toString());
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    height = mediaQuery.size.height;
    width = mediaQuery.size.width;
    isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
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
              child: Obx(() {
                if (dietController.isLoading.value) {
                  return Loader();
                }

                final data = dietController.suggestionsResponse.value.data;
                if (data == null || data.isEmpty) {
                  return Text("No suggestions"); // prevent crash
                }

                if (data.length < 2) {
                  return Text("Not enough suggestions");
                }
                if (data.length >= 2) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(2, (i) {
                      return suggestedItem(
                        width,
                        data[i].title ?? "",
                        data[i].heading ?? "",
                        data[i].thumbnailMedia ?? dietPlaceholder,
                        isDarkMode,
                        i,
                      );
                    }),
                  );
                } else {
                  return Text("Not enough suggestions");
                }
              }),
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
                children: List.generate(categoryDiets.length, (index) {
                  final category = categoryDiets[index];
                  final categoryText = category[0];
                  final icon = category[1];

                  return dietCategoryIcons(width, categoryText, icon, index);
                }),
              ),
            ),

            SizedBox(height: defaultSize - 20),
            Obx(() {
              final categoryIndex = dietController.selectedCategoryIndex.value;
              final list = [];

              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text("No data available"),
                );
              }

              return SafeArea(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),

                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return dietContainer(
                      width,
                      item[0],
                      item[1],
                      item[2],
                      isDarkMode,
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> fetchCategoryReponse(String categoryText) async {
    final result = await dietController.getAllDiets(context, categoryText);
    print(result?.data);
  }

  Widget dietCategoryIcons(
    double width,
    String categoryText,
    String icon,
    int index,
  ) {
    return Obx(() {
      final isSelected = dietController.selectedCategoryIndex.value == index;

      return GestureDetector(
        onTap: () {
          dietController.changeCategory(index);
          fetchCategoryReponse(categoryText);
        },
        child: Container(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(icon, height: width * 0.1, fit: BoxFit.cover),
              SizedBox(height: 5),
              AutoSizeText(
                categoryText,
                minFontSize: 10,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: isSelected ? AppColors.primaryColor : grey,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Material suggestedItem(
    double width,
    String heading,
    String subHeading,
    String dietImg,
    bool isDarkMode,
    int index,
  ) {
    return Material(
      color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
      elevation: 1,
      borderRadius: BorderRadius.circular(4),
      child: GestureDetector(
        onTap:
            () => Get.to(
              CelebrityDietPlan(title: heading, img: dietImg, index: index),
            ),
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
                child: CachedNetworkImage(
                  imageUrl: dietImg,
                  height: 120,
                  width: width * 0.43,
                  fit: BoxFit.cover,
                ),
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
                child: Image.asset(
                  dietImg,
                  height: 120,
                  width: width * 0.43,
                  fit: BoxFit.cover,
                ),
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

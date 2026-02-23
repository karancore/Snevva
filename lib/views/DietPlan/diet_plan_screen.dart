import 'package:cached_network_image/cached_network_image.dart';
import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/models/diet_tags_response.dart';
import 'package:snevva/views/DietPlan/diet_details_screen.dart';

import '../../common/loader.dart';
import '../../consts/consts.dart';
import '../../env/env.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  final dietController = Get.find<DietPlanController>();
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await dietController.getCelebrity(context);
      await dietController.getAllSuggestions(context);
      await dietController.getAllDiets(context, "Vegetarian");
      // logLong("Celebrity Diet Response:" ,  celebrity.toString());
    });

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
    print("Height of Diet Plan Screen: $height");
    width = mediaQuery.size.width;

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
                if (dietController.isSuggestionsLoading.value) {
                  return const Loader();
                }

                final data = dietController.suggestionsResponse.value.data;

                if (data == null || data.isEmpty) {
                  return Center(child: const Text("No data available"));
                }
                return SizedBox(
                  height: 170,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.length,
                    separatorBuilder: (_, __) => SizedBox(width: defaultSize),
                    itemBuilder: (context, index) {
                      final item = data[index];

                      print(
                        "Runtime Type of meal plan is: ${item.runtimeType}",
                      );

                      return KeyedSubtree(
                        key: ValueKey(item.id ?? index), // if id exists, use it
                        child: suggestedItem(
                          item: item,
                          width: width,
                          heading: item.heading ?? "",
                          subHeading: item.title ?? "",
                          dietImg: item.thumbnailMedia ?? dietPlaceholder,
                          isDarkMode: isDarkMode,
                        ),
                      );
                    },
                  ),
                );
              }),
            ),

            SizedBox(height: defaultSize - 10),

            // NEW Celebrity Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AutoSizeText(
                'Celebrity',
                minFontSize: 20,
                maxLines: 1,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: defaultSize - 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Obx(() {
                if (dietController.isCelebrityLoading.value) {
                  return const Loader();
                }

                final data = dietController.celebrityList;
                if (data.isEmpty) {
                  return const Text("No celebrity plans available");
                }
                return SizedBox(
                  height: 170,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.length,
                    separatorBuilder: (_, __) => SizedBox(width: defaultSize),
                    itemBuilder: (context, index) {
                      final item = data[index];

                      return KeyedSubtree(
                        key: ValueKey(item.id ?? index),
                        child: suggestedItem(
                          item: item,
                          width: width,
                          heading: item.heading ?? "",
                          subHeading: item.title ?? "",
                          dietImg: item.thumbnailMedia ?? dietPlaceholder,
                          isDarkMode: isDarkMode,
                        ),
                      );
                    },
                  ),
                );
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

                  return Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 20 : 10,
                      right: index == categoryDiets.length - 1 ? 20 : 0,
                    ),
                    child: dietCategoryIcons(width, categoryText, icon, index),
                  );
                }),
              ),
            ),

            SizedBox(height: defaultSize - 20),
            Obx(() {
              if (dietController.isCategoryLoading.value) {
                return const Loader();
              }

              final data = dietController.categoryResponse.value.data;

              if (data == null || data.isEmpty) {
                return Center(child: const Text("No data available"));
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.length,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 154,
                ),
                itemBuilder: (context, index) {
                  final item = data[index];
                  return KeyedSubtree(
                    key: ValueKey(item.id ?? index), // if id exists, use it
                    child: suggestedItem(
                      item: item,
                      width: width,
                      heading: item.heading ?? "",
                      subHeading: item.title ?? "",
                      dietImg: item.thumbnailMedia ?? dietPlaceholder,
                      isDarkMode: isDarkMode,
                      isGridItem: true,
                    ),
                  );
                },
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
      final iconSize = width * 0.09;

      return InkWell(
        onTap: () {
          dietController.changeCategory(index);
          fetchCategoryReponse(categoryText);
        },
        child: SizedBox(
          width: 74,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: iconSize,
                width: iconSize,
                child: Image.asset(icon, fit: BoxFit.contain),
              ),
              const SizedBox(height: 6),
              AutoSizeText(
                categoryText,
                minFontSize: 10,
                maxLines: 2,
                textAlign: TextAlign.center,
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

  Widget suggestedItem({
    required DietTagData item,
    required double width,
    required String heading,
    required String subHeading,
    required String dietImg,
    required bool isDarkMode,
    bool isGridItem = false,
  }) {
    final cardWidth = isGridItem ? double.infinity : width * 0.43;
    final cardRadius = isGridItem ? 12.0 : 16.0;
    final imageHeight = isGridItem ? 95.0 : 120.0;
    final textPadding =
        isGridItem
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 8);

    return Material(
      color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
      elevation: 4,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: () {
          dietController.dietTagsDataResponse.value = item;
          final daysList = item.mealPlan ?? [];

          Get.to(DietDetailsScreen(diet: item, daysList: daysList));
        },
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(width: border04px, color: mediumGrey),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(cardRadius),
                ),
                child: CachedNetworkImage(
                  imageUrl: dietImg,
                  height: imageHeight,
                  width: cardWidth,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: textPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      heading,
                      minFontSize: 10,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isGridItem ? 14 : 16,
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
                        fontSize: isGridItem ? 9 : 10,
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
    int index,
  ) {
    return Material(
      color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
      elevation: 1,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: () {
          final diet = DietTagData(
            heading: heading,
            title: subHeading,
            thumbnailMedia: dietImg,
            mealPlan: [],
            tags: [],
          );

          Get.to(DietDetailsScreen(diet: diet, daysList: []));
        },
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart';
import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';

import '../../common/global_variables.dart';
import '../../common/loader.dart';
import '../../consts/consts.dart';

class CelebrityDietPlan extends StatefulWidget {
  final String title;
  final String img;
  final int? index;

  const CelebrityDietPlan({
    super.key,
    required this.title,
    required this.img,
    this.index,
  });

  @override
  State<CelebrityDietPlan> createState() => _CelebrityDietPlanState();
}

class _CelebrityDietPlanState extends State<CelebrityDietPlan> {
  final dietController = Get.put(DietPlanController());
  List<String> daysList = [];

  @override
  void initState() {
    super.initState();
    fetchDietTagData();
  }

  void fetchDietTagData() async {
    await dietController.getAllDiets(context, "Vegetarian");
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    // final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size(double.infinity, 48),
        child: Obx(() {
          final heading =
              dietController
                  .categoryResponse
                  .value
                  .data?[widget.index ?? 0]
                  .heading;
          return CustomAppBar(appbarText: heading ?? widget.title);
        }),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(width: border04px, color: mediumGrey),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    child: Obx(() {
                      final imageUrl =
                          dietController
                              .categoryResponse
                              .value
                              .data?[widget.index ?? 0]
                              .thumbnailMedia;
                      return CachedNetworkImage(
                        imageUrl: imageUrl ?? dietPlaceholder,
                        height: height * 0.25,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      );
                    }),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 2),
                          Obx(() {
                            final description =
                                dietController
                                    .categoryResponse
                                    .value
                                    .data?[widget.index ?? 0]
                                    .shortDescription;
                            return AutoSizeText(
                              description ?? '',
                              minFontSize: 10,
                              textAlign: TextAlign.justify,
                              maxLines: 8,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: mediumGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: defaultSize - 20),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            child: Obx(() {
              // if(dietController.isLoading.value){
              //   return Loader();
              // }
              final dataList =
                  dietController
                      .categoryResponse
                      .value
                      .data?[widget.index ?? 0]
                      .mealPlan ??
                  [];
              print(dataList.length);
              if (dataList.isEmpty) {
                return SizedBox.shrink();
              }
              print(dietController.categoryResponse.value.data);
              return Column(
                children: [
                  //Text(dietController.dietTagResponse.value.toJson().toString()) ,
                  Row(
                    children: List.generate(dataList.length, (index) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => dietController.changeDay(index),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 8,
                            top: 6,
                            bottom: 6,
                          ),
                          child: dietDaysCont(
                            index + 1,
                            isDarkMode,
                            isSelected:
                                dietController.selectedDayIndex.value == index,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            }),
          ),
          Expanded(
            child: Obx(() {
              // if (dietController.isLoading.value) {
              //   return Center(child: CircularProgressIndicator());
              // }

              final plans = dietController.categoryResponse.value.data;
              if (plans == null || plans.isEmpty) {
                return Center(child: Text("No diet plans available"));
              }

              // Select first diet plan
              final plan = plans[0];
              final meals = plan.mealPlan ?? [];

              return PageView.builder(
                controller: dietController.celebrityPageController,
                onPageChanged: dietController.onCelebrityPageChanged,
                itemCount: meals.length, // <-- Number of days
                itemBuilder: (context, index) {
                  final dayMeal = meals[index];

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        dietDish(
                          'Breakfast',
                          dayMeal.breakFastMedia ?? dietPlaceholder,
                          dayMeal.breakFast ?? "N/A",
                          "",
                        ),
                        dietDish(
                          'Lunch',
                          dayMeal.lunchMedia ?? dietPlaceholder,
                          dayMeal.lunch ?? "N/A",
                          "",
                        ),
                        dietDish(
                          'Snacks',
                          dayMeal.eveningMedia ?? dietPlaceholder,
                          dayMeal.evening ?? "N/A",
                          "",
                        ),
                        dietDish(
                          'Dinner',
                          dayMeal.breakFastMedia ?? dietPlaceholder,
                          dayMeal.dinner ?? "N/A",
                          "",
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Padding dietDish(
    String heading,
    String dishImg,
    String ingredients,
    String cal,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Column(
        children: [
          const Divider(thickness: border04px, color: mediumGrey),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RotatedBox(
                quarterTurns: -1,
                child: AutoSizeText(
                  heading,
                  minFontSize: 14,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                height: 100,
                width: 100,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(dishImg),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      ingredients,
                      minFontSize: 8,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Image.asset(caloriesImg, height: 24),
                        const SizedBox(width: 5),
                        Text(cal, style: TextStyle(color: mediumGrey)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Container dietDaysCont(
    int count,
    bool isDarkMode, {
    bool? isSelected = false,
  }) {
    return Container(
      margin: EdgeInsets.only(right: 10),
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected! ? AppColors.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          width: border04px,
          color: isSelected ? white : mediumGrey,
        ),
      ),
      child: Center(
        child: Text(
          'Day $count',
          style: TextStyle(
            color:
                isSelected
                    ? white
                    : isDarkMode
                    ? white
                    : black,
          ),
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart';
import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/models/diet_tags_response.dart';

import '../../common/global_variables.dart';
import '../../common/loader.dart';
import '../../consts/consts.dart';
import '../../env/env.dart';

class DietDetailsScreen extends StatefulWidget {
  final DietTagData diet;
  final List<MealPlanItem> daysList;

  const DietDetailsScreen({
    super.key,
    required this.diet,
    required this.daysList,
  });

  @override
  State<DietDetailsScreen> createState() => _DietDetailsScreenState();
}

class _DietDetailsScreenState extends State<DietDetailsScreen> {
  final dietController = Get.find<DietPlanController>();

  @override
  void initState() {
    super.initState();
    dietController.selectedDayIndex.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dietController.celebrityPageController.hasClients) {
        dietController.celebrityPageController.jumpToPage(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    logLong("Celebrity Diet Plan", widget.diet.toJson().toString());
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final daysList = widget.daysList;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size(double.infinity, 48),
        child: CustomAppBar(
          appbarText: widget.diet.heading ?? widget.diet.title ?? "Diet Plan",
        ),
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
                    child: CachedNetworkImage(
                      imageUrl: widget.diet.thumbnailMedia ?? dietPlaceholder,
                      height: height * 0.25,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 2),
                          AutoSizeText(
                            widget.diet.shortDescription ?? '',
                            minFontSize: 10,
                            textAlign: TextAlign.justify,
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: mediumGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: defaultSize - 30),

          // SingleChildScrollView(
          //   padding: const EdgeInsets.only(left: 12),
          //   scrollDirection: Axis.horizontal ,
          //   child: Row(
          //   children: List.generate(daysList.length, (index) {
          //     return InkWell(
          //       borderRadius: BorderRadius.circular(20),
          //       onTap: () => dietController.changeDay(index),
          //       child: Padding(
          //         padding: const EdgeInsets.only(
          //           left: 8,
          //           top: 6,
          //           bottom: 6,
          //         ),
          //         child: dietDaysCont(
          //           index + 1,
          //           isDarkMode,
          //           isSelected:
          //           dietController.selectedDayIndex.value == index,
          //         ),
          //       ),
          //     );
          //   }),
          // ),),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            child: Obx(() {
              final dataList = widget.daysList;
              logLong(
                "Celebrity dietags response ",
                dataList.length.toString(),
              );
              if (dataList.isEmpty) {
                return SizedBox.shrink();
              }
              logLong(
                "",
                dietController.categoryResponse.value.data.toString(),
              );
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
          if (daysList.isEmpty) Center(child: Text("No diet plans available")),
          Expanded(
            child: PageView.builder(
              controller: dietController.celebrityPageController,
              onPageChanged: dietController.onCelebrityPageChanged,
              itemCount: daysList.length, // <-- Number of days
              itemBuilder: (context, index) {
                final dayMeal = daysList[index];

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      if ((dayMeal.breakFast ?? '').isNotEmpty)
                        dietDish(
                          'Breakfast',
                          dayMeal.breakFastMedia ?? dietPlaceholder,
                          dayMeal.breakFast!,
                          "",
                        )
                      else
                        const SizedBox.shrink(),

                      if ((dayMeal.lunch ?? '').isNotEmpty)
                        dietDish(
                          'Lunch',
                          dayMeal.lunchMedia ?? dietPlaceholder,
                          dayMeal.lunch!,
                          "",
                        )
                      else
                        const SizedBox.shrink(),

                      if ((dayMeal.evening ?? '').isNotEmpty)
                        dietDish(
                          'Snacks',
                          dayMeal.eveningMedia ?? dietPlaceholder,
                          dayMeal.evening!,
                          "",
                        )
                      else
                        const SizedBox.shrink(),

                      if ((dayMeal.dinner ?? '').isNotEmpty)
                        dietDish(
                          'Dinner',
                          dayMeal.dinnerMedia ?? dietPlaceholder,
                          dayMeal.dinner!,
                          "",
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                );
              },
            ),
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

//   }
// }
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:http/http.dart';
// import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';
// import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
// import 'package:snevva/models/diet_tags_response.dart';
//
// import '../../common/global_variables.dart';
// import '../../common/loader.dart';
// import '../../consts/consts.dart';
// import '../../env/env.dart';
//
// class CelebrityDietPlan extends StatefulWidget {
//   final DietTagData diet;
//
//   const CelebrityDietPlan({super.key, required this.diet});
//
//   @override
//   State<CelebrityDietPlan> createState() => _CelebrityDietPlanState();
// }
//
// class _CelebrityDietPlanState extends State<CelebrityDietPlan> {
//   final dietController = Get.put(DietPlanController());
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeDietPlan();
//   }
//
//   void _initializeDietPlan() {
//     // Reset selected day index when entering this screen
//     dietController.selectedDayIndex.value = 0;
//
//     // Initialize PageController to first page
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (dietController.celebrityPageController.hasClients) {
//         dietController.celebrityPageController.jumpToPage(0);
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final mediaQuery = MediaQuery.of(context);
//     final height = mediaQuery.size.height;
//     final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
//
//     return Scaffold(
//       appBar: PreferredSize(
//         preferredSize: Size(double.infinity, 48),
//         child: CustomAppBar(
//           appbarText: widget.diet.heading ?? widget.diet.title ?? "Diet Plan",
//         ),
//       ),
//       body: Builder(
//         builder: (context) {
//           // Get the meal plan from widget.diet
//           List<MealPlanItem> mealPlanList = widget.diet.mealPlan ?? [];
//
//           if (mealPlanList.isEmpty) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.no_food, size: 64, color: Colors.grey),
//                   SizedBox(height: 16),
//                   Text(
//                     "No meal plan available",
//                     style: TextStyle(fontSize: 16, color: Colors.grey),
//                   ),
//                 ],
//               ),
//             );
//           }
//
//           return Column(
//             children: [
//               // Diet Plan Header
//               Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Container(
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(4),
//                     border: Border.all(width: border04px, color: mediumGrey),
//                   ),
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.start,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       ClipRRect(
//                         borderRadius: BorderRadius.vertical(
//                           top: Radius.circular(4),
//                         ),
//                         child: CachedNetworkImage(
//                           imageUrl:
//                           widget.diet.thumbnailMedia ?? dietPlaceholder,
//                           height: height * 0.25,
//                           width: double.infinity,
//                           fit: BoxFit.cover,
//                           placeholder: (context, url) => Container(
//                             height: height * 0.25,
//                             color: Colors.grey[300],
//                             child: Center(child: CircularProgressIndicator()),
//                           ),
//                           errorWidget: (context, url, error) => Container(
//                             height: height * 0.25,
//                             color: Colors.grey[300],
//                             child: Icon(Icons.error),
//                           ),
//                         ),
//                       ),
//                       if (widget.diet.shortDescription != null &&
//                           widget.diet.shortDescription!.isNotEmpty)
//                         Padding(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 10,
//                           ),
//                           child: Center(
//                             child: AutoSizeText(
//                               widget.diet.shortDescription!,
//                               minFontSize: 10,
//                               textAlign: TextAlign.justify,
//                               maxLines: 8,
//                               overflow: TextOverflow.ellipsis,
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: mediumGrey,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//               ),
//               SizedBox(height: defaultSize - 20),
//
//               // Days Selection
//               SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 padding: const EdgeInsets.only(left: 20),
//                 child: Row(
//                   children: List.generate(mealPlanList.length, (index) {
//                     return Obx(() {
//                       final isSelected =
//                           dietController.selectedDayIndex.value == index;
//
//                       return InkWell(
//                         borderRadius: BorderRadius.circular(20),
//                         onTap: () => dietController.changeDay(index),
//                         child: Padding(
//                           padding: const EdgeInsets.only(
//                             left: 8,
//                             top: 6,
//                             bottom: 6,
//                           ),
//                           child: dietDaysCont(
//                             mealPlanList[index].day ?? (index + 1),
//                             isDarkMode,
//                             isSelected: isSelected,
//                           ),
//                         ),
//                       );
//                     });
//                   }),
//                 ),
//               ),
//
//               SizedBox(height: defaultSize - 10),
//
//               // Meal Plan Content
//               Expanded(
//                 child: PageView.builder(
//                   controller: dietController.celebrityPageController,
//                   onPageChanged: dietController.onCelebrityPageChanged,
//                   itemCount: mealPlanList.length,
//                   itemBuilder: (context, index) {
//                     final dayMeal = mealPlanList[index];
//
//                     return SingleChildScrollView(
//                       padding: EdgeInsets.only(bottom: 20),
//                       child: Column(
//                         children: [
//                           if (dayMeal.breakFast != null &&
//                               dayMeal.breakFast!.isNotEmpty)
//                             dietDish(
//                               'Breakfast',
//                               dayMeal.breakFastMedia ?? dietPlaceholder,
//                               dayMeal.breakFast!,
//                               "",
//                             ),
//                           if (dayMeal.lunch != null &&
//                               dayMeal.lunch!.isNotEmpty)
//                             dietDish(
//                               'Lunch',
//                               dayMeal.lunchMedia ?? dietPlaceholder,
//                               dayMeal.lunch!,
//                               "",
//                             ),
//                           if (dayMeal.evening != null &&
//                               dayMeal.evening!.isNotEmpty)
//                             dietDish(
//                               'Snacks',
//                               dayMeal.eveningMedia ?? dietPlaceholder,
//                               dayMeal.evening!,
//                               "",
//                             ),
//                           if (dayMeal.dinner != null &&
//                               dayMeal.dinner!.isNotEmpty)
//                             dietDish(
//                               'Dinner',
//                               dayMeal.dinnerMedia ?? dietPlaceholder,
//                               dayMeal.dinner!,
//                               "",
//                             ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   Padding dietDish(
//       String heading,
//       String dishImg,
//       String ingredients,
//       String cal,
//       ) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
//       child: Column(
//         children: [
//           const Divider(thickness: border04px, color: mediumGrey),
//           const SizedBox(height: 10),
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               RotatedBox(
//                 quarterTurns: -1,
//                 child: AutoSizeText(
//                   heading,
//                   minFontSize: 14,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//               Container(
//                 height: 100,
//                 width: 100,
//                 margin: const EdgeInsets.symmetric(horizontal: 10),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(8),
//                   color: Colors.grey[300],
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(8),
//                   child: CachedNetworkImage(
//                     imageUrl: dishImg,
//                     fit: BoxFit.cover,
//                     placeholder: (context, url) => Center(
//                       child: CircularProgressIndicator(strokeWidth: 2),
//                     ),
//                     errorWidget: (context, url, error) => Center(
//                       child: Icon(Icons.restaurant, color: Colors.grey),
//                     ),
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     AutoSizeText(
//                       ingredients,
//                       minFontSize: 8,
//                       maxLines: 4,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                     if (cal.isNotEmpty) ...[
//                       const SizedBox(height: 10),
//                       Row(
//                         children: [
//                           Image.asset(caloriesImg, height: 24),
//                           const SizedBox(width: 5),
//                           Text(
//                             cal + " cal",
//                             style: TextStyle(color: mediumGrey),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Container dietDaysCont(
//       int count,
//       bool isDarkMode, {
//         bool? isSelected = false,
//       }) {
//     return Container(
//       margin: EdgeInsets.only(right: 10),
//       padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
//       decoration: BoxDecoration(
//         color: isSelected! ? AppColors.primaryColor : Colors.transparent,
//         borderRadius: BorderRadius.circular(30),
//         border: Border.all(
//           width: border04px,
//           color: isSelected ? white : mediumGrey,
//         ),
//       ),
//       child: Center(
//         child: Text(
//           'Day $count',
//           style: TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w500,
//             color: isSelected
//                 ? white
//                 : isDarkMode
//                 ? white
//                 : black,
//           ),
//         ),
//       ),
//     );
//   }
// }
//}

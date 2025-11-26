import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';

import '../../consts/consts.dart';

class CelebrityDietPlan extends StatefulWidget {
  final String title;
  final String img;

  const CelebrityDietPlan({super.key, required this.title, required this.img});

  @override
  State<CelebrityDietPlan> createState() => _CelebrityDietPlanState();
}

class _CelebrityDietPlanState extends State<CelebrityDietPlan> {
  final dietController = Get.put(DietPlanController());

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    // final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.title),
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: Icon(FontAwesomeIcons.arrowLeft),
          color: isDarkMode ? white : black,
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
                    child: Image.asset(
                      widget.img,
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
                            '${widget.title} eats balanced, nutritious meals with portion control, rooted in Indian traditions—plus a weekly “Sunday binge” for cravings.',
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
          SizedBox(height: defaultSize - 20),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Obx(
                () => Row(
                  children: List.generate(7, (index) {
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
              ),
            ),
          ),

          Expanded(
            child: PageView.builder(
              controller: dietController.pageController,
              onPageChanged: dietController.onPageChanged,
              itemCount: 7,
              itemBuilder: (context, index) {
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    children: [
                      dietDish(
                        'Breakfast',
                        morningDietImg,
                        'Oats, milk, pomegranate, chia, soaked almonds',
                        '340',
                      ),
                      dietDish(
                        'Lunch     ',
                        afternoonDietImg,
                        'Brown rice, ghee, veg curry, grilled chicken',
                        '800',
                      ),
                      dietDish(
                        'Snacks   ',
                        eveningDietImg,
                        'Roasted makhana & walnuts',
                        '270'
                      ),
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

  Padding dietDish(String heading, String dishImg, String ingredients, String cal) {
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
                    image: AssetImage(dishImg),
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

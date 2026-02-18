import 'dart:math';

import 'package:flutter_svg/svg.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';

import 'bmi_result.dart';

class BmiCal extends StatefulWidget {
  const BmiCal({super.key});

  @override
  State<BmiCal> createState() => _BmiCalState();
}

class _BmiCalState extends State<BmiCal> {
  bool isMale = true;
  int age = 19;
  double weight = 52;
  double height = 158;

  bool isSelected = false;

  late FixedExtentScrollController weightController;
  late ScrollController _scrollController;

  final List<int> weights = List.generate(100, (i) => i + 1); // 1–120 kg
  int selectedWeight = 70;

  static const int _virtualItemCount = 500; // BIG list (infinite illusion)
  static const int _realItemCount = 100;

  late int _middleIndex;

  final double itemWidth = 38; // 30 width + 8 separator spacing
  final double viewportWidth = 220; // your SizedBox width
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _scrollController.addListener(_onScroll);

    _middleIndex = _virtualItemCount ~/ 2;

    weightController = FixedExtentScrollController(
      initialItem: selectedWeight - 1,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        _scrollToWeight(weight);
      });
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    const double itemWidth = 32;
    const double spacing = 8;
    const double itemExtent = itemWidth + spacing;

    final center = _scrollController.offset + (viewportWidth / 2);

    int index = (center / itemExtent).round();

    int number = (index % _realItemCount) + 1;

    if (number != weight.round()) {
      setState(() {
        weight = number.toDouble();
      });
    }
  }

  void _scrollToWeight(double number) {
    if (!_scrollController.hasClients) return;

    const double itemWidth = 32;
    const double spacing = 8;
    const double itemExtent = itemWidth + spacing;

    // Find the nearest cycle around middle
    int baseIndex = _middleIndex - (_middleIndex % _realItemCount);
    int targetIndex = baseIndex + number.round() - 1;

    // center correction
    final screenCenter = viewportWidth / 2;
    final itemCenter = itemExtent / 2;

    double offset = (targetIndex * itemExtent) - (screenCenter - itemCenter);

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final heightDevice = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bottomButtonHeight = 80.0;

    return Scaffold(
      drawer: Drawer(
        child: DrawerMenuWidget(height: heightDevice, width: width),
      ),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: transparent,
        centerTitle: true,
        title: Text(
          "BMI Calculator",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: white,
          ),
        ),

        // Conditionally show leading drawer icon
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: SvgPicture.asset(drawerIcon, color: white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),

        // Conditionally show close (cross) icon
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: SizedBox(
                height: 24,
                width: 24,
                child: Icon(
                  Icons.clear,
                  size: 21,
                  color: white, // Adapt to theme
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: 300,
            child: Image.asset(bmiCalculator, fit: BoxFit.fill),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 260),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomButtonHeight + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gender and Age in Cards
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          color: isDarkMode ? darkGray : white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text("Gender"),
                                Divider(color: Colors.grey, thickness: 1),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.female,
                                            color:
                                                !isMale
                                                    ? AppColors.primaryColor
                                                    : mediumGrey,
                                          ),
                                          onPressed:
                                              () => setState(
                                                () => isMale = false,
                                              ),
                                        ),
                                        const Text("Female"),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.male,
                                            color:
                                                isMale
                                                    ? AppColors.primaryColor
                                                    : mediumGrey,
                                          ),
                                          onPressed:
                                              () =>
                                                  setState(() => isMale = true),
                                        ),
                                        const Text("Male"),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          color: isDarkMode ? darkGray : white,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                const Text("Age"),
                                Divider(color: mediumGrey, thickness: 1),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      onPressed:
                                          () => setState(
                                            () => age = age > 0 ? age - 1 : 0,
                                          ),
                                    ),
                                    AutoSizeText(
                                      "$age",
                                      minFontSize: 16,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        color: AppColors.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      onPressed: () => setState(() => age++),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Weight Card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    color: isDarkMode ? darkGray : white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text("Weight"),
                          Divider(color: mediumGrey, thickness: 1),
                          Row(
                            children: [
                              // Minus button
                              // IconButton(
                              //   icon: const Icon(Icons.remove_circle_outline),
                              //   onPressed: () {
                              //     if (weight <= 1) return;
                              //     setState(() => weight--);
                              //     _scrollToWeight(weight);
                              //   },
                              // ),

                              // Responsive list
                              Expanded(
                                child: SizedBox(
                                  height: 60,
                                  child: RotatedBox(
                                    quarterTurns: -1,
                                    child: ListWheelScrollView.useDelegate(
                                      controller: weightController,
                                      itemExtent: 50,
                                      // VERY IMPORTANT (height of each number)
                                      diameterRatio: 2.5,
                                      physics: const FixedExtentScrollPhysics(),
                                      perspective: 0.003,
                                      onSelectedItemChanged: (index) {
                                        setState(() {
                                          selectedWeight = weights[index];
                                        });
                                      },
                                      childDelegate:
                                          ListWheelChildBuilderDelegate(
                                            childCount: weights.length,
                                            builder: (context, index) {
                                              final isSelected =
                                                  weights[index] ==
                                                  selectedWeight;

                                              return Center(
                                                child: AnimatedDefaultTextStyle(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize:
                                                        isSelected ? 26 : 18,
                                                    fontWeight:
                                                        isSelected
                                                            ? FontWeight.bold
                                                            : FontWeight.w400,
                                                    color:
                                                        isSelected
                                                            ? AppColors
                                                                .primaryColor
                                                            : Colors.grey,
                                                  ),
                                                  child: RotatedBox(
                                                    quarterTurns: 1,
                                                    child: Text(
                                                      weights[index].toString(),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                    ),
                                  ),
                                ),
                              ),

                              // Plus button
                              // IconButton(
                              //   icon: const Icon(Icons.add_circle_outline),
                              //   onPressed: () {
                              //     if (weight >= 100) return;
                              //     setState(() => weight++);
                              //     _scrollToWeight(weight);
                              //   },
                              // ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Height Card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    color: isDarkMode ? darkGray : white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      child: Column(
                        children: [
                          const Text("Height"),
                          Divider(color: Colors.grey, thickness: 1),
                          Slider(
                            value: height,
                            min: 100,
                            max: 220,
                            divisions: 120,
                            activeColor: AppColors.primaryColor,
                            inactiveColor: mediumGrey.withValues(alpha: 0.3),
                            label: height.round().toString(),
                            onChanged: (val) => setState(() => height = val),
                          ),
                          Text(
                            "${height.round()} cm",
                            style: const TextStyle(
                              fontSize: 20,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Calculate BMI Button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: CustomOutlinedButton(
            width: width,
            isDarkMode: isDarkMode,
            buttonName: "Calculate BMI",
            backgroundColor: AppColors.primaryColor,
            onTap: () {
              double bmi = weight / pow(height / 100, 2);
              Get.to(BmiResultPage(bmi: bmi, age: age));
            },
          ),
        ),
      ),
    );
  }
}

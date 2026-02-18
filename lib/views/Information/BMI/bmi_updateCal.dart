import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:snevva/Controllers/BMI/bmi_updatecontroller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import 'bmi_result.dart';
import 'bmi_update_result.dart';

class BmiUpdatecal extends StatefulWidget {
  const BmiUpdatecal({super.key});

  @override
  State<BmiUpdatecal> createState() => _BmiUpdatecalState();
}

class _BmiUpdatecalState extends State<BmiUpdatecal> {
  bool isMale = true;
  int age = 19;
  double weight = 52;
  double height = 158;

  // smaller virtual list to lower layout cost
  static const int _virtualItemCount = 200;
  static const int _realItemCount = 100;

  late FixedExtentScrollController weightController;

  final List<int> weights = List.generate(100, (i) => i + 1); // 1–120 kg
  int selectedWeight = 70;

  // visual dimensions (keep them consistent)
  static const double _visibleItemWidth = 32.0;
  static const double _itemSpacing = 8.0;
  static const double _itemExtent = _visibleItemWidth + _itemSpacing;

  // keeps track of last computed viewport (set inside LayoutBuilder)
  double _currentViewportWidth = 220.0;

  late int _middleIndex;
  late ScrollController _scrollController;

  // guard to avoid feedback loop when we animate programmatically
  bool _isAutoScrolling = false;

  // controller (keep as you had it)
  final bmicontroller = Get.put(BmiUpdateController());

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _middleIndex = _virtualItemCount ~/ 2;

    weightController = FixedExtentScrollController(
      initialItem: selectedWeight - 1,
    );
    // wait for first layout then scroll (small delay avoids heavy layout + animate overlap)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _scrollToWeight(weight);
      });
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isAutoScrolling) return;

    // center point inside the list view (accounting for left padding)
    final center = _scrollController.offset + (_currentViewportWidth / 2);

    final int index = (center / _itemExtent).round();
    final int newNumber = (index % _realItemCount) + 1;

    if (newNumber != weight.round()) {
      // only update when changed
      setState(() {
        weight = newNumber.toDouble();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToWeight(double number) async {
    if (!_scrollController.hasClients) return;

    // Find the nearest cycle around middle
    final int baseIndex = _middleIndex - (_middleIndex % _realItemCount);
    final int targetIndex = baseIndex + number.round() - 1;

    // compute the left offset so that target item is centered
    final double screenCenter = _currentViewportWidth / 2;
    final double itemCenter = _itemExtent / 2;
    final double offset =
        (targetIndex * _itemExtent) - (screenCenter - itemCenter);

    _isAutoScrolling = true;
    try {
      await _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 330),
        curve: Curves.easeOut,
      );
    } catch (_) {
      // animateTo can throw if controller disposed — ignore safely
    } finally {
      // small delay to ensure the scroll metrics settle before turning the guard off
      await Future.delayed(const Duration(milliseconds: 30));
      if (mounted) _isAutoScrolling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final heightDevice = mediaQuery.size.height;
    final width = mediaQuery.size.width;
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
        title: const Text(
          "Update Your BMI",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: SvgPicture.asset(drawerIcon, color: white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                height: 24,
                width: 24,
                child: Icon(Icons.clear, size: 21, color: Colors.white),
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
            padding: const EdgeInsets.only(top: 270),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomButtonHeight + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                              //     weight = max(1, weight - 1);
                              //     _scrollToWeight(weight);
                              //     setState(() {});
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
                              //     if (weight >= _realItemCount) return;
                              //     weight = min(_realItemCount.toDouble(), weight + 1);
                              //     _scrollToWeight(weight);
                              //     setState(() {});
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
            onTap: () async {
              final double bmi = weight / pow(height / 100, 2);

              bool flag = await bmicontroller.setHeightAndWeight(
                context,
                age,
                height,
                weight,
              );
              if (flag) {
                Get.to(BMIUpdateResultScreen(bmi: bmi, age: age));
              }
            },
          ),
        ),
      ),
    );
  }
}

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
  int weight = 52;
  double height = 158;

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
            padding: const EdgeInsets.only(top: 250),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed:
                                    () => setState(
                                      () =>
                                          weight = weight > 1 ? weight - 1 : 1,
                                    ),
                              ),

                              for (int i = weight - 2; i <= weight + 2; i++)
                                if (i > 0)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: AutoSizeText(
                                      "$i",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            i == weight
                                                ? AppColors.primaryColor
                                                : mediumGrey,
                                      ),
                                    ),
                                  ),

                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => setState(() => weight++),
                              ),
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
                  CustomOutlinedButton(
                    width: width,
                    isDarkMode: isDarkMode,
                    buttonName: "Calculate BMI",
                    backgroundColor: AppColors.primaryColor,
                    onTap: () {
                      double bmi = weight / ((height / 100) * (height / 100));
                      Get.to(BmiResultPage(bmi: bmi, age: age));
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

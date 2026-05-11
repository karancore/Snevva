import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:snevva/widgets/add_glucose_card.dart';
import 'package:snevva/widgets/glucose_card.dart';

import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../consts/colors.dart';
import '../../consts/images.dart';

class GlucoseScreen extends StatelessWidget {
  const GlucoseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;

    return Scaffold(
      backgroundColor: isDarkMode ? scaffoldColorDark : white,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      body: Stack(
        children: [
          const BloodGlucoseHeader(),
          Positioned(
            top: height * 0.32,
            right: 10,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap:
                      () => showDialog(
                        context: context,
                        barrierColor: Colors.black26,
                        builder: (_) => const AddGlucoseCard(),
                      ),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(0xffB475FF),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.add, size: 24, color: white),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: height * 0.36,
            child: SizedBox(
              height: height * 0.49,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: 0.0,
                    horizontal: 24.0,
                  ),
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return GlucoseCard(
                      glucoseLevel: 4.2.toString(),
                      time: DateTime.now().toString(),
                    );
                  },
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 14.0),
                child: Image.asset(glucoseBanner),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BloodGlucoseHeader extends StatelessWidget {
  const BloodGlucoseHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final double scale = MediaQuery.of(context).size.width / 360;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? scaffoldColorDark : white,
      body: Column(
        children: [
          ClipPath(
            clipper: BottomEllipseClipper(),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 340 * scale,
                  // ✅ Purple header stays same in both modes (brand color)
                  decoration: const BoxDecoration(color: Color(0xffB475FF)),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: SvgPicture.asset(
                                  drawerIcon,
                                  color: white,
                                ),
                                onPressed:
                                    () => Scaffold.of(context).openDrawer(),
                              ),
                              const Text(
                                'Blood Glucose',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Glucose Drop + Text Overlay
                Positioned(
                  bottom: 120 * scale,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          glucoseDrop,
                          width: 90 * scale,
                          height: 124 * scale,
                          fit: BoxFit.contain,
                        ),
                        Positioned(
                          top: 45 * scale,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(" ", style: TextStyle(height: 0.5 * scale)),
                              Text(
                                '5.4',
                                style: TextStyle(
                                  // ✅ Dark: white text | Light: black text
                                  color: isDarkMode ? darkGray : black,
                                  fontSize: 40 * scale,
                                  fontWeight: FontWeight.w600,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'mmol/L',
                                style: TextStyle(
                                  // ✅ Dark: white text | Light: black text
                                  color: isDarkMode ? darkGray : black,
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w400,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Status Badge
                Positioned(
                  bottom: 90 * scale,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 106 * scale,
                      height: 26 * scale,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode ? darkGray : white,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text(
                          'Low Blood Sugar',
                          style: TextStyle(
                            // ✅ Dark: white text | Light: black text
                            color: isDarkMode ? white : black,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // "Need Attention" label
                Positioned(
                  bottom: 75 * scale,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.center,
                    child: Center(
                      child: Text(
                        'Need Attention',
                        style: TextStyle(
                          color: white, // always white on purple bg
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // Random Raindrops (unchanged — decorative only)
                Positioned(
                  bottom: 120 * scale,
                  right: 120 * scale,
                  child: Opacity(
                    opacity: 0.35,
                    child: Image.asset(
                      glucoseDrop,
                      width: 10 * scale,
                      height: 12 * scale,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 150 * scale,
                  left: 100 * scale,
                  child: Opacity(
                    opacity: 0.25,
                    child: Image.asset(
                      glucoseDrop,
                      width: 18 * scale,
                      height: 20 * scale,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 95 * scale,
                  left: 40 * scale,
                  child: Opacity(
                    opacity: 0.18,
                    child: Image.asset(
                      glucoseDrop,
                      width: 8 * scale,
                      height: 10 * scale,
                    ),
                  ),
                ),
                Positioned(
                  top: 130 * scale,
                  right: 55 * scale,
                  child: Opacity(
                    opacity: 0.22,
                    child: Image.asset(
                      glucoseDrop,
                      width: 12 * scale,
                      height: 14 * scale,
                    ),
                  ),
                ),
                Positioned(
                  top: 170 * scale,
                  left: 70 * scale,
                  child: Opacity(
                    opacity: 0.15,
                    child: Image.asset(
                      glucoseDrop,
                      width: 7 * scale,
                      height: 9 * scale,
                    ),
                  ),
                ),
                Positioned(
                  top: 210 * scale,
                  right: 95 * scale,
                  child: Opacity(
                    opacity: 0.18,
                    child: Image.asset(
                      glucoseDrop,
                      width: 9 * scale,
                      height: 11 * scale,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 180 * scale,
                  left: 30 * scale,
                  child: Opacity(
                    opacity: 0.12,
                    child: Image.asset(
                      glucoseDrop,
                      width: 6 * scale,
                      height: 8 * scale,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 200 * scale,
                  right: 35 * scale,
                  child: Opacity(
                    opacity: 0.16,
                    child: Image.asset(
                      glucoseDrop,
                      width: 8 * scale,
                      height: 10 * scale,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 145 * scale,
                  left: 145 * scale,
                  child: Opacity(
                    opacity: 0.14,
                    child: Image.asset(
                      glucoseDrop,
                      width: 5 * scale,
                      height: 7 * scale,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 235 * scale,
                  right: 150 * scale,
                  child: Opacity(
                    opacity: 0.18,
                    child: Image.asset(
                      glucoseDrop,
                      width: 11 * scale,
                      height: 13 * scale,
                    ),
                  ),
                ),
                Positioned(
                  top: 115 * scale,
                  right: 140 * scale,
                  child: Opacity(
                    opacity: 0.10,
                    child: Image.asset(
                      glucoseDrop,
                      width: 6 * scale,
                      height: 8 * scale,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BottomEllipseClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.6);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      0,
      size.height * 0.6,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

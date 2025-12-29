import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:snevva/consts/colors.dart';

class Navbar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;

  const Navbar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    final List<IconData> androidIcons = [
      Icons.home,
      Icons.health_and_safety,
      Icons.notifications_active,
      Icons.apps,
    ];
    final List<IconData> iosIcons = [
      Icons.home_outlined,
      Icons.person_2_outlined,
      Icons.notification_important,
      Icons.grid_view,
    ];

    final icons =
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
            ? iosIcons
            : androidIcons;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color:
              isDarkMode
                  ? black
                  : white,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(4, (index) {
            final bool isSelected = selectedIndex == index;

            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () => onTabSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width:
                            isSelected ? screenWidth * 0.13 : screenWidth * 0.1,
                        height:
                            isSelected ? screenWidth * 0.13 : screenWidth * 0.1,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              isSelected ? AppColors.primaryGradient : null,
                        ),
                        child: Icon(
                          icons[index],
                          color: isSelected ? white : AppColors.primaryColor,
                          size: isSelected ? 30 : 26,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          color:
                              isSelected
                                  ? AppColors.primaryColor
                                  : isDarkMode
                                  ? white
                                  : black,
                          fontSize: screenWidth * 0.03,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        child: Text(
                          ["Home", "My Health", "Alerts", "Menu"][index],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

import 'package:flutter_svg/svg.dart';
import '../../Controllers/Hydration/hydration_stat_controller.dart';
import '../../consts/consts.dart';

class FloatingButtonBar extends StatelessWidget {
  const FloatingButtonBar({
    super.key,
    required this.onStatBtnTap,
    required this.onReminderBtnTap,
    required this.onAddBtnLongTap,
    required this.onAddBtnTap,
    this.addWaterValue,
  });

  final VoidCallback onStatBtnTap;
  final VoidCallback onReminderBtnTap;
  final VoidCallback onAddBtnLongTap;
  final VoidCallback onAddBtnTap;
  final int? addWaterValue;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    //   final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
    final controller = Get.find<HydrationStatController>();

    return SafeArea(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: onStatBtnTap,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(statIcon),
                            const SizedBox(height: 4),
                            const AutoSizeText(
                              'Statistics',
                              maxLines: 1,
                              minFontSize: 8,
                              maxFontSize: 14,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onReminderBtnTap,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(gearIcon2),
                            const SizedBox(height: 4),
                            const AutoSizeText(
                              'Reminder',
                              maxLines: 1,
                              minFontSize: 8,
                              maxFontSize: 14,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Center white circle container
          Positioned(
            top: -20,
            bottom: -20,
            child: InkWell(
              onLongPress: onAddBtnLongTap,
              onTap: onAddBtnTap,
              borderRadius: BorderRadius.circular(50),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Container(
                  width: 98,
                  decoration: BoxDecoration(
                    color: isDarkMode ? black : white,
                    borderRadius: BorderRadius.circular(90), // circle
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        spreadRadius: 0.2,
                        blurRadius: 30,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, size: 36),
                      const SizedBox(height: 4),
                      if (addWaterValue != null)
                        Text(
                          "$addWaterValue ml",
                          style: TextStyle(
                            color: isDarkMode ? white : black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

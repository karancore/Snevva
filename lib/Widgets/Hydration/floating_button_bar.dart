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
    this.isMood = false,
  });

  final VoidCallback onStatBtnTap;
  final VoidCallback onReminderBtnTap;
  final VoidCallback onAddBtnLongTap;
  final VoidCallback onAddBtnTap;
  final int? addWaterValue;
  final bool? isMood;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
              // ✅ Fix 1: removed vertical: 8 — it was eating 16px from the 70px bar
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    // ── Statistics button ──────────────────────────────────
                    InkWell(
                      onTap: onStatBtnTap,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        // ✅ Fix 2: removed vertical: 4 — was eating another 8px
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,     // ✅ Fix 3: min not max
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ✅ Fix 4: explicit size — unsized SVG defaulted to ~32px
                            SvgPicture.asset(
                              statIcon,
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(height: 4),
                            const AutoSizeText(
                              'Statistics',
                              maxLines: 1,
                              minFontSize: 8,
                              maxFontSize: 12,   // ✅ Fix 5: 14 → 12
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Reminder / Mood button ─────────────────────────────
                    InkWell(
                      onTap: onReminderBtnTap,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        // ✅ Fix 6: removed vertical: 4
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: (isMood! == true)
                            ? Column(
                          mainAxisSize: MainAxisSize.min,   // ✅ Fix 7
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              smileyIcon,
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(height: 4),
                            const AutoSizeText(
                              'Mood',
                              maxLines: 1,
                              minFontSize: 8,
                              maxFontSize: 12,   // ✅
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        )
                            : Column(
                          mainAxisSize: MainAxisSize.min,   // ✅ Fix 8
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ✅ Fix 9: explicit size on gearIcon2
                            SvgPicture.asset(
                              gearIcon2,
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(height: 4),
                            const AutoSizeText(
                              'Reminder',
                              maxLines: 1,
                              minFontSize: 8,
                              maxFontSize: 12,   // ✅
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

          // ── Center white circle button ─────────────────────────────────────
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
                    borderRadius: BorderRadius.circular(90),
                    boxShadow: const [
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
                          "${controller.addWaterValue} ml",
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
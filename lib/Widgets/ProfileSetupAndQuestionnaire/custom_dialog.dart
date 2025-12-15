import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/views/ReportScan/scan_report_screen.dart';

import '../../consts/colors.dart';

class MyDialogWidget extends StatelessWidget {
  final String title;
  final String message;

  const MyDialogWidget({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDarkMode ? darkGray : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/Icons/Questionnaire_Icons/report.svg',
              height: 200,
            ),
            SizedBox(height: 20),
            AutoSizeText(
              minFontSize: 10,
              maxFontSize: 20,
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            AutoSizeText(
              message,
              minFontSize: 10,
              maxFontSize: 18,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: 50,
                  width: width * 0.25,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(color: AppColors.primaryColor, width: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                    ),
                    onPressed: () {
                      Get.back();
                      Get.off(HomeWrapper());
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                CustomOutlinedButton(
                  width: width * 0.25,
                  backgroundColor: AppColors.primaryColor,
                  isDarkMode: isDarkMode,
                  buttonName: 'Scan',
                  onTap: () {
                    Get.back();
                    Get.offAll(ScanReportScreen());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

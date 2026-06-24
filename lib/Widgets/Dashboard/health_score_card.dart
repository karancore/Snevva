import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:snevva/consts/colors.dart';

import '../../Controllers/dashboard/health_score_controller.dart';
import 'health_summary_dialog.dart';

class HealthScoreCard extends StatelessWidget {
  final bool isDarkMode;

  const HealthScoreCard({Key? key, required this.isDarkMode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Inject the controller
    final controller = Get.put(HealthScoreController());

    return GestureDetector(
      onTap: () {
        HealthSummaryDialogHelper.show(context, isDarkMode);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isDarkMode ? darkGray : white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDarkMode ? Colors.white12 : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Obx(() {
          Color categoryColor = _getCategoryColor(
            controller.healthCategory.value,
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Side - Score
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Health Score',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 80,
                          width: 80,
                          child: CircularProgressIndicator(
                            value: controller.overallHealthScore.value / 100.0,
                            strokeWidth: 8,
                            backgroundColor: categoryColor.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              categoryColor,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${controller.ratingOutOf10.value}",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              "/ 10",
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDarkMode
                                        ? Colors.white54
                                        : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                height: 80,
                width: 1,
                color:
                    isDarkMode ? Colors.white24 : Colors.grey.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
              ),

              // Right Side - Quote & Category
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        controller.healthCategory.value.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.healthQuote.value,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Excellent':
        return Colors.green;
      case 'Good':
        return Colors.blue;
      case 'Average':
        return Colors.orange;
      case 'Needs Attention':
        return Colors.deepOrangeAccent;
      case 'High Risk':
        return Colors.red;
      default:
        return AppColors.primaryColor;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';

import '../../Controllers/Reminder/reminder_controller.dart';
import '../../consts/colors.dart';
import '../../models/hive_models/reminder_payload_model.dart';

class CollapsedHeader extends StatelessWidget {
  final ReminderPayloadModel reminder;
  final String category;
  final bool isDarkMode;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CollapsedHeader({
    required this.reminder,
    required this.category,
    required this.isDarkMode,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          Get.find<ReminderController>(
            tag: 'reminder',
          ).getCategoryIcon(category),
          width: 24,
          height: 24,
        ),
        const SizedBox(width: 10),

        Expanded(
          child: Text(
            reminder.title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 18,
              color: isDarkMode ? white : black,
            ),
          ),
        ),

        IconButton(
          onPressed: onToggle,
          icon: Icon(
            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: const Color(0xff878787),
          ),
        ),
      ],
    );
  }
}

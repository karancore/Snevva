import 'package:alarm/alarm.dart';

import '../../consts/consts.dart';

/// Full-screen "reminder ringing" UI shown on iOS in place of the system
/// notification banner, since iOS won't reliably surface a full-screen
/// alarm-style notification while the reminder fires.
class ReminderNotificationsScreen extends StatelessWidget {
  final AlarmSettings alarmSettings;
  const ReminderNotificationsScreen({super.key, required this.alarmSettings});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? black : white;
    final textColor = isDarkMode ? white : black;
    final subTextColor = isDarkMode ? grey : mediumGrey;

    final title = alarmSettings.notificationSettings.title;
    final body = alarmSettings.notificationSettings.body;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: white,
                    size: 48,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      await Alarm.stop(alarmSettings.id);
                      if (Get.key.currentState?.canPop() ?? false) {
                        Get.back();
                      }
                    },
                    child: const Text(
                      'Stop',
                      style: TextStyle(
                        color: white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
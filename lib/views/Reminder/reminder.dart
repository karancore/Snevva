import 'package:flutter_svg/flutter_svg.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Reminder/add_reminder.dart';
import 'package:snevva/views/Reminder/all_reminder.dart';

class Reminder extends StatefulWidget {
  const Reminder({super.key});

  @override
  State<Reminder> createState() => _ReminderState();
}

class _ReminderState extends State<Reminder> {
  final ReminderController controller = Get.put(ReminderController());

  @override
  void initState() {
    super.initState();
    // Load both API reminders and local alarm lists
    _loadData();
  }

  Future<void> _loadData() async {
    await controller.getReminders();
    await controller.loadAllReminderLists();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        appbarText: "Reminder",
        showCloseButton: false,
        showDrawerIcon: false,
      ),
      body: Obx(() {
        // Show loading indicator
        if (controller.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primaryColor),
          );
        }

        // Show empty state
        if (controller.reminders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.alarm_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No reminders yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap "+ Add Reminder" to create one',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Show reminder list
        return RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primaryColor,
          child: ListView.builder(
            itemCount: controller.reminders.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final reminder = controller.reminders[index];
              final category = reminder['Category'] ?? 'Unknown';

              return Card(
                color: isDarkMode ? darkGray : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Image.asset(
                            controller.getCategoryIcon(category),
                            width: 24,
                            height: 24,
                            //color: controller.getCategoryColor(category),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              reminder['Title'] ?? 'No title',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 18,
                              ),
                            ),
                          ),

                          IconButton(
                            icon: Icon(
                              Icons.keyboard_arrow_down_outlined,
                              size: 24,
                              color: mediumGrey,
                            ),
                            onPressed: () async {
                              final result = await Get.to(
                                () => AddReminder(reminder: reminder),
                              );
                              // Reload data when returning from edit
                              if (result == true) {
                                await _loadData();
                              }
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Category-specific content
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildCategoryContent(reminder, category),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CustomOutlinedButton(
              width: width / 2.35,
              isDarkMode: isDarkMode,
              buttonName: "History",
              onTap: () {
                Get.to(() => AllReminder());
              },
            ),
            CustomOutlinedButton(
              width: width / 2.35,
              isDarkMode: isDarkMode,
              buttonName: "+ Add Reminder",
              onTap: () async {
                final result = await Get.to(() => AddReminder());
                // Always reload data when returning, regardless of result
                // The controller already handles the update, but this ensures consistency
                if (result == true) {
                  await _loadData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> reminder) {
    Get.defaultDialog(
      title: "Delete Reminder",
      middleText: "Are you sure you want to delete this reminder?",
      textConfirm: "Delete",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primaryColor,
      onConfirm: () async {
        await controller.deleteReminder(reminder);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildCategoryContent(Map<String, dynamic> reminder, String category) {
    switch (category) {
      case 'Medicine':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reminder['MedicineName'] != null)
              Text(
                (reminder['MedicineName'] as List).join(', '),
                style: TextStyle(fontSize: 12, color: Color(0xff878787)),
              ),

            Text(
              "Notes: ${reminder['Description'] ?? 'N/A'}",
              style: TextStyle(fontSize: 12, color: Color(0xff878787)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Image.asset(
                  clockRemIcon,
                  color: Color(0xff878787),
                  width: 12,
                  height: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  controller.formatReminderTime(reminder['RemindTime'] ?? []),
                  style: TextStyle(fontSize: 12, color: Color(0xff878787)),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: SvgPicture.asset(
                    pen,
                    width: 18,
                    height: 18,
                    color: Color(0xff878787),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _showDeleteConfirmation(reminder),
                  child: Icon(Icons.delete, size: 18, color: Color(0xff878787)),
                ),
              ],
            ),
          ],
        );

      case 'Water':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reminder['RemindFrequencyHour'] != null &&
                reminder['RemindFrequencyHour'] > 0)
              Text(
                "Frequency: Every ${reminder['RemindFrequencyHour']} hours",
                style: TextStyle(fontSize: 12, color: Color(0xff878787)),
              ),
            if (reminder['RemindFrequencyCount'] != null &&
                reminder['RemindFrequencyCount'] > 0)
              Text(
                "Times per day: ${reminder['RemindFrequencyCount']}",
                style: TextStyle(fontSize: 12, color: Color(0xff878787)),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => _showDeleteConfirmation(reminder),
                  child: Icon(Icons.delete, size: 18, color: Color(0xff878787)),
                ),
              ],
            ),
          ],
        );

      case 'Meal':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.asset(
              clockRemIcon,
              color: Color(0xff878787),
              width: 12,
              height: 12,
            ),
            const SizedBox(width: 4),

            Text(
              controller.formatReminderTime(reminder['RemindTime'] ?? []),
              style: TextStyle(fontSize: 12, color: Color(0xff878787)),
            ),
            Spacer(),
            GestureDetector(
              onTap: () {},
              child: SvgPicture.asset(
                pen,
                width: 18,
                height: 18,
                color: Color(0xff878787),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => _showDeleteConfirmation(reminder),
              child: Icon(Icons.delete, size: 18, color: Color(0xff878787)),
            ),

            const SizedBox(width: 4),
          ],
        );

      case 'Event':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Image.asset(
                  clockRemIcon,
                  color: Color(0xff878787),
                  width: 12,
                  height: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  controller.formatReminderTime(reminder['RemindTime'] ?? []),
                  style: TextStyle(fontSize: 12, color: Color(0xff878787)),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: SvgPicture.asset(
                    pen,
                    width: 18,
                    height: 18,
                    color: Color(0xff878787),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _showDeleteConfirmation(reminder),
                  child: Icon(Icons.delete, size: 18, color: Color(0xff878787)),
                ),
              ],
            ),
            Text(
              "Notes: ${reminder['Description'] ?? 'N/A'}",
              style: TextStyle(fontSize: 12, color: Color(0xff878787)),
            ),
          ],
        );

      default:
        return Text("Unknown category");
    }
  }
}

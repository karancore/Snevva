import 'package:flutter_svg/flutter_svg.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/common/animted_reminder_bar.dart';
import 'package:snevva/common/loader.dart';
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
  bool showReminderBar = true;

  @override
  void initState() {
    super.initState();
    // Load both API reminders and local alarm lists
    _loadData();
    controller.loadAllReminderLists();
  }

  Future<void> _loadData() async {
    await controller.getReminders(context);
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
        onClose: () {
          Navigator.of(context).pop();
        },
      ),
      body: Obx(() {
        // Show loading indicator
        // if (controller.isLoading.value) {
        //   return Loader();
        // }

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
        return Column(
          children: [
            if (showReminderBar) AnimatedReminderBar(show: false),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primaryColor,
                child: ListView(
                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  children: [
                    ...controller.reminders.map((reminder) {
                      final category = reminder['Category'] ?? 'Unknown';
                      return Card(
                        color: isDarkMode ? darkGray : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 12,
                            top: 8,
                            right: 8,
                            bottom: 8,
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
                                      if (result == true) {
                                        await _loadData();
                                        // setState(() {
                                        //   showReminderBar = true;
                                        // });
                                      }
                                    },
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildCategoryContent(
                                  reminder,
                                  category,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: CustomOutlinedButton(
          width: double.infinity,
          isDarkMode: isDarkMode,
          buttonName: "+ Add Reminder",
          backgroundColor: AppColors.primaryColor,
          onTap: () async {
            final result = await Get.to(() => AddReminder());
            // Always reload data when returning, regardless of result
            // The controller already handles the update, but this ensures consistency
            if (result == true) {
              await _loadData();
            }
          },
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
        setState(() {});
      },
    );
  }

  Widget _buildCategoryContent(Map<String, dynamic> reminder, String category) {
    print(reminder.toString());
    print(reminder);
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
                  onTap: () {
                    print("$reminder tapped");
                    Get.to(AddReminder(reminder: reminder));
                  },
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
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14.0),
                    child: Icon(
                      Icons.delete,
                      size: 18,
                      color: Color(0xff878787),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'Water':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (reminder['RemindFrequencyCount'] != null &&
                    reminder['RemindFrequencyCount'] > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 2.0),
                    child: Text(
                      "Times per day: ${reminder['RemindFrequencyCount']}",
                      style: TextStyle(fontSize: 12, color: Color(0xff878787)),
                    ),
                  ),
                Spacer(flex: 30),
                GestureDetector(
                  onTap: () {
                    print("$reminder tapped");
                    Get.to(AddReminder(reminder: reminder));
                  },
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
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14.0),
                    child: Icon(
                      Icons.delete,
                      size: 18,
                      color: Color(0xff878787),
                    ),
                  ),
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
              onTap: () {
                print("$reminder tapped");
                Get.to(AddReminder(reminder: reminder));
              },
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
              child: Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: Icon(Icons.delete, size: 18, color: Color(0xff878787)),
              ),
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
                  onTap: () {
                    print("$reminder tapped");
                    Get.to(AddReminder(reminder: reminder));
                  },
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
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14.0),
                    child: Icon(
                      Icons.delete,
                      size: 18,
                      color: Color(0xff878787),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              "Title: ${reminder['Title'] ?? 'N/A'}",
              style: TextStyle(fontSize: 12, color: Color(0xff878787)),
            ),
            if (controller.notesController.text.isEmpty)
              SizedBox.shrink()
            else
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

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
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(appbarText: "Reminder", showCloseButton: false, showDrawerIcon: false,),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (controller.reminders.isEmpty) {
          return Center(child: Text("No reminders found."));
        }

        return ListView.builder(
          itemCount: controller.reminders.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final reminder = controller.reminders[index];
            final category = reminder['Category'] ?? 'Unknown';

            Widget icon = Icon(
              Icons.notifications,
              color: AppColors.primaryColor,
            );
            if (category == 'Medicine')
              icon = Icon(Icons.medication, color: AppColors.primaryColor);
            if (category == 'Water')
              icon = Icon(Icons.local_drink, color: AppColors.primaryColor);
            if (category == 'Meal')
              icon = Icon(Icons.restaurant, color: AppColors.primaryColor);
            if (category == 'Event')
              icon = Icon(Icons.event, color: AppColors.primaryColor);

            return Card(
              color: isDarkMode ? darkGray : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        icon,
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reminder['Title'] ?? 'No title',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Icon(Icons.expand_more),
                        IconButton(
                          icon: Icon(Icons.edit, size: 20, color: mediumGrey),
                          onPressed: () async {
                            // Pass the current reminder data to the AddReminder screen
                            Get.to(() => AddReminder(reminder: reminder));
                            // final result = await Get.to(() => AddReminder(reminder: reminder));
                            //   if (result == true) {
                            //     controller.getReminders(); // Refresh list after editing
                            //   }
                          },
                        ),
                      ],
                    ),
                    SizedBox(height:1),
                    // Category-based card rendering
                    if (category == 'Medicine') ...[
                      if (reminder['MedicineName'] != null)
                        Text(
                          "Medicines: ${(reminder['MedicineName'] as List).join(', ')}",
                        ),
                      Text(
                        "Reminder Times: ${(reminder['RemindTime'] as List).join(', ')}",
                      ),
                      Text("Notes: ${reminder['Description'] ?? 'N/A'}"),
                    ] else if (category == 'Water') ...[
                      Text(
                        "Frequency (Every X hours): ${reminder['RemindFrequencyHour'] ?? 0}",
                      ),
                      Text(
                        "Times per day: ${reminder['RemindFrequencyCount'] ?? 0}",
                      ),
                    ] else if (category == 'Meal') ...[
                      Text(
                        "Meal Time: ${(reminder['RemindTime'] as List).join(', ')}",
                      ),
                    ] else if (category == 'Event') ...[
                      Text(
                        "Event Date: ${reminder['StartDay']}/${reminder['StartMonth']}/${reminder['StartYear']}",
                      ),
                      Text(
                        "Time: ${(reminder['RemindTime'] as List).join(', ')}",
                      ),
                      Text("Notes: ${reminder['Description'] ?? 'N/A'}"),
                    ] else ...[
                      Text("Unknown category"),
                    ],

                    // Bottom row (edit/delete icons)
                    SizedBox(height: 1),
                    // Row(
                    //   children: [
                    //     Icon(Icons.edit, size: 20, color: mediumGrey),
                    //     SizedBox(width: 12),
                    //     Icon(Icons.delete, size: 20, color: mediumGrey),
                    //   ],
                    // ),
                  ],
                ),
              ),
            );
          },
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
                if (result == true) {
                  controller.getReminders(); // Refresh list after adding
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

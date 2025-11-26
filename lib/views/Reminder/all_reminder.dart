import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // For date formatting

class AllReminder extends StatelessWidget {
  const AllReminder({super.key});

  @override
  Widget build(BuildContext context) {
    // Getting the ReminderController instance
    final ReminderController controller = Get.put(ReminderController());

    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;

    // UI related variables for date selection
    List<String> dates = [];
    List<String> days = [];
    Map<String, List<Map<String, dynamic>>> groupedReminders = {};

    int selectedDateIndex = 0;

    // Group reminders by date
    for (var reminder in controller.reminders) {
      // Skip reminders with invalid dates
      if (reminder['StartDay'] == 0 ||
          reminder['StartMonth'] == 0 ||
          reminder['StartYear'] == 0) {
        continue;
      }

      final reminderDate = DateTime(
        reminder['StartYear'],
        reminder['StartMonth'],
        reminder['StartDay'],
      );
      final formattedDate = DateFormat('dd MMM').format(reminderDate);
      final dayOfWeek = DateFormat(
        'EEE',
      ).format(reminderDate); // Day (e.g., Mon, Tue)

      // Add date and day to the list if not already added
      if (!dates.contains(formattedDate)) {
        dates.add(formattedDate);
        days.add(dayOfWeek);
      }

      // Group reminders by formatted date
      if (!groupedReminders.containsKey(formattedDate)) {
        groupedReminders[formattedDate] = [];
      }

      groupedReminders[formattedDate]!.add(reminder);
    }

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "All Reminder"),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Horizontal Date Selector
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: dates.length,
                itemBuilder: (context, index) {
                  final isSelected = selectedDateIndex == index;
                  return GestureDetector(
                    onTap: () {
                      selectedDateIndex =
                          index; // Update the selected date index
                      controller
                          .getReminders(); // Refetch reminders based on selected date
                    },
                    child: Container(
                      width: 70,
                      margin: EdgeInsets.only(right: 12),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.primaryColor
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dates[index],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            days[index],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),

            // Display today's reminder list
            if (groupedReminders.isNotEmpty) ...[
              Text(
                "Today's Record",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 10),
              // Get reminders for the selected date
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final selectedDate = dates[selectedDateIndex];
                  final remindersForSelectedDate =
                      groupedReminders[selectedDate] ?? [];

                  return ListView.builder(
                    itemCount: remindersForSelectedDate.length,
                    itemBuilder: (context, index) {
                      final reminder = remindersForSelectedDate[index];

                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Time
                              Text(
                                reminder['RemindTime'].join(
                                  ", ",
                                ), // Display multiple times if available
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 16),

                              // Reminder Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reminder['Title'] ?? 'No Title',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      reminder['Description'] ??
                                          'No Description',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),

                              // Checkbox
                              // Checkbox(
                              //   value: false, // Handle checkbox state here
                              //   onChanged: (value) {
                              //     // Handle checkbox state change
                              //   },
                              //   activeColor: AppColors.primaryColor,
                              // ),
                            ],
                          ),
                          Divider(),
                        ],
                      );
                    },
                  );
                }),
              ),
            ] else ...[
              // No reminders found
              Center(child: Text("No reminders for today.")),
            ],
          ],
        ),
      ),
    );
  }
}

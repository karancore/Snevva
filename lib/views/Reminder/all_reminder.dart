import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class AllReminder extends StatelessWidget {
  const AllReminder({super.key});

  @override
  Widget build(BuildContext context) {
    final ReminderController controller = Get.put(ReminderController());

    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;

    // Observable for selected date index
    final selectedDateIndex = 0.obs;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "All Reminder"),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Obx(() {
          // Group reminders by date
          List<String> dates = [];
          List<String> days = [];
          Map<String, List<Map<String, dynamic>>> groupedReminders = {};

          for (var reminder in controller.reminders) {
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
            final dayOfWeek = DateFormat('EEE').format(reminderDate);

            if (!dates.contains(formattedDate)) {
              dates.add(formattedDate);
              days.add(dayOfWeek);
            }

            if (!groupedReminders.containsKey(formattedDate)) {
              groupedReminders[formattedDate] = [];
            }

            groupedReminders[formattedDate]!.add(reminder);
          }

          return Column(
            children: [
              // Horizontal Date Selector
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: dates.length,
                  itemBuilder: (context, index) {
                    return Obx(() {
                      final isSelected = selectedDateIndex.value == index;
                      return GestureDetector(
                        onTap: () {
                          selectedDateIndex.value = index;
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
                                  color:
                                      isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                days[index],
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    });
                  },
                ),
              ),
              SizedBox(height: 20),

              // Display reminders list
              if (groupedReminders.isNotEmpty) ...[
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (dates.isEmpty) {
                      return Center(child: Text("No reminders available."));
                    }

                    final selectedDate = dates[selectedDateIndex.value];
                    final remindersForSelectedDate =
                        groupedReminders[selectedDate] ?? [];

                    if (remindersForSelectedDate.isEmpty) {
                      return Center(child: Text("No reminders for this date."));
                    }

                    return ListView.builder(
                      itemCount: remindersForSelectedDate.length,
                      itemBuilder: (context, index) {
                        final reminder = remindersForSelectedDate[index];

                        // Safe parsing of date and time
                        String time = '';
                        String title =
                            (reminder['Title'] == null ||
                                    reminder['Title'].toString().trim().isEmpty)
                                ? 'No Title'
                                : reminder['Description'].toString();
                        String description =
                            (reminder['Description'] == null ||
                                    reminder['Description']
                                        .toString()
                                        .trim()
                                        .isEmpty)
                                ? 'No Description'
                                : reminder['Description'].toString();

                        try {
                          // Check if RemindTime exists and has data
                          if (reminder['RemindTime'] != null &&
                              reminder['RemindTime'] is List &&
                              (reminder['RemindTime'] as List).isNotEmpty) {
                            final remindTimeList =
                                reminder['RemindTime'] as List;
                            final rawTime =
                                remindTimeList[index < remindTimeList.length
                                    ? index
                                    : 0];

                            // Try to parse if it's a valid DateTime string
                            if (rawTime != null &&
                                rawTime.toString().isNotEmpty) {
                              try {
                                final DateTime dt = DateTime.parse(
                                  rawTime.toString(),
                                );
                                time = DateFormat('hh:mm a').format(dt);
                              } catch (e) {
                                // If it's already in time format like "09:04 PM"
                                time = rawTime.toString();
                                // Use the start date for the date part
                                final reminderDate = DateTime(
                                  reminder['StartYear'] ?? 0,
                                  reminder['StartMonth'] ?? 0,
                                  reminder['StartDay'] ?? 0,
                                );
                              }
                            }
                          }
                        } catch (e) {
                          print('Error parsing reminder time: $e');
                          time = 'N/A';
                        }

                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  time,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 14,
                                          color: Color(0xff2E2E2E),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xff878787),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                Center(child: Text("No reminders for today.")),
              ],
            ],
          );
        }),
      ),
    );
  }
}

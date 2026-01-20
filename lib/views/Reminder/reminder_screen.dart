import 'package:flutter_svg/flutter_svg.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/common/loader.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Reminder/add_reminder_screen.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final ReminderController controller = Get.put(ReminderController());
  bool showReminderBar = true;

  @override
  void initState() {
    super.initState();
    // Load both API reminders and local alarm lists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
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
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(
        appbarText: "Reminder",
        showCloseButton: false,
        onClose: () {
          Navigator.of(context).pop();
        },
      ),
      body: Obx(() {
        //Show loading indicator
        if (controller.isLoading.value) {
          return Loader();
        }

        // Show empty state
        if (controller.reminders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(noReminders, scale: 2),
                SizedBox(height: 8),
                Text(
                  'Tap "+ Add Reminder" to create one',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Show reminder list
        return Column(
          children: [
            //if (showReminderBar) AnimatedReminderBar(show: true ),
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
                                      reminder['Title'] != null &&
                                              reminder['Title']
                                                  .toString()
                                                  .isNotEmpty
                                          ? reminder['Title']
                                          : 'No Title',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 18,
                                        color:
                                            reminder['Title'] != null &&
                                                    reminder['Title']
                                                        .toString()
                                                        .isNotEmpty
                                                ? (Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.dark
                                                    ? white
                                                    : black)
                                                : grey,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_outlined,
                                      size: 24,
                                      color: mediumGrey,
                                    ),
                                    onPressed: () {},
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: CustomOutlinedButton(
            width: double.infinity,
            isDarkMode: isDarkMode,
            buttonName: "+ Add Reminder",
            backgroundColor: AppColors.primaryColor,
            onTap: () async {
              final result = await Get.to(AddReminderScreen());
              // Always reload data when returning, regardless of result
              // The controller already handles the update, but this ensures consistency
              if (result == true) {
                await _loadData();
              }
              if (result == "updated") {
                CustomSnackbar().showReminderBar(context);
              }
            },
          ),
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
    final int frequencyHour =
        int.tryParse(reminder['RemindFrequencyHour']?.toString() ?? '0') ?? 0;
    final int freqHour =
        reminder['RemindFrequencyHour'] is int
            ? reminder['RemindFrequencyHour']
            : int.tryParse(
                  reminder['RemindFrequencyHour']?.toString() ?? '0',
                ) ??
                0;

    logLong(" Reminder Screen ", reminder.toString());

    switch (category) {
      case 'Medicine':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reminder['MedicineName'] != null)
              Text(
                'Medicine : ${buildMedicineText(reminder['MedicineName'])}',
                style: TextStyle(fontSize: 12, color: Color(0xff878787)),
              ),
            if (reminder['Description'] != null &&
                reminder['Description'].toString().isNotEmpty)
              Text(
                "Note : ${reminder['Description']}",
                style: TextStyle(fontSize: 12, color: Color(0xff878787)),
              )
            else
              SizedBox.shrink(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  clockRemIcon,
                  color: Color(0xff878787),
                  width: 12,
                  height: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  formatReminderTime(reminder['RemindTime'] ?? []),
                  style: TextStyle(fontSize: 12, color: Color(0xff878787)),
                ),
                Spacer(),
                InkWell(
                  onTap: () {
                    Get.to(AddReminderScreen(reminder: reminder));
                  },
                  child: SvgPicture.asset(
                    pen,
                    width: 18,
                    height: 18,
                    color: Color(0xff878787),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => _showDeleteConfirmation(reminder),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14.0),
                    child: Icon(
                      Icons.delete_forever_rounded,
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
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reminder['RemindFrequencyCount'] != null &&
                    reminder['RemindFrequencyCount'] > 0)
                  Text(
                    "Times per day: ${reminder['RemindFrequencyCount']}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Color(0xff878787)),
                  ),

                if (freqHour > 0)
                  Text(
                    "Reminder will ring after every $frequencyHour ${pluralizeHour(frequencyHour)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Color(0xff878787)),
                  ),
              ],
            ),
            const Spacer(),

            InkWell(
              onTap: () => Get.to(AddReminderScreen(reminder: reminder)),
              child: SvgPicture.asset(
                pen,
                width: 18,
                height: 18,
                color: Color(0xff878787),
              ),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: () => _showDeleteConfirmation(reminder),
              child: Icon(
                Icons.delete_forever_rounded,
                size: 18,
                color: Color(0xff878787),
              ),

            ),
            const SizedBox(width: 14),
          ],
        );

      case 'Meal':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SvgPicture.asset(
              clockRemIcon,
              color: Color(0xff878787),
              width: 12,
              height: 12,
            ),
            const SizedBox(width: 4),

            Text(
              formatReminderTime(reminder['RemindTime'] ?? []),
              style: TextStyle(fontSize: 12, color: Color(0xff878787)),
            ),
            Spacer(),
            InkWell(
              onTap: () {
                Get.to(AddReminderScreen(reminder: reminder));
              },
              child: SvgPicture.asset(
                pen,
                width: 18,
                height: 18,
                color: Color(0xff878787),
              ),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: () => _showDeleteConfirmation(reminder),
              child: Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: Icon(
                  Icons.delete_forever_rounded,
                  size: 18,
                  color: Color(0xff878787),
                ),
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
                SvgPicture.asset(
                  clockRemIcon,
                  color: Color(0xff878787),
                  width: 12,
                  height: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  formatReminderTime(reminder['RemindTime'] ?? []),
                  style: TextStyle(fontSize: 12, color: Color(0xff878787)),
                ),
                Spacer(),
                InkWell(
                  onTap: () {
                    Get.to(AddReminderScreen(reminder: reminder));
                  },
                  child: SvgPicture.asset(
                    pen,
                    width: 18,
                    height: 18,
                    color: Color(0xff878787),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => _showDeleteConfirmation(reminder),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14.0),
                    child: Icon(
                      Icons.delete_forever_rounded,
                      size: 18,
                      color: Color(0xff878787),
                    ),
                  ),
                ),
              ],
            ),
            // Text(
            //   "Title: ${reminder['Title'] ?? 'N/A'}",
            //   style: TextStyle(fontSize: 12, color: Color(0xff878787)),
            // ),
            // if (controller.notesController.text.isEmpty)
            //   SizedBox.shrink()
            // else
            //   Text(
            //     "Notes: ${reminder['Description'] ?? 'N/A'}",
            //     style: TextStyle(fontSize: 12, color: Color(0xff878787)),
            //   ),
          ],
        );

      default:
        return Text("Unknown category");
    }
  }
}

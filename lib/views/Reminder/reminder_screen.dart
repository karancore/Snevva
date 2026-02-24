import 'package:flutter_svg/flutter_svg.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/common/loader.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/views/Reminder/add_reminder_screen.dart';
import 'package:snevva/views/Reminder/reminder_details_card.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';
import 'collapsed_header.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen>
    with SingleTickerProviderStateMixin {
  final ReminderController controller = Get.find<ReminderController>(
    tag: 'reminder',
  );
  bool showReminderBar = true;
  int? expandedIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
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
                  "No reminders… for now!\nAdd one and I’ll make sure you don’t forget.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Show reminder list
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primaryColor,
                child: ListView(
                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  children: [
                    ...controller.reminders.asMap().entries.map((entry) {
                      final index = entry.key;
                      final reminder = entry.value;

                      final category = reminder.category;
                      return Container(
                        margin: EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: isDarkMode ? darkGray : white,
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.4),
                              spreadRadius: 2,
                              blurRadius: 6,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 12,
                            top: 8,
                            right: 8,
                            bottom: 8,
                          ),
                          child: AnimatedCrossFade(
                            duration: const Duration(milliseconds: 250),
                            firstCurve: Curves.easeIn,
                            secondCurve: Curves.easeOut,
                            crossFadeState:
                                expandedIndex == index
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,

                            firstChild: Column(
                              children: [
                                CollapsedHeader(
                                  reminder: reminder,
                                  category: category,
                                  isDarkMode: isDarkMode,
                                  onToggle: () {
                                    setState(() {
                                      expandedIndex =
                                          expandedIndex == index ? null : index;
                                    });
                                  },
                                  onEdit:
                                      () => Get.to(
                                        AddReminderScreen(reminder: reminder),
                                      ),
                                  onDelete:
                                      () => _showDeleteConfirmation(reminder),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildCategoryContent(
                                    reminder,
                                    category,
                                  ),
                                ),
                              ],
                            ),

                            secondChild: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CollapsedHeader(
                                  reminder: reminder,
                                  category: category,
                                  isDarkMode: isDarkMode,
                                  isExpanded: true,
                                  onToggle: () {
                                    setState(() {
                                      expandedIndex =
                                          expandedIndex == index ? null : index;
                                    });
                                  },
                                  onEdit:
                                      () => Get.to(
                                        AddReminderScreen(reminder: reminder),
                                      ),
                                  onDelete:
                                      () => _showDeleteConfirmation(reminder),
                                ),
                                const SizedBox(height: 6),
                                ReminderDetailsCard(
                                  reminder: reminder,
                                  index: index,
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
              // Get.snackbar(
              //   "WIP",
              //   "Reminder inundation is work in progress.",
              //   snackPosition: SnackPosition.TOP,
              //   colorText: white,
              //   backgroundColor: AppColors.primaryColor,
              //   duration: const Duration(seconds: 3),
              // );
              // return;
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

  void _showDeleteConfirmation(ReminderPayloadModel reminder) {
    Get.defaultDialog(
      title: "Delete Reminder",
      middleText: "Are you sure you want to delete this reminder?",
      textConfirm: "Delete",
      textCancel: "Cancel",
      confirmTextColor: white,
      buttonColor: AppColors.primaryColor,
      onConfirm: () async {
        await controller.deleteReminder(reminder);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildCategoryContent(ReminderPayloadModel reminder, String category) {
    final int frequencyHour =
        int.tryParse(
          reminder.customReminder?.everyXHours?.hours.toString() ?? '0',
        ) ??
        0;
    final int timesPerDay =
        int.tryParse(
          reminder.customReminder?.timesPerDay?.count?.toString() ?? '1',
        ) ??
        1;

    switch (category) {
      case 'medicine':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reminder.medicineName != null)
              // Text(
              //   'Medicine : {buildMedicineText(reminder['MedicineName'])}',
              //   style: TextStyle(fontSize: 12, color: Color(0xff878787)),
              // ),
              if (reminder.notes != null &&
                  reminder.notes.toString().isNotEmpty)
                Text(
                  "Note : ${reminder.notes}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff878787),
                  ),
                )
              else
                const SizedBox.shrink(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  clockRemIcon,
                  color: const Color(0xff878787),
                  width: 12,
                  height: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  formatReminderTime(reminder.customReminder.timesPerDay!.list),
                  style: TextStyle(fontSize: 12, color: Color(0xff878787)),
                ),
                Spacer(),
                InkWell(
                  onTap: () {
                    // Get.snackbar(
                    //   "WIP",
                    //   "Reminder inundation is work in progress.",
                    //   snackPosition: SnackPosition.BOTTOM,
                    //   colorText: white,
                    //   backgroundColor: AppColors.primaryColor,
                    //   duration: const Duration(seconds: 3),
                    // );
                    // return;
                    Get.to(AddReminderScreen(reminder: reminder));
                  },
                  child: SvgPicture.asset(
                    pen,
                    width: 18,
                    height: 18,
                    color: const Color(0xff878787),
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

      case 'water':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reminder.customReminder.timesPerDay?.count != null)
                  Text(
                    "Times per day: $timesPerDay",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff878787),
                    ),
                  ),
                if (frequencyHour >= 1)
                  Text(
                    "Reminder will ring after every $frequencyHour ${pluralizeHour(frequencyHour)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff878787),
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            const Spacer(),

            InkWell(
              onTap: () {
                // Get.snackbar(
                //   "WIP",
                //   "Reminder inundation is work in progress.",
                //   snackPosition: SnackPosition.BOTTOM,
                //   colorText: white,
                //   backgroundColor: AppColors.primaryColor,
                //   duration: const Duration(seconds: 3),
                // );
                // return;
                Get.to(AddReminderScreen(reminder: reminder));
              },
              child: SvgPicture.asset(
                pen,
                width: 18,
                height: 18,
                color: const Color(0xff878787),
              ),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: () => _showDeleteConfirmation(reminder),
              child: const Icon(
                Icons.delete_forever_rounded,
                size: 18,
                color: Color(0xff878787),
              ),
            ),
            const SizedBox(width: 14),
          ],
        );

      case 'meal':
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
              formatReminderTime(
                reminder.customReminder?.timesPerDay?.list ?? [],
              ),
              style: TextStyle(fontSize: 12, color: Color(0xff878787)),
            ),
            Spacer(),
            InkWell(
              onTap: () {
                // Get.snackbar(
                //   "WIP",
                //   "Reminder inundation is work in progress.",
                //   snackPosition: SnackPosition.BOTTOM,
                //   colorText: white,
                //   backgroundColor: AppColors.primaryColor,
                //   duration: const Duration(seconds: 3),
                // );
                // return;
                Get.to(AddReminderScreen(reminder: reminder));
              },
              child: SvgPicture.asset(
                pen,
                width: 18,
                height: 18,
                color: const Color(0xff878787),
              ),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: () => _showDeleteConfirmation(reminder),
              child: Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  size: 18,
                  color: Color(0xff878787),
                ),
              ),
            ),

            const SizedBox(width: 4),
          ],
        );

      case 'event':
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
                  formatReminderTime(
                    reminder.customReminder!.timesPerDay!.list ?? [],
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff878787),
                  ),
                ),
                Spacer(),
                InkWell(
                  onTap: () {
                    // Get.snackbar(
                    //   "WIP",
                    //   "Reminder inundation is work in progress.",
                    //   snackPosition: SnackPosition.BOTTOM,
                    //   colorText: white,
                    //   backgroundColor: AppColors.primaryColor,
                    //   duration: const Duration(seconds: 3),
                    // );
                    // return;
                    Get.to(AddReminderScreen(reminder: reminder));
                  },
                  child: SvgPicture.asset(
                    pen,
                    width: 18,
                    height: 18,
                    color: const Color(0xff878787),
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
                      color: const Color(0xff878787),
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
        return const Text("Unknown category");
    }
  }
}

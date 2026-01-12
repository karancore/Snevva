import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/Reminder/event_controller.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/medicine_reminder_model.dart';

import '../../Controllers/Reminder/meal_controller.dart';
import '../../Controllers/Reminder/medicine_controller.dart';
import '../../Controllers/Reminder/water_controller.dart';

class AddReminderScreen extends StatefulWidget {
  final Map<String, dynamic>? reminder;

  const AddReminderScreen({super.key, this.reminder});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final controller = Get.find<ReminderController>();
  final medicineGetxController = Get.find<MedicineController>();
  final waterGetxController = Get.find<WaterController>();
  final mealGetxController = Get.find<MealController>();
  final eventGetxController = Get.find<EventController>();

  final double itemHeight = 56.0;
  final double maxHeight = 150.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final formattedTime = DateFormat('hh:mm a').format(now);
    controller.timeController.text = formattedTime;
    waterGetxController.startWaterTimeController.text = formattedTime;
    waterGetxController.endWaterTimeController.text = formattedTime;

    // Load existing reminder data if editing
    if (widget.reminder != null) {
      controller.loadReminderData(widget.reminder!);
      controller.titleController.text =
          widget.reminder!['Title']?.toString() ?? '';
      final medicinesData = widget.reminder!['Medicines'];

      if (medicinesData is List) {
        medicineGetxController.medicines.clear();

        for (final med in medicinesData) {
          medicineGetxController.medicines.add(
            MedicineItem(
              name: med['name'],
              times: (med['times'] as List)
                  .map(
                    (t) => MedicineTime(
                  time: TimeOfDay.fromDateTime(DateTime.parse(t)),
                ),
              )
                  .toList(),
            ),
          );
        }
      }

      controller.timeController.text = formatReminderTime(
        widget.reminder!['RemindTime'] ?? [],
      );
      if (widget.reminder!["Category"] == "Medicine" ||
          widget.reminder!["Category"] == "Event" ||
          widget.reminder!["Category"] == "Meal") {
        controller.pickedTime.value = TimeOfDay.fromDateTime(
          DateTime.parse(widget.reminder!['RemindTime'][0]),
        );
      }

      controller.notesController.text =
          widget.reminder!['Description']?.toString() ?? '';
    }
    if (widget.reminder == null) {
      medicineGetxController.medicineList.value = [];
      medicineGetxController.medicines.value = [];
      waterGetxController.waterList.value = [];
      eventGetxController.eventList.value = [];
      mealGetxController.mealsList.value = [];
    }
  }

  @override
  void dispose() {
    controller.resetForm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(
        appbarText: widget.reminder == null ? "Add Reminder" : "Edit Reminder",
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildTitleField(),
            SizedBox(height: 20),
            _buildCategorySelection(),
            Obx(() => _buildCategorySpecificFields()),
            SizedBox(height: 20),
            _buildToggles(),
            SizedBox(height: 20),
            _buildNotesField(),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: SafeArea(
          child: CustomOutlinedButton(
            width: width,
            isDarkMode: isDarkMode,
            backgroundColor: AppColors.primaryColor,
            buttonName: widget.reminder == null ? "Save" : "Update",
            onTap:
                widget.reminder == null
                    ? () {
                      final result = controller.validateAndSave(context);
                      if (result == true) {
                        medicineGetxController.medicineList.value = [];
                        waterGetxController.waterList.value = [];
                        eventGetxController.eventList.value = [];
                        mealGetxController.mealsList.value = [];
                        Navigator.pop(context);
                      }
                      //Navigator.pop(context);
                    }
                    : () {
                      controller.updateReminderFromLocal(
                        context,
                        id: widget.reminder!['id'].toString(),
                        category: widget.reminder!['Category'].toString(),
                        timeOfDay:
                            widget.reminder!['Category'].toString() == "Water"
                                ? TimeOfDay.now()
                                : TimeOfDay.fromDateTime(
                                  DateTime.parse(
                                    widget.reminder!['RemindTime'][0],
                                  ),
                                ),
                        times:
                            widget.reminder!['RemindFrequencyCount'] is int
                                ? widget.reminder!['RemindFrequencyCount']
                                : int.tryParse(
                                  widget.reminder!['RemindFrequencyCount']
                                          ?.toString() ??
                                      '',
                                ),
                      );
                    },
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Title", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        TextField(
          controller: controller.titleController,
          decoration: InputDecoration(
            hintText: 'Enter title',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Select category", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Obx(
          () => Wrap(
            spacing: 8,
            children:
                controller.categories.map((category) {
                  final isSelected =
                      controller.selectedCategory.value == category;
                  return GestureDetector(
                    onTap: () => controller.selectedCategory.value = category,
                    child: Card(
                      color:
                          isSelected
                              ? AppColors.primaryColor
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? black
                                  : white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              controller.getCategoryIcon(category),
                              //color: isSelected ? white : grey,
                            ),
                            SizedBox(height: 4),
                            Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? white : grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySpecificFields() {
    switch (controller.selectedCategory.value) {
      case 'Medicine':
        return _buildMedicineFields();
      case 'Water':
        return _buildWaterFields();
      case 'Meal':
        return _buildMealFields();
      case 'Event':
        return _buildEventFields();
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildMedicineFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Text("Medicine", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: medicineGetxController.medicineController,
                decoration: InputDecoration(
                  hintText: 'Medicine name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () => medicineGetxController.addMedicine(),
            ),
          ],
        ),
        SizedBox(height: 10),
        Obx(() => ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: medicineGetxController.medicines.length,
          itemBuilder: (context, index) {
            final med = medicineGetxController.medicines[index];
            return Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(med.name),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () =>
                          medicineGetxController.removeMedicine(index),
                    ),
                    onTap: () =>
                    medicineGetxController.selectedMedicineIndex.value = index,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Wrap(
                      spacing: 8,
                      children: med.times
                          .map((t) => Chip(
                        label: Text(
                          t.time.format(context),
                        ),
                      ))
                          .toList(),
                    ),
                  )
                ],
              ),
            );
          },
        )),
        SizedBox(height: 20),
        Text("Medicine Date", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Obx(
            () => OutlinedButton(
              onPressed: () => _selectDate(),
              child: Text(
                controller.startDate.value == null
                    ? 'Start Date'
                    : controller.startDate.value.toString().split(' ')[0],
              ),
            ),
          ),
        ),
        SizedBox(height: 20),
        Text("Medicine Time", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.timeController,
                readOnly: true,
                onTap: () => _selectTime(controller.timeController.text),
                decoration: InputDecoration(
                  hintText: '09:30 AM',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () => medicineGetxController.addMedicine(),
            ),
          ],
        ),
        // SizedBox(height: 10),
        // Obx(
        //   () =>
        //       controller.medicineList.isEmpty
        //           ? SizedBox.shrink()
        //           : SizedBox(
        //             height: controller.getListHeight(
        //               controller.medicineList.length,
        //             ),
        //             child: ListView.separated(
        //               itemCount: controller.medicineList.length,
        //               separatorBuilder: (context, index) => SizedBox(height: 1),
        //               itemBuilder: (context, index) {
        //                 final reminder = controller.medicineList[index];
        //                 final title = reminder.title;
        //                 final alarm = reminder.alarm;
        //                 return ListTile(
        //                   title: Text(
        //                     '${alarm.dateTime.hour.toString().padLeft(2, '0')}:${alarm.dateTime.minute.toString().padLeft(2, '0')}', // FIX: Added padding
        //                   ),
        //                   subtitle: Text(title),
        //                   trailing: IconButton(
        //                     icon: Icon(Icons.delete),
        //                     onPressed: () async {
        //                       // FIX: Made async and handle MedicineReminderModel
        //                       await controller.stopAlarm(
        //                         index,
        //                         alarm,
        //                         controller
        //                             .mealsList, // Workaround - will handle in controller
        //                       );
        //                       // Alternative: directly delete from medicineList
        //                       await Alarm.stop(alarm.id);
        //                       controller.medicineList.removeAt(index);
        //                       await controller.saveReminderList(
        //                         controller.medicineList,
        //                         "medicine_list",
        //                       );
        //                     },
        //                   ),
        //                 );
        //               },
        //             ),
        //           ),
        // ),
      ],
    );
  }

  Widget _buildWaterFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Text(
          "Set Reminder Time",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  height: 48,

                  child: TextField(
                    controller: waterGetxController.startWaterTimeController,
                    readOnly: true,
                    textAlign: TextAlign.center,
                    onTap: () => _selectStartTime(),
                    decoration: InputDecoration(
                      hintText: '09:30 AM',
                      contentPadding: const EdgeInsets.all(8),
                      hintStyle: TextStyle(fontSize: 2),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
            ),
            Text("  to  "),
            Expanded(
              child: Center(
                child: SizedBox(
                  height: 48,

                  child: Center(
                    child: TextField(
                      controller: waterGetxController.endWaterTimeController,
                      readOnly: true,
                      textAlign: TextAlign.center,
                      onTap: () => _selectEndTime(),
                      decoration: InputDecoration(
                        hintText: "12:00 PM",
                        contentPadding: const EdgeInsets.all(8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Text(
          "Set Reminder Frequency",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Radio<Option>(
                    value: Option.times,
                    groupValue: waterGetxController.waterReminderOption.value,
                    onChanged: (value) {
                      if (value != null) {
                        waterGetxController.waterReminderOption.value = value;
                      }
                    },
                  ),
                  Text("Remind me"),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: waterGetxController.timesPerDayController,
                      keyboardType: TextInputType.number,
                      enabled:
                          waterGetxController.waterReminderOption.value ==
                          Option.times,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      onChanged: (_) {
                        waterGetxController.savedTimes.value =
                            int.tryParse(
                              waterGetxController.timesPerDayController.text,
                            ) ??
                            0;
                      },
                    ),
                  ),
                  Text("times"),
                  Text("a"),
                  Text("day"),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Radio<Option>(
                    value: Option.interval,
                    groupValue: waterGetxController.waterReminderOption.value,
                    onChanged: (value) {
                      if (value != null) {
                        waterGetxController.waterReminderOption.value = value;
                      }
                    },
                  ),
                  Text("Remind"),
                  Text("me"),
                  Text("every"),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: waterGetxController.everyHourController,
                      keyboardType: TextInputType.number,
                      enabled:
                          waterGetxController.waterReminderOption.value ==
                          Option.interval,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      onChanged: (_) {
                        waterGetxController.savedTimes.value =
                            int.tryParse(
                              waterGetxController.everyHourController.text,
                            ) ??
                            0;
                      },
                    ),
                  ),
                  Text("hours"),
                  Text("a"),
                  Text("day"),
                  // Text("between"),
                  // SizedBox(
                  //   height: 40,
                  //   width: 100,
                  //   child: TextField(
                  //     controller: controller.startWaterTimeController,
                  //     readOnly: true,
                  //     onTap: () => _selectStartTime(),
                  //     decoration: InputDecoration(
                  //       hintText: '09:30 AM',
                  //       contentPadding: const EdgeInsets.all(8),
                  //       hintStyle: TextStyle(fontSize: 2),
                  //       border: OutlineInputBorder(),
                  //     ),
                  //   ),
                  // ),
                  // Text("to"),
                  // SizedBox(
                  //   height: 40,
                  //   width: 100,
                  //   child: TextField(
                  //     controller: controller.endWaterTimeController,
                  //     readOnly: true,
                  //     onTap: () => _selectEndTime(),
                  //     decoration: InputDecoration(
                  //       hintText: "12:00 PM",
                  //       contentPadding: const EdgeInsets.all(8),
                  //       border: OutlineInputBorder(),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
        ),

        // SizedBox(height: 10),
        // Obx(
        //   () =>
        //       controller.waterList.isEmpty
        //           ? SizedBox.shrink()
        //           : SizedBox(
        //             height: controller.getListHeight(
        //               controller.waterList.length,
        //             ),
        //             child: ListView.separated(
        //               separatorBuilder: (context, index) => SizedBox(height: 1),
        //               itemCount: controller.waterList.length,
        //               itemBuilder: (context, index) {
        //                 final reminderMap = controller.waterList[index];
        //                 final title = reminderMap.title;
        //                 return ListTile(
        //                   title: Text(title),
        //                   trailing: IconButton(
        //                     icon: Icon(Icons.delete),
        //                     onPressed:
        //                         () => controller.stopAlarm(
        //                           index,
        //                           controller.waterList[index].alarms[index],
        //                           controller.waterList,
        //                         ),
        //                   ),
        //                 );
        //               },
        //             ),
        //           ),
        // ),
      ],
    );
  }

  Widget _buildMealFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Text(
          "Set Reminder Time",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        TextField(
          controller: controller.timeController,
          readOnly: true,
          onTap: () => _selectTime(controller.timeController.text),
          decoration: InputDecoration(border: OutlineInputBorder()),
        ),
        SizedBox(height: 8),
        // Obx(
        //   () =>
        //       controller.mealsList.isEmpty
        //           ? SizedBox.shrink()
        //           : SizedBox(
        //             height: controller.getListHeight(
        //               controller.mealsList.length,
        //             ),
        //             child: ListView.separated(
        //               separatorBuilder: (context, index) => SizedBox(height: 1),
        //               itemCount: controller.mealsList.length,
        //               itemBuilder: (context, index) {
        //                 final reminderMap = controller.mealsList[index];
        //                 final title = reminderMap.keys.first;
        //                 final alarm = reminderMap.values.first;
        //                 return ListTile(
        //                   visualDensity: VisualDensity(
        //                     horizontal: 0,
        //                     vertical: -4,
        //                   ),
        //                   title: Text(
        //                     '${alarm.dateTime.hour.toString().padLeft(2, '0')}:${alarm.dateTime.minute.toString().padLeft(2, '0')}', // FIX: Added padding
        //                   ),
        //                   subtitle: Text(title),
        //                   trailing: IconButton(
        //                     icon: Icon(Icons.delete),
        //                     onPressed:
        //                         () => controller.stopAlarm(
        //                           index,
        //                           alarm,
        //                           controller.mealsList,
        //                         ),
        //                   ),
        //                 );
        //               },
        //             ),
        //           ),
        // ),
      ],
    );
  }

  Widget _buildEventFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Text("Event Date", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: Obx(
            () => OutlinedButton(
              onPressed: () => _selectDate(),
              child: Text(
                controller.startDate.value == null
                    ? 'Start Date'
                    : controller.startDate.value.toString().split(' ')[0],
              ),
            ),
          ),
        ),
        SizedBox(height: 20),
        Text("Event Time", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        TextField(
          controller: controller.timeController,
          readOnly: true,
          onTap: () => _selectTime(controller.timeController.text),
          decoration: InputDecoration(
            hintText: '09:30 AM',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            Text(
              "Remind me before event",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                // FIX: Changed from Wrap to Row for cleaner layout
                children: [
                  Radio(
                    value: 0,
                    groupValue: controller.eventReminderOption.value,
                    onChanged: (value) {
                      controller.eventReminderOption.value = value as int;
                    },
                  ),
                  Text("Remind me "),

                  SizedBox(
                    width: 50,
                    height: 35,
                    child: TextField(
                      controller: waterGetxController.timesPerDayController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      enabled: controller.eventReminderOption.value == 0,
                      // FIX: Changed condition
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      onChanged: (_) {
                        waterGetxController.savedTimes.value =
                            int.tryParse(
                              waterGetxController.timesPerDayController.text,
                            ) ??
                            0;
                      },
                    ),
                  ),
                  Text("  "),

                  SizedBox(
                    width: 70,
                    height: 35,
                    child: DropdownButton<String>(
                      value: controller.selectedValue.value,
                      isExpanded: false,
                      iconSize: 18,
                      items:
                          ['minutes', 'hours']
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (newValue) {
                        controller.selectedValue.value = newValue!;
                      },
                    ),
                  ),

                  Text("  before"),
                ],
              ),
            ),
          ],
        ),
        Obx(
          () =>
              eventGetxController.eventList.isEmpty
                  ? SizedBox.shrink()
                  : SizedBox(
                    height: getListHeight(
                      eventGetxController.eventList.length,
                      itemHeight,
                      maxHeight,
                    ),
                    child: ListView.separated(
                      separatorBuilder: (context, index) => SizedBox(height: 1),
                      itemCount: eventGetxController.eventList.length,
                      itemBuilder: (context, index) {
                        final reminderMap =
                            eventGetxController.eventList[index];
                        final title = reminderMap.keys.first;
                        final alarm = reminderMap.values.first;
                        return ListTile(
                          title: Text(
                            '${alarm.dateTime.hour.toString().padLeft(2, '0')}:${alarm.dateTime.minute.toString().padLeft(2, '0')}', // FIX: Added padding
                          ),
                          subtitle: Text(title),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed:
                                () => controller.stopAlarm(
                                  index,
                                  alarm,
                                  eventGetxController.eventList,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildToggles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Toggles",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),

        Obx(() => _compactCheckbox(
          value: controller.enableNotifications.value,
          text: "Enable notifications",
          onChanged: (v) => controller.enableNotifications.value = v,
        )),

        const SizedBox(height: 4), // 👈 exact spacing control

        Obx(() => _compactCheckbox(
          value: controller.soundVibrationToggle.value,
          text: "Sound/Vibration toggle",
          onChanged: (v) => controller.soundVibrationToggle.value = v,
        )),
      ],
    );
  }

  Widget _compactCheckbox({
    required bool value,
    required String text,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12.0 , right: 6 , top: 10 , bottom: 10),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v!),
                activeColor: AppColors.primaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }


  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Notes", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8,),
        TextField(
          controller: controller.notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Optional',
            border: UnderlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(String time) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );

    if (picked != null) {
      controller.pickedTime.value = picked;
      final hour = picked.hourOfPeriod.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      controller.timeController.text = '$hour:$minute $period';
    }
  }

  Future<void> _selectStartTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );

    if (picked != null) {
      controller.pickedTime.value = picked;
      final hour = picked.hourOfPeriod.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      waterGetxController.startWaterTimeController.text =
          '$hour:$minute $period';
    }
  }

  Future<void> _selectEndTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );

    if (picked != null) {
      controller.pickedTime.value = picked;
      final hour = picked.hourOfPeriod.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      waterGetxController.endWaterTimeController.text = '$hour:$minute $period';
    }
  }

  Future<void> _selectDate() async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.startDate.value = picked;
    }
  }
}

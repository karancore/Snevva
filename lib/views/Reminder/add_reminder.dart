import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';

class AddReminder extends StatefulWidget {
  final Map<String, dynamic>? reminder;

  const AddReminder({super.key, this.reminder});

  @override
  State<AddReminder> createState() => _AddReminderState();
}

class _AddReminderState extends State<AddReminder> {
  final controller = Get.put(ReminderController());

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final formattedTime = DateFormat('hh:mm a').format(now);
    controller.timeController.text = formattedTime;

    // Load existing reminder data if editing
    if (widget.reminder != null) {
      controller.loadReminderData(widget.reminder!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

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
        child: CustomOutlinedButton(
          width: width,
          isDarkMode: isDarkMode,
          buttonName: widget.reminder == null ? "Save" : "Update",
          onTap: () => controller.validateAndSave(context),
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
                      color: isSelected ? AppColors.primaryColor : Colors.white,
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
                              //color: isSelected ? Colors.white : Colors.grey,
                            ),
                            SizedBox(height: 4),
                            Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey,
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
      case 'Water':
        return _buildWaterFields();
      case 'Meal':
        return _buildMealFields();
      case 'Medicine':
        return _buildMedicineFields();
      case 'Event':
        return _buildEventFields();
      default:
        return SizedBox.shrink();
    }
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
        SizedBox(height: 10),
        Obx(
          () => Row(
            children: [
              Radio(
                value: 0,
                groupValue: controller.waterReminderOption.value,
                onChanged:
                    (value) =>
                        controller.waterReminderOption.value = value as int,
              ),
              Text("Remind me every "),
              SizedBox(
                width: 50,
                child: TextField(
                  controller: controller.everyHourController,
                  keyboardType: TextInputType.number,
                  enabled: controller.waterReminderOption.value == 0,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  onChanged: (_) {
                    controller.savedInterval.value =
                        int.tryParse(controller.everyHourController.text) ?? 0;
                  },
                ),
              ),
              Text(" hours"),
            ],
          ),
        ),
        Obx(
          () => Row(
            children: [
              Radio(
                value: 1,
                groupValue: controller.waterReminderOption.value,
                onChanged:
                    (value) =>
                        controller.waterReminderOption.value = value as int,
              ),
              Text("Remind me "),
              SizedBox(
                width: 50,
                child: TextField(
                  controller: controller.timesPerDayController,
                  keyboardType: TextInputType.number,
                  enabled: controller.waterReminderOption.value == 1,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  onChanged: (_) {
                    controller.savedTimes.value =
                        int.tryParse(controller.timesPerDayController.text) ??
                        0;
                  },
                ),
              ),
              Text(" times a day"),
            ],
          ),
        ),
        SizedBox(height: 8),
        Obx(
          () =>
              controller.waterList.isEmpty
                  ? SizedBox.shrink()
                  : SizedBox(
                    height: controller.getListHeight(
                      controller.waterList.length,
                    ),
                    child: ListView.separated(
                      separatorBuilder: (context, index) => SizedBox(height: 1),
                      itemCount: controller.waterList.length,
                      itemBuilder: (context, index) {
                        final reminderMap = controller.waterList[index];
                        final title = reminderMap.keys.first;
                        final alarm = reminderMap.values.first;
                        return ListTile(
                          title: Text(
                            '${alarm.dateTime.hour}:${alarm.dateTime.minute}',
                          ),
                          subtitle: Text(title),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed:
                                () => controller.stopAlarm(
                                  index,
                                  alarm,
                                  controller.waterList,
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
          onTap: () => _selectTime(),
          decoration: InputDecoration(border: OutlineInputBorder()),
        ),
        SizedBox(height: 8),
        Obx(
          () =>
              controller.mealsList.isEmpty
                  ? SizedBox.shrink()
                  : SizedBox(
                    height: controller.getListHeight(
                      controller.mealsList.length,
                    ),
                    child: ListView.separated(
                      separatorBuilder: (context, index) => SizedBox(height: 1),
                      itemCount: controller.mealsList.length,
                      itemBuilder: (context, index) {
                        final reminderMap = controller.mealsList[index];
                        final title = reminderMap.keys.first;
                        final alarm = reminderMap.values.first;
                        return ListTile(
                          visualDensity: VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                          title: Text(
                            '${alarm.dateTime.hour}:${alarm.dateTime.minute}',
                          ),
                          subtitle: Text(title),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed:
                                () => controller.stopAlarm(
                                  index,
                                  alarm,
                                  controller.mealsList,
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
                controller: controller.medicineController,
                decoration: InputDecoration(
                  hintText: 'Medicine name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () => controller.addMedicine(),
            ),
          ],
        ),
        SizedBox(height: 10),
        Obx(
          () => ListView.separated(
            shrinkWrap: true,
            separatorBuilder: (context, index) => SizedBox(height: 1),
            physics: NeverScrollableScrollPhysics(),
            itemCount: controller.medicineNames.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(controller.medicineNames[index]),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => controller.removeMedicine(index),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 20),
        Text("Reminder Date", style: TextStyle(fontWeight: FontWeight.bold)),
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
        Text("Reminder Time", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        TextField(
          controller: controller.timeController,
          readOnly: true,
          onTap: () => _selectTime(),
          decoration: InputDecoration(
            hintText: '09:30 AM',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10),
        Obx(
          () =>
              controller.medicineList.isEmpty
                  ? SizedBox.shrink()
                  : SizedBox(
                    height: controller.getListHeight(
                      controller.medicineList.length,
                    ),
                    child: ListView.separated(
                      itemCount: controller.medicineList.length,
                      separatorBuilder: (context, index) => SizedBox(height: 1),
                      itemBuilder: (context, index) {
                        final reminderMap = controller.medicineList[index];
                        final title = reminderMap.keys.first;
                        final alarm = reminderMap.values.first;
                        return ListTile(
                          title: Text(
                            '${alarm.dateTime.hour}:${alarm.dateTime.minute}',
                          ),
                          subtitle: Text(title),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed:
                                () => controller.stopAlarm(
                                  index,
                                  alarm,
                                  controller.medicineList,
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

  Widget _buildEventFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Text("Reminder Date", style: TextStyle(fontWeight: FontWeight.bold)),
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
        Text("Reminder Time", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        TextField(
          controller: controller.timeController,
          readOnly: true,
          onTap: () => _selectTime(),
          decoration: InputDecoration(
            hintText: '09:30 AM',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            Text(
              "Set Reminder Time",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Obx(
                  () => Wrap(
                spacing: 8,           // horizontal spacing
                runSpacing: 8,        // vertical wrap spacing
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Radio(
                    value: 0,
                    groupValue: controller.eventReminderOption.value,
                    onChanged: (value) {
                      controller.eventReminderOption.value = value as int;
                    },
                  ),

                  Text("Remind me"),

                  // Times per day input
                  SizedBox(
                    width: 40,
                    height: 30,
                    child: TextField(
                      controller: controller.timesPerDayController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      enabled: controller.waterReminderOption.value == 1,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onChanged: (_) {
                        controller.savedTimes.value =
                            int.tryParse(controller.timesPerDayController.text) ?? 0;
                      },
                    ),
                  ),

                  // Small dropdown
                  SizedBox(
                    width: 68,
                    child: DropdownButton<String>(
                      value: controller.selectedValue.value,
                      isExpanded: true,
                      underline: const SizedBox(), // remove line
                      iconSize: 18,
                      items: ['minutes', 'hours']
                          .map((value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ))
                          .toList(),
                      onChanged: (newValue) {
                        controller.selectedValue.value = newValue!;
                      },
                    ),
                  ),

                  Text("before"),

                  // Time input
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: controller.timeController,
                      readOnly: true,
                      style: const TextStyle(fontSize: 13),
                      onTap: _selectTime,
                      enabled: controller.waterReminderOption.value == 1,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                ],
              ),
            )

          ],
        ),
        Obx(
          () =>
              controller.eventList.isEmpty
                  ? SizedBox.shrink()
                  : SizedBox(
                    height: controller.getListHeight(
                      controller.eventList.length,
                    ),
                    child: ListView.separated(
                      separatorBuilder: (context, index) => SizedBox(height: 1),
                      itemCount: controller.eventList.length,
                      itemBuilder: (context, index) {
                        final reminderMap = controller.eventList[index];
                        final title = reminderMap.keys.first;
                        final alarm = reminderMap.values.first;
                        return ListTile(
                          title: Text(
                            '${alarm.dateTime.hour}:${alarm.dateTime.minute}',
                          ),
                          subtitle: Text(title),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed:
                                () => controller.stopAlarm(
                                  index,
                                  alarm,
                                  controller.eventList,
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
        Text("Toggles", style: TextStyle(fontWeight: FontWeight.bold)),
        Obx(
          () => CheckboxListTile(
            value: controller.enableNotifications.value,
            onChanged: (value) => controller.enableNotifications.value = value!,
            title: Text('Enable notifications'),
            activeColor: AppColors.primaryColor,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        Obx(
          () => CheckboxListTile(
            value: controller.soundVibrationToggle.value,
            onChanged:
                (value) => controller.soundVibrationToggle.value = value!,
            title: Text('Sound/Vibration toggle'),
            activeColor: AppColors.primaryColor,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Notes", style: TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _selectTime() async {
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

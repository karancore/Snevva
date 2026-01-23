import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/Reminder/event_controller.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/medicine_reminder_model.dart';
import 'package:snevva/widgets/reminder/horizontal_selectable_card_row.dart';
import '../../Controllers/Reminder/meal_controller.dart';
import '../../Controllers/Reminder/medicine_controller.dart';
import '../../Controllers/Reminder/water_controller.dart';
import '../../widgets/reminder/custom_Radio.dart';

class AddReminderScreen extends StatefulWidget {
  final Map<String, dynamic>? reminder;

  const AddReminderScreen({super.key, this.reminder});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final controller = Get.find<ReminderController>();
  bool isSelected = false;
  bool showMedicineTime = true;
  num dosage = 1;

  bool isFirstTime = true;
  final medicineQuantity = "Tablet";
  bool showMedicineTimeSecond = true;
  bool _highlightBorder = false;

  final medicineGetxController = Get.find<MedicineController>();
  final waterGetxController = Get.find<WaterController>();
  final mealGetxController = Get.find<MealController>();
  final eventGetxController = Get.find<EventController>();

  final double itemHeight = 56.0;
  final double maxHeight = 150.0;

  @override
  void initState() {
    super.initState();
    //
    // final formattedTime = DateFormat('hh:mm a').format(now);
    // final endWater = DateFormat('hh:mm a').format(now.add(Duration(hours: 8)));
    // controller.timeController.text = formattedTime;
    // waterGetxController.startWaterTimeController.text = formattedTime;
    // waterGetxController.endWaterTimeController.text = endWater;

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
              times:
                  (med['times'] as List)
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

  void _blinkBorder() {
    setState(() => _highlightBorder = true);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _highlightBorder = false);
      }
    });
  }

  void increaseDosage() {
    setState(() {
      final selected = medicineGetxController.selectedType.value;
      dosage += selected == 'Drops' ? 1 : 0.5;
    });
  }

  void decreaseDosage() {
    setState(() {
      final selected = medicineGetxController.selectedType.value;
      final step = selected == 'Drops' ? 1 : 0.5;
      dosage = (dosage - step).clamp(step, double.infinity);
    });
  }

  Future<void> _selectTime({required TextEditingController controller}) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';

      controller.text = '$hour:$minute $period';
    }
  }

  Future<void> _selectStartTime({required String text}) async {
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
      text = '$hour:$minute $period';
      setState(() {
        isFirstTime = false;
      });
    }
  }

  Future<void> _selectEndTime({required String text}) async {
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
      text = '$hour:$minute $period';
      setState(() {
        isFirstTime = false;
      });
    }
  }

  String getDisplayUnit(String type, num dosage) {
    final baseUnit = medicineGetxController.typeToDosage[type] ?? 'ML';

    const pluralizableUnits = {'TABLET', 'UNIT', 'DROP'};

    if (dosage > 1 && pluralizableUnits.contains(baseUnit)) {
      return '${baseUnit}S';
    }

    return baseUnit;
  }

  Future<void> _selectDate({
    required Rx<DateTime?> date,
    RxString? dateString,
    TextEditingController? controller,
  }) async {
    DateTime now = DateTime.now();

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: date.value ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      date.value = picked;

      final formattedDate = DateFormat('dd MMMM').format(picked);

      if (dateString != null) {
        dateString.value = formattedDate;
      }

      if (controller != null) {
        controller.text = formattedDate;
      }
    }
  }

  String formatDosage(String type, num dosage) {
    if (type == 'Drops') {
      return dosage.round().toString();
    }
    return dosage % 1 == 0 ? dosage.toInt().toString() : dosage.toString();
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          _buildTitleField(),
          SizedBox(height: 16),
          _buildCategorySelection(),
          SizedBox(height: 16),
          Obx(() => _buildCategorySpecificFields()),
          SizedBox(height: 16),
          _buildNotesField(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
                        // Navigator.pop(context);
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
          decoration: commonInputDecoration(hint: 'Enter title'),
        ),
      ],
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Select category", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Obx(
          () => HorizontalSelectableCardRow<String>(
            items: controller.categories,
            selectedItem: controller.selectedCategory.value,
            onSelected: (category) {
              controller.selectedCategory.value = category;
            },
            iconBuilder:
                (category, isSelected) =>
                    Image.asset(controller.getCategoryIcon(category)),
            labelBuilder: (category) => category,
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
        Text("Medicine", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: medicineGetxController.medicineController,
          decoration: commonInputDecoration(hint: "Medicine name"),
        ),
        const SizedBox(height: 16),
        Text("Medicine Type", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Obx(
          () => HorizontalSelectableCardRow<String>(
            items: medicineGetxController.types,
            selectedItem: medicineGetxController.selectedType.value,
            onSelected: (type) {
              medicineGetxController.selectedType.value = type;
            },
            iconBuilder:
                (type, isSelected) => SvgPicture.asset(
                  medicineGetxController.getCategoryIcon(type),
                  color: isSelected ? white : grey,
                ),
            labelBuilder: (type) => type,
          ),
        ),
        const SizedBox(height: 12),
        Text("Dosage", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          height: 48,
          decoration: BoxDecoration(
            color: white,
            border: Border.all(
              color: _highlightBorder ? AppColors.primaryColor : grey,
              width: _highlightBorder ? 1.5 : 0.5,
            ),
            borderRadius: BorderRadius.circular(
              4,
            ), // Applies a circular radius of 20 to all corners
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  decreaseDosage();
                  _blinkBorder();
                },
                icon: const Icon(
                  Icons.remove,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
              ),
              Obx(() {
                final selected = medicineGetxController.selectedType.value;
                final unit = getDisplayUnit(selected, dosage);
                final displayDosage = formatDosage(selected, dosage);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayDosage,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      unit,
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 10,
                      ),
                    ),
                  ],
                );
              }),
              IconButton(
                onPressed: () {
                  increaseDosage();
                  _blinkBorder();
                },
                icon: const Icon(
                  Icons.add,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "When to take?",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        HorizontalSelectableCardRow(
          items: medicineGetxController.mealOptions,
          selectedItem: medicineGetxController.selectedOption.value,
          onSelected: (value) {
            medicineGetxController.selectedOption.value = value;
          },
          labelBuilder: (item) {
            return item;
          },
          spacing: 32,
        ),
        const SizedBox(height: 16),
        //Setting reminder frequency
        Text(
          "Set Medicine Frequency",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        HorizontalSelectableCardRow(
          items: medicineGetxController.medicineFrequencies,
          selectedItem: medicineGetxController.selectedFrequency.value,
          onSelected: (value) {
            medicineGetxController.selectedFrequency.value = value;
          },
          labelBuilder: (item) {
            return item;
          },
          spacing: 22,
        ),
        const SizedBox(height: 8),
        //Custom frequency radio buttons
        Obx(() {
          return medicineGetxController.selectedFrequency.value == 'Custom'
              ? _medicineFrequencyFields()
              : const SizedBox.shrink();
        }),
        const SizedBox(height: 6),
        Obx(() {
          final selected = medicineGetxController.medicineReminderOption.value;
          final timesSelected = selected == Option.times;
          final intervalSelected = selected == Option.interval;

          if (medicineGetxController.selectedFrequency.value == 'Custom') {
            medicineGetxController.timesPerDayController.text = 4.toString();
            medicineGetxController.everyHourController.text = 4.toString();
          }
          return timesSelected
              ? _medicineTimesField()
              : (intervalSelected
                  ? _setReminderTimes(
                    title: 'Medicine',
                    startTimeController:
                        medicineGetxController.startMedicineTimeController,
                    endTimeController:
                        medicineGetxController.endMedicineTimeController,
                  )
                  : SizedBox.shrink());
        }),
        const SizedBox(height: 20),
        Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomRadio(
                selected:
                    medicineGetxController.medicineRemindMeBeforeOption.value ==
                    0,
                onTap: () {
                  final rx =
                      medicineGetxController.medicineRemindMeBeforeOption;
                  rx.value = rx.value == 0 ? null : 0;
                },
              ),
              const SizedBox(width: 8),
              const Text("Remind me "),
              SizedBox(
                width: 48,
                height: 35,
                child: TextField(
                  controller: medicineGetxController.remindMeBeforeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    isDense: true,
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.primaryColor,
                        width: 1.5, // Change thickness
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: grey,
                        width: 0.5,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ),
              const Text("   "),
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

        //const SizedBox(height: 20),
        //_remindMeBeforeMedicine()
      ],
    );
  }

  Widget _remindMeBeforeMedicine() {
    return Obx(() {
      final isSelected = medicineGetxController.timeBeforeReminder.value == 0;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// RADIO
          Theme(
            data: Theme.of(context).copyWith(unselectedWidgetColor: grey),
            child: Radio<int>(
              value: 0,
              groupValue: medicineGetxController.timeBeforeReminder.value,
              activeColor: black,
              onChanged: (value) {
                medicineGetxController.timeBeforeReminder.value = value!;
              },
            ),
          ),

          /// TEXT
          Text(
            "Remind me ",
            style: TextStyle(color: isSelected ? black : grey),
          ),

          /// TEXT FIELD
          SizedBox(
            width: 32,
            height: 35,
            child: TextField(
              controller: medicineGetxController.timesPerDayController,
              keyboardType: TextInputType.number,
              enabled: isSelected,
              style: TextStyle(fontSize: 13, color: isSelected ? black : grey),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
              ),
            ),
          ),

          const Text("  "),

          /// DROPDOWN
          SizedBox(
            width: 70,
            height: 35,
            child: DropdownButton<String>(
              value: medicineGetxController.selectedValue.value,
              iconSize: 18,
              isExpanded: false,
              underline: const SizedBox(),
              style: TextStyle(fontSize: 13, color: isSelected ? black : grey),
              items:
                  ['minutes', 'hours']
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
              onChanged:
                  isSelected
                      ? (newValue) {
                        medicineGetxController.selectedValue.value = newValue!;
                      }
                      : null,
            ),
          ),

          /// TEXT
          Text("  before", style: TextStyle(color: isSelected ? black : grey)),
        ],
      );
    });
  }

  Widget _buildWaterFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _setReminderTimes(
          title: 'Water',
          startTimeController: waterGetxController.startWaterTimeController,
          endTimeController: waterGetxController.endWaterTimeController,
        ),
        const SizedBox(height: 20),
        Text(
          "Set Reminder Frequency",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
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
                    activeColor: black,
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
                    activeColor: black,
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
      ],
    );
  }

  Widget _buildMealFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Set Meal Time",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        TextField(
          controller: controller.timeController,
          readOnly: true,
          onTap: () => _selectTime(controller: controller.timeController),
          decoration: commonInputDecoration(hint: '10:00 AM'),
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
        Text("Event Date", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Obx(
            () => OutlinedButton(
              onPressed:
                  () => _selectDate(
                    date: controller.startDate,
                    dateString: controller.startDateString,
                  ),
              style: ButtonStyle(
                side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return BorderSide(color: AppColors.primaryColor);
                  }
                  return BorderSide(color: grey);
                }),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              child: Text(
                controller.startDate.value == null
                    ? 'Start Date'
                    : controller.startDateString.value,
                style: TextStyle(
                  color:
                      controller.startDateString.value == "Select Date"
                          ? grey
                          : AppColors.primaryColor,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Set Event Time",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller.timeController,
          readOnly: true,
          onTap: () => _selectTime(controller: controller.timeController),
          decoration: commonInputDecoration(hint: '09:28 AM'),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              "Reminder before event",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                // FIX: Changed from Wrap to Row for cleaner layout
                children: [
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(unselectedWidgetColor: grey),
                    child: Radio(
                      activeColor: black,
                      value: 0,
                      groupValue: controller.eventReminderOption.value,
                      onChanged: (value) {
                        controller.eventReminderOption.value = value as int;
                      },
                    ),
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

  Widget _medicineTimesField() {
    return Obx(() {
      final isCustom =
          medicineGetxController.selectedFrequency.value == 'Custom';

      final length =
          medicineGetxController.frequencyNum[medicineGetxController
              .selectedFrequency
              .value] ??
          1;

      medicineGetxController.updateTimeControllers(length);

      return isCustom
          ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "Time",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: medicineGetxController.addCustomTime,
                    child: const Text(
                      '+ Add',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: medicineGetxController.timeControllers.length,
                itemBuilder: (context, index) {
                  final controller =
                      medicineGetxController.timeControllers[index];
                  medicineGetxController.timesPerDayController.text = medicineGetxController.timeControllers.length.toString();
                  return Row(
                    children: [
                      Flexible(
                        flex: 12,
                        child: TextField(
                          controller: controller,
                          readOnly: true,
                          onTap: () => _selectTime(controller: controller),
                          decoration: const InputDecoration(
                            hintText: '09:30 AM',
                            hintStyle: TextStyle(color: grey),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isCustom)
                        Flexible(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () {
                              medicineGetxController.removeCustomTime(index);
                            },
                            child: Container(
                              height: 54,
                              width: 54,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: grey,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(height: 8);
                },
              ),
            ],
          )
          : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Time", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: medicineGetxController.timeControllers.length,
                itemBuilder: (context, index) {
                  final controller =
                      medicineGetxController.timeControllers[index];
                  return Row(
                    children: [
                      Flexible(
                        flex: 7,
                        child: TextField(
                          controller: controller,
                          readOnly: true,
                          onTap: () => _selectTime(controller: controller),
                          decoration: const InputDecoration(
                            hintText: '09:30 AM',
                            hintStyle: TextStyle(color: grey),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isCustom)
                        Flexible(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () {
                              // medicineGetxController.timeControllers
                              //     .removeAt(index);
                              //
                              // medicineGetxController.frequencyNum['Custom'] =
                              //     medicineGetxController
                              //         .timeControllers.length;
                            },
                            child: const Icon(
                              Icons.close,
                              color: mediumGrey,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(height: 8);
                },
              ),
            ],
          );
    });
  }

  Widget _medicineFrequencyFields() {
    return Obx(() {
      final selected = medicineGetxController.medicineReminderOption.value;

      final timesSelected = selected == Option.times;
      final intervalSelected = selected == Option.interval;

      if (medicineGetxController.selectedFrequency.value == 'Custom') {
        medicineGetxController.timesPerDayController.text = 4.toString();
        medicineGetxController.everyHourController.text = 4.toString();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// -------- TIMES PER DAY --------
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Theme(
                data: Theme.of(context).copyWith(unselectedWidgetColor: grey),
                child: Radio<Option>(
                  value: Option.times,
                  groupValue: selected,
                  activeColor: black,
                  onChanged: (value) {
                    medicineGetxController.medicineReminderOption.value =
                        value!;
                  },
                ),
              ),
              _greyText("Remind me", timesSelected),
              SizedBox(
                width: 36,
                child: TextField(
                  controller: medicineGetxController.timesPerDayController,
                  enabled: timesSelected,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: timesSelected ? black : grey),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ),
              _greyText("times a day", timesSelected),
            ],
          ),

          const SizedBox(height: 8),

          /// -------- INTERVAL --------
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Theme(
                data: Theme.of(context).copyWith(unselectedWidgetColor: grey),
                child: Radio<Option>(
                  value: Option.interval,
                  groupValue: selected,
                  activeColor: black,
                  onChanged: (value) {
                    medicineGetxController.medicineReminderOption.value =
                        value!;
                  },
                ),
              ),
              _greyText("Remind me every", intervalSelected),
              SizedBox(
                width: 36,
                child: TextField(
                  controller: medicineGetxController.everyHourController,
                  enabled: intervalSelected,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: intervalSelected ? black : grey),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ),
              _greyText("hours a day", intervalSelected),
            ],
          ),
        ],
      );
    });
  }

  Widget _setReminderTimes({
    required String title,
    required TextEditingController startTimeController,
    required TextEditingController endTimeController,
  }) {
    return Obx(() {
      final isCustom =
          medicineGetxController.selectedFrequency.value == 'Custom';
      return isCustom
          ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Set $title Time",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: TextField(
                        controller: startTimeController,
                        readOnly: true,
                        textAlign: TextAlign.center,
                        onTap:
                            () => _selectStartTime(
                              text: startTimeController.text,
                            ),
                        decoration: commonInputDecoration(hint: '09:30 AM'),
                      ),
                    ),
                  ),
                  Text(
                    "  to  ",
                    style: TextStyle(
                      color: isFirstTime ? grey : black,
                      fontWeight: isFirstTime ? FontWeight.w800 : null,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Center(
                        child: TextField(
                          controller: endTimeController,
                          readOnly: true,
                          textAlign: TextAlign.center,
                          onTap:
                              () =>
                                  _selectEndTime(text: endTimeController.text),
                          decoration: commonInputDecoration(hint: '11:30 PM'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
          : _medicineTimesField();
    });
  }

  InputDecoration commonInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: grey),
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _greyText(String text, bool enabled) {
    return Text(
      text,
      style: TextStyle(
        color: enabled ? black : grey,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Notes", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: controller.notesController,
          maxLines: 1,
          decoration: InputDecoration(
            isDense: true,

            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: grey, width: 0.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
            ),
            hintText: 'Optional',
            hintStyle: TextStyle(color: grey, fontWeight: FontWeight.w400),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

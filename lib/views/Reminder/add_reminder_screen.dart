import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:snevva/Controllers/Reminder/event_controller.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/common/first_letter_upper_case_formatter.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/widgets/reminder/horizontal_selectable_card_row.dart';
import '../../Controllers/Reminder/meal_controller.dart';
import '../../Controllers/Reminder/medicine_controller.dart';
import '../../Controllers/Reminder/water_controller.dart';
import '../../widgets/reminder/custom_Radio.dart';

class AddReminderScreen extends StatefulWidget {
  final ReminderPayloadModel? reminder;

  const AddReminderScreen({super.key, this.reminder});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final reminderController = Get.find<ReminderController>(tag: 'reminder');
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

    final reminder = widget.reminder;

    debugPrint("Reminder ${reminder.toString()}");
    if (reminder != null) {
      waterGetxController.timesPerDayController.addListener(() {
        waterGetxController.savedTimes.value =
            int.tryParse(
              waterGetxController.timesPerDayController.text.trim(),
            ) ??
            0;
      });

      waterGetxController.everyHourController.addListener(() {
        waterGetxController.everyXhours.value =
            int.tryParse(waterGetxController.everyHourController.text.trim()) ??
            0;
      });
      // editing existing reminder
      fillByCategory(reminder);
    } else {
      reminderController.selectedCategory.value = 'medicine';
    }
  }

  void fillByCategory(ReminderPayloadModel reminder) {
    switch (reminder.category) {
      case "medicine":
        fillMedicineFields(reminder);
        break;
      case "water":
        fillWaterFields(reminder);
        break;
      case "meal":
        fillMealFields(reminder);
        break;
      case "event":
        fillEventFields(reminder);
        break;
    }
  }

  void fillTimeControllers(List<String> times) {
    medicineGetxController.timeControllers.clear();
    for (var time in times) {
      medicineGetxController.timeControllers.add(
        TextEditingController(text: time),
      );
    }
  }

  void fillEventFields(ReminderPayloadModel reminder) {
    // 1. Basic Fields
    reminderController.titleController.text = reminder.title ?? '';
    reminderController.selectedCategory.value = reminder.category;
    reminderController.notesController.text = reminder?.notes ?? '';

    // 2. Time Parsing
    final dateTimeString =
        reminder.customReminder.timesPerDay?.list.first ?? '';

    if (dateTimeString.isNotEmpty) {
      try {
        reminderController.timeController.text = DateFormat(
          'hh:mm a',
        ).format(DateTime.parse(dateTimeString));
      } catch (e) {
        debugPrint("❌ Error parsing time: $e");
      }
    }

    // 3. Start Date Logic
    reminderController.startDateString.value = reminder?.startDate ?? '';

    // 4. Remind Before Logic
    if (reminder.remindBefore != null) {
      final rb = reminder.remindBefore;
      eventGetxController.eventRemindMeBefore.value = 0;

      eventGetxController.eventTimeBeforeController.text =
          rb?.time.toString() ?? '';
      reminderController.selectedValue.value = rb?.unit ?? '';
    } else {
      debugPrint("ℹ️ No RemindBefore data associated with this reminder.");
    }
  }

  void resetByCategory(String category) {
    switch (category) {
      case "medicine":
        medicineGetxController.resetForm();
        break;
      case "water":
        waterGetxController.resetForm();
        break;
      case "meal":
        mealGetxController.resetForm();
        break;
      case "event":
        eventGetxController.resetForm();
        break;
    }
  }

  void fillMealFields(ReminderPayloadModel reminder) {
    reminderController.titleController.text = reminder.title ?? '';
    reminderController.selectedCategory.value = reminder.category;
    reminderController.notesController.text = reminder?.notes ?? '';
    final dateTimeString =
        reminder.customReminder.timesPerDay?.list.first ?? '';
    mealGetxController.timeController.text = DateFormat(
      'hh:mm a',
    ).format(DateTime.parse(dateTimeString));
  }

  void fillWaterFields(ReminderPayloadModel reminder) {
    reminderController.titleController.text = reminder.title ?? '';
    reminderController.selectedCategory.value = reminder.category;

    reminderController.notesController.text = reminder?.notes ?? '';
    final type = reminder.customReminder?.type;

    if (type != null) {
      waterGetxController.waterReminderOption.value = type;

      if (type == Option.interval) {
        waterGetxController.everyXhours.value = 0;
        waterGetxController.everyHourController.text =
            reminder.customReminder?.everyXHours?.hours?.toString() ?? '';

        waterGetxController.startWaterTimeController.text =
            reminder.startWaterTime ?? '';
        waterGetxController.endWaterTimeController.text =
            reminder.endWaterTime ?? '';
      }
      if (type == Option.times) {
        waterGetxController.savedTimes.value = 0;
        waterGetxController.timesPerDayController.text =
            reminder.customReminder?.timesPerDay?.count?.toString() ?? '';

        waterGetxController.startWaterTimeController.text =
            reminder.startWaterTime ?? '';
        waterGetxController.endWaterTimeController.text =
            reminder.endWaterTime ?? '';
      }
    }
  }

  void fillMedicineFields(ReminderPayloadModel reminder) {
    debugPrint("\n================ MEDICINE REMINDER LOAD ================");
    debugPrint("Title: ${reminder.title}");
    debugPrint("Category: ${reminder.category}");
    debugPrint("Medicine Name: ${reminder.medicineNameSafe}");
    debugPrint("Notes: ${reminder.notes}");

    reminderController.titleController.text = reminder.title ?? '';
    reminderController.selectedCategory.value = reminder.category;
    medicineGetxController.medicineController.text =
        reminder.medicineNameSafe ?? '';

    reminderController.notesController.text = reminder.notes ?? '';

    debugPrint("Type: ${reminder.medicineType}");
    debugPrint("Dosage: ${reminder.dosage?.value}");
    debugPrint("When To Take: ${reminder.whenToTake}");
    debugPrint("Frequency: ${reminder.medicineFrequencyPerDay}");
    final int frequency =
        int.tryParse(reminder.medicineFrequencyPerDay ?? '') ?? 0;

    print("integer frequency is $frequency");

    final entry = medicineGetxController.frequencyNum.entries.firstWhere(
      (e) => e.value == frequency,
      orElse: () => const MapEntry('Custom', 4),
    );

    medicineGetxController.selectedFrequency.value = entry.key;

    medicineGetxController.selectedType.value = reminder.medicineType ?? '';
    dosage = asDouble(reminder.dosage?.value);
    print(
      "medicineGetxController.dosageMed.value ${medicineGetxController.dosageMed.value}",
    );

    medicineGetxController.selectedWhenToTake.value = reminder.whenToTake ?? '';

    List<String> times = reminder.customReminder.timesPerDay?.list ?? [];
    debugPrint("Parsed Times Length: ${times.length}");

    fillTimeControllers(times);

    /// -------- CUSTOM MEDICINE LOGIC ----------
    if (reminder.medicineFrequencyPerDay == 'Custom') {
      debugPrint("Custom Reminder Detected");
      debugPrint("Custom Type: ${reminder.customReminder.type}");

      if (reminder.customReminder.type == Option.times) {
        debugPrint("---- TIMES PER DAY MODE ----");
        debugPrint("Count: ${reminder.customReminder.timesPerDay?.count}");
        debugPrint("Times List: ${reminder.customReminder.timesPerDay?.list}");

        medicineGetxController.timesPerDayController.text =
            reminder.customReminder.timesPerDay?.count ?? '';

        List<String> times = reminder.customReminder.timesPerDay?.list ?? [];
        debugPrint("Parsed Times Length: ${times.length}");

        fillTimeControllers(times);
      }

      if (reminder.customReminder.type == Option.interval) {
        debugPrint("---- INTERVAL MODE ----");
        debugPrint(
          "Every X Hours: ${reminder.customReminder.everyXHours?.hours}",
        );
        debugPrint(
          "Start Time: ${reminder.customReminder.everyXHours?.startTime}",
        );
        debugPrint("End Time: ${reminder.customReminder.everyXHours?.endTime}");

        medicineGetxController.everyHourController.text =
            reminder.customReminder.everyXHours?.hours.toString() ?? '';

        medicineGetxController.startMedicineTimeController.text =
            reminder.customReminder.everyXHours?.startTime ?? '';

        medicineGetxController.endMedicineTimeController.text =
            reminder.customReminder.everyXHours?.endTime ?? '';
      }
    }

    debugPrint("Start Date: ${reminder.startDate}");
    debugPrint("End Date: ${reminder.endDate}");

    final savedStartDate = (reminder.startDate ?? '').trim();
    final savedEndDate = (reminder.endDate ?? '').trim();

    medicineGetxController.startDateString.value =
        savedStartDate.isEmpty ? 'Start Date' : savedStartDate;
    medicineGetxController.endDateString.value =
        savedEndDate.isEmpty ? 'End Date' : savedEndDate;

    medicineGetxController.startMedicineDateController.text = savedStartDate;
    medicineGetxController.endMedicineDateController.text = savedEndDate;

    DateTime? parseSavedDate(String raw) {
      if (raw.isEmpty) return null;
      final isoParsed = DateTime.tryParse(raw);
      if (isoParsed != null) return isoParsed;
      try {
        final partial = DateFormat('dd MMMM').parseStrict(raw);
        final now = DateTime.now();
        return DateTime(now.year, partial.month, partial.day);
      } catch (_) {
        return null;
      }
    }

    medicineGetxController.startDate.value = parseSavedDate(savedStartDate);
    medicineGetxController.endDate.value = parseSavedDate(savedEndDate);

    /// -------- REMIND BEFORE ----------
    if (reminder.remindBefore != null) {
      final rb = reminder.remindBefore;

      debugPrint("Remind Before Present");
      debugPrint("Remind Time: ${rb?.time}");
      debugPrint("Remind Unit: ${rb?.unit}");

      medicineGetxController.medicineRemindMeBeforeOption.value = 0;

      medicineGetxController.medicineTimeBeforeController.text =
          rb?.time.toString() ?? '';
      reminderController.selectedValue.value = rb?.unit ?? '';
    } else {
      debugPrint("No RemindBefore data associated with this reminder.");
    }

    debugPrint("================ END MEDICINE LOAD ================\n");
  }

  @override
  void dispose() {
    reminderController.resetForm();
    medicineGetxController.resetForm();
    mealGetxController.resetForm();
    eventGetxController.resetForm();
    waterGetxController.resetForm();
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

  Future<void> _selectTime({
    required TextEditingController textController,
    String? category,
  }) async {
    print("Selecting time... ${textController.toString()} ");
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    print("Picked time: $picked");
    reminderController.pickedTime.value = picked;

    if (picked != null) {
      final hour = picked.hourOfPeriod.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';

      if (category == "Medicine") {
        final startDate = reminderController.startDate.value ?? DateTime.now();
        final endDate = reminderController.endDate.value ?? startDate;
        final count =
            medicineGetxController.frequencyNum[medicineGetxController
                .selectedFrequency
                .value] ??
            1;

        final difference = endDate.difference(startDate);
        if (endDate.isBefore(startDate)) {
          CustomSnackbar.showError(
            context: context,
            title: 'Invalid Date',
            message: 'End date cannot be before start date',
          );
          return;
        }

        if (medicineGetxController.scheduledTimes.length < count) {
          final scheduledTime = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
            picked.hour,
            picked.minute,
          );

          medicineGetxController.scheduledTimes.add(scheduledTime);
        }
      }

      textController.text = '$hour:$minute $period';
    }
  }

  Future<void> _selectStartTime({required String text}) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );

    if (picked != null) {
      reminderController.pickedTime.value = picked;
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
      reminderController.pickedTime.value = picked;
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

  String _formatDosage(String type, num dosage) {
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
          const SizedBox(height: 16),
          _buildCategorySelection(),
          const SizedBox(height: 16),
          Obx(() => _buildCategorySpecificFields()),
          const SizedBox(height: 16),
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
                    ? () async {
                      final result = await reminderController.validateAndSave(
                        context: context,
                        dosage: dosage,
                      );
                      if (result == true) {
                        medicineGetxController.medicineList.value = [];
                        waterGetxController.waterList.value = [];
                        eventGetxController.eventList.value = [];
                        mealGetxController.mealsList.value = [];
                        // Navigator.pop(context);
                      }
                      //Navigator.pop(context);
                    }
                    : () async {
                      final result = await reminderController.validateAndUpdate(
                        context: context,
                        reminder: widget.reminder!,

                        dosage: dosage,
                      );
                      if (result == true) {
                        medicineGetxController.medicineList.value = [];
                        waterGetxController.waterList.value = [];
                        eventGetxController.eventList.value = [];
                        mealGetxController.mealsList.value = [];
                        // Navigator.pop(context);
                      }
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
          controller: reminderController.titleController,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [FirstLetterUpperCaseFormatter()],
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
            items: reminderController.categories,
            selectedItem: reminderController.selectedCategory.value,
            onSelected: (category) {
              reminderController.selectedCategory.value = category;
            },
            iconBuilder:
                (category, isSelected) =>
                    Image.asset(reminderController.getCategoryIcon(category)),
            labelBuilder: (category) => category,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySpecificFields() {
    switch (reminderController.selectedCategory.value) {
      case 'medicine':
        return _buildMedicineFields();
      case 'water':
        return _buildWaterFields();
      case 'meal':
        return _buildMealFields();
      case 'event':
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
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [FirstLetterUpperCaseFormatter()],
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
              12,
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
                final displayDosage = _formatDosage(selected, dosage);

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
          selectedItem: medicineGetxController.selectedWhenToTake.value,
          onSelected: (value) {
            medicineGetxController.selectedWhenToTake.value = value;
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
            medicineGetxController.scheduledTimes.clear();
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
                  ? _setMedicineTimes(
                    title: 'Medicine',
                    startTimeController:
                        medicineGetxController.startMedicineTimeController,
                    endTimeController:
                        medicineGetxController.endMedicineTimeController,
                  )
                  : SizedBox.shrink());
        }),
        const SizedBox(height: 20),
        Text("Date", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Obx(() {
          return Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed:
                        () => _selectDate(
                          date: medicineGetxController.startDate,
                          dateString: medicineGetxController.startDateString,
                        ),
                    style: ButtonStyle(
                      side: WidgetStateProperty.resolveWith<BorderSide?>((
                        states,
                      ) {
                        if (states.contains(WidgetState.pressed)) {
                          return BorderSide(color: AppColors.primaryColor);
                        }
                        return BorderSide(color: grey);
                      }),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    child: Text(
                      medicineGetxController.startDateString.value ==
                              'Start Date'
                          ? 'Start Date'
                          : medicineGetxController.startDateString.value,
                      style: TextStyle(
                        color:
                            medicineGetxController.startDateString.value ==
                                    "Start Date"
                                ? grey
                                : black,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed:
                        () => _selectDate(
                          date: medicineGetxController.endDate,
                          dateString: medicineGetxController.endDateString,
                        ),
                    style: ButtonStyle(
                      side: WidgetStateProperty.resolveWith<BorderSide?>((
                        states,
                      ) {
                        if (states.contains(WidgetState.pressed)) {
                          return BorderSide(color: AppColors.primaryColor);
                        }
                        return BorderSide(color: grey);
                      }),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    child: Text(
                      medicineGetxController.endDateString.value == 'End Date'
                          ? 'End Date'
                          : medicineGetxController.endDateString.value,
                      style: TextStyle(
                        color:
                            medicineGetxController.endDateString.value ==
                                    "End Date"
                                ? grey
                                : black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),

        const SizedBox(height: 20),

        //Remind before medicine
        Obx(() {
          final isSelected =
              medicineGetxController.medicineRemindMeBeforeOption.value == 0;
          return Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Theme(
                data: Theme.of(context).copyWith(unselectedWidgetColor: grey),
                child: CustomRadio(
                  selected: isSelected,
                  onTap: () {
                    final rx =
                        medicineGetxController.medicineRemindMeBeforeOption;
                    if (rx.value == 0) {
                      rx.value = null;
                      medicineGetxController.medicineTimeBeforeController
                          .clear();
                    } else {
                      rx.value = 0;
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Remind me ",
                style: TextStyle(color: isSelected ? black : grey),
              ),
              SizedBox(
                width: 50,
                height: 36,
                child: TextField(
                  controller:
                      medicineGetxController.medicineTimeBeforeController,
                  enabled: isSelected,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? black : grey,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              SizedBox(
                width: 70,
                height: 35,
                child: DropdownButton<String>(
                  dropdownColor: white,
                  value: reminderController.selectedValue.value,
                  isExpanded: false,
                  iconSize: 18,
                  items:
                      ['minutes', 'hours']
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected ? black : grey,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (newValue) {
                    if (newValue != null)
                      reminderController.selectedValue.value = newValue;
                  },
                ),
              ),
              Text(
                " before",
                style: TextStyle(color: isSelected ? black : grey),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildWaterFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _setWaterTimes(
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
        Obx(() {
          final selected = waterGetxController.waterReminderOption.value;
          final timesSelected = selected == Option.times;
          final intervalSelected = selected == Option.interval;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(unselectedWidgetColor: grey),
                    child: Radio<Option>(
                      value: Option.times,
                      activeColor: black,
                      groupValue: selected,
                      onChanged: (value) {
                        if (value != null) {
                          waterGetxController.waterReminderOption.value = value;
                        }
                      },
                    ),
                  ),
                  Text(
                    "Remind me",
                    style: TextStyle(color: timesSelected ? black : grey),
                  ),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: waterGetxController.timesPerDayController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: timesSelected ? black : grey),
                      enabled: timesSelected,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      // onChanged: (val) {
                      //   waterGetxController.savedTimes.value =
                      //       int.tryParse(val) ?? 0;
                      // },
                    ),
                  ),
                  Obx(() {
                    final t = waterGetxController.savedTimes.value;
                    return Text(
                      "time${t > 1 ? 's' : ''}",
                      style: TextStyle(color: timesSelected ? black : grey),
                    );
                  }),

                  Text(
                    "a",
                    style: TextStyle(color: timesSelected ? black : grey),
                  ),
                  Text(
                    "day",
                    style: TextStyle(color: timesSelected ? black : grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(unselectedWidgetColor: grey),
                    child: Radio<Option>(
                      value: Option.interval,
                      activeColor: black,
                      groupValue: waterGetxController.waterReminderOption.value,
                      onChanged: (value) {
                        if (value != null) {
                          waterGetxController.waterReminderOption.value = value;
                        }
                      },
                    ),
                  ),
                  Text(
                    "Remind",
                    style: TextStyle(color: intervalSelected ? black : grey),
                  ),
                  Text(
                    "me",
                    style: TextStyle(color: intervalSelected ? black : grey),
                  ),
                  Text(
                    "every",
                    style: TextStyle(color: intervalSelected ? black : grey),
                  ),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: waterGetxController.everyHourController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: intervalSelected ? black : grey),
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
                      // onChanged: (_) {
                      //   waterGetxController.everyXhours.value =
                      //       int.tryParse(
                      //         waterGetxController.everyHourController.text,
                      //       ) ??
                      //       0;
                      // },
                    ),
                  ),

                  Obx(() {
                    final t = waterGetxController.everyXhours.value;
                    return Text(
                      "hour${t > 1 ? 's' : ''}",
                      style: TextStyle(color: intervalSelected ? black : grey),
                    );
                  }),

                  Text(
                    "a",
                    style: TextStyle(color: intervalSelected ? black : grey),
                  ),
                  Text(
                    "day",
                    style: TextStyle(color: intervalSelected ? black : grey),
                  ),
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
          );
        }),
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
          controller: mealGetxController.timeController,
          readOnly: true,
          onTap:
              () => _selectTime(
                textController: mealGetxController.timeController,
              ),
          decoration: commonInputDecoration(hint: '10:00 AM'),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEventFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Set Event Time",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: reminderController.timeController,
          readOnly: true,
          onTap:
              () => _selectTime(
                textController: reminderController.timeController,
              ),
          decoration: commonInputDecoration(hint: '09:28 AM'),
        ),
        const SizedBox(height: 16),
        Text("Event Date", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Obx(
            () => OutlinedButton(
              onPressed:
                  () => _selectDate(
                    date: reminderController.startDate,
                    dateString: reminderController.startDateString,
                  ),
              style: ButtonStyle(
                side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return BorderSide(color: AppColors.primaryColor);
                  }
                  return BorderSide(color: grey, width: 0.0);
                }),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              child: Text(
                reminderController.startDate.value == null
                    ? 'Start Date'
                    : reminderController.startDateString.value,
                style: TextStyle(
                  color:
                      reminderController.startDateString.value == "Start Date"
                          ? grey
                          : black,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              "Reminder before event",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Obx(() {
              // Check if "Remind me" option is selected
              final isSelected =
                  eventGetxController.eventRemindMeBefore.value == 0;

              // Get the number input
              final enteredValue =
                  int.tryParse(
                    eventGetxController.eventTimeBeforeController.text,
                  ) ??
                  0;

              // Get the selected unit from dropdown
              final unit = reminderController.selectedValue.value;

              // Proper pluralization
              final unitText =
                  enteredValue == 1 ? unit.substring(0, unit.length - 1) : unit;

              return Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Custom radio
                  CustomRadio(
                    selected: isSelected,
                    onTap: () {
                      final rx = eventGetxController.eventRemindMeBefore;
                      if (rx.value == 0) {
                        rx.value = null;
                        eventGetxController.eventTimeBeforeController.clear();
                      } else {
                        rx.value = 0;
                      }
                    },
                  ),
                  const SizedBox(width: 8),

                  // "Remind me" text
                  Text(
                    "Remind me",
                    style: TextStyle(color: isSelected ? black : grey),
                  ),
                  const SizedBox(width: 4),

                  // Number input
                  SizedBox(
                    width: 50,
                    height: 35,
                    child: TextField(
                      controller: eventGetxController.eventTimeBeforeController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? black : grey,
                      ),
                      enabled: isSelected,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Dropdown for minutes/hours
                  SizedBox(
                    width: 70,
                    height: 35,
                    child: DropdownButton<String>(
                      value: reminderController.selectedValue.value,
                      dropdownColor: white,
                      isExpanded: false,
                      iconSize: 18,
                      items:
                          ['minutes', 'hours']
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected ? black : grey,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          reminderController.selectedValue.value = newValue;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Pluralized unit + "before"
                  Text(
                    " before",
                    style: TextStyle(color: isSelected ? black : grey),
                  ),
                ],
              );
            }),
          ],
        ),
        // Obx(
        //   () =>
        //       eventGetxController.eventList.isEmpty
        //           ? SizedBox.shrink()
        //           : SizedBox(
        //             height: getListHeight(
        //               eventGetxController.eventList.length,
        //               itemHeight,
        //               maxHeight,
        //             ),
        //             child: ListView.separated(
        //               separatorBuilder: (context, index) => SizedBox(height: 1),
        //               itemCount: eventGetxController.eventList.length,
        //               itemBuilder: (context, index) {
        //                 final reminderMap =
        //                     eventGetxController.eventList[index];
        //                 final title = reminderMap.keys.first;
        //                 final alarm = reminderMap.values.first;
        //                 return ListTile(
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
        //                           eventGetxController.eventList,
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
                  medicineGetxController.timesPerDayController.text =
                      medicineGetxController.timeControllers.length.toString();
                  return Row(
                    children: [
                      Flexible(
                        flex: 12,
                        child: TextField(
                          controller: controller,
                          readOnly: true,
                          onTap: () => _selectTime(textController: controller),
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
                          onTap: () {
                            // final count =
                            //     medicineGetxController.frequencyNum[medicineGetxController.selectedFrequency.value] ?? 1;
                            //
                            // if (medicineGetxController.scheduledTimes.length >= count) {
                            //   CustomSnackbar.showError(
                            //     context: context,
                            //     title: 'Limit reached',
                            //     message: 'You can only select $count time(s)',
                            //   );
                            //   return;
                            // }
                            _selectTime(
                              textController: controller,
                              category: "Medicine",
                            );
                          },
                          decoration: commonInputDecoration(hint: "09:30 AM"),
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
      final t = medicineGetxController.savedTimes.value;
      final e = medicineGetxController.everyXhours.value;

      // if (medicineGetxController.selectedFrequency.value == 'Custom') {
      //   medicineGetxController.timesPerDayController.text = 4.toString();
      //   medicineGetxController.everyHourController.text = 4.toString();
      // }

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
              Text(
                "Remind me",
                style: TextStyle(color: timesSelected ? black : grey),
              ),
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
              Text(
                "time${t > 1 ? 's' : ''}",
                style: TextStyle(color: timesSelected ? black : grey),
              ),

              Text("a", style: TextStyle(color: timesSelected ? black : grey)),
              Text(
                "day",
                style: TextStyle(color: timesSelected ? black : grey),
              ),
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
              Text(
                "Remind me every",
                style: TextStyle(color: intervalSelected ? black : grey),
              ),
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

              Text(
                "hour${e > 1 ? 's' : ''}",
                style: TextStyle(color: intervalSelected ? black : grey),
              ),

              Text(
                "a",
                style: TextStyle(color: intervalSelected ? black : grey),
              ),
              Text(
                "day",
                style: TextStyle(color: intervalSelected ? black : grey),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _setMedicineTimes({
    required String title,
    required TextEditingController startTimeController,
    required TextEditingController endTimeController,
  }) {
    return Obx(() {
      final isCustom =
          medicineGetxController.selectedFrequency.value == 'Custom';
      return isCustom
          ? _setWaterTimes(
            title: title,
            startTimeController: startTimeController,
            endTimeController: endTimeController,
          )
          : _medicineTimesField();
    });
  }

  Widget _setWaterTimes({
    required String title,
    required TextEditingController startTimeController,
    required TextEditingController endTimeController,
  }) {
    return Column(
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
                      () => _selectTime(
                        textController: startTimeController,
                        category: "Water",
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
                        () => _selectTime(
                          textController: endTimeController,
                          category: "Water",
                        ),
                    decoration: commonInputDecoration(hint: '11:30 PM'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration commonInputDecoration({String? hint}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: grey, width: 0),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: grey),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Notes", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: reminderController.notesController,
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

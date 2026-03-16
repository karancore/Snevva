import '../hive_models/reminder_payload_model.dart';
import '../reminders/medicine_reminder_model.dart'
    hide CustomReminder, Dosage, TimesPerDay, EveryXHours, RemindBefore;
import 'package:snevva/common/global_variables.dart' show Option;

extension MedicineToReminderMapper on MedicineReminderModel {
  ReminderPayloadModel toReminderPayload() {
    final hasTimes = customReminder.timesPerDay != null;
    final hasInterval = customReminder.everyXHours != null;
    return ReminderPayloadModel(
      id: id,
      title: title,
      category: category,
      whenToTake: whenToTake,

      medicineName: medicineName,
      medicineType: medicineType,

      dosage: Dosage(value: dosage.value.toInt(), unit: dosage.unit),

      medicineFrequencyPerDay: medicineFrequencyPerDay,
      reminderFrequencyType: reminderFrequencyType,

      customReminder: CustomReminder(
        type: hasInterval ? Option.interval : (hasTimes ? Option.times : null),
        timesPerDay:
            customReminder.timesPerDay != null
                ? TimesPerDay(
                  count: customReminder.timesPerDay!.count.toString(),
                  list: customReminder.timesPerDay!.list,
                )
                : null,
        everyXHours:
            customReminder.everyXHours != null
                ? EveryXHours(
                  hours:
                      int.tryParse(
                        customReminder.everyXHours!.hours.toString(),
                      ) ??
                      0,
                  startTime: customReminder.everyXHours!.startTime,
                  endTime: customReminder.everyXHours!.endTime,
                )
                : null,
      ),

      remindBefore:
          remindBefore != null
              ? RemindBefore(time: remindBefore!.time, unit: remindBefore!.unit)
              : null,

      startDate: startDate,
      endDate: endDate,
      notes: notes,
    );
  }
}

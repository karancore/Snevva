import '../hive_models/reminder_payload_model.dart';
import '../medicine_reminder_model.dart' hide CustomReminder, Dosage, TimesPerDay, EveryXHours, RemindBefore;

extension MedicineToReminderMapper on MedicineReminderModel {
  ReminderPayloadModel toReminderPayload() {
    return ReminderPayloadModel(
      id: id,
      title: title,
      category: category,

      medicineName: medicineName,
      medicineType: medicineType,

      dosage: Dosage(
        value: dosage.value.toInt(),
        unit: dosage.unit,
      ),

      medicineFrequencyPerDay: medicineFrequencyPerDay,
      reminderFrequencyType: reminderFrequencyType,

      customReminder: CustomReminder(
        timesPerDay: customReminder.timesPerDay != null
            ? TimesPerDay(
          count:
            customReminder.timesPerDay!.count.toString(),
          list: customReminder.timesPerDay!.list,
        )
            : null,
        everyXHours: customReminder.everyXHours != null
            ? EveryXHours(
          hours: int.tryParse(
            customReminder.everyXHours!.hours.toString(),
          ) ??
              0,
          startTime: customReminder.everyXHours!.startTime,
          endTime: customReminder.everyXHours!.endTime,
        )
            : null,
      ),

      remindBefore: remindBefore != null
          ? RemindBefore(
        time: remindBefore!.time,
        unit: remindBefore!.unit,
      )
          : null,

      startDate: startDate,
      endDate: endDate,
      notes: notes,
    );
  }
}
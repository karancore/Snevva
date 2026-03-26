import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/models/reminders/water_reminder_model.dart';

extension WaterToMedicineMapper on WaterReminderModel {
  ReminderPayloadModel toReminderPayload() {
    return ReminderPayloadModel(
      id: id,
      title: title,
      category: category,
      customReminder: CustomReminder(
        type: type,
        timesPerDay:
            TimesPerDay(
              count: timesPerDay,
              list: alarms.map((e) => e.dateTime.toIso8601String()).toList(),
            ),
        everyXHours:
            interval != null
                ? EveryXHours(
                  hours: int.tryParse(interval ?? '') ?? 0,
                  startTime: waterReminderStartTime,
                  endTime: waterReminderEndTime,
                )
                : null,
      ),
    );
  }
}

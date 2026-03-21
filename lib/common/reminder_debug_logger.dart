import 'package:flutter/foundation.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';

enum ReminderLogSource { api, local }

void logReminderStats({
  required List api,
  required List local,
  required List finalList,
}) {
  debugPrint('===== REMINDER DEBUG STATS =====');
  debugPrint('[API_REMINDER] count: ${api.length}');
  debugPrint('[LOCAL_REMINDER] count: ${local.length}');
  debugPrint('[FINAL_REMINDER_LIST] count: ${finalList.length}');
}

void logReminderSourceSnapshot({
  required ReminderLogSource source,
  required List<ReminderPayloadModel> reminders,
  bool logItems = true,
}) {
  final countTag =
      source == ReminderLogSource.api ? '[API_REMINDER]' : '[LOCAL_REMINDER]';
  final itemTag =
      source == ReminderLogSource.api
          ? '[API_REMINDER_ITEM]'
          : '[LOCAL_REMINDER_ITEM]';

  debugPrint('$countTag count: ${reminders.length}');

  if (!logItems) return;

  for (final reminder in reminders) {
    debugPrint(
      '$itemTag id: ${reminder.id} category: ${reminder.category} title: ${reminder.title}',
    );
  }
}

void logFinalReminderListSnapshot(List<ReminderPayloadModel> finalList) {
  debugPrint('[FINAL_REMINDER_LIST] count: ${finalList.length}');
}

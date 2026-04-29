import 'package:snevva/models/hive_models/reminder_payload_model.dart';

class ReminderApiMapper {
  static const Map<String, String> _apiToInternalCategory = {
    'Medicine': 'medicine',
    'Water': 'water',
    'Meal': 'meal',
    'Event': 'event',
  };

  static const Map<String, String> _internalToApiCategory = {
    'medicine': 'Medicine',
    'water': 'Water',
    'meal': 'Meal',
    'event': 'Event',
  };

  static ReminderPayloadModel fromApiJson(
    Map<String, dynamic> json, {
    required String timezoneIdFallback,
  }) {
    final mapped = Map<String, dynamic>.from(json);
    final category = mapped['Category']?.toString();
    if (category != null && _apiToInternalCategory.containsKey(category)) {
      mapped['Category'] = _apiToInternalCategory[category];
    }
    return ReminderPayloadModel.fromApiJson(
      mapped,
      timezoneIdFallback: timezoneIdFallback,
    );
  }

  static Map<String, dynamic> toApiJson(ReminderPayloadModel reminder) {
    final mapped = reminder.toApiJson();
    final category = mapped['Category']?.toString().trim().toLowerCase();
    if (category != null && _internalToApiCategory.containsKey(category)) {
      mapped['Category'] = _internalToApiCategory[category];
    }
    return mapped;
  }
}

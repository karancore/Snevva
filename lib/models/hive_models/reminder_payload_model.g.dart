// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_payload_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderPayloadModelAdapter extends TypeAdapter<ReminderPayloadModel> {
  @override
  final int typeId = 20;

  @override
  ReminderPayloadModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReminderPayloadModel(
      id: fields[0] as int,
      title: fields[1] as String,
      category: fields[2] as String,
      medicineName: fields[3] as String?,
      medicineType: fields[4] as String?,
      dosage: fields[5] as Dosage?,
      medicineFrequencyPerDay: fields[6] as String?,
      reminderFrequencyType: fields[7] as String?,
      customReminder: fields[8] as CustomReminder,
      remindBefore: fields[9] as RemindBefore?,
      startDate: fields[10] as String?,
      endDate: fields[11] as String?,
      notes: fields[12] as String?,
      whenToTake: fields[13] as String?,
      startWaterTime: fields[14] as String?,
      endWaterTime: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderPayloadModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.medicineName)
      ..writeByte(4)
      ..write(obj.medicineType)
      ..writeByte(5)
      ..write(obj.dosage)
      ..writeByte(6)
      ..write(obj.medicineFrequencyPerDay)
      ..writeByte(7)
      ..write(obj.reminderFrequencyType)
      ..writeByte(8)
      ..write(obj.customReminder)
      ..writeByte(9)
      ..write(obj.remindBefore)
      ..writeByte(10)
      ..write(obj.startDate)
      ..writeByte(11)
      ..write(obj.endDate)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.whenToTake)
      ..writeByte(14)
      ..write(obj.startWaterTime)
      ..writeByte(15)
      ..write(obj.endWaterTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderPayloadModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DosageAdapter extends TypeAdapter<Dosage> {
  @override
  final int typeId = 21;

  @override
  Dosage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Dosage(value: fields[0] as num, unit: fields[1] as String);
  }

  @override
  void write(BinaryWriter writer, Dosage obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.value)
      ..writeByte(1)
      ..write(obj.unit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DosageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CustomReminderAdapter extends TypeAdapter<CustomReminder> {
  @override
  final int typeId = 22;

  @override
  CustomReminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomReminder(
      type: fields[0] as Option?,
      timesPerDay: fields[1] as TimesPerDay?,
      everyXHours: fields[2] as EveryXHours?,
    );
  }

  @override
  void write(BinaryWriter writer, CustomReminder obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.timesPerDay)
      ..writeByte(2)
      ..write(obj.everyXHours);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TimesPerDayAdapter extends TypeAdapter<TimesPerDay> {
  @override
  final int typeId = 23;

  @override
  TimesPerDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimesPerDay(
      count: fields[0] as String,
      list: (fields[1] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, TimesPerDay obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.count)
      ..writeByte(1)
      ..write(obj.list);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimesPerDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EveryXHoursAdapter extends TypeAdapter<EveryXHours> {
  @override
  final int typeId = 24;

  @override
  EveryXHours read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EveryXHours(
      hours: fields[0] as int,
      startTime: fields[1] as String,
      endTime: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, EveryXHours obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.hours)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EveryXHoursAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RemindBeforeAdapter extends TypeAdapter<RemindBefore> {
  @override
  final int typeId = 25;

  @override
  RemindBefore read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RemindBefore(time: fields[0] as int, unit: fields[1] as String);
  }

  @override
  void write(BinaryWriter writer, RemindBefore obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.time)
      ..writeByte(1)
      ..write(obj.unit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemindBeforeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_payload_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderPayloadModelAdapter extends TypeAdapter<ReminderPayloadModel> {
  @override
  final int typeId = 10;

  @override
  ReminderPayloadModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReminderPayloadModel(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      category: fields[3] as String,
      medicineNames: (fields[4] as List).cast<String>(),
      startDay: fields[5] as int,
      startMonth: fields[6] as int,
      startYear: fields[7] as int,
      remindTimes: (fields[8] as List).cast<String>(),
      remindFrequencyHour: fields[9] as int,
      remindFrequencyCount: fields[10] as int,
      isActive: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderPayloadModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.medicineNames)
      ..writeByte(5)
      ..write(obj.startDay)
      ..writeByte(6)
      ..write(obj.startMonth)
      ..writeByte(7)
      ..write(obj.startYear)
      ..writeByte(8)
      ..write(obj.remindTimes)
      ..writeByte(9)
      ..write(obj.remindFrequencyHour)
      ..writeByte(10)
      ..write(obj.remindFrequencyCount)
      ..writeByte(11)
      ..write(obj.isActive);
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

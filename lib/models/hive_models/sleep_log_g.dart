import 'package:hive/hive.dart';
import 'package:snevva/models/hive_models/sleep_log.dart';

class SleepLogAdapter extends TypeAdapter<SleepLog> {
  @override
  final int typeId = 4;

  @override
  SleepLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepLog(
      date: fields[0] as DateTime,
      durationMinutes: fields[1] as int,
      startTime: fields[2] as DateTime?,
      endTime: fields[3] as DateTime?,
      goalMinutes: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, SleepLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.durationMinutes)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.goalMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

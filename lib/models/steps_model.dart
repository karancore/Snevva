import 'package:hive/hive.dart';

part 'steps_model.g.dart'; // for generated adapter

@HiveType(typeId: 0)
class StepEntry extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  int steps; // ✅ store daily total steps (delta), not baseline

  StepEntry({required this.date, required this.steps});
}

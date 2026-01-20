
import 'package:hive/hive.dart';
import 'package:snevva/common/global_variables.dart';

class Boxes{
  static Box getData() => Hive.box(reminderBox);
}
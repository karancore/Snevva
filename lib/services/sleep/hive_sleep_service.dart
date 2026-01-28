import 'package:get/get_state_manager/src/rx_flutter/rx_disposable.dart';
import 'package:hive/hive.dart';

import '../../models/hive_models/sleep_log.dart';

class HiveSleepService extends GetxService {
  static const boxName = 'sleep_log';

  Future<Box<SleepLog>> _openBox() async {
    return Hive.openBox<SleepLog>(boxName);
  }

  Future<Map<String, Duration>> loadWeeklySleep() async {
    final box = await _openBox();
    final Map<String, Duration> data = {};

    for (final log in box.values) {
      data[_dateKey(log.date)] =
          Duration(minutes: log.durationMinutes);
    }
    return data;
  }

  Future<void> saveSleep(DateTime bedDate, Duration duration) async {
    final box = await _openBox();
    final key = _dateKey(bedDate);

    await box.put(
      key,
      SleepLog(
        date: DateTime(bedDate.year, bedDate.month, bedDate.day),
        durationMinutes: duration.inMinutes,
      ),
    );
  }

  String _dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}

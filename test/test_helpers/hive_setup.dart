import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:snevva/models/hive_models/sleep_log.dart';
import 'package:snevva/models/hive_models/sleep_log_g.dart';

Future<void> setupHiveForTests() async {
  await setUpTestHive();

  // Register all Hive adapters
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(SleepLogAdapter());
  }
}

Future<void> cleanupHiveAfterTests() async {
  await tearDownTestHive();
  await Hive.close();
}

Future<Box<SleepLog>> openTestSleepBox() async {
  await Hive.deleteBoxFromDisk('sleep_log');
  return await Hive.openBox<SleepLog>('sleep_log');
}

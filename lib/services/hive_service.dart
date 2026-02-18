import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/hive_models/sleep_log.dart';
import '../models/hive_models/sleep_log_g.dart';
import '../models/hive_models/steps_model.dart';
import '../models/hive_models/reminder_payload_model.dart';

class HiveService {
  HiveService._internal();

  static final HiveService _instance = HiveService._internal();

  factory HiveService() => _instance;

  bool _initialized = false;

  late Box<StepEntry> stepHistory;
  late Box<SleepLog> sleepLog;
  late Box reminders;
  late Box medicine;

  // UI isolate init
  Future<void> initMain() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    _registerAdapters();
    await _openBoxes();

    _initialized = true;
    print("✅ Hive initialized (MAIN)");
  }

  // background isolate init
  Future<void> initBackground() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path); // IMPORTANT: NOT initFlutter

    _registerAdapters();
    await _openBoxes();

    _initialized = true;
    print("✅ Hive initialized (BACKGROUND)");
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(StepEntryAdapter().typeId)) {
      Hive.registerAdapter(StepEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(SleepLogAdapter().typeId)) {
      Hive.registerAdapter(SleepLogAdapter());
    }
    if (!Hive.isAdapterRegistered(ReminderPayloadModelAdapter().typeId)) {
      Hive.registerAdapter(ReminderPayloadModelAdapter());
    }
    if (!Hive.isAdapterRegistered(DosageAdapter().typeId)) {
      Hive.registerAdapter(DosageAdapter());
    }
    if (!Hive.isAdapterRegistered(CustomReminderAdapter().typeId)) {
      Hive.registerAdapter(CustomReminderAdapter());
    }
    if (!Hive.isAdapterRegistered(TimesPerDayAdapter().typeId)) {
      Hive.registerAdapter(TimesPerDayAdapter());
    }
    if (!Hive.isAdapterRegistered(EveryXHoursAdapter().typeId)) {
      Hive.registerAdapter(EveryXHoursAdapter());
    }
    if (!Hive.isAdapterRegistered(RemindBeforeAdapter().typeId)) {
      Hive.registerAdapter(RemindBeforeAdapter());
    }
  }

  Future<void> _openBoxes() async {
    stepHistory = await Hive.openBox<StepEntry>('step_history');
    sleepLog = await Hive.openBox<SleepLog>('sleep_log');
    reminders = await Hive.openBox('reminders_box');
    medicine = await Hive.openBox('medicine_list');
  }

  Future<void> resetAppData() async {
    try {
      await _clearTypedBox<StepEntry>('step_history');
      await _clearTypedBox<SleepLog>('sleep_log');
      await _clearUntypedBox('reminders_box');
      await _clearUntypedBox('medicine_list');

      print("🔥 All Hive data cleared (Logout Reset)");
    } catch (e) {
      print("❌ App reset failed: $e");
      rethrow;
    }
  }

  Future<void> _clearTypedBox<T>(String name) async {
    final box =
        Hive.isBoxOpen(name) ? Hive.box<T>(name) : await Hive.openBox<T>(name);
    await box.clear();
  }

  Future<void> _clearUntypedBox(String name) async {
    final box = Hive.isBoxOpen(name) ? Hive.box(name) : await Hive.openBox(name);
    await box.clear();
  }
}

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
  Future<void>? _initFuture;

  // UI isolate init
  Future<void> initMain() async {
    await _initializeCore(label: "MAIN");
  }

  // background isolate init
  Future<void> initBackground() async {
    await _initializeCore(label: "BACKGROUND");
  }

  Future<void> _initializeCore({required String label}) async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture!;

    _initFuture = () async {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
      _registerAdapters();
      _initialized = true;
      print("✅ Hive initialized ($label) - adapters registered");
    }();

    await _initFuture;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await initMain();
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

  Future<Box<StepEntry>> stepHistoryBox() async {
    await _ensureInitialized();
    if (Hive.isBoxOpen('step_history')) {
      return Hive.box<StepEntry>('step_history');
    }
    return Hive.openBox<StepEntry>('step_history');
  }

  Future<Box<SleepLog>> sleepLogBox() async {
    await _ensureInitialized();
    if (Hive.isBoxOpen('sleep_log')) {
      return Hive.box<SleepLog>('sleep_log');
    }
    return Hive.openBox<SleepLog>('sleep_log');
  }

  Future<Box> remindersBox() async {
    await _ensureInitialized();
    if (Hive.isBoxOpen('reminders_box')) {
      return Hive.box('reminders_box');
    }
    return Hive.openBox('reminders_box');
  }

  Future<Box> medicineBox() async {
    await _ensureInitialized();
    if (Hive.isBoxOpen('medicine_list')) {
      return Hive.box('medicine_list');
    }
    return Hive.openBox('medicine_list');
  }

  Future<void> resetAppData() async {
    try {
      final step = await stepHistoryBox();
      final sleep = await sleepLogBox();
      final reminders = await remindersBox();
      final medicine = await medicineBox();

      await step.clear();
      await sleep.clear();
      await reminders.clear();
      await medicine.clear();

      print("🔥 All Hive data cleared (Logout Reset)");
    } catch (e) {
      print("❌ App reset failed: $e");
      rethrow;
    }
  }
}

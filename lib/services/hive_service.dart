import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../consts/consts.dart';
import '../models/hive_models/reminder_payload_model.dart';

// Step and sleep Hive boxes have been migrated to FileStorageService (daily JSON
// files). HiveService now only manages the Reminders and Medicine boxes.
//
// Intentionally kept:
//   • remindersBox() — ReminderPayloadModel objects (low-frequency, tiny)
//   • medicineBox()  — medicine_list (low-frequency, tiny)
//   • resetAppData() — still clears reminders/medicine on logout

class HiveService {
  HiveService._internal();

  static final HiveService _instance = HiveService._internal();

  factory HiveService() => _instance;

  bool _initialized = false;
  Future<void>? _initFuture;

  // UI isolate init — only reminders/medicine boxes are needed
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
      debugPrint("✅ Hive initialized ($label) — reminders/medicine only");
    }();

    await _initFuture;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await initMain();
  }

  void _registerAdapters() {
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

  // ──────────────────────────────────────────────
  // ACTIVE BOXES — reminders & medicine only
  // ──────────────────────────────────────────────

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

  // ──────────────────────────────────────────────
  // RESET — clears reminders/medicine on logout
  // ──────────────────────────────────────────────

  Future<void> resetAppData() async {
    try {
      final reminders = await remindersBox();
      final medicine = await medicineBox();

      await reminders.clear();
      await medicine.clear();

      debugPrint("🔥 Reminders/medicine Hive data cleared (Logout Reset)");
    } catch (e) {
      debugPrint("❌ App reset failed: $e");
      rethrow;
    }
  }
}

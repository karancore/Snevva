import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// MUST be top level
@pragma('vm:entry-point')
void startSleepCallback() {
  FlutterForegroundTask.setTaskHandler(SleepService());
}

class SleepService extends TaskHandler {
  bool screenOff = false;
  DateTime? screenOffAt;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print("SleepService Started");
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (screenOff && screenOffAt != null) {
      final diff = DateTime.now().difference(screenOffAt!).inMinutes;
      if (diff >= 15) {
        FlutterForegroundTask.sendDataToMain({"event": "sleep_start"});
      }
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      if (data["event"] == "screen_off") {
        screenOff = true;
        screenOffAt = DateTime.now();
      }

      if (data["event"] == "screen_on") {
        if (screenOff == true) {
          FlutterForegroundTask.sendDataToMain({"event": "sleep_end"});
        }
        screenOff = false;
        screenOffAt = null;
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print("SleepService Destroyed");
  }
}

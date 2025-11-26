import 'dart:async';
import 'package:get/get.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Controllers/SleepScreen/sleep_controller.dart';

class SleepTrackerService {
  final _screenState = Screen();

  StreamSubscription<ScreenStateEvent>? _subscription;

  void startListening() {
    _subscription = _screenState.screenStateStream.listen((event) async {
      final prefs = await SharedPreferences.getInstance();

      if (event == ScreenStateEvent.SCREEN_OFF) {

        prefs.setString("sleep_start", DateTime.now().toIso8601String());
      } else if (event == ScreenStateEvent.SCREEN_ON) {
        final storedStart = prefs.getString("sleep_start");
        if (storedStart != null) {
          final sleepStart = DateTime.parse(storedStart);
          final wakeUp = DateTime.now();
          final duration = wakeUp.difference(sleepStart);

          if (duration.inHours >= 3) {
            final controller = Get.find<SleepController>();
            controller.updateBedTimeFromTimestamp(sleepStart, wakeUp);
          }

          prefs.remove("sleep_start");
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
  }
}

import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("Phone used within 15 minutes → bedtime should NOT change", () {
    final ctrl = SleepController();

    final bedtime = DateTime(2025, 1, 1, 22, 0); // 10pm
    final start = DateTime(2025, 1, 1, 22, 05); // 10:05
    final end   = DateTime(2025, 1, 1, 22, 10); // 10:10

    ctrl.setBedtime(bedtime);
    ctrl.setWakeTime(DateTime(2025,1,2,6,30));

    ctrl.onPhoneUsed(start, end);

    expect(ctrl.newBedtime.value, bedtime);
  });

  test("Phone used AFTER 15m → bedtime should shift", () {
    final ctrl = SleepController();

    final bedtime = DateTime(2025, 1, 1, 22, 0);
    final start = DateTime(2025, 1, 1, 22, 20); // 20 min after bedtime
    final end   = DateTime(2025, 1, 1, 22, 40); // used for 20 min

    ctrl.setBedtime(bedtime);
    ctrl.setWakeTime(DateTime(2025,1,2,6,30));

    ctrl.onPhoneUsed(start, end);

    // expected logic:
    // sleepAfterUsage = 22:40
    // newBedtime = 22:40 - 15m = 22:25
    final expected = DateTime(2025, 1, 1, 22, 25);

    expect(ctrl.newBedtime.value, expected);
  });
}

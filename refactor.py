import re

file_path = r'd:\Git\Snevva\lib\services\unified_background_service.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    orig = f.read()

content = orig

# 1. Imports
content = content.replace("import 'package:pedometer/pedometer.dart';", "import 'package:flutter/services.dart';")

# 2. Globals
content = content.replace("""StreamSubscription<StepCount>? _pedometerSubscription;
Timer? _sleepProgressTimer;
Timer? _sleepIntervalAggregatorTimer;
Timer? _sleepWindowWatchdogTimer;""", """const MethodChannel _bgEventChannel = MethodChannel('com.coretegra.snevva/bg_events');""")

# 3. Aggregation function start
content = content.replace("    _startSleepIntervalAggregator(service, prefs);\n", "")

# 4. _sleepProgressTimer block
sleep_prog_pattern = re.compile(r'    _sleepProgressTimer\?\.cancel\(\);\s*_sleepProgressTimer = Timer\.periodic[\s\S]*?(?=    // ═══════════════════════════════════════════════════════════════\s*    // 👣 STEP COUNTING SETUP)', re.MULTILINE)
content = sleep_prog_pattern.sub("", content)

# 5. _pedometerSubscription block
pedometer_pattern = re.compile(r'    await _pedometerSubscription\?\.cancel\(\);\s*_pedometerSubscription = Pedometer\.stepCountStream\.listen\([\s\S]*?(?=\s*_startSleepWindowWatchdog)', re.MULTILINE)

new_pedometer = """    _bgEventChannel.setMethodCallHandler((call) async {
      if (call.method == 'onStepDetected') {
        int steps = call.arguments as int;
        
        await _ensureCurrentDayStepState(
          service: service,
          prefs: prefs,
          stepBox: stepBox,
        );

        final now = DateTime.now();
        final todayKey = "${now.year}-${now.month}-${now.day}";

        final lastRawSteps = prefs.getInt('lastRawSteps') ?? steps;
        int diff = steps - lastRawSteps;

        if (diff < 0) {
          diff = steps;
        }

        final todayEntry = stepBox.get(todayKey);
        final currentSteps = todayEntry?.steps ?? 0;
        final newSteps = currentSteps + diff;

        await stepBox.put(todayKey, StepEntry(date: now, steps: newSteps));
        await prefs.setInt('today_steps', newSteps);
        await prefs.setInt('lastRawSteps', steps);

        service.invoke("steps_updated", {"steps": newSteps});

        // Update notification PASSIVELY
        if (service is AndroidServiceInstance) {
          final isSleeping = prefs.getBool("is_sleeping") ?? false;

          if (isSleeping) {
            final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;
            final totalSleepMinutes =
                await _sleepNoticingService.getTotalSleepMinutes();
            final progress =
                ((totalSleepMinutes / goalMinutes) * 100).clamp(0, 100).toInt();

            service.setForegroundNotificationInfo(
              title: "Sleep Tracking 😴 ($progress%)",
              content:
                  "${_formatDuration(totalSleepMinutes)} / ${_formatDuration(goalMinutes)}",
            );
          } else {
            service.setForegroundNotificationInfo(
              title: "Health Tracking",
              content: "$newSteps steps tracked",
            );
          }
        }
      } else if (call.method == 'onAlarmWakeup') {
        // Run watchdog / sleep progress logic passively here on occasional wakeups
        await _ensureCurrentDayStepState(
          service: service,
          prefs: prefs,
          stepBox: stepBox,
        );

        await _restoreOrAutoStartSleepTracking(
          service: service,
          prefs: prefs,
          sleepBox: sleepBox,
        );
        
        final isSleeping = prefs.getBool("is_sleeping") ?? false;
        if (isSleeping) {
          final goalMinutes = prefs.getInt("sleep_goal_minutes") ?? 480;
          final totalSleepMinutes = await _sleepNoticingService.getTotalSleepMinutes();
          final windowKey = prefs.getString("current_sleep_window_key");
          final startTime = prefs.getString("sleep_start_time");

          service.invoke("sleep_update", {
            "elapsed_minutes": totalSleepMinutes,
            "goal_minutes": goalMinutes,
            "is_sleeping": true,
            "current_sleep_window_key": windowKey,
            "start_time": startTime,
          });

          if (service is AndroidServiceInstance) {
            final progress = ((totalSleepMinutes / goalMinutes) * 100).clamp(0, 100).toInt();
            service.setForegroundNotificationInfo(
              title: "Sleep Tracking 😴 ($progress%)",
              content: "${_formatDuration(totalSleepMinutes)} / ${_formatDuration(goalMinutes)} - Auto-tracking",
            );
          }

          final windowEndStr = prefs.getString("current_sleep_window_end");
          if (windowEndStr != null) {
            final windowEnd = DateTime.parse(windowEndStr);
            if (DateTime.now().isAfter(windowEnd)) {
              await _stopSleepAndSave(service, prefs, sleepBox);
            }
          }
        }
      }
    });

"""

content = pedometer_pattern.sub(new_pedometer, content)

# 6. Watchdog start block removals
content = re.sub(r'    _startSleepWindowWatchdog\([\s\S]*?\);\n', '', content)

# 7. Cancel block removals in stopService
content = content.replace("""      _pedometerSubscription?.cancel();
      _sleepProgressTimer?.cancel();
      _sleepIntervalAggregatorTimer?.cancel();
      _sleepWindowWatchdogTimer?.cancel();""", "")

# 8. Function _startSleepWindowWatchdog removal entirely
watchdog_func_pattern = re.compile(r'void _startSleepWindowWatchdog\(\{[\s\S]*?\n\}\n', re.MULTILINE)
content = watchdog_func_pattern.sub("", content)

# 9. Function _startSleepIntervalAggregator removal entirely
aggregator_func_pattern = re.compile(r'void _startSleepIntervalAggregator\([\s\S]*?\n\}\n', re.MULTILINE)
content = aggregator_func_pattern.sub("", content)

# 10. Removal of aggregator timer cancel in stopSleepAndSave
content = content.replace("  // Stop interval aggregator\n  _sleepIntervalAggregatorTimer?.cancel();\n", "")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Modifications written successfully!")

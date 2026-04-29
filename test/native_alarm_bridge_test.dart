import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/services/reminder/native_alarm_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.coretegra.snevva/reminder_alarms');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'saveAndArm persists alarms and sends the schedule JSON to Kotlin armAll',
    () async {
      final methodCalls = <MethodCall>[];
      final scheduledTime = DateTime.now().add(const Duration(hours: 2));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methodCalls.add(call);
            return true;
          });

      final alarm = AlarmSettings(
        id: 216007324,
        dateTime: scheduledTime,
        assetAudioPath: mealSound,
        volumeSettings: VolumeSettings.fade(
          fadeDuration: const Duration(seconds: 1),
        ),
        notificationSettings: const NotificationSettings(
          title: 'Meal',
          body: '',
          stopButton: 'Stop',
        ),
        payload: jsonEncode({
          'groupId': '953654687',
          'category': 'meal',
          'type': 'times',
        }),
      );

      await NativeAlarmBridge.saveAndArm([alarm]);

      final prefs = await SharedPreferences.getInstance();
      final savedRaw = prefs.getString('native_reminder_alarms');
      expect(savedRaw, isNotNull);

      final savedEntries = jsonDecode(savedRaw!) as List<dynamic>;
      final savedEntry = Map<String, dynamic>.from(savedEntries.single as Map);
      expect(savedEntry['alarmId'], 216007324);
      expect(savedEntry['groupId'], '953654687');
      expect(savedEntry['category'], 'meal');

      expect(methodCalls, hasLength(1));
      expect(methodCalls.single.method, 'armAll');

      final args = Map<String, dynamic>.from(
        methodCalls.single.arguments as Map,
      );
      final armedEntries = jsonDecode(args['json'] as String) as List<dynamic>;
      final armedEntry = Map<String, dynamic>.from(armedEntries.single as Map);

      expect(armedEntry['alarmId'], 216007324);
      expect(armedEntry['groupId'], '953654687');
      expect(armedEntry['category'], 'meal');
      expect(armedEntry['epochMs'], scheduledTime.millisecondsSinceEpoch);
    },
  );
}

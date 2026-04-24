import 'package:alarm/alarm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/models/reminder_schedule_metadata.dart';
import 'package:snevva/services/reminder/reminder_alarm_transaction.dart';
import 'package:snevva/services/reminder/reminder_schedule_resolver.dart';

class _FakeResolver extends ReminderScheduleResolver {
  const _FakeResolver(this._resolved);

  final ResolvedReminderSchedule _resolved;

  @override
  Future<ResolvedReminderSchedule> resolve(
    ReminderPayloadModel reminder,
  ) async {
    return _resolved;
  }
}

ReminderPayloadModel _buildReminder() {
  return const ReminderPayloadModel(
    id: 101,
    title: 'Hydrate',
    category: 'water',
    customReminder: CustomReminder(
      type: Option.times,
      timesPerDay: TimesPerDay(count: '2', list: ['08:00', '12:00']),
    ),
    startWaterTime: '08:00',
    endWaterTime: '20:00',
    scheduleMetadata: ReminderScheduleMetadata(
      timezoneId: 'Asia/Kolkata',
      scheduleSemantics: ScheduleSemantics.wallClock,
    ),
  );
}

void main() {
  group('ReminderAlarmTransaction', () {
    test(
      'rolls back already-scheduled alarms if any later alarm fails',
      () async {
        final reminder = _buildReminder();
        final mainTimes = [
          DateTime(2026, 4, 11, 8, 0),
          DateTime(2026, 4, 11, 12, 0),
        ];
        final stoppedIds = <int>[];
        final scheduledIds = <int>[];
        var setCount = 0;

        final transaction = ReminderAlarmTransaction(
          resolver: _FakeResolver(
            ResolvedReminderSchedule(
              reminder: reminder,
              mainTimes: mainTimes,
              preReminderTimes: const [],
              nextFireAt: mainTimes.first.toUtc().toIso8601String(),
              updatedMetadata: reminder.scheduleMetadata.copyWith(
                nextFireAt: mainTimes.first.toUtc().toIso8601String(),
                lastResolutionStatus: ReminderResolutionStatus.resolved,
              ),
            ),
          ),
          setAlarm: (AlarmSettings settings) async {
            setCount += 1;
            if (setCount == 2) {
              return false;
            }
            scheduledIds.add(settings.id);
            return true;
          },
          stopAlarm: (int alarmId) async {
            stoppedIds.add(alarmId);
            return true;
          },
        );

        await expectLater(
          transaction.schedule(reminder),
          throwsA(isA<StateError>()),
        );

        expect(scheduledIds, isNotEmpty);
        expect(stoppedIds, scheduledIds);
      },
    );

    test(
      'persists scheduled ids and tracks pre-alarm ids separately',
      () async {
        final reminder = _buildReminder().copyWith(
          remindBefore: const RemindBefore(time: 10, unit: 'minutes'),
        );
        final mainTime = DateTime(2026, 4, 11, 8, 0);

        final transaction = ReminderAlarmTransaction(
          resolver: _FakeResolver(
            ResolvedReminderSchedule(
              reminder: reminder,
              mainTimes: [mainTime],
              preReminderTimes: [
                mainTime.subtract(const Duration(minutes: 10)),
              ],
              nextFireAt: mainTime.toUtc().toIso8601String(),
              updatedMetadata: reminder.scheduleMetadata.copyWith(
                nextFireAt: mainTime.toUtc().toIso8601String(),
                lastResolutionStatus: ReminderResolutionStatus.resolved,
              ),
            ),
          ),
          setAlarm: (AlarmSettings settings) async => true,
          stopAlarm: (int alarmId) async => Alarm.stop(alarmId),
        );

        final result = await transaction.schedule(reminder);

        expect(result.mainAlarms, hasLength(1));
        expect(result.preAlarms, hasLength(1));
        expect(result.reminder.scheduleMetadata.alarmIds, hasLength(2));
        expect(result.reminder.scheduleMetadata.preAlarmIds, hasLength(1));
        expect(
          result.reminder.scheduleMetadata.lastResolutionStatus,
          ReminderResolutionStatus.scheduled,
        );
        expect(
          DateTime.parse(result.reminder.scheduleMetadata.nextFireAt!).isUtc,
          isTrue,
        );
        expect(
          DateTime.parse(
            result.reminder.scheduleMetadata.lastResolvedAt!,
          ).isUtc,
          isTrue,
        );
      },
    );

    test(
      'main alarm payload keeps event startDate and remindBefore metadata',
      () {
        final reminder = ReminderPayloadModel(
          id: 202,
          title: 'Haircut',
          category: 'event',
          startDate: '2026-04-18',
          remindBefore: const RemindBefore(time: 15, unit: 'minutes'),
          customReminder: const CustomReminder(
            type: Option.times,
            timesPerDay: TimesPerDay(count: '1', list: ['15:02']),
          ),
          scheduleMetadata: const ReminderScheduleMetadata(
            timezoneId: 'Asia/Kolkata',
            scheduleSemantics: ScheduleSemantics.absolute,
          ),
        );
        final transaction = ReminderAlarmTransaction();

        final alarm = transaction.buildMainAlarm(
          reminder: reminder,
          scheduledTime: DateTime(2026, 4, 18, 15, 2),
          alarmId: 12345,
        );

        final payload = jsonDecode(alarm.payload!) as Map<String, dynamic>;
        final remindBefore =
            payload['remindBefore'] as Map<String, dynamic>? ?? const {};

        expect(payload['startDate'], '2026-04-18');
        expect(remindBefore['time'], 15);
        expect(remindBefore['unit'], 'minutes');
      },
    );

    test(
      'main alarm payload keeps medicine startDate and endDate metadata',
      () {
        final reminder = ReminderPayloadModel(
          id: 303,
          title: 'Vitamin D',
          category: 'medicine',
          medicineName: 'Vitamin D',
          medicineType: 'Tablet',
          dosage: const Dosage(value: 1, unit: 'tablet'),
          startDate: '2026-04-18',
          endDate: '2026-04-25',
          customReminder: const CustomReminder(
            type: Option.times,
            timesPerDay: TimesPerDay(count: '1', list: ['09:00']),
          ),
          scheduleMetadata: const ReminderScheduleMetadata(
            timezoneId: 'Asia/Kolkata',
            scheduleSemantics: ScheduleSemantics.wallClock,
          ),
        );
        final transaction = ReminderAlarmTransaction();

        final alarm = transaction.buildMainAlarm(
          reminder: reminder,
          scheduledTime: DateTime(2026, 4, 18, 9, 0),
          alarmId: 12346,
        );

        final payload = jsonDecode(alarm.payload!) as Map<String, dynamic>;

        expect(payload['startDate'], '2026-04-18');
        expect(payload['endDate'], '2026-04-25');
      },
    );
  });
}

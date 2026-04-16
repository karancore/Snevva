import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:snevva/common/global_variables.dart';
import 'package:snevva/models/hive_models/reminder_payload_model.dart';
import 'package:snevva/models/reminder_schedule_metadata.dart';
import 'package:snevva/services/reminder/device_timezone_service.dart';
import 'package:snevva/services/reminder/reminder_alarm_transaction.dart';
import 'package:snevva/services/reminder/reminder_schedule_resolver.dart';

class _PassThroughResolver extends ReminderScheduleResolver {
  const _PassThroughResolver({
    required this.mainTimes,
    this.preReminderTimes = const [],
  });

  final List<DateTime> mainTimes;
  final List<DateTime> preReminderTimes;

  @override
  Future<ResolvedReminderSchedule> resolve(
    ReminderPayloadModel reminder,
  ) async {
    final sortedMainTimes = List<DateTime>.from(mainTimes)..sort();
    final sortedPreReminderTimes = List<DateTime>.from(preReminderTimes)
      ..sort();
    final nextFireAt =
        sortedMainTimes.isEmpty
            ? null
            : sortedMainTimes.first.toUtc().toIso8601String();
    final updatedMetadata = reminder.scheduleMetadata.copyWith(
      nextFireAt: nextFireAt,
      lastResolvedAt: DateTime.now().toUtc().toIso8601String(),
      lastResolutionStatus: ReminderResolutionStatus.resolved,
    );

    return ResolvedReminderSchedule(
      reminder: reminder.copyWithScheduleMetadata(updatedMetadata),
      mainTimes: sortedMainTimes,
      preReminderTimes: sortedPreReminderTimes,
      nextFireAt: nextFireAt,
      updatedMetadata: updatedMetadata,
    );
  }
}

ReminderPayloadModel _buildEventReminder({
  int id = 1,
  String? startDate,
  List<String> times = const ['10:00'],
  ReminderScheduleMetadata? scheduleMetadata,
}) {
  return ReminderPayloadModel(
    id: id,
    title: 'Doctor Visit',
    category: 'event',
    startDate: startDate,
    customReminder: CustomReminder(
      type: Option.times,
      timesPerDay: TimesPerDay(count: times.length.toString(), list: times),
    ),
    scheduleMetadata:
        scheduleMetadata ??
        const ReminderScheduleMetadata(
          timezoneId: 'Asia/Kolkata',
          scheduleSemantics: ScheduleSemantics.wallClock,
        ),
  );
}

ReminderPayloadModel _buildMedicineReminder({
  int id = 1,
  String? startDate,
  List<String> times = const ['10:00'],
  ReminderScheduleMetadata? scheduleMetadata,
}) {
  return ReminderPayloadModel(
    id: id,
    title: 'Vitamin D',
    category: 'medicine',
    medicineName: 'Vitamin D',
    medicineType: 'Tablet',
    dosage: const Dosage(value: 1, unit: 'tablet'),
    customReminder: CustomReminder(
      type: Option.times,
      timesPerDay: TimesPerDay(count: times.length.toString(), list: times),
    ),
    startDate: startDate,
    scheduleMetadata:
        scheduleMetadata ??
        const ReminderScheduleMetadata(
          timezoneId: 'Asia/Kolkata',
          scheduleSemantics: ScheduleSemantics.wallClock,
        ),
  );
}

ReminderPayloadModel _buildWaterIntervalReminder({
  int id = 1,
  String? startDate,
  int everyXHours = 1,
  String startTime = '00:00',
  String endTime = '23:59',
  ReminderScheduleMetadata? scheduleMetadata,
}) {
  return ReminderPayloadModel(
    id: id,
    title: 'Hydrate',
    category: 'water',
    startDate: startDate,
    startWaterTime: startTime,
    endWaterTime: endTime,
    customReminder: CustomReminder(
      type: Option.interval,
      everyXHours: EveryXHours(
        hours: everyXHours,
        startTime: startTime,
        endTime: endTime,
      ),
    ),
    scheduleMetadata:
        scheduleMetadata ??
        const ReminderScheduleMetadata(
          timezoneId: 'Asia/Kolkata',
          scheduleSemantics: ScheduleSemantics.wallClock,
        ),
  );
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _hhmm(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  setUp(() {
    DeviceTimezoneService.instance.prime('Asia/Kolkata');
  });

  group('Reminder scheduling edge cases', () {
    test('single day reminder resolves one future alarm correctly', () async {
      final resolver = const ReminderScheduleResolver();
      final india = tz.getLocation('Asia/Kolkata');
      final fireTimeInIndia = tz.TZDateTime.now(
        india,
      ).add(const Duration(hours: 2));
      final reminder = _buildEventReminder(
        startDate: _dateOnly(fireTimeInIndia),
        times: [_hhmm(fireTimeInIndia)],
      );

      final resolved = await resolver.resolve(reminder);
      final resolvedInIndia = tz.TZDateTime.from(
        resolved.mainTimes.first,
        india,
      );

      expect(resolved.mainTimes, hasLength(1));
      expect(resolved.mainTimes.first.isAfter(DateTime.now()), isTrue);
      expect(resolvedInIndia.year, fireTimeInIndia.year);
      expect(resolvedInIndia.month, fireTimeInIndia.month);
      expect(resolvedInIndia.day, fireTimeInIndia.day);
      expect(resolvedInIndia.hour, fireTimeInIndia.hour);
      expect(resolvedInIndia.minute, fireTimeInIndia.minute);
    });

    test(
      'no end date schedules only a bounded set of future interval alarms',
      () async {
        final resolver = const ReminderScheduleResolver();
        final reminder = _buildWaterIntervalReminder(
          startDate: _dateOnly(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
          everyXHours: 1,
        );

        final resolved = await resolver.resolve(reminder);

        expect(resolved.mainTimes, isNotEmpty);
        expect(resolved.mainTimes.length, lessThanOrEqualTo(30));
        expect(
          resolved.mainTimes.every((time) => time.isAfter(DateTime.now())),
          isTrue,
        );
        expect(
          resolved.mainTimes.every(
            (time) =>
                !time.isAfter(DateTime.now().add(const Duration(hours: 24))),
          ),
          isTrue,
        );
      },
    );

    test(
      'past start dates still resolve only future wall-clock alarms',
      () async {
        final resolver = const ReminderScheduleResolver();
        final india = tz.getLocation('Asia/Kolkata');
        final now = tz.TZDateTime.now(india);
        final reminder = _buildEventReminder(
          startDate: _dateOnly(now.subtract(const Duration(days: 14))),
          times: [_hhmm(now.add(const Duration(hours: 2)))],
        );

        final resolved = await resolver.resolve(reminder);

        expect(resolved.mainTimes, hasLength(1));
        expect(resolved.mainTimes.first.isAfter(now), isTrue);
      },
    );

    test('skips today when the configured time has already passed', () async {
      final resolver = const ReminderScheduleResolver();
      final india = tz.getLocation('Asia/Kolkata');
      final now = tz.TZDateTime.now(india);
      final reminder = _buildEventReminder(
        startDate: _dateOnly(now),
        times: [_hhmm(now.subtract(const Duration(hours: 1)))],
      );

      final resolved = await resolver.resolve(reminder);
      final resolvedInIndia = tz.TZDateTime.from(
        resolved.mainTimes.first,
        india,
      );

      expect(resolved.mainTimes, hasLength(1));
      expect(resolved.mainTimes.first.isAfter(now), isTrue);
      expect(
        _dateOnly(resolvedInIndia),
        _dateOnly(now.add(const Duration(days: 1))),
      );
    });

    test('generates multiple alarms for multiple explicit times', () async {
      final resolver = const ReminderScheduleResolver();
      final india = tz.getLocation('Asia/Kolkata');
      final firstTime = tz.TZDateTime.now(india).add(const Duration(hours: 2));
      final secondTime = firstTime.add(const Duration(hours: 2));
      final reminder = _buildEventReminder(
        startDate: _dateOnly(firstTime),
        times: [_hhmm(firstTime), _hhmm(secondTime)],
      );

      final resolved = await resolver.resolve(reminder);
      final resolvedInIndia = resolved.mainTimes
          .map((time) => tz.TZDateTime.from(time, india))
          .toList(growable: false);

      expect(resolved.mainTimes, hasLength(2));
      expect(resolvedInIndia.map(_hhmm), [_hhmm(firstTime), _hhmm(secondTime)]);
    });

    test('alarm ids remain stable across identical rebuilds', () async {
      final scheduledIds = <int>[];
      final fireTime = DateTime.now().add(const Duration(days: 2));
      final reminder = _buildEventReminder(
        startDate: _dateOnly(fireTime),
        scheduleMetadata: const ReminderScheduleMetadata(
          timezoneId: 'Asia/Kolkata',
          scheduleSemantics: ScheduleSemantics.wallClock,
        ),
      );
      final transaction = ReminderAlarmTransaction(
        resolver: _PassThroughResolver(mainTimes: [fireTime]),
        setAlarm: (settings) async {
          scheduledIds.add(settings.id);
          return true;
        },
        stopAlarm: (_) async => true,
      );

      final first = await transaction.schedule(reminder);
      final second = await transaction.schedule(first.reminder);

      expect(
        first.reminder.scheduleMetadata.alarmIds,
        second.reminder.scheduleMetadata.alarmIds,
      );
      expect(scheduledIds, [first.reminder.scheduleMetadata.alarmIds.first]);
    });

    test('alarm ids change when scheduleVersion changes', () async {
      final fireTime = DateTime.now().add(const Duration(days: 2));
      final resolver = _PassThroughResolver(mainTimes: [fireTime]);
      final transaction = ReminderAlarmTransaction(
        resolver: resolver,
        setAlarm: (_) async => true,
        stopAlarm: (_) async => true,
      );
      final versionOneReminder = _buildEventReminder(
        startDate: _dateOnly(fireTime),
        scheduleMetadata: const ReminderScheduleMetadata(
          timezoneId: 'Asia/Kolkata',
          scheduleSemantics: ScheduleSemantics.wallClock,
          scheduleVersion: 1,
        ),
      );
      final versionTwoReminder = _buildEventReminder(
        startDate: _dateOnly(fireTime),
        scheduleMetadata: const ReminderScheduleMetadata(
          timezoneId: 'Asia/Kolkata',
          scheduleSemantics: ScheduleSemantics.wallClock,
          scheduleVersion: 2,
        ),
      );

      final first = await transaction.schedule(versionOneReminder);
      final second = await transaction.schedule(versionTwoReminder);

      expect(
        first.reminder.scheduleMetadata.alarmIds.first,
        isNot(second.reminder.scheduleMetadata.alarmIds.first),
      );
    });

    test('rescheduling replaces obsolete alarm ids after rollback', () async {
      final stoppedIds = <int>[];
      final firstTime = DateTime.now().add(const Duration(days: 2));
      final secondTime = firstTime.add(const Duration(hours: 3));
      final transactionV1 = ReminderAlarmTransaction(
        resolver: _PassThroughResolver(mainTimes: [firstTime]),
        setAlarm: (_) async => true,
        stopAlarm: (alarmId) async {
          stoppedIds.add(alarmId);
          return true;
        },
      );
      final transactionV2 = ReminderAlarmTransaction(
        resolver: _PassThroughResolver(mainTimes: [secondTime]),
        setAlarm: (_) async => true,
        stopAlarm: (alarmId) async {
          stoppedIds.add(alarmId);
          return true;
        },
      );
      final original = _buildEventReminder(startDate: _dateOnly(firstTime));

      final first = await transactionV1.schedule(original);
      await transactionV1.rollbackReminder(first.reminder);
      final second = await transactionV2.schedule(first.reminder);

      expect(
        stoppedIds,
        contains(first.reminder.scheduleMetadata.alarmIds.first),
      );
      expect(
        second.reminder.scheduleMetadata.alarmIds.first,
        isNot(first.reminder.scheduleMetadata.alarmIds.first),
      );
    });

    test('recomputes next fire when cached metadata is stale', () async {
      final resolver = const ReminderScheduleResolver();
      final fireDate = DateTime.now().add(const Duration(days: 2));
      final reminder = _buildEventReminder(
        startDate: _dateOnly(fireDate),
        scheduleMetadata: ReminderScheduleMetadata(
          timezoneId: 'Asia/Kolkata',
          scheduleSemantics: ScheduleSemantics.wallClock,
          scheduleVersion: 1,
          lastResolvedAt:
              DateTime.now()
                  .subtract(const Duration(days: 2))
                  .toUtc()
                  .toIso8601String(),
          nextFireAt:
              DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .toUtc()
                  .toIso8601String(),
        ),
      );

      final nextFire = await resolver.computeNextFireSafe(reminder);

      expect(nextFire, isNotNull);
      expect(nextFire!.isAfter(DateTime.now()), isTrue);
    });

    test('timezone changes resolve different fire instants', () async {
      final resolver = const ReminderScheduleResolver();
      final fireDate = _dateOnly(DateTime.now().add(const Duration(days: 10)));
      final reminder = _buildEventReminder(
        startDate: fireDate,
        times: const ['09:00'],
      );

      DeviceTimezoneService.instance.prime('Asia/Kolkata');
      final india = await resolver.resolve(reminder);

      DeviceTimezoneService.instance.prime('America/New_York');
      final us = await resolver.resolve(reminder);

      expect(india.mainTimes.first.toUtc(), isNot(us.mainTimes.first.toUtc()));
    });

    test('handles DST spring-forward missing hours without crashing', () async {
      final resolver = const ReminderScheduleResolver();
      final reminder = _buildMedicineReminder(
        startDate: '2030-03-10',
        times: const ['02:30'],
        scheduleMetadata: const ReminderScheduleMetadata(
          timezoneId: 'America/New_York',
          scheduleSemantics: ScheduleSemantics.absolute,
        ),
      );

      final resolved = await resolver.resolve(reminder);

      expect(resolved.mainTimes, hasLength(1));
      expect(resolved.mainTimes.first.isAfter(DateTime.now()), isTrue);
    });

    test('fails safely when the reminder has no explicit times', () async {
      final resolver = const ReminderScheduleResolver();
      final reminder = _buildEventReminder(
        startDate: _dateOnly(DateTime.now().add(const Duration(days: 1))),
        times: const [],
      );

      await expectLater(resolver.resolve(reminder), throwsException);
    });

    test('fails safely when the reminder start date is malformed', () async {
      final resolver = const ReminderScheduleResolver();
      final reminder = _buildEventReminder(
        startDate: '2026/04/10',
        times: const ['10:00'],
      );

      await expectLater(
        resolver.resolve(reminder),
        throwsA(isA<ReminderResolutionException>()),
      );
    });

    test(
      'documents pending support for inclusive multi-day start and end ranges',
      () {},
      skip:
          'The current resolver schedules upcoming occurrences, not full date spans.',
    );

    test(
      'documents pending support for rejecting inverted date ranges',
      () {},
      skip:
          'The current resolver does not validate startDate/endDate ordering yet.',
    );
  });
}

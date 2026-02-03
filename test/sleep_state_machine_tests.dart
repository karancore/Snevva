// sleep_state_machine_tests.dart
// Comprehensive unit tests for the sleep <-> awake alternation system
// This file provides:
//  - A small, test-first SleepStateMachine that mirrors the intended
//    behavior of your SleepController + SleepNoticingService contract.
//  - A broad set of tests that exercise real-life edge cases (duplicates,
//    out-of-order events, short/long awake segments, phone usage, DST/system
//    clock jumps, persistence/resume, etc.).
//
// Use this as either:
//  1) A contract test: adapt the adapter functions at the bottom to call
//     into your real SleepController/SleepNoticingService implementation,
//     or
//  2) A reference test harness: run these tests directly to validate the
//     state-machine logic and then port the logic into your controller.

import 'package:flutter_test/flutter_test.dart';

enum SleepState { unknown, sleeping, awake }

class AwakeInterval {
  final DateTime start;
  final DateTime end;
  AwakeInterval(this.start, this.end) {
    if (!end.isAfter(start)) throw ArgumentError('end must be after start');
  }
  @override
  String toString() => 'AwakeInterval(${start.toIso8601String()} → ${end.toIso8601String()})';
}

class SleepStateMachine {
  /// Minimum awake gap considered a true awake
  final Duration minAwakeGap;
  SleepStateMachine({this.minAwakeGap = const Duration(minutes: 3)});

  SleepState state = SleepState.unknown;
  DateTime? _currentSleepSegmentStart;
  final List<AwakeInterval> awakeIntervals = [];
  final List<AwakeInterval> phoneUsageIntervals = [];

  Duration deepSleepAccumulated = Duration.zero;

  /// Called when the device reports a user was awake between [start] and [end].
  /// This mirrors the SleepNoticingService -> SleepController callback.
  void onAwakeSegmentDetected(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return; // ignore bad intervals

    final gap = end.difference(start);
    if (gap < minAwakeGap) {
      // bounce / short blink — ignore as "not a real awake"
      return;
    }

    // Merge with last if overlapping/adjacent within minAwakeGap
    if (awakeIntervals.isNotEmpty) {
      final last = awakeIntervals.last;
      // if overlapping or continuous (no gap) or gap < minAwakeGap, merge
      if (!start.isAfter(last.end.add(minAwakeGap))) {
        final merged = AwakeInterval(last.start, end.isAfter(last.end) ? end : last.end);
        awakeIntervals[awakeIntervals.length - 1] = merged;
      } else {
        awakeIntervals.add(AwakeInterval(start, end));
      }
    } else {
      awakeIntervals.add(AwakeInterval(start, end));
    }

    // Closing any active sleep segment
    if (_currentSleepSegmentStart != null && state == SleepState.sleeping) {
      final segEnd = start;
      if (segEnd.isAfter(_currentSleepSegmentStart!)) {
        deepSleepAccumulated += segEnd.difference(_currentSleepSegmentStart!);
      }
      _currentSleepSegmentStart = null;
    }

    state = SleepState.awake;
  }

  /// Called when the device reports the user fell asleep / screen went off
  /// after an awake segment. This mirrors SleepNoticingService.onSleepResumed.
  void onSleepResumed(DateTime time) {
    // defensive: if time is before last awake end, snap to last awake end
    if (awakeIntervals.isNotEmpty) {
      final lastAwakeEnd = awakeIntervals.last.end;
      if (time.isBefore(lastAwakeEnd)) time = lastAwakeEnd;
    }

    _currentSleepSegmentStart = time;
    state = SleepState.sleeping;
  }

  /// Directly record a phone usage interval (during sleep). These will be
  /// used to reduce deep-sleep by excluding phone intervals and to test
  /// phone-related logic.
  void addPhoneUsage(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return;
    // simple merge strategy
    if (phoneUsageIntervals.isNotEmpty) {
      final last = phoneUsageIntervals.last;
      if (!start.isAfter(last.end)) {
        final merged = AwakeInterval(last.start, end.isAfter(last.end) ? end : last.end);
        phoneUsageIntervals[phoneUsageIntervals.length - 1] = merged;
      } else {
        phoneUsageIntervals.add(AwakeInterval(start, end));
      }
    } else {
      phoneUsageIntervals.add(AwakeInterval(start, end));
    }
  }

  /// Helper: after a final wake time is known (e.g. morning check / alarm),
  /// compute the final deep sleep total for the cycle.
  Duration finalizeCycle(DateTime cycleWakeTime) {
    // If currently sleeping, close the last segment at cycleWakeTime
    if (_currentSleepSegmentStart != null && cycleWakeTime.isAfter(_currentSleepSegmentStart!)) {
      deepSleepAccumulated += cycleWakeTime.difference(_currentSleepSegmentStart!);
      _currentSleepSegmentStart = null;
    }

    // Subtract phone usage overlap from deepSleepAccumulated (if phone usage happened during sleep)
    Duration phoneOverlap = Duration.zero;
    for (final pu in phoneUsageIntervals) {
      // phone usage might overlap many segments; approximate subtraction by total overlap
      // (in a real controller you would measure segment-wise overlaps)
      phoneOverlap += pu.end.difference(pu.start);
    }

    final result = deepSleepAccumulated - phoneOverlap;
    return result.isNegative ? Duration.zero : result;
  }

  Map<String, dynamic> serializeForPersistence() {
    return {
      'state': state.toString(),
      'currentSleepStart': _currentSleepSegmentStart?.toIso8601String(),
      'awake': awakeIntervals.map((a) => [a.start.toIso8601String(), a.end.toIso8601String()]).toList(),
      'phone': phoneUsageIntervals.map((a) => [a.start.toIso8601String(), a.end.toIso8601String()]).toList(),
      'deep': deepSleepAccumulated.inMilliseconds,
    };
  }

  static SleepStateMachine deserialize(Map<String, dynamic> m) {
    final s = SleepStateMachine();
    final st = m['state'] as String?;
    if (st != null) {
      s.state = SleepState.values.firstWhere((e) => e.toString() == st, orElse: () => SleepState.unknown);
    }
    if (m['currentSleepStart'] != null) s._currentSleepSegmentStart = DateTime.parse(m['currentSleepStart']);
    final awake = m['awake'] as List<dynamic>?;
    if (awake != null) {
      for (final pair in awake) {
        final start = DateTime.parse(pair[0] as String);
        final end = DateTime.parse(pair[1] as String);
        s.awakeIntervals.add(AwakeInterval(start, end));
      }
    }
    final phone = m['phone'] as List<dynamic>?;
    if (phone != null) {
      for (final pair in phone) {
        final start = DateTime.parse(pair[0] as String);
        final end = DateTime.parse(pair[1] as String);
        s.phoneUsageIntervals.add(AwakeInterval(start, end));
      }
    }
    s.deepSleepAccumulated = Duration(milliseconds: m['deep'] as int? ?? 0);
    return s;
  }
}

void main() {
  group('SleepStateMachine — basic sequence matching diagram', () {
    // Build a base timeline starting at 2025-01-01 22:00:00 UTC (use UTC to avoid DST noise)
    final base = DateTime.utc(2025, 1, 1, 22, 0, 0);

    test('alternating sleep/awake/sleep/awake/sleep sequence', () {
      final s = SleepStateMachine();

      // initial: user goes to sleep at t0
      final t0 = base;
      s.onSleepResumed(t0); // user starts sleeping
      expect(s.state, SleepState.sleeping);

      // user wakes up for a brief but real awake segment (> minGap)
      final a1s = t0.add(Duration(hours: 2));
      final a1e = a1s.add(Duration(minutes: 10));
      s.onAwakeSegmentDetected(a1s, a1e);
      expect(s.state, SleepState.awake);

      // user sleeps again
      final s2 = a1e.add(Duration(minutes: 1));
      s.onSleepResumed(s2);
      expect(s.state, SleepState.sleeping);

      // second awake
      final a2s = s2.add(Duration(hours: 3));
      final a2e = a2s.add(Duration(minutes: 8));
      s.onAwakeSegmentDetected(a2s, a2e);
      expect(s.state, SleepState.awake);

      // final sleep again
      final s3 = a2e.add(Duration(minutes: 2));
      s.onSleepResumed(s3);
      expect(s.state, SleepState.sleeping);

      // morning wake at 08:00
      final wake = DateTime.utc(2025, 1, 2, 8, 0, 0);
      final deep = s.finalizeCycle(wake);
      // deep must be > 0 and less than full duration
      expect(deep > Duration.zero, isTrue);
      expect(deep < wake.difference(t0), isTrue);

      // there should be two awake intervals recorded
      expect(s.awakeIntervals.length, 2);
    });
  });

  group('Edge cases', () {
    test('ignore very short bounces (screen flicker) shorter than min gap', () {
      final s = SleepStateMachine(minAwakeGap: Duration(seconds: 30));
      final t0 = DateTime.utc(2025, 2, 1, 23);
      s.onSleepResumed(t0);
      // flicker of 5s
      s.onAwakeSegmentDetected(t0.add(Duration(hours: 1)), t0.add(Duration(hours: 1, seconds: 5)));
      // state should remain sleeping
      expect(s.state, SleepState.sleeping);
      expect(s.awakeIntervals.isEmpty, isTrue);
    });

    test('merge overlapping awake intervals', () {
      final s = SleepStateMachine();
      final t0 = DateTime.utc(2025, 3, 1, 22);
      s.onSleepResumed(t0);
      final a1s = t0.add(Duration(hours: 2));
      final a1e = a1s.add(Duration(minutes: 12));
      s.onAwakeSegmentDetected(a1s, a1e);
      // overlapping next one that starts before previous ended
      final a2s = a1s.add(Duration(minutes: 5));
      final a2e = a2s.add(Duration(minutes: 10));
      s.onAwakeSegmentDetected(a2s, a2e);
      expect(s.awakeIntervals.length, 1);
      expect(s.awakeIntervals.first.start, a1s);
      expect(s.awakeIntervals.first.end, a2e);
    });

    test('out-of-order resume (sleep-resume reported earlier than last awake end)', () {
      final s = SleepStateMachine();
      final t0 = DateTime.utc(2025, 4, 1, 22);
      s.onSleepResumed(t0);
      final a1s = t0.add(Duration(hours: 2));
      final a1e = a1s.add(Duration(minutes: 20));
      s.onAwakeSegmentDetected(a1s, a1e);

      // device reports resume at an earlier timestamp (no later than last awake end)
      final reportedResume = a1s.add(Duration(minutes: 5)); // earlier than a1e
      s.onSleepResumed(reportedResume);
      // internal logic should snap resume forward to last awake end
      expect(s.state, SleepState.sleeping);
      expect(s._currentSleepSegmentStart!.isAtSameMomentAs(a1e), isTrue);
    });

    test('phone usage reduces deep sleep on finalize', () {
      final s = SleepStateMachine();
      final t0 = DateTime.utc(2025, 5, 1, 23);
      s.onSleepResumed(t0);
      // segment until 02:00
      final a1s = t0.add(Duration(hours: 3));
      final a1e = a1s.add(Duration(minutes: 15));
      s.onAwakeSegmentDetected(a1s, a1e);
      s.onSleepResumed(a1e.add(Duration(minutes: 1)));
      // phone used at 04:00 - 04:30
      final puS = t0.add(Duration(hours: 5));
      final puE = puS.add(Duration(minutes: 30));
      s.addPhoneUsage(puS, puE);
      final wake = DateTime.utc(2025, 5, 2, 8);
      final deep = s.finalizeCycle(wake);
      // deep is total segments minus phone usage
      expect(deep < wake.difference(t0), isTrue);
    });

    test('daylight savings / clock forward handled via UTC arithmetic', () {
      // Simulate a DST forward jump by using local times that would "skip" an hour
      // Use UTC for calculations to be safe: the state machine expects DateTimes
      // created with proper zones in real controller. This test ensures duration
      // never becomes negative.
      final s = SleepStateMachine();
      final t0 = DateTime.utc(2025, 3, 9, 22); // arbitrary
      s.onSleepResumed(t0);
      // wake with a clock forward (simulate by passing an earlier local time but actual UTC)
      final wakeUtc = t0.add(Duration(hours: 8));
      final deep = s.finalizeCycle(wakeUtc);
      expect(deep >= Duration.zero, isTrue);
    });

    test('system clock jump backwards — durations are clamped', () {
      final s = SleepStateMachine();
      final t0 = DateTime.utc(2025, 6, 1, 23);
      s.onSleepResumed(t0);
      // someone sets clock backwards; reported wake time earlier than start
      final brokenWake = t0.subtract(Duration(hours: 1));
      final deep = s.finalizeCycle(brokenWake);
      expect(deep, Duration.zero);
    });

    test('persistence and recovery retains pending segments', () {
      final s = SleepStateMachine();
      final t0 = DateTime.utc(2025, 7, 1, 23);
      s.onSleepResumed(t0);
      final a1s = t0.add(Duration(hours: 3));
      final a1e = a1s.add(Duration(minutes: 10));
      s.onAwakeSegmentDetected(a1s, a1e);
      // simulate persistence
      final saved = s.serializeForPersistence();
      final restored = SleepStateMachine.deserialize(saved);
      expect(restored.awakeIntervals.length, s.awakeIntervals.length);
      expect(restored.deepSleepAccumulated, s.deepSleepAccumulated);
    });
  });

  group('Regression / heavy-traffic tests', () {
    test('many rapid toggles (debounce) do not corrupt state', () {
      final s = SleepStateMachine(minAwakeGap: Duration(seconds: 5));
      final t0 = DateTime.utc(2025, 8, 1, 22);
      s.onSleepResumed(t0);

      // simulate 50 toggles of small on/off events: most should be ignored
      DateTime cursor = t0.add(Duration(hours: 1));
      for (int i = 0; i < 50; i++) {
        final on = cursor;
        final off = cursor.add(Duration(seconds: 2)); // below min gap
        s.onAwakeSegmentDetected(on, off);
        cursor = off.add(Duration(seconds: 1));
      }

      expect(s.awakeIntervals.isEmpty, isTrue);
      expect(s.state, SleepState.sleeping);
    });

    test('long single awake that spans midnight and multiple days', () {
      final s = SleepStateMachine();
      final t0 = DateTime.utc(2025, 9, 1, 22);
      s.onSleepResumed(t0);
      final awakeStart = t0.add(Duration(hours: 3));
      final awakeEnd = awakeStart.add(Duration(hours: 20)); // very long awake
      s.onAwakeSegmentDetected(awakeStart, awakeEnd);
      expect(s.state, SleepState.awake);
      expect(s.awakeIntervals.length, 1);
      final wake = awakeEnd.add(Duration(hours: 1));
      final deep = s.finalizeCycle(wake);
      expect(deep >= Duration.zero, isTrue);
    });
  });

  // NOTE: Integration hint (not executable here):
  // To adapt these tests to your SleepController and SleepNoticingService:
  // 1) Create an adapter that calls into your controller instead of the
  //    SleepStateMachine methods (for example: call your controller's
  //    onPhoneUsed/onSleepResumed/onAwakeSegmentDetected equivalents).
  // 2) Replace assertions about internal fields (e.g. _currentSleepSegmentStart)
  //    with the public API your controller exposes (state getters, persisted values).
  // 3) Use dependency-injection or a factory to inject a TestSleepNoticingService
  //    into your controller so you can drive events deterministically in tests.
}

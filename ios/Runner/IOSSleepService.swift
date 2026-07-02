import Foundation
import Flutter
import BackgroundTasks

// MARK: - IOSSleepService

/// iOS sleep tracking coordinator.
///
/// Architecture overview:
///
///   Primary path  — HealthKit `HKCategoryTypeIdentifier.sleepAnalysis`
///     • Queried on app-foreground and in the `sleep_calc` BGProcessingTask.
///     • Writes merged segments directly to the daily JSON via IOSStepBufferManager.
///     • Requires `com.apple.developer.healthkit` entitlement + NSHealthShareUsageDescription.
///
///   Fallback path — manual session (user pressed Start / Stop Sleep in Flutter UI)
///     • Dart's `_stopSleepAndSave` writes the interval to sleep_buf.tmp on iOS
///       (see unified_background_service.dart iOS branch).
///     • IOSStepBufferManager.flushSleepToDaily() converts that buffer to daily JSON.
///
///   Both paths use the same daily JSON schema as Android (same as BufferManager.kt):
///     {date, steps:{total}, sleep:{total_sleep_minutes, segments:[{start,end}]}, sent, created_at}
///
///   The Flutter SleepController reads from FileStorageService.readRecentSleepMap() which
///   reads those JSON files — no Dart-side changes needed.
final class IOSSleepService {

    static let shared = IOSSleepService()
    private init() {}

    private let fetcher = IOSHealthKitSleepFetcher()
    private var methodChannel: FlutterMethodChannel?
    private var isFetching = false

    private let isoFmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Setup

    /// Wire the `com.coretegra.snevvaa/sleep_service` MethodChannel.
    /// Call from AppDelegate.didInitializeImplicitFlutterEngine.
    func configure(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "com.coretegra.snevvaa/sleep_service",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(FlutterError(code: "RELEASED", message: nil, details: nil))
                return
            }
            switch call.method {
            case "requestHealthKitPermission":
                self.fetcher.requestAuthorization { granted, _ in
                    result(granted)
                }
            case "fetchHealthKitSleep":
                self.fetchAndStoreLastNightSleep { minutes in
                    result(minutes)
                }
            case "fetchHealthKitSleepForDate":
                let dateKey = call.arguments as? String ?? self.yesterdayDateKey()
                self.fetchAndStoreHealthKitSleep(for: dateKey) { minutes in
                    result(minutes)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        methodChannel = channel
    }

    /// Request HealthKit authorization and populate last night's sleep data.
    /// Call from applicationDidBecomeActive / first launch.
    func start() {
        fetcher.requestAuthorization { [weak self] _, _ in
            self?.fetchAndStoreLastNightSleep(completion: nil)
        }
    }

    // MARK: - HealthKit primary path

    /// Fetches last night's sleep (yesterday's date key).
    func fetchAndStoreLastNightSleep(completion: ((Int) -> Void)?) {
        fetchAndStoreHealthKitSleep(for: yesterdayDateKey(), completion: completion)
    }

    /// Fetches HealthKit sleep for the given bed-date key ("YYYY-MM-DD") and stores it.
    ///
    /// Query window: `dateKey` 6 PM → `dateKey+1` 12 PM (wide enough to catch any overnight pattern).
    /// Merges into daily JSON only if the new total ≥ current stored total (HealthKit wins).
    /// Adds a typed `sleep` entry to sync_queue.json for IOSApiSyncService.
    func fetchAndStoreHealthKitSleep(for dateKey: String, completion: ((Int) -> Void)?) {
        guard !isFetching else { completion?(0); return }
        isFetching = true

        let (windowStart, windowEnd) = sleepQueryWindow(for: dateKey)

        fetcher.fetchSleepSegments(from: windowStart, to: windowEnd) { [weak self] segments in
            guard let self = self else { completion?(0); return }
            defer { self.isFetching = false }

            guard !segments.isEmpty else {
                print("💤 IOSSleepService: no HealthKit sleep for \(dateKey)")
                // Still flush manual-session buffer in case Dart wrote something
                IOSStepBufferManager.shared.flushSleepToDaily()
                completion?(0)
                return
            }

            let totalMinutes = segments.reduce(0) {
                $0 + Int($1.end.timeIntervalSince($1.start) / 60)
            }

            let segmentDicts = segments.map { seg -> [String: String] in
                ["start": self.isoFmt.string(from: seg.start),
                 "end":   self.isoFmt.string(from: seg.end)]
            }

            IOSStepBufferManager.shared.mergeSleepIntoDailyFile(
                dateKey: dateKey,
                totalMinutes: totalMinutes,
                segments: segmentDicts
            )
            IOSStepBufferManager.shared.addToSyncQueue(dateKey: dateKey, type: "sleep")

            print("💤 IOSSleepService: stored \(totalMinutes)m for \(dateKey)")
            completion?(totalMinutes)
        }
    }

    // MARK: - Foreground catch-up

    /// Called on every `applicationDidBecomeActive`. BGProcessingTask scheduling is
    /// opportunistic — iOS may delay `sleep_calc` by hours or skip it entirely — so if
    /// the user opens the app after their sleep window has already ended and it hasn't
    /// been finalized yet, run the same interrupt-model calculation immediately instead
    /// of waiting on the BGTask.
    func catchUpSleepCalcIfWindowEnded() {
        guard let window = IOSLockUnlockSleepDetector.shared.currentSleepWindow() else {
            return
        }
        guard Date() >= window.end else {
            return
        }

        let wakeDateKey = IOSStepBufferManager.shared.dateKeyFromDate(window.end)
        if UserDefaults.standard.string(forKey: "flutter.sleep_final_date") == wakeDateKey {
            // Already finalized (by the BGTask or a previous catch-up) — nothing to do.
            return
        }

        print("💤 IOSSleepService: catching up sleep_calc for ended window [\(window.dateKey)]")
        performSleepCalcBackgroundTask {
        }
    }

    // MARK: - Background task entry point

    /// Called by AppDelegate when `com.coretegra.snevva.sleep_calc` BGProcessingTask fires.
    ///
    /// Interrupt model:
    ///   sleep = (waketime − bedtime) − Σ(interrupt_durations)
    ///
    /// Each interrupt = period the screen was unlocked (user was awake) within the window.
    /// Stored in interrupt_buf.tmp as: dateKey | user-phone-screen-unlocked | user-phone-screen-locked
    /// interrupt-duration = lock_ts − unlock_ts
    ///
    /// Flow:
    ///  1. Close any open interrupt (phone still unlocked when BGTask fires → final awake period).
    ///  2. Sum all interrupt durations from interrupt_buf.tmp.
    ///  3. sleep = window_minutes − interrupt_minutes.
    ///  4. If Apple Watch HealthKit has a better reading, use it instead.
    ///  5. Write to daily JSON + UserDefaults, queue for sync, reschedule.
    func performSleepCalcBackgroundTask(completion: @escaping () -> Void) {
        guard let window = IOSLockUnlockSleepDetector.shared.currentSleepWindow() else {
            IOSApiSyncService.shared.sync { [weak self] _ in
                self?.scheduleSleepCalcTask()
                completion()
            }
            return
        }

        // A BGTask can still be queued for a window that catchUpSleepCalcIfWindowEnded()
        // already finalized on foreground (BGTaskScheduler doesn't let us cancel a specific
        // pending request). Since clearInterruptBuffer() already ran, recomputing here would
        // read 0 interrupts and overwrite the correct total with the full window duration.
        let wakeDateKey = IOSStepBufferManager.shared.dateKeyFromDate(window.end)
        if UserDefaults.standard.string(forKey: "flutter.sleep_final_date") == wakeDateKey {
            IOSApiSyncService.shared.sync { [weak self] _ in
                self?.scheduleSleepCalcTask()
                completion()
            }
            return
        }

        // Step 1 — close any interrupt that was still open at wake time
        IOSLockUnlockSleepDetector.shared.flushOpenUnlockInterval(for: window)

        // Step 2 — compute sleep = window − interrupts
        let windowMinutes = Int(window.end.timeIntervalSince(window.start) / 60)
        let interruptMinutes = IOSStepBufferManager.shared.readTotalInterruptMinutes(dateKey: window.dateKey)
        let lockUnlockMinutes = max(0, windowMinutes - interruptMinutes)
        IOSStepBufferManager.shared.clearInterruptBuffer()

        print("💤 IOSSleepService BGTask: window=\(windowMinutes)m interrupts=\(interruptMinutes)m sleep=\(lockUnlockMinutes)m [\(window.dateKey)]")

        // Step 3 — check Apple Watch for a better reading
        let (queryStart, queryEnd) = sleepQueryWindow(for: window.dateKey)
        fetcher.fetchAppleWatchSleepSegments(from: queryStart, to: queryEnd) { [weak self] watchSegments in
            guard let self = self else { completion(); return }

            if !watchSegments.isEmpty {
                let watchMinutes = watchSegments.reduce(0) {
                    $0 + Int($1.end.timeIntervalSince($1.start) / 60)
                }
                print("💤 IOSSleepService BGTask: Apple Watch=\(watchMinutes)m [\(window.dateKey)]")

                if watchMinutes > lockUnlockMinutes {
                    let segDicts = watchSegments.map { seg -> [String: String] in
                        ["start": self.isoFmt.string(from: seg.start),
                         "end": self.isoFmt.string(from: seg.end)]
                    }
                    IOSStepBufferManager.shared.mergeSleepIntoDailyFile(
                        dateKey: window.dateKey,
                        totalMinutes: watchMinutes,
                        segments: segDicts
                    )
                    self.finalizeSleep(window: window, finalMinutes: watchMinutes, completion: completion)
                    return
                }
            }

            // Write interrupt-model sleep total to daily JSON
            IOSStepBufferManager.shared.mergeSleepIntoDailyFile(
                dateKey: window.dateKey,
                totalMinutes: lockUnlockMinutes,
                segments: []
            )
            self.finalizeSleep(window: window, finalMinutes: lockUnlockMinutes, completion: completion)
        }
    }

    /// Writes the finalized sleep total to UserDefaults and triggers sync.
    /// Mirrors Android SleepCalcWorker's SharedPreferences writes exactly:
    ///   flutter.sleep_final_minutes, flutter.sleep_final_date,
    ///   flutter.sleep_elapsed_minutes, flutter.is_sleeping = false.
    private func finalizeSleep(window: IOSSleepWindow, finalMinutes: Int, completion: @escaping () -> Void) {
        let wakeDateKey = IOSStepBufferManager.shared.dateKeyFromDate(window.end)

        let ud = UserDefaults.standard
        ud.set(finalMinutes, forKey: "flutter.sleep_final_minutes")
        ud.set(wakeDateKey, forKey: "flutter.sleep_final_date")
        ud.set(0, forKey: "flutter.sleep_elapsed_minutes")
        ud.set(false, forKey: "flutter.is_sleeping")
        ud.removeObject(forKey: "flutter.sleep_start_time")
        ud.removeObject(forKey: "flutter.current_sleep_window_start")
        ud.removeObject(forKey: "flutter.current_sleep_window_end")
        ud.removeObject(forKey: "flutter.current_sleep_window_key")

        IOSStepBufferManager.shared.addToSyncQueue(dateKey: window.dateKey, type: "sleep")
        print("💤 IOSSleepService: finalized \(finalMinutes)m [\(window.dateKey)], wake=\(wakeDateKey)")

        // The night's window is done — release the audio keep-alive that was holding
        // the process resident so it could keep receiving lock/unlock notifications.
        IOSBackgroundAudioKeepAlive.shared.stop()

        IOSApiSyncService.shared.sync { [weak self] _ in
            self?.scheduleSleepCalcTask()
            completion()
        }
    }

    // MARK: - BGTask scheduling

    /// Schedules the next `sleep_calc` BGProcessingTask for 30 min after wake time.
    func scheduleSleepCalcTask() {
        guard #available(iOS 13.0, *) else { return }

        // Dart writes wake time under WAKETIME_KEY = "user_waketime_ms" (minutes since midnight).
        // shared_preferences_foundation v2 stores keys with the "flutter." prefix in UserDefaults.
        let ud = UserDefaults.standard
        let wakeMinutes = ud.integer(forKey: "user_waketime_ms").zeroToNil
            ?? ud.integer(forKey: "flutter.user_waketime_ms").zeroToNil
            ?? (7 * 60)

        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = wakeMinutes / 60
        comps.minute = wakeMinutes % 60
        comps.second = 0

        guard var wakeDate = cal.date(from: comps) else { return }
        if wakeDate <= now { wakeDate = wakeDate.addingTimeInterval(24 * 3600) }

        let request = BGProcessingTaskRequest(identifier: "com.coretegra.snevva.sleep_calc")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = wakeDate.addingTimeInterval(30 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("💤 sleep_calc scheduled at ~\(request.earliestBeginDate!)")
        } catch {
            print("⚠️ IOSSleepService: failed to schedule sleep_calc: \(error)")
        }
    }

    // MARK: - Helpers

    /// Query window: 6 PM of bedDate → 12 PM of the next day.
    private func sleepQueryWindow(for dateKey: String) -> (Date, Date) {
        guard let bedDay = dateFromKey(dateKey) else {
            let now = Date()
            return (now.addingTimeInterval(-18 * 3600), now)
        }
        let cal = Calendar.current
        var startComps = cal.dateComponents([.year, .month, .day], from: bedDay)
        startComps.hour = 18; startComps.minute = 0; startComps.second = 0

        let nextDay = bedDay.addingTimeInterval(24 * 3600)
        var endComps = cal.dateComponents([.year, .month, .day], from: nextDay)
        endComps.hour = 12; endComps.minute = 0; endComps.second = 0

        let start = cal.date(from: startComps) ?? bedDay
        let end   = cal.date(from: endComps)   ?? nextDay
        return (start, end)
    }

    private func yesterdayDateKey() -> String {
        return IOSStepBufferManager.shared.dateKeyFromDate(Date().addingTimeInterval(-24 * 3600))
    }

    private func dateFromKey(_ key: String) -> Date? {
        let parts = key.components(separatedBy: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 0; c.minute = 0
        return Calendar.current.date(from: c)
    }
}

private extension Int {
    var zeroToNil: Int? { self == 0 ? nil : self }
}
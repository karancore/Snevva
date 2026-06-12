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

    // MARK: - Background task entry point

    /// Called by AppDelegate when `com.coretegra.snevva.sleep_calc` BGProcessingTask fires.
    func performSleepCalcBackgroundTask(completion: @escaping () -> Void) {
        // Flush manual-session buffer first (Dart fallback may have written it)
        IOSStepBufferManager.shared.flushSleepToDaily()

        fetchAndStoreLastNightSleep { [weak self] minutes in
            guard let self = self else { completion(); return }
            print("💤 IOSSleepService BGTask: \(minutes)m stored")
            IOSApiSyncService.shared.sync { _ in
                self.scheduleSleepCalcTask()
                completion()
            }
        }
    }

    // MARK: - BGTask scheduling

    /// Schedules the next `sleep_calc` BGProcessingTask for 30 min after wake time.
    func scheduleSleepCalcTask() {
        guard #available(iOS 13.0, *) else { return }

        let wakeMinutes = UserDefaults.standard.integer(forKey: "wake_time_minutes").zeroToNil
            ?? UserDefaults.standard.integer(forKey: "flutter.wake_time_minutes").zeroToNil
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
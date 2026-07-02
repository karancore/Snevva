import Foundation
import CoreMotion
import Flutter

// MARK: - IOSStepService

/// iOS step tracking coordinator — mirrors the role of Android's StepCounterService.kt.
///
/// Data flow:
///   CMPedometer.startUpdates → handlePedometerUpdate
///       → IOSStepBufferManager.appendStepEvent  (file buffer, mirrors BufferManager.kt)
///       → UserDefaults["flutter.today_steps"]   (fast-path for Dart's file poller)
///       → MethodChannel "onStepDetected"         (live push to Flutter UI)
///
/// Auto-flush: every 5 min (via PeriodicFlushTimer) + 500-line threshold (inside BufferManager).
///
/// Day boundary:
///   Query CMPedometer for the full previous day → flush → addToSyncQueue → IOSApiSyncService.sync
///
/// Background:
///   performBackgroundRefresh() is called from BGAppRefreshTask "com.coretegra.snevva.step_refresh".
final class IOSStepService: NSObject {

    static let shared = IOSStepService()
    private override init() {}

    private let pedometer = CMPedometer()
    private let healthFetcher = IOSHealthKitStepsFetcher()
    private var methodChannel: FlutterMethodChannel?
    private var isRunning = false
    private var flushTimer: Timer?
    private var lastKnownDateKey = ""

    // MARK: - Configure

    /// Wire the MethodChannel once the Flutter engine's binary messenger is available.
    /// Call from AppDelegate.didInitializeImplicitFlutterEngine.
    func configure(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.coretegra.snevvaa/step_detector",
            binaryMessenger: messenger
        )
    }

    // MARK: - Start / Stop

    func start() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("⚠️ IOSStepService: CMPedometer not available on this device")
            return
        }
        guard !isRunning else { return }
        isRunning = true
        lastKnownDateKey = todayKey()

        let startOfDay = Calendar.current.startOfDay(for: Date())
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            self.handlePedometerUpdate(data)
        }

        startPeriodicFlushTimer()

        // Request HealthKit authorization so the Watch-inclusive total (see
        // IOSHealthKitStepsFetcher) is available — without this call the read
        // silently returns 0, same failure mode fixed for sleep.
        healthFetcher.requestAuthorization { [weak self] _, _ in
            self?.fetchAndMergeHealthKitStepsToday()
        }

        print("✅ IOSStepService: started (date=\(lastKnownDateKey))")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        pedometer.stopUpdates()
        flushTimer?.invalidate()
        flushTimer = nil
        IOSStepBufferManager.shared.flushStepsToDaily()
        print("🛑 IOSStepService: stopped, buffer flushed")
    }

    // MARK: - Seed at login

    /// Called when the user logs in with an API-provided step count for today
    /// (e.g. reinstall scenario where the server already has 644 steps).
    /// Only applies if the API value exceeds what CMPedometer has recorded locally.
    func seedTodaySteps(_ apiSteps: Int) {
        guard apiSteps > 0 else { return }
        let current = UserDefaults.standard.integer(forKey: "flutter.today_steps")
        guard apiSteps > current else { return }

        UserDefaults.standard.set(apiSteps, forKey: "flutter.today_steps")
        IOSStepBufferManager.shared.appendStepEvent(apiSteps)
        print("🌱 IOSStepService.seedTodaySteps: \(apiSteps) (was \(current))")
    }

    // MARK: - HealthKit merge (Apple Watch-inclusive total)

    /// Fetches today's HealthKit step total (merged across iPhone + Apple Watch)
    /// and merges it in if it exceeds what CMPedometer alone has recorded —
    /// same max-wins pattern as IOSStepBufferManager.mergeStepsIntoDailyFile.
    func fetchAndMergeHealthKitStepsToday(completion: (() -> Void)? = nil) {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let dateKey = todayKey()

        healthFetcher.fetchTotalSteps(from: startOfDay, to: now) { [weak self] healthSteps in
            guard let self = self, healthSteps > 0 else {
                completion?(); return
            }

            let current = UserDefaults.standard.integer(forKey: "flutter.today_steps")
            if healthSteps > current {
                UserDefaults.standard.set(healthSteps, forKey: "flutter.today_steps")
                IOSStepBufferManager.shared.appendStepEvent(healthSteps)
                print("🍎 IOSStepService: HealthKit steps=\(healthSteps) (was \(current)) for \(dateKey)")

                DispatchQueue.main.async {
                    self.methodChannel?.invokeMethod("onStepDetected", arguments: healthSteps)
                }
            }
            completion?()
        }
    }

    // MARK: - Pedometer update handler

    private func handlePedometerUpdate(_ data: CMPedometerData) {
        let steps   = data.numberOfSteps.intValue
        let dateKey = todayKey()

        // Day boundary: CMPedometer resets its "from: startOfDay" counter automatically
        // at midnight. When we detect the date key changed, flush the previous day.
        if !lastKnownDateKey.isEmpty && dateKey != lastKnownDateKey {
            handleDayBoundary(previousDateKey: lastKnownDateKey, onDone: nil)
        }
        lastKnownDateKey = dateKey

        // Fast-path: write to UserDefaults so Dart's SharedPreferences poller sees it
        UserDefaults.standard.set(steps, forKey: "flutter.today_steps")

        // Durable path: append to file buffer (mirrors Kotlin's appendStepEvent)
        IOSStepBufferManager.shared.appendStepEvent(steps)

        // Live push to Flutter UI — must run on main thread
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod("onStepDetected", arguments: steps)
        }
    }

    // MARK: - Day boundary

    /// Queries CMPedometer for the exact final step count of `previousDateKey`,
    /// flushes the buffer, adds to the sync queue, and triggers an API sync.
    private func handleDayBoundary(previousDateKey: String, onDone: (() -> Void)?) {
        print("📅 IOSStepService: day boundary — finalising \(previousDateKey)")

        guard let prevDate = dateFromKey(previousDateKey) else {
            IOSStepBufferManager.shared.flushStepsToDaily()
            IOSStepBufferManager.shared.addToSyncQueue(dateKey: previousDateKey, type: "steps")
            triggerSync()
            onDone?()
            return
        }

        let cal      = Calendar.current
        let dayStart = cal.startOfDay(for: prevDate)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else {
            IOSStepBufferManager.shared.flushStepsToDaily()
            IOSStepBufferManager.shared.addToSyncQueue(dateKey: previousDateKey, type: "steps")
            triggerSync()
            onDone?()
            return
        }

        let finalizeTs = Int(dayEnd.timeIntervalSince1970) - 1

        pedometer.queryPedometerData(from: dayStart, to: dayEnd) { [weak self] data, error in
            guard let self = self else {
                onDone?(); return
            }

            if let data = data, error == nil {
                let finalSteps = data.numberOfSteps.intValue
                if finalSteps > 0 {
                    IOSStepBufferManager.shared.appendStepEvent(finalSteps, ts: finalizeTs)
                    print("📊 IOSStepService: final \(previousDateKey) = \(finalSteps) steps (CMPedometer)")
                }
            } else if let error = error {
                print("⚠️ IOSStepService.queryPedometerData error: \(error)")
            }

            // Also append the Watch-inclusive HealthKit total for the same day —
            // flushStepsToDaily() takes the max of all buffered entries per day,
            // so whichever source recorded more steps wins (mirrors sleep's
            // Apple Watch-priority finalization).
            self.healthFetcher.fetchTotalSteps(from: dayStart, to: dayEnd) { healthSteps in
                if healthSteps > 0 {
                    IOSStepBufferManager.shared.appendStepEvent(healthSteps, ts: finalizeTs)
                    print("🍎 IOSStepService: final \(previousDateKey) = \(healthSteps) steps (HealthKit)")
                }
                IOSStepBufferManager.shared.flushStepsToDaily()
                IOSStepBufferManager.shared.addToSyncQueue(dateKey: previousDateKey, type: "steps")
                self.triggerSync()
                onDone?()
            }
        }
    }

    // MARK: - Flush timer

    private func startPeriodicFlushTimer() {
        flushTimer?.invalidate()
        // 5-min flush matching Android's FLUSH_INTERVAL_MS = 5 * 60 * 1000
        flushTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            guard self?.isRunning == true else { return }
            IOSStepBufferManager.shared.flushStepsToDaily()
        }
    }

    // MARK: - Background refresh (BGAppRefreshTask)

    /// Entry point for BGAppRefreshTask "com.coretegra.snevva.step_refresh".
    /// Queries CMPedometer for today's total, flushes, and triggers API sync.
    /// The caller must call setTaskCompleted after the returned completion fires.
    func performBackgroundRefresh(completion: @escaping () -> Void) {
        guard CMPedometer.isStepCountingAvailable() else {
            completion()
            return
        }

        let now        = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let dateKey    = todayKey()

        pedometer.queryPedometerData(from: startOfDay, to: now) { [weak self] data, error in
            guard let self = self else {
                completion(); return
            }
            if let data = data, error == nil {
                let steps = data.numberOfSteps.intValue
                if steps > 0 {
                    UserDefaults.standard.set(steps, forKey: "flutter.today_steps")
                    IOSStepBufferManager.shared.appendStepEvent(steps)
                    print("📲 IOSStepService BGRefresh: \(steps) steps for \(dateKey)")
                }
            }
            // Top up with the Watch-inclusive HealthKit total, if higher.
            self.fetchAndMergeHealthKitStepsToday {
                IOSStepBufferManager.shared.flushStepsToDaily()
                IOSApiSyncService.shared.sync { _ in
                    completion()
                }
            }
        }
    }

    // MARK: - Background processing (BGProcessingTask)

    /// Entry point for BGProcessingTask "com.coretegra.snevva.api_sync".
    /// Handles any pending sync queue entries (steps and/or sleep).
    func performBackgroundSync(completion: @escaping (Bool) -> Void) {
        IOSStepBufferManager.shared.flushStepsToDaily()
        IOSApiSyncService.shared.sync { success in
            print(success
                ? "✅ IOSStepService BGSync: completed"
                : "⚠️ IOSStepService BGSync: partial failure")
            completion(success)
        }
    }

    // MARK: - Trigger sync

    func triggerSync() {
        IOSApiSyncService.shared.sync { success in
            print(success
                ? "✅ IOSStepService.triggerSync: done"
                : "⚠️ IOSStepService.triggerSync: partial")
        }
    }

    // MARK: - Date helpers

    func todayKey() -> String {
        return IOSStepBufferManager.shared.dateKeyFromDate(Date())
    }

    private func dateFromKey(_ key: String) -> Date? {
        // key format: "YYYY-MM-DD"
        let parts = key.components(separatedBy: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else {
            return nil
        }
        return Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
    }
}
import Foundation
import UIKit

// MARK: - IOSSleepWindow

struct IOSSleepWindow {
    let dateKey: String
    let start: Date
    let end: Date
}

// MARK: - IOSLockUnlockSleepDetector

/// iOS equivalent of Android's SleepNoticingService.
///
/// Uses UIApplication protected-data notifications as the lock/unlock signal:
///   • protectedDataWillBecomeUnavailableNotification  → device locked   (≈ SCREEN_OFF)
///   • protectedDataDidBecomeAvailableNotification     → device unlocked  (≈ SCREEN_ON)
///
/// Within the user's bedtime–waketime window, each lock–unlock pair is written
/// as a sleep interval to `sleep_buf.tmp` via IOSStepBufferManager, exactly
/// mirroring Android's BufferManager.appendSleepInterval flow.
///
/// At wake time the BGProcessingTask (`sleep_calc`) calls `flushOpenLockInterval`
/// to handle the edge case where the device was never unlocked overnight (the
/// Android "screen-never-turned-on" case in SleepCalcWorker).
final class IOSLockUnlockSleepDetector {

    static let shared = IOSLockUnlockSleepDetector()

    private init() {
    }

    private let minSleepGapMinutes = 3

    private let isoFmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Lifecycle

    /// Register for lock/unlock notifications and seed the sleep-window anchor.
    /// Call once from AppDelegate.application(_:didFinishLaunchingWithOptions:).
    func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceLocked),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceUnlocked),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
        print("🔐 IOSLockUnlockSleepDetector: started")
    }

    // MARK: - Device Lock → possible sleep start

    @objc private func deviceLocked() {
        guard let window = currentSleepWindow() else {
            return
        }
        let now = Date()
        guard isWithinWindow(now, window) else {
            return
        }
        let key = lockAnchorKey(for: window.dateKey)
        UserDefaults.standard.set(isoFmt.string(from: now), forKey: key)
        print("🔒 IOSLockUnlockSleepDetector: locked at \(now), window=\(window.dateKey)")
    }

    // MARK: - Device Unlock → close interval, write to buffer

    @objc private func deviceUnlocked() {
        guard let window = currentSleepWindow() else {
            return
        }
        let key = lockAnchorKey(for: window.dateKey)
        guard let lockIso = UserDefaults.standard.string(forKey: key),
              let lockTime = isoFmt.date(from: lockIso)
        else {
            return
        }
        UserDefaults.standard.removeObject(forKey: key)

        let now = Date()
        let start = lockTime < window.start ? window.start : lockTime
        let end = now > window.end ? window.end : now

        guard end > start else {
            return
        }
        let diffMin = Int(end.timeIntervalSince(start) / 60)
        guard diffMin >= minSleepGapMinutes else {
            print("🔓 IOSLockUnlockSleepDetector: interval \(diffMin)m < minGap, skipping")
            return
        }

        IOSStepBufferManager.shared.appendSleepInterval(
            dateKey: window.dateKey,
            startIso: isoFmt.string(from: start),
            endIso: isoFmt.string(from: end)
        )
        print("💤 IOSLockUnlockSleepDetector: wrote \(diffMin)m [\(window.dateKey)]")
    }

    // MARK: - BGTask flush (device-never-unlocked edge case)

    /// Closes and flushes any open lock anchor at wake time.
    /// Mirrors Android SleepCalcWorker's open `lastOffKey` detection.
    /// Returns the number of minutes flushed (0 if nothing to flush).
    @discardableResult
    func flushOpenLockInterval(for window: IOSSleepWindow) -> Int {
        let key = lockAnchorKey(for: window.dateKey)
        guard let lockIso = UserDefaults.standard.string(forKey: key),
              let lockTime = isoFmt.date(from: lockIso)
        else {
            return 0
        }
        UserDefaults.standard.removeObject(forKey: key)

        let start = lockTime < window.start ? window.start : lockTime
        let end = window.end  // worker fires at/after wake time

        guard end > start else {
            return 0
        }
        let diffMin = Int(end.timeIntervalSince(start) / 60)
        guard diffMin >= minSleepGapMinutes else {
            return 0
        }

        IOSStepBufferManager.shared.appendSleepInterval(
            dateKey: window.dateKey,
            startIso: isoFmt.string(from: start),
            endIso: isoFmt.string(from: end)
        )
        print("💤 IOSLockUnlockSleepDetector: flushed open interval \(diffMin)m [\(window.dateKey)]")
        return diffMin
    }

    // MARK: - Seed open-lock anchor on app launch

    /// Seeds the lock anchor to window.start if none exists yet and we are
    /// currently inside the sleep window. Mirrors Dart's
    /// SleepNoticingService.initializeForSleepWindow().
    ///
    /// This ensures that even if the app was suspended/killed during the night
    /// (so no lock notifications were received), the BGTask at wake time can
    /// still produce a full-window sleep duration via flushOpenLockInterval.
    func initializeForSleepWindow() {
        guard let window = currentSleepWindow() else {
            return
        }
        let now = Date()
        guard now >= window.start, now <= window.end else {
            return
        }

        let key = lockAnchorKey(for: window.dateKey)
        if UserDefaults.standard.string(forKey: key) == nil {
            UserDefaults.standard.set(isoFmt.string(from: window.start), forKey: key)
            print("🔒 IOSLockUnlockSleepDetector: seeded anchor from window.start (\(window.start))")
        }
    }

    // MARK: - Current sleep window

    /// Computes the active sleep window from UserDefaults.
    /// Mirrors _computeActiveSleepWindow() in Dart's SleepNoticingService.
    func currentSleepWindow() -> IOSSleepWindow? {
        let ud = UserDefaults.standard

        let bedMin = readMinutes(ud, base: "user_bedtime_ms")
        let wakeMin = readMinutes(ud, base: "user_waketime_ms")
        guard bedMin > 0 || wakeMin > 0 else {
            return nil
        }

        let cal = Calendar.current
        let now = Date()

        let bedToday = buildTOD(bedMin, base: now, cal: cal)
        let wakeToday = buildTOD(wakeMin, base: now, cal: cal)

        let sleepStart: Date
        if bedMin > wakeMin {
            // Overnight: bedtime crosses midnight (e.g. 22:00 → 07:00)
            if now < wakeToday || now < bedToday {
                // Before wake time (early morning) or daytime before bed → previous session
                sleepStart = buildTOD(bedMin, base: now.addingTimeInterval(-86400), cal: cal)
            } else {
                // After today's bed time → new session starts tonight
                sleepStart = bedToday
            }
        } else {
            // Same-day window (e.g. 02:00 → 10:00)
            sleepStart = bedToday
        }

        var sleepEnd = buildTOD(wakeMin, base: sleepStart, cal: cal)
        if sleepEnd <= sleepStart {
            sleepEnd = sleepEnd.addingTimeInterval(86400)
        }

        let dateKey = IOSStepBufferManager.shared.dateKeyFromDate(sleepStart)
        return IOSSleepWindow(dateKey: dateKey, start: sleepStart, end: sleepEnd)
    }

    // MARK: - Helpers

    private func lockAnchorKey(for dateKey: String) -> String {
        return "last_screen_off_\(dateKey)"
    }

    private func isWithinWindow(_ date: Date, _ window: IOSSleepWindow) -> Bool {
        return date >= window.start && date <= window.end
    }

    /// Reads an integer from UserDefaults, trying both bare key and "flutter." prefix
    /// to handle both shared_preferences_foundation v2 (no prefix) and v1 (with prefix).
    private func readMinutes(_ ud: UserDefaults, base key: String) -> Int {
        let v = ud.integer(forKey: key)
        if v > 0 {
            return v
        }
        return ud.integer(forKey: "flutter.\(key)")
    }

    private func buildTOD(_ minutes: Int, base: Date, cal: Calendar) -> Date {
        var c = cal.dateComponents([.year, .month, .day], from: base)
        c.hour = minutes / 60; c.minute = minutes % 60; c.second = 0
        return cal.date(from: c) ?? base
    }
}
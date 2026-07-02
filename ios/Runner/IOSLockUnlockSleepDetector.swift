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
/// At wake time the BGProcessingTask (`sleep_calc`) calls `flushOpenUnlockInterval`
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

    // MARK: - Device Lock → closes an open interrupt

    // Interrupt model: sleep = (waketime − bedtime) − Σ(interrupt_durations)
    //
    // An "interrupt" is the period the user had the phone unlocked (awake).
    //   deviceUnlocked → interrupt starts  → store unlock timestamp
    //   deviceLocked   → interrupt ends    → compute duration, write to interrupt_buf.tmp
    //
    // Sleep start is window.start (bedtime) by default — no first-lock anchor needed.
    // At wake-time BGTask: close any still-open interrupt, then:
    //   sleep = window_minutes − total_interrupt_minutes

    @objc private func deviceLocked() {
        guard let window = currentSleepWindow() else {
            return
        }
        let now = Date()
        if isWithinWindow(now, window) {
            // Keep the process resident for the rest of the night so this notification
            // (and protectedDataDidBecomeAvailable) keep firing after iOS would otherwise
            // suspend us — see IOSBackgroundAudioKeepAlive. No-ops if already running.
            IOSBackgroundAudioKeepAlive.shared.start()
        }
        // Close any open interrupt (phone was in use, now re-locked).
        let key = unlockAnchorKey(for: window.dateKey)
        guard let unlockIso = UserDefaults.standard.string(forKey: key),
              let unlockTime = isoFmt.date(from: unlockIso)
        else {
            print("🔒 IOSLockUnlockSleepDetector: locked at \(now) (no open interrupt)")
            return
        }
        UserDefaults.standard.removeObject(forKey: key)

        let start = unlockTime < window.start ? window.start : unlockTime
        let end = now > window.end ? window.end : now
        guard end > start else {
            return
        }

        let diffMin = Int(end.timeIntervalSince(start) / 60)
        IOSStepBufferManager.shared.appendInterruptInterval(
            dateKey: window.dateKey,
            unlockIso: isoFmt.string(from: start),
            lockIso: isoFmt.string(from: end)
        )
        print("🔒📱 IOSLockUnlockSleepDetector: interrupt closed \(diffMin)m [\(window.dateKey)]")
    }

    // MARK: - Device Unlock → interrupt starts

    @objc private func deviceUnlocked() {
        guard let window = currentSleepWindow() else {
            return
        }
        let now = Date()
        guard isWithinWindow(now, window) else {
            return
        }
        // Record unlock time — deviceLocked will close it as an interrupt segment.
        let key = unlockAnchorKey(for: window.dateKey)
        UserDefaults.standard.set(isoFmt.string(from: now), forKey: key)
        print("🔓 IOSLockUnlockSleepDetector: unlocked at \(now) — interrupt started [\(window.dateKey)]")
    }

    // MARK: - BGTask flush (phone still unlocked at wake time)

    /// Closes any open interrupt whose unlock side was never followed by a re-lock.
    /// Treats the period from unlock to window.end as a final awake interval.
    /// Returns the number of interrupt minutes flushed (0 if none pending).
    @discardableResult
    func flushOpenUnlockInterval(for window: IOSSleepWindow) -> Int {
        let key = unlockAnchorKey(for: window.dateKey)
        guard let unlockIso = UserDefaults.standard.string(forKey: key),
              let unlockTime = isoFmt.date(from: unlockIso)
        else {
            return 0
        }
        UserDefaults.standard.removeObject(forKey: key)

        let start = unlockTime < window.start ? window.start : unlockTime
        let end = window.end
        guard end > start else {
            return 0
        }

        let diffMin = Int(end.timeIntervalSince(start) / 60)
        guard diffMin > 0 else {
            return 0
        }

        IOSStepBufferManager.shared.appendInterruptInterval(
            dateKey: window.dateKey,
            unlockIso: isoFmt.string(from: start),
            lockIso: isoFmt.string(from: end)
        )
        print("📱 IOSLockUnlockSleepDetector: flushed open interrupt \(diffMin)m [\(window.dateKey)]")
        return diffMin
    }

    // MARK: - No-op seed (interrupt model needs no initial anchor)

    /// No-op — kept for call-site compatibility (AppDelegate, IOSStepService).
    /// The interrupt model uses window.start as the implicit sleep start,
    /// so no UserDefaults anchor needs to be seeded.
    func initializeForSleepWindow() {
        // No anchor required — sleep = window_duration − Σ(interrupt_durations).
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

    private func unlockAnchorKey(for dateKey: String) -> String {
        return "last_screen_on_\(dateKey)"
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
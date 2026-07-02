import Foundation
import AVFoundation

// MARK: - IOSBackgroundAudioKeepAlive

/// Keeps the app process resident overnight so IOSLockUnlockSleepDetector's lock/unlock
/// notifications keep firing after the device is locked.
///
/// iOS suspends a backgrounded app within seconds of `applicationDidEnterBackground`
/// unless it holds an active background execution mode. `protectedDataWillBecomeUnavailableNotification` /
/// `protectedDataDidBecomeAvailableNotification` are only delivered while the process is
/// running — a suspended app misses every lock/unlock cycle after the first, which
/// defeats the interrupt model entirely. Declaring `audio` in UIBackgroundModes and
/// keeping an AVAudioPlayer actively looping (silence, in this case) is the standard
/// technique overnight-tracking apps (Sleep Cycle, AutoSleep, Pillow) use to stay
/// resident — there is no other supported way to receive continuous screen-lock events
/// in the background on iOS.
///
/// Started by IOSLockUnlockSleepDetector on the first device lock inside the active sleep
/// window; stopped by IOSSleepService.finalizeSleep() once that night's total is written.
final class IOSBackgroundAudioKeepAlive {

    static let shared = IOSBackgroundAudioKeepAlive()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    private var player: AVAudioPlayer?
    private var shouldBePlaying = false

    var isRunning: Bool {
        shouldBePlaying
    }

    // MARK: - Start / stop

    func start() {
        guard !shouldBePlaying else {
            return
        }
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
            print("⚠️ IOSBackgroundAudioKeepAlive: silence.wav not bundled — cannot keep process alive overnight")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0.0
            p.prepareToPlay()
            p.play()
            player = p
            shouldBePlaying = true
            print("🎧 IOSBackgroundAudioKeepAlive: started")
        } catch {
            print("⚠️ IOSBackgroundAudioKeepAlive: failed to start — \(error)")
        }
    }

    func stop() {
        guard shouldBePlaying else {
            return
        }
        shouldBePlaying = false
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        print("🎧 IOSBackgroundAudioKeepAlive: stopped")
    }

    // MARK: - Interruptions

    /// Phone calls, Siri, and alarms interrupt playback and pause the session. Resume the
    /// loop when the interruption ends, otherwise the process can go back to being
    /// suspendable mid-window.
    @objc private func handleInterruption(_ note: Notification) {
        guard shouldBePlaying,
              let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue),
              type == .ended
        else {
            return
        }

        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
    }
}
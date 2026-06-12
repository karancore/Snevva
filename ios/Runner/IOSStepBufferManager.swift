import Foundation

// MARK: - SyncEntry

/// Typed sync queue entry — mirrors Kotlin's ApiSyncWorker.SyncEntry.
struct SyncEntry {
    let date: String   // "YYYY-MM-DD"
    let type: String   // "steps" | "sleep" | "both"
}

// MARK: - IOSStepBufferManager

/// Append-only step/daily-JSON buffer manager.
///
/// Mirrors Kotlin's BufferManager.kt exactly:
///
///   fs/<uid>/buffer/steps_buf.tmp   → "$epochSec,$steps\n"
///   fs/<uid>/daily/YYYY-MM-DD.json  → {date, steps:{total}, sleep:{…}, sent, created_at}
///   fs/<uid>/sync_queue.json        → [{"date":"…","type":"steps"}]
///
/// <uid> is read from UserDefaults["flutter.PatientCode"] (written by Dart on login).
/// On iOS, UserDefaults.standard maps to Flutter's SharedPreferences — the key
/// is stored without the "flutter." prefix by the shared_preferences_foundation
/// plugin, but written BY Dart as "flutter.<key>" on older plugin versions.
/// We read both forms and fall back to "anonymous" when neither is present.
final class IOSStepBufferManager {

    static let shared = IOSStepBufferManager()
    private init() {}

    private let flushIntervalSec: TimeInterval = 5 * 60
    private let maxBufferLines = 500
    private let lock = NSLock()
    private var lastFlushTime = Date()
    private var stepLineCount = 0

    // MARK: - Directory helpers

    /// User-scoped root: <AppSupport>/fs/<uid>/
    /// Matches Flutter's getApplicationSupportDirectory() + "fs/<uid>".
    func fsDir() -> URL? {
        guard let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        // shared_preferences_foundation (v2) stores keys WITHOUT "flutter." prefix.
        // Older plugin versions and the Kotlin side use the "flutter." prefix form.
        // Try both; fall back to "anonymous".
        let uid = UserDefaults.standard.string(forKey: "PatientCode")
            ?? UserDefaults.standard.string(forKey: "flutter.PatientCode")
            ?? "anonymous"
        let dir = appSupport.appendingPathComponent("fs/\(uid)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func bufferDir() -> URL? {
        guard let base = fsDir() else { return nil }
        let dir = base.appendingPathComponent("buffer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func dailyDir() -> URL? {
        guard let base = fsDir() else { return nil }
        let dir = base.appendingPathComponent("daily", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func stepsBufFile() -> URL? {
        return bufferDir()?.appendingPathComponent("steps_buf.tmp")
    }

    private func sleepBufFile() -> URL? {
        return bufferDir()?.appendingPathComponent("sleep_buf.tmp")
    }

    private func dailyFileURL(dateKey: String) -> URL? {
        return dailyDir()?.appendingPathComponent("\(dateKey).json")
    }

    func syncQueueFileURL() -> URL? {
        guard let base = fsDir() else { return nil }
        return base.appendingPathComponent("sync_queue.json")
    }

    // MARK: - Step buffer (append-only)

    /// Appends one step event. O(1) — no reads. Triggers auto-flush when thresholds are met.
    func appendStepEvent(_ steps: Int, ts: Int? = nil) {
        lock.lock()
        defer { lock.unlock() }

        guard let bufFile = stepsBufFile() else { return }
        let epoch = ts ?? Int(Date().timeIntervalSince1970)
        let line = "\(epoch),\(steps)\n"

        do {
            if FileManager.default.fileExists(atPath: bufFile.path) {
                let handle = try FileHandle(forWritingTo: bufFile)
                defer { handle.closeFile() }
                handle.seekToEndOfFile()
                if let data = line.data(using: .utf8) { handle.write(data) }
            } else {
                try line.write(to: bufFile, atomically: false, encoding: .utf8)
            }
            stepLineCount += 1
        } catch {
            print("❌ IOSStepBufferManager.appendStepEvent: \(error)")
            return
        }

        let elapsed = Date().timeIntervalSince(lastFlushTime)
        if elapsed >= flushIntervalSec || stepLineCount >= maxBufferLines {
            _flushStepsToDaily()   // already holding lock — call private variant
        }
    }

    /// Force-flush. Call on day change, app-background, or BGTask.
    func flushStepsToDaily() {
        lock.lock()
        defer { lock.unlock() }
        _flushStepsToDaily()
    }

    private func _flushStepsToDaily() {
        guard let bufFile = stepsBufFile(),
              FileManager.default.fileExists(atPath: bufFile.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: bufFile.path),
              (attrs[.size] as? Int ?? 0) > 0 else { return }

        do {
            let content = try String(contentsOf: bufFile, encoding: .utf8)
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            var maxPerDay: [String: Int] = [:]
            for line in lines {
                guard let (ts, steps) = parseStepLine(line) else { continue }
                let key = dateKeyFromEpoch(ts)
                maxPerDay[key] = max(maxPerDay[key] ?? 0, steps)
            }
            for (dateKey, steps) in maxPerDay {
                mergeStepsIntoDailyFile(dateKey: dateKey, steps: steps)
            }
            try FileManager.default.removeItem(at: bufFile)
            lastFlushTime = Date()
            stepLineCount = 0
            print("✅ IOSStepBufferManager: flushed \(maxPerDay.count) day(s)")
        } catch {
            print("❌ IOSStepBufferManager.flushStepsToDaily: \(error)")
        }
    }

    // MARK: - Daily JSON

    func mergeStepsIntoDailyFile(dateKey: String, steps: Int) {
        mergeDailyJson(dateKey: dateKey) { json in
            let current = (json["steps"] as? [String: Any])?["total"] as? Int ?? 0
            if steps > current {
                json["steps"] = ["total": steps] as [String: Any]
            }
        }
    }

    func readDailySteps(dateKey: String) -> Int {
        guard let file = dailyFileURL(dateKey: dateKey),
              FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return 0
        }
        return (json["steps"] as? [String: Any])?["total"] as? Int ?? 0
    }

    private func mergeDailyJson(dateKey: String, mutate: (inout [String: Any]) -> Void) {
        guard let file = dailyFileURL(dateKey: dateKey) else { return }
        var json: [String: Any]
        if FileManager.default.fileExists(atPath: file.path),
           let data = try? Data(contentsOf: file),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = parsed
        } else {
            json = emptyDailyJson(dateKey: dateKey)
        }
        mutate(&json)
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) else { return }
        try? data.write(to: file, options: .atomic)
    }

    private func emptyDailyJson(dateKey: String) -> [String: Any] {
        return [
            "date": dateKey,
            "steps": ["total": 0] as [String: Any],
            "sleep": ["total_sleep_minutes": 0, "segments": [] as [Any]] as [String: Any],
            "sent": false,
            "created_at": Int(Date().timeIntervalSince1970)
        ]
    }

    // MARK: - Sync queue (typed format, mirrors ApiSyncWorker.kt)

    func addToSyncQueue(dateKey: String, type: String = "steps") {
        guard let file = syncQueueFileURL() else { return }
        var queue = readSyncQueue()
        guard !queue.contains(where: { $0.date == dateKey && $0.type == type }) else { return }
        queue.append(SyncEntry(date: dateKey, type: type))
        writeSyncQueue(file: file, queue: queue)
        print("📋 IOSStepBufferManager: queued \(dateKey) [\(type)]")
    }

    func readSyncQueue() -> [SyncEntry] {
        guard let file = syncQueueFileURL(),
              FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return []
        }
        return raw.compactMap { elem -> SyncEntry? in
            if let obj = elem as? [String: String],
               let date = obj["date"], let type = obj["type"] {
                return SyncEntry(date: date, type: type)
            }
            // Legacy plain-string format — treat as "both" (matches Kotlin behaviour)
            if let str = elem as? String, !str.isEmpty {
                return SyncEntry(date: str, type: "both")
            }
            return nil
        }
    }

    func removeFromSyncQueue(_ entries: [SyncEntry]) {
        guard let file = syncQueueFileURL() else { return }
        var queue = readSyncQueue()
        queue.removeAll { entry in
            entries.contains { $0.date == entry.date && $0.type == entry.type }
        }
        writeSyncQueue(file: file, queue: queue)
    }

    private func writeSyncQueue(file: URL, queue: [SyncEntry]) {
        let array = queue.map { ["date": $0.date, "type": $0.type] }
        guard let data = try? JSONSerialization.data(withJSONObject: array) else { return }
        try? data.write(to: file, options: .atomic)
    }

    // MARK: - Sleep buffer (append-only, mirrors Dart FileStorageService.appendSleepInterval)

    /// Appends one sleep interval to `sleep_buf.tmp`.
    /// Format: `"$dateKey|$startIso|$endIso\n"` — identical to Dart and Android.
    func appendSleepInterval(dateKey: String, startIso: String, endIso: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let bufFile = sleepBufFile() else { return }
        let line = "\(dateKey)|\(startIso)|\(endIso)\n"
        do {
            if FileManager.default.fileExists(atPath: bufFile.path) {
                let handle = try FileHandle(forWritingTo: bufFile)
                defer { handle.closeFile() }
                handle.seekToEndOfFile()
                if let data = line.data(using: .utf8) { handle.write(data) }
            } else {
                try line.write(to: bufFile, atomically: false, encoding: .utf8)
            }
        } catch {
            print("❌ IOSStepBufferManager.appendSleepInterval: \(error)")
        }
    }

    /// Reads `sleep_buf.tmp`, sums segments per day, merges into daily JSON, deletes buffer.
    /// Call on app-background or before API sync.
    func flushSleepToDaily() {
        lock.lock()
        defer { lock.unlock() }
        _flushSleepToDaily()
    }

    private func _flushSleepToDaily() {
        guard let bufFile = sleepBufFile(),
              FileManager.default.fileExists(atPath: bufFile.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: bufFile.path),
              (attrs[.size] as? Int ?? 0) > 0 else { return }

        do {
            let content = try String(contentsOf: bufFile, encoding: .utf8)
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }

            var segmentsByDay: [String: [[String: String]]] = [:]
            for line in lines {
                guard let (dateKey, startIso, endIso) = parseSleepLine(line) else { continue }
                segmentsByDay[dateKey, default: []].append(
                    ["start": startIso, "end": endIso]
                )
            }

            for (dateKey, segments) in segmentsByDay {
                let totalMinutes = segments.reduce(0) { sum, seg in
                    guard let start = parseIso(seg["start"] ?? ""),
                          let end   = parseIso(seg["end"] ?? "") else { return sum }
                    return sum + Int(end.timeIntervalSince(start) / 60)
                }
                mergeSleepIntoDailyFile(dateKey: dateKey, totalMinutes: totalMinutes, segments: segments)
            }

            try FileManager.default.removeItem(at: bufFile)
            print("✅ IOSStepBufferManager: flushed sleep for \(segmentsByDay.count) day(s)")
        } catch {
            print("❌ IOSStepBufferManager.flushSleepToDaily: \(error)")
        }
    }

    // MARK: - Sleep daily JSON

    /// Writes sleep data to the daily JSON.
    /// Only updates if `totalMinutes` is >= the current stored total (HealthKit wins over fallback).
    func mergeSleepIntoDailyFile(dateKey: String, totalMinutes: Int, segments: [[String: String]]) {
        mergeDailyJson(dateKey: dateKey) { json in
            let existing = (json["sleep"] as? [String: Any])?["total_sleep_minutes"] as? Int ?? 0
            if totalMinutes >= existing {
                json["sleep"] = [
                    "total_sleep_minutes": totalMinutes,
                    "segments": segments
                ] as [String: Any]
            }
        }
    }

    func readDailySleepMinutes(dateKey: String) -> Int {
        guard let file = dailyFileURL(dateKey: dateKey),
              FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return 0
        }
        return (json["sleep"] as? [String: Any])?["total_sleep_minutes"] as? Int ?? 0
    }

    func readDailySleepSegments(dateKey: String) -> [[String: String]] {
        guard let file = dailyFileURL(dateKey: dateKey),
              FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sleepObj = json["sleep"] as? [String: Any],
              let segments = sleepObj["segments"] as? [[String: String]] else {
            return []
        }
        return segments
    }

    // MARK: - Parsers / date helpers

    private func parseStepLine(_ line: String) -> (Int, Int)? {
        let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: ",")
        guard parts.count >= 2,
              let ts = Int(parts[0]),
              let steps = Int(parts[1]) else { return nil }
        return (ts, steps)
    }

    private func dateKeyFromEpoch(_ epochSec: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epochSec))
        return dateKeyFromDate(date)
    }

    func dateKeyFromDate(_ date: Date) -> String {
        let cal = Calendar.current
        return String(format: "%04d-%02d-%02d",
                      cal.component(.year, from: date),
                      cal.component(.month, from: date),
                      cal.component(.day, from: date))
    }

    /// Parses a sleep buffer line: `"$dateKey|$startIso|$endIso"`.
    private func parseSleepLine(_ line: String) -> (String, String, String)? {
        let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: "|")
        guard parts.count >= 3 else { return nil }
        return (parts[0], parts[1], parts[2])
    }

    private func parseIso(_ iso: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: iso) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: iso)
    }
}
import Foundation
import UIKit
import CommonCrypto

// MARK: - IOSApiSyncService

/// Pure-Swift mirror of Kotlin's ApiSyncWorker.kt.
///
/// Reads sync_queue.json, posts encrypted payloads to the step (and sleep)
/// endpoints, and removes successfully synced entries from the queue.
///
/// Encryption: AES-256-CBC / PKCS7 with the same key/IV as EncryptionService.dart
/// and ApiSyncWorker.kt — the three implementations must stay in lock-step.
final class IOSApiSyncService {

    static let shared = IOSApiSyncService()
    private init() {}

    // ── Must match EncryptionService.dart and ApiSyncWorker.kt exactly ──
    private let aesKey = "jc8upb889n3SHP1LTveX0s3tCJOemFYo"  // 32 bytes → AES-256
    private let aesIV  = "6LG0mK7sv1SMvyfO"                   // 16 bytes

    private let baseURL       = "https://abdmstg.coretegra.com"
    private let stepEndpoint  = "/api/upsert/addsteprecord"
    private let sleepEndpoint = "/api/upsert/addsleeprecord"

    private let typeSteps = "steps"
    private let typeSleep = "sleep"
    private let typeBoth  = "both"

    // MARK: - Main entry point

    /// Reads the sync queue, posts each entry, removes succeeded entries.
    /// Runs entirely on a background thread; calls completion on that thread.
    func sync(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { completion(false); return }

            guard let token = self.authToken(), !token.isEmpty else {
                print("⚠️ IOSApiSyncService: no auth token — skipping")
                completion(true)   // don't retry; token arrives after login
                return
            }

            let bufMgr = IOSStepBufferManager.shared
            bufMgr.flushStepsToDaily()

            let queue = bufMgr.readSyncQueue()
            guard !queue.isEmpty else {
                print("📋 IOSApiSyncService: queue empty")
                completion(true)
                return
            }

            print("📋 IOSApiSyncService: processing \(queue.count) entry(ies)")
            let deviceInfo = self.buildDeviceInfoHeader()
            var allSucceeded = true
            var syncedEntries: [SyncEntry] = []

            for entry in queue {
                let parts = entry.date.components(separatedBy: "-")
                guard parts.count == 3,
                      let year  = Int(parts[0]),
                      let month = Int(parts[1]),
                      let day   = Int(parts[2]) else {
                    // Malformed date — remove from queue to prevent perpetual block
                    syncedEntries.append(entry)
                    continue
                }

                var entrySucceeded = true
                let shouldSyncSteps = entry.type == self.typeSteps || entry.type == self.typeBoth
                let shouldSyncSleep = entry.type == self.typeSleep || entry.type == self.typeBoth

                // ── Step sync ────────────────────────────────────────────────
                if shouldSyncSteps {
                    let steps = bufMgr.readDailySteps(dateKey: entry.date)
                    if steps > 0 {
                        let payload: [String: Any] = [
                            "Day": day, "Month": month, "Year": year,
                            "Time": "11:59 PM", "Count": steps
                        ]
                        let code = self.postEncryptedSync(
                            endpoint: self.stepEndpoint,
                            payload: payload,
                            token: token,
                            deviceInfo: deviceInfo
                        )
                        if code >= 200 && code < 300 {
                            print("✅ Steps synced \(entry.date): \(steps)")
                        } else {
                            print("❌ Steps sync failed \(entry.date): HTTP \(code)")
                            entrySucceeded = false
                            allSucceeded = false
                        }
                    }
                }

                // ── Sleep sync ────────────────────────────────────────────────
                if shouldSyncSleep {
                    let sleepMins = bufMgr.readDailySleepMinutes(dateKey: entry.date)
                    if sleepMins > 0 {
                        let segments  = bufMgr.readDailySleepSegments(dateKey: entry.date)
                        let sleepStart = segments.first?["start"] ?? "\(entry.date)T22:00:00.000"
                        let sleepEnd   = segments.last?["end"]   ?? estimateEnd(sleepStart, mins: sleepMins)

                        let sleepingFrom = extractHHmm(sleepStart)
                        let sleepingTo   = extractHHmm(sleepEnd)
                        let timeAmPm     = toAmPm(sleepingTo)

                        let sleepPayload: [String: Any] = [
                            "Day":          day,
                            "Month":        month,
                            "Year":         year,
                            "Time":         timeAmPm,
                            "SleepingFrom": sleepingFrom,
                            "SleepingTo":   sleepingTo,
                            "Count":        String(sleepMins)
                        ]
                        let code = self.postEncryptedSync(
                            endpoint: self.sleepEndpoint,
                            payload: sleepPayload,
                            token: token,
                            deviceInfo: deviceInfo
                        )
                        if code >= 200 && code < 300 {
                            print("✅ Sleep synced \(entry.date): \(sleepMins)m")
                        } else {
                            print("❌ Sleep sync failed \(entry.date): HTTP \(code)")
                            entrySucceeded = false
                            allSucceeded = false
                        }
                    } else {
                        print("ℹ️ Skipping sleep sync for \(entry.date): no sleep data")
                    }
                }

                if entrySucceeded { syncedEntries.append(entry) }
            }

            if !syncedEntries.isEmpty {
                bufMgr.removeFromSyncQueue(syncedEntries)
                print("🗑️ IOSApiSyncService: removed \(syncedEntries.count) synced entry(ies)")
            }

            completion(allSucceeded)
        }
    }

    // MARK: - Synchronous HTTP helper (used inside the serial background queue above)

    private func postEncryptedSync(
        endpoint: String,
        payload: [String: Any],
        token: String,
        deviceInfo: String
    ) -> Int {
        guard let bodyJson = try? JSONSerialization.data(withJSONObject: payload),
              let bodyStr = String(data: bodyJson, encoding: .utf8),
              let encrypted = encryptPayload(bodyStr),
              let url = URL(string: "\(baseURL)\(endpoint)") else {
            return 0
        }

        let requestBody: [String: Any] = ["data": encrypted.encryptedData]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else { return 0 }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(encrypted.hash, forHTTPHeaderField: "x-data-hash")
        request.setValue(deviceInfo, forHTTPHeaderField: "X-Device-Info")
        request.httpBody = bodyData

        // Synchronous dispatch so the for-loop above stays serial
        var responseCode = 0
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("❌ IOSApiSyncService postEncrypted error: \(error)")
            }
            responseCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return responseCode
    }

    // MARK: - AES-256-CBC (mirrors EncryptionService.dart and ApiSyncWorker.kt)

    private struct EncryptedPayload {
        let encryptedData: String
        let hash: String
    }

    private func encryptPayload(_ plainText: String) -> EncryptedPayload? {
        guard let keyData   = aesKey.data(using: .utf8),
              let ivData    = aesIV.data(using: .utf8),
              let plainData = plainText.data(using: .utf8) else { return nil }

        let keyBytes   = [UInt8](keyData)
        let ivBytes    = [UInt8](ivData)
        let plainBytes = [UInt8](plainData)

        let outputLen = plainBytes.count + kCCBlockSizeAES128
        var outputBuf  = [UInt8](repeating: 0, count: outputLen)
        var writtenLen = 0

        let status = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            keyBytes,  keyBytes.count,
            ivBytes,
            plainBytes, plainBytes.count,
            &outputBuf, outputLen,
            &writtenLen
        )

        guard status == kCCSuccess else {
            print("❌ IOSApiSyncService AES failed: \(status)")
            return nil
        }

        let cipherData     = Data(bytes: outputBuf, count: writtenLen)
        let base64Cipher   = cipherData.base64EncodedString()
        let hash           = sha256Hex(base64Cipher)
        return EncryptedPayload(encryptedData: base64Cipher, hash: hash)
    }

    private func sha256Hex(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Device info header (base64-encoded JSON, mirrors Kotlin buildDeviceInfoHeader)

    private func buildDeviceInfoHeader() -> String {
        let device = UIDevice.current
        let isSimulator: Bool = {
            #if targetEnvironment(simulator)
            return true
            #else
            return false
            #endif
        }()
        let info: [String: Any] = [
            "platform":   "ios",
            "brand":      "Apple",
            "model":      device.model,
            "device":     device.name,
            "product":    device.systemName,
            "hardware":   device.model,
            "physical":   (!isSimulator).description,
            "abi":        "arm64",
            "iosVersion": device.systemVersion,
            "sdkInt":     "",
            "lowRam":     "false"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: info),
              let str  = String(data: data, encoding: .utf8) else { return "" }
        return Data(str.utf8).base64EncodedString()
    }

    // MARK: - Sleep time helpers (mirror Kotlin ApiSyncWorker.kt helpers)

    /// Extracts "HH:mm" from an ISO datetime string.
    private func extractHHmm(_ iso: String) -> String {
        let timePart = iso.contains("T") ? String(iso.split(separator: "T").last ?? "") : iso
        guard timePart.count >= 5 else { return "00:00" }
        return String(timePart.prefix(5))
    }

    /// Converts "HH:mm" to "H:mm AM/PM" — mirrors Kotlin's toAmPm().
    private func toAmPm(_ hhmm: String) -> String {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2,
              let hour24 = Int(parts[0]),
              let minute = Int(parts[1]) else { return "12:00 AM" }
        let amPm  = hour24 < 12 ? "AM" : "PM"
        let hour12: Int
        switch hour24 {
        case 0:  hour12 = 12
        case 13...: hour12 = hour24 - 12
        default: hour12 = hour24
        }
        return "\(hour12):\(String(format: "%02d", minute)) \(amPm)"
    }

    /// Estimates a sleep-end ISO string from a start ISO and duration in minutes.
    private func estimateEnd(_ startIso: String, mins: Int) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let start = fmt.date(from: startIso) else {
            return "\(startIso.prefix(10))T06:00:00.000"
        }
        return fmt.string(from: start.addingTimeInterval(TimeInterval(mins * 60)))
    }

    // MARK: - Helpers

    private func authToken() -> String? {
        // Flutter SharedPreferences (shared_preferences_foundation v2) stores without prefix.
        // Try both forms.
        return UserDefaults.standard.string(forKey: "auth_token")
            ?? UserDefaults.standard.string(forKey: "flutter.auth_token")
    }
}
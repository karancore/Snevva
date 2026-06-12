import HealthKit

struct SleepSegment {
    let start: Date
    let end: Date
}

// MARK: - IOSHealthKitSleepFetcher

/// Queries HealthKit for sleep analysis samples and converts them to SleepSegments.
///
/// - Uses `HKCategoryTypeIdentifier.sleepAnalysis`.
/// - Filters out `inBed` (value 0) and `awake` (value 2) — counts only actual sleep.
/// - Merges overlapping segments before returning.
final class IOSHealthKitSleepFetcher {

    private let store = HKHealthStore()

    static var isAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    private var sleepType: HKCategoryType? {
        return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    }

    // MARK: - Authorization

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard Self.isAvailable, let type = sleepType else {
            completion(false, nil); return
        }
        store.requestAuthorization(toShare: nil, read: [type], completion: completion)
    }

    // MARK: - Query

    /// Fetches actual sleep segments (not in-bed or awake) for the given window.
    /// Returned segments are sorted and non-overlapping.
    func fetchSleepSegments(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping ([SleepSegment]) -> Void
    ) {
        guard Self.isAvailable, let type = sleepType else {
            completion([]); return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, error in
            guard let self = self else { completion([]); return }

            if let error = error {
                print("⚠️ IOSHealthKitSleepFetcher: \(error.localizedDescription)")
                completion([]); return
            }

            guard let samples = samples as? [HKCategorySample] else {
                completion([]); return
            }

            let sleepSamples = samples.filter { self.isActualSleep($0) }
            let segments = sleepSamples.map { SleepSegment(start: $0.startDate, end: $0.endDate) }
            completion(self.mergeOverlapping(segments))
        }

        store.execute(query)
    }

    // MARK: - Helpers

    /// Actual sleep: asleepUnspecified (pre-iOS 16 "asleep") = 1,
    /// asleepCore = 3, asleepDeep = 4, asleepREM = 5.
    /// Excludes inBed = 0 and awake = 2.
    private func isActualSleep(_ sample: HKCategorySample) -> Bool {
        if #available(iOS 16.0, *) {
            guard let v = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
            switch v {
            case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
                return true
            default:
                return false
            }
        } else {
            // Pre-iOS 16: value 1 is the only "asleep" stage (rawValue of deprecated .asleep)
            return sample.value == 1
        }
    }

    private func mergeOverlapping(_ segments: [SleepSegment]) -> [SleepSegment] {
        guard !segments.isEmpty else { return [] }
        let sorted = segments.sorted { $0.start < $1.start }
        var merged: [SleepSegment] = [sorted[0]]
        for seg in sorted.dropFirst() {
            let last = merged.last!
            if seg.start <= last.end {
                merged[merged.count - 1] = SleepSegment(
                    start: last.start,
                    end: max(last.end, seg.end)
                )
            } else {
                merged.append(seg)
            }
        }
        return merged
    }
}
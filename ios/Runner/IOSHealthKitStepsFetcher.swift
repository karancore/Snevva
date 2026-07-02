import HealthKit

// MARK: - IOSHealthKitStepsFetcher

/// Queries HealthKit for cumulative step count.
///
/// HealthKit merges/dedupes step samples across all contributing sources for the
/// same device family (iPhone + Apple Watch), so a single `HKStatisticsQuery` sum
/// already reflects Watch-only walks (e.g. phone left at home) without any extra
/// source filtering — mirrors the sleep fetcher's role of providing the
/// Watch-inclusive total that CMPedometer (iPhone-only) cannot see.
final class IOSHealthKitStepsFetcher {

    private let store = HKHealthStore()

    static var isAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    private var stepType: HKQuantityType? {
        return HKObjectType.quantityType(forIdentifier: .stepCount)
    }

    // MARK: - Authorization

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard Self.isAvailable, let type = stepType else {
            completion(false, nil); return
        }
        store.requestAuthorization(toShare: nil, read: [type], completion: completion)
    }

    // MARK: - Query

    /// Total step count in `[startDate, endDate)`, summed across all sources.
    func fetchTotalSteps(from startDate: Date, to endDate: Date, completion: @escaping (Int) -> Void) {
        guard Self.isAvailable, let type = stepType else {
            completion(0); return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, error in
            if let error = error {
                print("⚠️ IOSHealthKitStepsFetcher: \(error.localizedDescription)")
                completion(0); return
            }
            guard let sum = statistics?.sumQuantity() else {
                completion(0); return
            }
            completion(Int(sum.doubleValue(for: .count())))
        }

        store.execute(query)
    }
}
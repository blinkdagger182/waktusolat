import Foundation
import Observation

@MainActor
@Observable
final class WatchPrayerStore {
    private let suiteName = "group.app.riskcreatives.waktu"
    private let prayersKey = "prayersData"
    private let locationKey = "currentLocation"

    var prayers: WatchPrayerDay?
    var location: WatchPrayerLocation?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    func reload() {
        let defaults = UserDefaults(suiteName: suiteName)

        if let data = defaults?.data(forKey: prayersKey),
           let decoded = try? decoder.decode(WatchPrayerDay.self, from: data) {
            prayers = decoded
        } else {
            prayers = nil
        }

        if let data = defaults?.data(forKey: locationKey),
           let decoded = try? decoder.decode(WatchPrayerLocation.self, from: data) {
            location = decoded
        } else {
            location = nil
        }
    }

    var displayLocation: String {
        prayers?.city ?? location?.city ?? "Open iPhone app"
    }

    var todayPrayers: [WatchPrayer] {
        let source = prayers?.fullPrayers.isEmpty == false ? prayers?.fullPrayers : prayers?.prayers
        return source ?? []
    }

    var nextPrayer: WatchPrayer? {
        let now = Date()
        return todayPrayers.first(where: { $0.time > now }) ?? todayPrayers.first
    }

    var currentPrayer: WatchPrayer? {
        let now = Date()
        return todayPrayers.last(where: { $0.time <= now }) ?? todayPrayers.last
    }
}

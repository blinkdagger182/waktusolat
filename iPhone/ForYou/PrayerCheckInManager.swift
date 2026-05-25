import Foundation

enum PrayerCheckInSource: String, Codable {
    case autoOpen, wirid, dua, guidance
}

struct PrayerCheckInDisplayState {
    let count: Int
    let lastCheckedInAt: Date?
    let hasCurrentUserCheckedIn: Bool
}

@MainActor
final class PrayerCheckInManager: ObservableObject {
    @Published private(set) var displayState = PrayerCheckInDisplayState(
        count: 0, lastCheckedInAt: nil, hasCurrentUserCheckedIn: false
    )

    private let defaults = UserDefaults.standard

    func configure(prayer: String) {
        let checkedIn = hasCheckedIn(prayer: prayer)
        displayState = PrayerCheckInDisplayState(
            count: checkedIn ? 29 : 28,
            lastCheckedInAt: checkedInAt(prayer: prayer),
            hasCurrentUserCheckedIn: checkedIn
        )
    }

    func hasCheckedIn(prayer: String) -> Bool {
        defaults.object(forKey: storageKey(for: prayer)) != nil
    }

    func checkIn(prayer: String, source: PrayerCheckInSource) {
        guard !hasCheckedIn(prayer: prayer) else { return }
        let now = Date()
        let record = CheckInRecord(checkedInAt: now, source: source.rawValue)
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: storageKey(for: prayer))
        displayState = PrayerCheckInDisplayState(
            count: 29, lastCheckedInAt: now, hasCurrentUserCheckedIn: true
        )
    }

    private func storageKey(for prayer: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return "prayer_checkin_\(f.string(from: Date()))_\(prayer)"
    }

    private func checkedInAt(prayer: String) -> Date? {
        guard
            let data = defaults.data(forKey: storageKey(for: prayer)),
            let record = try? JSONDecoder().decode(CheckInRecord.self, from: data)
        else { return nil }
        return record.checkedInAt
    }

    private struct CheckInRecord: Codable {
        let checkedInAt: Date
        let source: String
    }
}

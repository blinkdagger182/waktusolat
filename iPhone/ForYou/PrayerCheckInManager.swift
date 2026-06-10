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
    private static let baseURL = "https://api-waktusolat.vercel.app"

    private var deviceId: String {
        if let id = defaults.string(forKey: "prayer_checkin_device_id") { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: "prayer_checkin_device_id")
        return id
    }

    func configure(prayer: String) {
        let checkedIn = hasCheckedIn(prayer: prayer)
        displayState = PrayerCheckInDisplayState(
            count: cachedRemoteCount(prayer: prayer),
            lastCheckedInAt: checkedInAt(prayer: prayer),
            hasCurrentUserCheckedIn: checkedIn
        )
        Task { await fetchRemoteStats(prayer: prayer) }
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
            count: todayCheckInCount(),
            lastCheckedInAt: now,
            hasCurrentUserCheckedIn: true
        )
        Task { await postRemoteCheckIn(prayer: prayer, source: source, checkedInAt: now) }
    }

    // MARK: - Network

    private func fetchRemoteStats(prayer: String) async {
        let key = normalizedPrayerKey(prayer)
        let date = todayDateString()
        guard let url = URL(string: "\(Self.baseURL)/api/checkin/prayer?prayerKey=\(key)&date=\(date)") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let remote = try? JSONDecoder().decode(RemoteStats.self, from: data) else { return }
        let checkedIn = hasCheckedIn(prayer: prayer)
        cacheRemoteCount(remote.count, prayer: prayer)
        displayState = PrayerCheckInDisplayState(
            count: remote.count,
            lastCheckedInAt: checkedIn ? checkedInAt(prayer: prayer) : nil,
            hasCurrentUserCheckedIn: checkedIn
        )
    }

    private func postRemoteCheckIn(prayer: String, source: PrayerCheckInSource, checkedInAt localTime: Date) async {
        guard let url = URL(string: "\(Self.baseURL)/api/checkin/prayer") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "prayerKey": normalizedPrayerKey(prayer),
            "date": todayDateString(),
            "deviceId": deviceId,
            "source": source.rawValue,
        ]
        guard let bodyData = try? JSONEncoder().encode(body) else { return }
        req.httpBody = bodyData
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let remote = try? JSONDecoder().decode(RemoteStats.self, from: data) else { return }
        displayState = PrayerCheckInDisplayState(
            count: remote.count,
            lastCheckedInAt: localTime,
            hasCurrentUserCheckedIn: true
        )
    }

    // MARK: - Local helpers

    private func cachedRemoteCount(prayer: String) -> Int {
        defaults.integer(forKey: remoteCountKey(prayer: prayer))
    }

    private func cacheRemoteCount(_ count: Int, prayer: String) {
        defaults.set(count, forKey: remoteCountKey(prayer: prayer))
    }

    private func remoteCountKey(prayer: String) -> String {
        "prayer_checkin_remote_count_\(todayDateString())_\(normalizedPrayerKey(prayer))"
    }

    private func todayCheckInCount() -> Int {
        let prefix = "prayer_checkin_\(todayDateString())_"
        return defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }.count
    }

    private func todayDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.string(from: Date())
    }

    private func storageKey(for prayer: String) -> String {
        "prayer_checkin_\(todayDateString())_\(prayer)"
    }

    private func checkedInAt(prayer: String) -> Date? {
        guard let data = defaults.data(forKey: storageKey(for: prayer)),
              let record = try? JSONDecoder().decode(CheckInRecord.self, from: data)
        else { return nil }
        return record.checkedInAt
    }

    private func normalizedPrayerKey(_ prayer: String) -> String {
        let lower = prayer.lowercased().trimmingCharacters(in: .whitespaces)
        switch lower {
        case "subuh", "fajr":                             return "fajr"
        case "syuruk", "shurooq", "sunrise", "ishraq":   return "sunrise"
        case "dhuha":                                      return "dhuha"
        case "dhuhr", "zuhur", "zuhr", "zohor",
             "jumuah", "jumaat":                          return "dhuhr"
        case "asr", "asar":                               return "asr"
        case "maghrib", "magrib":                         return "maghrib"
        case "isha", "isya", "isyak":                     return "isha"
        default:                                           return lower
        }
    }

    // MARK: - Codable helpers

    private struct CheckInRecord: Codable {
        let checkedInAt: Date
        let source: String
    }

    private struct RemoteStats: Decodable {
        let count: Int
        let lastCheckedInAt: Date?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            count = try c.decode(Int.self, forKey: .count)
            if let iso = try c.decodeIfPresent(String.self, forKey: .lastCheckedInAt) {
                lastCheckedInAt = ISO8601DateFormatter().date(from: iso)
            } else {
                lastCheckedInAt = nil
            }
        }

        private enum CodingKeys: String, CodingKey {
            case count
            case lastCheckedInAt
        }
    }
}

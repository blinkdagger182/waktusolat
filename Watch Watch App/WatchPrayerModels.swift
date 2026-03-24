import Foundation

struct WatchPrayerLocation: Codable {
    var city: String
    let latitude: Double
    let longitude: Double
    var countryCode: String?
}

struct WatchPrayerDay: Codable {
    let day: Date
    let city: String
    let prayers: [WatchPrayer]
    let fullPrayers: [WatchPrayer]
    var setNotification: Bool
}

struct WatchPrayer: Identifiable, Codable {
    var id = UUID()

    let nameArabic: String
    let nameTransliteration: String
    let nameEnglish: String
    let time: Date
    let image: String
    let rakah: String
    let sunnahBefore: String
    let sunnahAfter: String
}

extension WatchPrayer {
    var displayName: String {
        switch nameTransliteration.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "subuh":
            return "Fajr"
        case "syuruk", "shurooq":
            return "Shurooq"
        case "zuhur", "dhuhr":
            return "Dhuhr"
        case "asar", "asr":
            return "Asr"
        case "isyak", "isya", "isha":
            return "Isha"
        case "maghrib":
            return "Maghrib"
        default:
            return nameTransliteration
        }
    }
}

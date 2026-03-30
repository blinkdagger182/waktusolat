import Foundation
import SwiftUI

struct WatchWidgetLocation: Codable {
    let city: String
    let latitude: Double
    let longitude: Double
    let countryCode: String?
}

struct WatchWidgetPrayerDay: Codable {
    let day: Date
    let city: String
    let prayers: [WatchWidgetPrayer]
    let fullPrayers: [WatchWidgetPrayer]
    let setNotification: Bool
}

struct WatchWidgetPrayer: Identifiable, Codable, Equatable {
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

struct WatchWidgetMonthDay: Codable {
    let day: Int
    let doha: TimeInterval?
}

struct WatchWidgetMonthCache: Codable {
    let year: Int
    let monthNumber: Int
    let prayers: [WatchWidgetMonthDay]

    enum CodingKeys: String, CodingKey {
        case year
        case monthNumber = "month_number"
        case prayers
    }
}

struct WatchWidgetPrayerDisplayInfo: Equatable {
    let title: String
    let subtitle: String
    let time: Date
    let image: String
    let isDerivedDhuha: Bool
}

enum WatchWidgetSupport {
    static let appGroupID = "group.app.riskcreatives.waktu"
    static let prayersStorageKey = "prayersData"
    static let locationStorageKey = "currentLocation"
    static let prayerCalculationStorageKey = "prayerCalculation"
    static let accentColorStorageKey = "accentColor"
    static let legacyMonthCacheKey = "waktusolat.gps.month.cache.v1"
    static let monthCacheKeyPrefix = "waktusolat.gps.month.cache.v2."

    static func normalizedPrayerKey(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    static func isShurooqKey(_ key: String) -> Bool {
        key == "shurooq" || key == "syuruk" || key == "sunrise"
    }

    static func sourceLabel(calculation: String, countryCode: String?) -> String {
        if calculation == "Auto (By Location)" {
            switch countryCode?.uppercased() {
            case "MY": return "JAKIM"
            case "BN": return "MORA"
            case "SG": return "MUIS"
            case "ID": return "KEMENAG"
            case "US", "CA": return "ISNA"
            case "GB": return "MWL"
            default: return "MWL"
            }
        }

        switch calculation {
        case "Jabatan Kemajuan Islam Malaysia (JAKIM)": return "JAKIM"
        case "Kementerian Hal Ehwal Ugama (MORA)": return "MORA"
        case "Majlis Ugama Islam Singapura, Singapore": return "MUIS"
        case "KEMENAG - Kementerian Agama Republik Indonesia": return "KEMENAG"
        case "Islamic Society of North America (ISNA)",
             "Islamic Society of North America": return "ISNA"
        case "Moonsighting Committee Worldwide": return "Moonsighting"
        case "Muslim World League": return "MWL"
        default: return calculation
        }
    }

    static func monthCacheKey(for date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        return "\(monthCacheKeyPrefix)\(components.year ?? 0)-\(String(format: "%02d", components.month ?? 0))"
    }
}

extension Date {
    func widgetIsSameDay(as other: Date) -> Bool {
        Calendar(identifier: .gregorian).isDate(self, inSameDayAs: other)
    }
}

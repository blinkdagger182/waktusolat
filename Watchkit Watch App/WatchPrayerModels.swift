import Foundation
import SwiftUI

let watchSharedAppGroupID = "group.app.riskcreatives.waktu"

enum WatchAppLanguage: String {
    case english = "en"
    case malay = "ms"

    init(storedCode: String?) {
        let code = storedCode?.lowercased() ?? Locale.preferredLanguages.first?.lowercased() ?? "en"
        self = code.hasPrefix("ms") ? .malay : .english
    }

    var isMalay: Bool { self == .malay }
}

enum WatchAccentColor: String {
    case adaptive
    case red
    case orange
    case yellow
    case green
    case blue
    case indigo
    case cyan
    case teal
    case mint
    case purple
    case brown
    case lightPink
    case hotPink
    case emerald
    case coral

    static func fromStoredValue(_ raw: String?) -> WatchAccentColor {
        guard let raw else { return .adaptive }
        switch raw {
        case "pink":
            return .hotPink
        case "white", "default":
            return .adaptive
        default:
            return WatchAccentColor(rawValue: raw) ?? .adaptive
        }
    }

    var color: Color {
        switch self {
        case .adaptive: return .accentColor
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .indigo: return .indigo
        case .cyan: return .cyan
        case .teal: return .teal
        case .mint: return .mint
        case .purple: return .purple
        case .brown: return .brown
        case .lightPink: return Color(red: 1.0, green: 182.0 / 255.0, blue: 193.0 / 255.0)
        case .hotPink: return Color(red: 1.0, green: 105.0 / 255.0, blue: 180.0 / 255.0)
        case .emerald: return Color(red: 0.0, green: 168.0 / 255.0, blue: 107.0 / 255.0)
        case .coral: return Color(red: 1.0, green: 127.0 / 255.0, blue: 80.0 / 255.0)
        }
    }
}

struct WatchPrayerLocation: Codable, Equatable {
    var city: String
    let latitude: Double
    let longitude: Double
    var countryCode: String?
}

struct WatchPrayerDay: Codable, Equatable {
    let day: Date
    let city: String
    let prayers: [WatchPrayer]
    let fullPrayers: [WatchPrayer]
    var setNotification: Bool
}

struct WatchPrayer: Identifiable, Codable, Equatable {
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

struct WatchPrayerMonthDay: Decodable {
    let day: Int
    let fajr: TimeInterval
    let syuruk: TimeInterval
    let doha: TimeInterval?
    let dhuhr: TimeInterval
    let asr: TimeInterval
    let maghrib: TimeInterval
    let isha: TimeInterval
}

struct WatchPrayerMonthCache: Decodable {
    let zone: String
    let location: String?
    let province: String?
    let timezone: String?
    let year: Int
    let month: String?
    let monthNumber: Int
    let prayers: [WatchPrayerMonthDay]

    enum CodingKeys: String, CodingKey {
        case zone
        case regionId = "region_id"
        case location
        case province
        case timezone
        case year
        case month
        case monthNumber = "month_number"
        case prayers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let zoneValue = try container.decodeIfPresent(String.self, forKey: .zone) {
            zone = zoneValue
        } else {
            zone = try container.decode(String.self, forKey: .regionId)
        }
        location = try container.decodeIfPresent(String.self, forKey: .location)
        province = try container.decodeIfPresent(String.self, forKey: .province)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        year = try container.decode(Int.self, forKey: .year)
        month = try container.decodeIfPresent(String.self, forKey: .month)
        monthNumber = try container.decodeIfPresent(Int.self, forKey: .monthNumber) ?? 0
        prayers = try container.decode([WatchPrayerMonthDay].self, forKey: .prayers)
    }
}

struct WatchShurooqHelperTimes: Equatable {
    let ishraq: Date
    let dhuha: Date
}

struct WatchPrayerDisplayInfo: Equatable {
    let nameTransliteration: String
    let nameEnglish: String
    let nameArabic: String
    let time: Date
    let image: String
    let isDerivedDhuha: Bool
}

enum WatchPrayerPresentation {
    static let prayerCalculationStorageKey = "prayerCalculation"
    static let accentColorStorageKey = "accentColor"
    static let appLanguageStorageKey = "appLanguageCode"
    static let prayersStorageKey = "prayersData"
    static let locationStorageKey = "currentLocation"
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

    static func shortSourceLabel(calculation: String, countryCode: String?) -> String {
        if calculation == "Auto (By Location)" {
            return autoSourceLabel(for: countryCode)
        }

        switch calculation {
        case "Jabatan Kemajuan Islam Malaysia (JAKIM)":
            return "JAKIM"
        case "Kementerian Hal Ehwal Ugama (MORA)":
            return "MORA"
        case "Majlis Ugama Islam Singapura, Singapore":
            return "MUIS"
        case "KEMENAG - Kementerian Agama Republik Indonesia":
            return "KEMENAG"
        case "Islamic Society of North America (ISNA)",
             "Islamic Society of North America":
            return "ISNA"
        case "Moonsighting Committee Worldwide":
            return "Moonsighting"
        case "Muslim World League":
            return "MWL"
        default:
            return calculation
        }
    }

    static func autoSourceLabel(for countryCode: String?) -> String {
        switch countryCode?.uppercased() {
        case "MY":
            return "JAKIM"
        case "BN":
            return "MORA"
        case "SG":
            return "MUIS"
        case "ID":
            return "KEMENAG"
        case "US", "CA":
            return "ISNA"
        case "GB":
            return "MWL"
        default:
            return "MWL"
        }
    }

    static func monthCacheKey(for date: Date) -> String {
        let components = Calendar.gregorian.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return "\(monthCacheKeyPrefix)\(year)-\(String(format: "%02d", month))"
    }

    static func shurooqHelpers(
        prayers: [WatchPrayer],
        countryCode: String?,
        storedDhuha: Date?
    ) -> [UUID: WatchShurooqHelperTimes] {
        guard let countryCode = countryCode?.uppercased(), countryCode == "MY" || countryCode == "BN" else {
            return [:]
        }

        guard let shurooq = prayers.first(where: { isShurooqKey(normalizedPrayerKey($0.nameTransliteration)) }) else {
            return [:]
        }

        let ishraq = shurooq.time.addingTimeInterval(18 * 60)
        let dhuha: Date

        if countryCode == "BN" {
            guard let storedDhuha, storedDhuha > shurooq.time else { return [:] }
            dhuha = storedDhuha
        } else {
            guard let fajr = prayers.first(where: { normalizedPrayerKey($0.nameTransliteration) == "fajr" }) else {
                return [:]
            }
            let sunriseGap = shurooq.time.timeIntervalSince(fajr.time)
            guard sunriseGap > 0 else { return [:] }
            dhuha = shurooq.time.addingTimeInterval(sunriseGap / 3)
        }

        return [shurooq.id: WatchShurooqHelperTimes(ishraq: ishraq, dhuha: dhuha)]
    }

    static func displayInfo(
        for prayer: WatchPrayer,
        in prayers: [WatchPrayer],
        countryCode: String?,
        storedDhuha: Date?,
        now: Date
    ) -> WatchPrayerDisplayInfo {
        let normalizedName = normalizedPrayerKey(prayer.nameTransliteration)
        let base = WatchPrayerDisplayInfo(
            nameTransliteration: prayer.nameTransliteration,
            nameEnglish: prayer.nameEnglish,
            nameArabic: prayer.nameArabic,
            time: prayer.time,
            image: prayer.image,
            isDerivedDhuha: false
        )

        guard
            let countryCode = countryCode?.uppercased(),
            (countryCode == "MY" || countryCode == "BN"),
            isShurooqKey(normalizedName),
            now.isSameDay(as: prayer.time),
            let helper = shurooqHelpers(prayers: prayers, countryCode: countryCode, storedDhuha: storedDhuha)[prayer.id],
            let dhuhr = prayers.first(where: {
                let key = normalizedPrayerKey($0.nameTransliteration)
                return key == "dhuhr" || key == "zuhur" || key == "jumuah"
            }),
            now >= helper.dhuha,
            now < dhuhr.time
        else {
            return base
        }

        return WatchPrayerDisplayInfo(
            nameTransliteration: "Dhuha",
            nameEnglish: "Forenoon",
            nameArabic: "الضُّحَى",
            time: helper.dhuha,
            image: prayer.image,
            isDerivedDhuha: true
        )
    }

    static func displayedName(for prayer: WatchPrayer, language: WatchAppLanguage) -> String {
        let key = normalizedPrayerKey(prayer.nameTransliteration)
        switch key {
        case "subuh":
            return language.isMalay ? "Subuh" : "Fajr"
        case "syuruk", "shurooq", "sunrise":
            return language.isMalay ? "Syuruk" : "Shurooq"
        case "zuhur", "dhuhr":
            return language.isMalay ? "Zuhur" : "Dhuhr"
        case "asar", "asr":
            return language.isMalay ? "Asar" : "Asr"
        case "isyak", "isya", "isha":
            return language.isMalay ? "Isyak" : "Isha"
        default:
            return prayer.nameTransliteration
        }
    }
}

extension Calendar {
    static let gregorian = Calendar(identifier: .gregorian)
}

extension Date {
    func isSameDay(as other: Date) -> Bool {
        Calendar.gregorian.isDate(self, inSameDayAs: other)
    }
}

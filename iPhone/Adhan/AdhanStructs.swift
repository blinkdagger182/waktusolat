import SwiftUI
import CoreLocation

struct Location: Codable, Equatable {
    var city: String
    let latitude: Double
    let longitude: Double
    var countryCode: String? = nil
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
}

struct ResolvedPrayerArea: Codable, Equatable {
    let regionId: String
    let location: String
    let province: String
    let timezone: String
    let resolvedBy: String

    var displayName: String {
        "\(Self.prettyName(location)), \(Self.prettyName(province))"
    }

    static func prettyName(_ raw: String) -> String {
        raw
            .split(separator: " ")
            .map { token in
                let upper = token.uppercased()
                switch upper {
                case "KAB.": return "Kab."
                case "KOTA": return "Kota"
                case "DI": return "DI"
                case "DKI": return "DKI"
                case "NAD": return "NAD"
                default:
                    let lower = token.lowercased()
                    return lower.prefix(1).uppercased() + lower.dropFirst()
                }
            }
            .joined(separator: " ")
    }
}

struct Prayers: Identifiable, Codable, Equatable {
    var id = UUID()
    
    let day: Date
    let city: String
    
    let prayers: [Prayer]
    let fullPrayers: [Prayer]
    
    var setNotification: Bool
}

struct Prayer: Identifiable, Codable, Equatable {
    var id = UUID()
    
    let nameArabic: String
    let nameTransliteration: String
    let nameEnglish: String
    
    let time: Date
    let image: String
    
    let rakah: String
    let sunnahBefore: String
    let sunnahAfter: String
    
    static func ==(lhs: Prayer, rhs: Prayer) -> Bool {
        return lhs.id == rhs.id
    }
}

struct HijriDate: Identifiable, Codable {
    var id: Date { date }
    
    let english: String
    let arabic: String
    
    let date: Date
}

struct ShurooqDerivedHelperTimes: Equatable {
    let ishraq: Date
    let dhuha: Date
}

struct PrayerDisplayInfo: Equatable {
    let nameTransliteration: String
    let nameEnglish: String
    let nameArabic: String
    let time: Date
    let image: String
    let usesSecondarySunStyle: Bool
    let isDerivedDhuha: Bool
}

enum PrayerDerivedTimes {
    private static func resolvedDerivedSunCountryCode(for prayers: [Prayer], countryCode: String?) -> String? {
        if let countryCode = countryCode?.uppercased(), countryCode == "MY" || countryCode == "BN" {
            return countryCode
        }

        let normalizedNames = Set(prayers.map { normalizedPrayerKey($0.nameTransliteration) })
        let hasSunriseSlot =
            normalizedNames.contains("syuruk") ||
            normalizedNames.contains("shurooq") ||
            normalizedNames.contains("sunrise")
        let hasFajrSlot =
            normalizedNames.contains("subuh") ||
            normalizedNames.contains("fajr")
        let hasMiddaySlot =
            normalizedNames.contains("zuhur") ||
            normalizedNames.contains("dhuhr") ||
            normalizedNames.contains("jumuah")
        let looksLikeWidgetPrayerList = hasSunriseSlot && hasFajrSlot && hasMiddaySlot

        return looksLikeWidgetPrayerList ? "MY" : nil
    }

    static func shurooqHelpers(
        for prayers: [Prayer],
        countryCode: String?,
        storedDhuha: Date? = nil
    ) -> [UUID: ShurooqDerivedHelperTimes] {
        guard let countryCode = resolvedDerivedSunCountryCode(for: prayers, countryCode: countryCode) else { return [:] }

        guard let shurooq = prayers.first(where: { isShurooqKey(normalizedPrayerKey($0.nameTransliteration)) }) else {
            return [:]
        }

        let ishraq = shurooq.time.addingTimeInterval(TimeInterval(18 * 60))
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

        return [
            shurooq.id: ShurooqDerivedHelperTimes(
                ishraq: ishraq,
                dhuha: dhuha
            )
        ]
    }

    static func displayInfo(
        for prayer: Prayer,
        in prayers: [Prayer],
        countryCode: String?,
        storedDhuha: Date? = nil,
        now: Date = Date()
    ) -> PrayerDisplayInfo {
        let normalizedName = normalizedPrayerKey(prayer.nameTransliteration)
        let baseDisplay = PrayerDisplayInfo(
            nameTransliteration: prayer.nameTransliteration,
            nameEnglish: prayer.nameEnglish,
            nameArabic: prayer.nameArabic,
            time: prayer.time,
            image: prayer.image,
            usesSecondarySunStyle: normalizedName == "shurooq",
            isDerivedDhuha: false
        )

        guard isShurooqKey(normalizedName) else {
            return baseDisplay
        }

        guard let countryCode = resolvedDerivedSunCountryCode(for: prayers, countryCode: countryCode) else {
            return baseDisplay
        }

        guard now.isSameDay(as: prayer.time) else {
            return baseDisplay
        }

        guard
            let helperTimes = shurooqHelpers(for: prayers, countryCode: countryCode, storedDhuha: storedDhuha)[prayer.id],
            let middayPrayer = prayers.first(where: {
                let key = normalizedPrayerKey($0.nameTransliteration)
                return key == "dhuhr" || key == "zuhur" || key == "jumuah"
            })
        else {
            return baseDisplay
        }

        guard now >= helperTimes.dhuha, now < middayPrayer.time else {
            return baseDisplay
        }

        return PrayerDisplayInfo(
            nameTransliteration: "Dhuha",
            nameEnglish: "Forenoon",
            nameArabic: "الضُّحَى",
            time: helperTimes.dhuha,
            image: prayer.image,
            usesSecondarySunStyle: true,
            isDerivedDhuha: true
        )
    }

    private static func normalizedPrayerKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isShurooqKey(_ key: String) -> Bool {
        key == "shurooq" || key == "syuruk" || key == "sunrise"
    }
}

extension Date {
    func isSameDay(as date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: date)
    }
    
    func addingMinutes(_ minutes: Int) -> Date {
        self.addingTimeInterval(TimeInterval(minutes * 60))
    }
}

extension Character {
    var asciiDigitValue: UInt32? {
        guard let v = unicodeScalars.first?.value, (48...57).contains(v) else { return nil }
        return v - 48        // '0' is 48
    }
}

extension DateFormatter {
    static let timeAR: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.locale    = Locale(identifier: "ar")
        f.timeZone  = .current
        return f
    }()

    static let timeEN: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.timeZone  = .current
        return f
    }()
}

extension Double {
    var stringRepresentation: String {
        return String(format: "%.3f", self)
    }
}

extension CLLocationCoordinate2D {
    var stringRepresentation: String {
        let lat = String(format: "%.3f", self.latitude)
        let lon = String(format: "%.3f", self.longitude)
        return "(\(lat), \(lon))"
    }
}

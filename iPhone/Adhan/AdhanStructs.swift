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
    static func shurooqHelpers(for prayers: [Prayer], countryCode: String?) -> [UUID: ShurooqDerivedHelperTimes] {
        guard countryCode?.uppercased() == "MY" else { return [:] }

        guard
            let fajr = prayers.first(where: { normalizedPrayerKey($0.nameTransliteration) == "fajr" }),
            let shurooq = prayers.first(where: { normalizedPrayerKey($0.nameTransliteration) == "shurooq" })
        else {
            return [:]
        }

        let sunriseGap = shurooq.time.timeIntervalSince(fajr.time)
        guard sunriseGap > 0 else { return [:] }

        let ishraq = shurooq.time.addingTimeInterval(TimeInterval(18 * 60))
        let dhuha = shurooq.time.addingTimeInterval(sunriseGap / 3)

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

        guard countryCode?.uppercased() == "MY", normalizedName == "shurooq" else {
            return baseDisplay
        }

        guard now.isSameDay(as: prayer.time) else {
            return baseDisplay
        }

        guard
            let helperTimes = shurooqHelpers(for: prayers, countryCode: countryCode)[prayer.id],
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

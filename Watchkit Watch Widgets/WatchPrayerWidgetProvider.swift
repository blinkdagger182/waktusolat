import Foundation
import SwiftUI
import WidgetKit

struct WatchPrayerWidgetEntry: TimelineEntry {
    let date: Date
    let city: String
    let sourceLabel: String
    let currentPrayer: WatchWidgetPrayer?
    let nextPrayer: WatchWidgetPrayer?
    let prayers: [WatchWidgetPrayer]
    let countryCode: String?
    let storedDhuha: Date?
    let accentRawValue: String?
}

struct WatchPrayerWidgetProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: WatchWidgetSupport.appGroupID)
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    func placeholder(in context: Context) -> WatchPrayerWidgetEntry {
        previewEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchPrayerWidgetEntry) -> Void) {
        completion(loadEntry(for: .now) ?? previewEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchPrayerWidgetEntry>) -> Void) {
        let now = Date()
        let baseEntry = loadEntry(for: now) ?? previewEntry(date: now)
        var entries = [baseEntry]

        let transitionDates = exactTransitionDates(after: now, prayers: baseEntry.prayers, countryCode: baseEntry.countryCode, storedDhuha: baseEntry.storedDhuha)
        for transition in transitionDates {
            if let entry = loadEntry(for: transition) {
                entries.append(entry)
            }
        }

        let refresh = transitionDates.first ?? Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        completion(Timeline(entries: entries.sorted { $0.date < $1.date }, policy: .after(refresh)))
    }

    private func loadEntry(for date: Date) -> WatchPrayerWidgetEntry? {
        guard
            let prayerData = defaults?.data(forKey: WatchWidgetSupport.prayersStorageKey),
            let prayerDay = try? decoder.decode(WatchWidgetPrayerDay.self, from: prayerData)
        else {
            return nil
        }

        let locationData = defaults?.data(forKey: WatchWidgetSupport.locationStorageKey)
        let location = locationData.flatMap { try? decoder.decode(WatchWidgetLocation.self, from: $0) }
        let prayers = prayerDay.fullPrayers.isEmpty ? prayerDay.prayers : prayerDay.fullPrayers
        let current = prayers.last(where: { $0.time <= date }) ?? prayers.last
        let next = prayers.first(where: { $0.time > date }) ?? prayers.first
        let calculation = defaults?.string(forKey: WatchWidgetSupport.prayerCalculationStorageKey) ?? "Auto (By Location)"
        let countryCode = location?.countryCode?.uppercased()

        return WatchPrayerWidgetEntry(
            date: date,
            city: prayerDay.city.isEmpty ? (location?.city ?? "Waktu") : prayerDay.city,
            sourceLabel: WatchWidgetSupport.sourceLabel(calculation: calculation, countryCode: countryCode),
            currentPrayer: current,
            nextPrayer: next,
            prayers: prayers,
            countryCode: countryCode,
            storedDhuha: storedDhuha(for: date, countryCode: countryCode),
            accentRawValue: defaults?.string(forKey: WatchWidgetSupport.accentColorStorageKey)
        )
    }

    private func storedDhuha(for date: Date, countryCode: String?) -> Date? {
        guard countryCode == "BN" else { return nil }
        let keyedCache = defaults?.data(forKey: WatchWidgetSupport.monthCacheKey(for: date))
        let legacyCache = defaults?.data(forKey: WatchWidgetSupport.legacyMonthCacheKey)
        let data = keyedCache ?? legacyCache

        guard
            let data,
            let month = try? decoder.decode(WatchWidgetMonthCache.self, from: data),
            let day = Calendar(identifier: .gregorian).dateComponents([.day], from: date).day,
            let cachedDay = month.prayers.first(where: { $0.day == day }),
            let doha = cachedDay.doha,
            doha > 0
        else {
            return nil
        }

        return Date(timeIntervalSince1970: doha)
    }

    private func exactTransitionDates(after now: Date, prayers: [WatchWidgetPrayer], countryCode: String?, storedDhuha: Date?) -> [Date] {
        var dates = prayers.map(\.time).filter { $0 > now }

        if let dhuhaTransition = shurooqHelper(prayers: prayers, countryCode: countryCode, storedDhuha: storedDhuha)?.dhuha,
           dhuhaTransition > now {
            dates.append(dhuhaTransition)
        }

        return dates.sorted()
    }

    private func shurooqHelper(prayers: [WatchWidgetPrayer], countryCode: String?, storedDhuha: Date?) -> (ishraq: Date, dhuha: Date)? {
        guard let countryCode = countryCode?.uppercased(), countryCode == "MY" || countryCode == "BN" else { return nil }
        guard let shurooq = prayers.first(where: { WatchWidgetSupport.isShurooqKey(WatchWidgetSupport.normalizedPrayerKey($0.nameTransliteration)) }) else {
            return nil
        }

        let ishraq = shurooq.time.addingTimeInterval(18 * 60)
        if countryCode == "BN" {
            guard let storedDhuha, storedDhuha > shurooq.time else { return nil }
            return (ishraq, storedDhuha)
        }

        guard let fajr = prayers.first(where: { WatchWidgetSupport.normalizedPrayerKey($0.nameTransliteration) == "fajr" }) else {
            return nil
        }

        let sunriseGap = shurooq.time.timeIntervalSince(fajr.time)
        guard sunriseGap > 0 else { return nil }
        return (ishraq, shurooq.time.addingTimeInterval(sunriseGap / 3))
    }
}

extension WatchPrayerWidgetProvider {
    func displayInfo(for prayer: WatchWidgetPrayer, in entry: WatchPrayerWidgetEntry, now: Date) -> WatchWidgetPrayerDisplayInfo {
        let base = WatchWidgetPrayerDisplayInfo(
            title: prayer.nameTransliteration,
            subtitle: prayer.nameEnglish,
            time: prayer.time,
            image: prayer.image,
            isDerivedDhuha: false
        )

        let key = WatchWidgetSupport.normalizedPrayerKey(prayer.nameTransliteration)
        guard
            WatchWidgetSupport.isShurooqKey(key),
            let countryCode = entry.countryCode?.uppercased(),
            (countryCode == "MY" || countryCode == "BN"),
            now.widgetIsSameDay(as: prayer.time),
            let helper = shurooqHelper(prayers: entry.prayers, countryCode: entry.countryCode, storedDhuha: entry.storedDhuha),
            let dhuhr = entry.prayers.first(where: {
                let name = WatchWidgetSupport.normalizedPrayerKey($0.nameTransliteration)
                return name == "dhuhr" || name == "zuhur" || name == "jumuah"
            }),
            now >= helper.dhuha,
            now < dhuhr.time
        else {
            return base
        }

        return WatchWidgetPrayerDisplayInfo(
            title: "Dhuha",
            subtitle: "Forenoon",
            time: helper.dhuha,
            image: prayer.image,
            isDerivedDhuha: true
        )
    }

    func accentColor(for rawValue: String?) -> Color {
        switch rawValue {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "indigo": return .indigo
        case "cyan": return .cyan
        case "teal": return .teal
        case "mint": return .mint
        case "purple": return .purple
        case "brown": return .brown
        case "lightPink": return Color(red: 1.0, green: 182.0 / 255.0, blue: 193.0 / 255.0)
        case "hotPink", "pink": return Color(red: 1.0, green: 105.0 / 255.0, blue: 180.0 / 255.0)
        case "emerald": return Color(red: 0.0, green: 168.0 / 255.0, blue: 107.0 / 255.0)
        case "coral": return Color(red: 1.0, green: 127.0 / 255.0, blue: 80.0 / 255.0)
        default: return .accentColor
        }
    }

    func previewEntry(date: Date) -> WatchPrayerWidgetEntry {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: date)
        func time(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? date
        }
        let prayers = [
            WatchWidgetPrayer(nameArabic: "الفَجْر", nameTransliteration: "Fajr", nameEnglish: "Dawn", time: time(5, 42), image: "sunrise", rakah: "2", sunnahBefore: "2", sunnahAfter: "0"),
            WatchWidgetPrayer(nameArabic: "الشُّرُوق", nameTransliteration: "Shurooq", nameEnglish: "Sunrise", time: time(7, 2), image: "sunrise.fill", rakah: "0", sunnahBefore: "0", sunnahAfter: "0"),
            WatchWidgetPrayer(nameArabic: "الظُّهْر", nameTransliteration: "Dhuhr", nameEnglish: "Noon", time: time(13, 15), image: "sun.max", rakah: "4", sunnahBefore: "2 and 2", sunnahAfter: "2"),
            WatchWidgetPrayer(nameArabic: "العَصْر", nameTransliteration: "Asr", nameEnglish: "Afternoon", time: time(16, 35), image: "sun.min", rakah: "4", sunnahBefore: "0", sunnahAfter: "0"),
            WatchWidgetPrayer(nameArabic: "المَغْرِب", nameTransliteration: "Maghrib", nameEnglish: "Sunset", time: time(19, 20), image: "sunset", rakah: "3", sunnahBefore: "0", sunnahAfter: "2"),
            WatchWidgetPrayer(nameArabic: "العِشَاء", nameTransliteration: "Isha", nameEnglish: "Night", time: time(20, 35), image: "moon", rakah: "4", sunnahBefore: "0", sunnahAfter: "2")
        ]
        return WatchPrayerWidgetEntry(
            date: date,
            city: "Kuala Lumpur",
            sourceLabel: "JAKIM",
            currentPrayer: prayers.first,
            nextPrayer: prayers.dropFirst().first,
            prayers: prayers,
            countryCode: "MY",
            storedDhuha: nil,
            accentRawValue: "green"
        )
    }
}

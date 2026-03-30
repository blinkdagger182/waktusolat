import Foundation
import Combine
import WidgetKit

@MainActor
final class WatchPrayerStore: ObservableObject {
    @Published private(set) var day: WatchPrayerDay?
    @Published private(set) var location: WatchPrayerLocation?
    @Published private(set) var accentColor: WatchAccentColor = .adaptive
    @Published private(set) var language: WatchAppLanguage = .english
    @Published private(set) var prayerCalculation: String = "Auto (By Location)"
    @Published private(set) var lastRefreshAt: Date?

    private let defaults = UserDefaults(suiteName: watchSharedAppGroupID)
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    func reload() {
        if let data = defaults?.data(forKey: WatchPrayerPresentation.prayersStorageKey),
           let decoded = try? decoder.decode(WatchPrayerDay.self, from: data) {
            day = decoded
        } else {
            day = nil
        }

        if let data = defaults?.data(forKey: WatchPrayerPresentation.locationStorageKey),
           let decoded = try? decoder.decode(WatchPrayerLocation.self, from: data) {
            location = decoded
        } else {
            location = nil
        }

        accentColor = WatchAccentColor.fromStoredValue(defaults?.string(forKey: WatchPrayerPresentation.accentColorStorageKey))
        language = WatchAppLanguage(storedCode: defaults?.string(forKey: WatchPrayerPresentation.appLanguageStorageKey))
        prayerCalculation = defaults?.string(forKey: WatchPrayerPresentation.prayerCalculationStorageKey) ?? "Auto (By Location)"
        lastRefreshAt = Date()

        WidgetCenter.shared.reloadAllTimelines()
    }

    var city: String {
        day?.city ?? location?.city ?? (language.isMalay ? "Buka app iPhone" : "Open iPhone app")
    }

    var countryCode: String? {
        location?.countryCode?.uppercased()
    }

    var sourceLabel: String {
        WatchPrayerPresentation.shortSourceLabel(calculation: prayerCalculation, countryCode: countryCode)
    }

    var prayers: [WatchPrayer] {
        let source = day?.fullPrayers.isEmpty == false ? day?.fullPrayers : day?.prayers
        return source ?? []
    }

    var storedDhuha: Date? {
        guard countryCode == "BN" else { return nil }
        let today = Date()
        let keyedCache = defaults?.data(forKey: WatchPrayerPresentation.monthCacheKey(for: today))
        let legacyCache = defaults?.data(forKey: WatchPrayerPresentation.legacyMonthCacheKey)
        let data = keyedCache ?? legacyCache

        guard
            let data,
            let monthCache = try? decoder.decode(WatchPrayerMonthCache.self, from: data),
            let dayOfMonth = Calendar.gregorian.dateComponents([.day], from: today).day,
            let cachedDay = monthCache.prayers.first(where: { $0.day == dayOfMonth }),
            let doha = cachedDay.doha,
            doha > 0
        else {
            return nil
        }

        return Date(timeIntervalSince1970: doha)
    }

    var shurooqHelpersByPrayerID: [UUID: WatchShurooqHelperTimes] {
        WatchPrayerPresentation.shurooqHelpers(
            prayers: prayers,
            countryCode: countryCode,
            storedDhuha: storedDhuha
        )
    }

    func displayInfo(for prayer: WatchPrayer, now: Date = Date()) -> WatchPrayerDisplayInfo {
        WatchPrayerPresentation.displayInfo(
            for: prayer,
            in: prayers,
            countryCode: countryCode,
            storedDhuha: storedDhuha,
            now: now
        )
    }

    func currentPrayer(now: Date = Date()) -> WatchPrayer? {
        prayers.last(where: { $0.time <= now }) ?? prayers.last
    }

    func nextPrayer(now: Date = Date()) -> WatchPrayer? {
        prayers.first(where: { $0.time > now }) ?? prayers.first
    }

    var emptyStateMessage: String {
        language.isMalay
            ? "Buka app iPhone untuk segarkan waktu solat dan hantar data ke Apple Watch."
            : "Open the iPhone app to refresh prayer times and sync them to Apple Watch."
    }
}

import SwiftUI
import WidgetKit

private let widgetAppGroupID = "group.app.riskcreatives.waktu"
private let preferredPrayerLockScreenFooterWidgetKindKey = "preferredPrayerLockScreenFooterWidgetKind"

struct PrayersProvider: TimelineProvider {
    private let store = UserDefaults(suiteName: widgetAppGroupID)
    private let settings = Settings.shared

    func placeholder(in context: Context) -> PrayersEntry { previewEntry() }

    func getSnapshot(in ctx: Context, completion: @escaping (PrayersEntry) -> Void) {
        if ctx.isPreview {
            completion(previewEntry())
        } else {
            completion(makeEntry())
        }
    }

    func getTimeline(in ctx: Context, completion: @escaping (Timeline<PrayersEntry>) -> Void) {
        let entry = makeEntry()
        let now = Date()
        let cal = Calendar.current
        let nextMidnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        // Only use nextPrayer time if it's actually in the future — otherwise asking
        // WidgetKit to refresh at a past time leaves it budget-throttled for hours.
        let nextPrayerRefresh = entry.nextPrayer.flatMap { $0.time > now ? $0.time : nil }
        let refresh = [nextPrayerRefresh, nextMidnight].compactMap { $0 }.min() ?? nextMidnight
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func makeEntry() -> PrayersEntry {
        let now = Date()
        if let data = store?.data(forKey: "prayersData"),
           let prayers = try? Settings.decoder.decode(Prayers.self, from: data) {
            settings.prayers = prayers
        }

        if let locData = store?.data(forKey: "currentLocation"),
           let loc = try? Settings.decoder.decode(Location.self, from: locData) {
            settings.currentLocation = loc
        }

        settings.accentColor = AccentColor.fromStoredValue(store?.string(forKey: "accentColor"))
        settings.travelingMode = store?.bool(forKey: "travelingMode") ?? false
        settings.hanafiMadhab = store?.bool(forKey: "hanafiMadhab") ?? false
        settings.prayerCalculation = store?.string(forKey: "prayerCalculation") ?? "Muslim World League"
        settings.hijriOffset = store?.integer(forKey: "hijriOffset") ?? 0
        let isMalaysia = settings.shouldUseMalaysiaPrayerAPI(for: settings.currentLocation)

        settings.fetchPrayerTimes()

        guard let obj = settings.prayers else {
            return emptyEntry(accent: settings.accentColor)
        }

        let inferred = inferCurrentAndNext(from: obj.prayers, at: now)
        let current = settings.currentPrayer ?? inferred.current
        let next = settings.nextPrayer ?? inferred.next

        return PrayersEntry(
            date: now,
            accentColor: settings.accentColor,
            currentCity: settings.prayers?.city ?? settings.effectivePrayerLocationDisplayName ?? settings.currentLocation?.city ?? "",
            prayers: obj.prayers,
            fullPrayers: obj.fullPrayers,
            currentPrayer: current,
            nextPrayer: next,
            hijriOffset: settings.hijriOffset,
            isMalaysia: isMalaysia,
            travelingMode: settings.travelingMode
        )
    }

    private func emptyEntry(accent: AccentColor) -> PrayersEntry {
        .init(
            date: Date(),
            accentColor: accent,
            currentCity: "",
            prayers: [],
            fullPrayers: [],
            currentPrayer: nil,
            nextPrayer: nil,
            hijriOffset: 0,
            isMalaysia: true,
            travelingMode: false
        )
    }

    private func previewEntry() -> PrayersEntry {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func t(_ h: Int, _ m: Int) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0, of: today)!
        }
        let prayers: [Prayer] = [
            Prayer(nameArabic: "الفَجْر", nameTransliteration: "Subuh", nameEnglish: "Dawn", time: t(5, 47), image: "sun.horizon", rakah: "2", sunnahBefore: "2", sunnahAfter: "0"),
            Prayer(nameArabic: "الشُّرُوق", nameTransliteration: "Syuruk", nameEnglish: "Sunrise", time: t(7, 4), image: "sunrise", rakah: "0", sunnahBefore: "0", sunnahAfter: "0"),
            Prayer(nameArabic: "الظُّهْر", nameTransliteration: "Zuhur", nameEnglish: "Midday", time: t(13, 12), image: "sun.max", rakah: "4", sunnahBefore: "4", sunnahAfter: "2"),
            Prayer(nameArabic: "العَصْر", nameTransliteration: "Asar", nameEnglish: "Afternoon", time: t(16, 33), image: "sun.min", rakah: "4", sunnahBefore: "0", sunnahAfter: "0"),
            Prayer(nameArabic: "المَغْرِب", nameTransliteration: "Maghrib", nameEnglish: "Sunset", time: t(19, 22), image: "sunset", rakah: "3", sunnahBefore: "0", sunnahAfter: "2"),
            Prayer(nameArabic: "العِشَاء", nameTransliteration: "Isyak", nameEnglish: "Night", time: t(20, 33), image: "moon.stars.fill", rakah: "4", sunnahBefore: "0", sunnahAfter: "2"),
        ]
        let now = Date()
        let current = prayers.last(where: { $0.time <= now }) ?? prayers[3]
        let next = prayers.first(where: { $0.time > now }) ?? prayers[4]
        return .init(
            date: now,
            accentColor: .green,
            currentCity: "Kuala Lumpur",
            prayers: prayers,
            fullPrayers: prayers,
            currentPrayer: current,
            nextPrayer: next,
            hijriOffset: 0,
            isMalaysia: true,
            travelingMode: false
        )
    }

    private func inferCurrentAndNext(from prayers: [Prayer], at now: Date) -> (current: Prayer?, next: Prayer?) {
        guard !prayers.isEmpty else { return (nil, nil) }
        if let nextIdx = prayers.firstIndex(where: { $0.time > now }) {
            return (nextIdx == 0 ? prayers.last : prayers[nextIdx - 1], prayers[nextIdx])
        }
        return (prayers.last, prayers.first)
    }
}

struct PrayersEntry: TimelineEntry {
    let date: Date
    let accentColor: AccentColor
    let currentCity: String
    let prayers: [Prayer]
    let fullPrayers: [Prayer]
    let currentPrayer: Prayer?
    let nextPrayer: Prayer?
    let hijriOffset: Int
    let isMalaysia: Bool
    let travelingMode: Bool
}

struct WidgetLocationFooter: View {
    let entry: PrayersEntry
    let widgetKind: String

    var body: some View {
        if shouldShowLocationFooter, !entry.currentCity.isEmpty {
            Text(entry.currentCity)
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(appLocalized("Last known location, %@", entry.currentCity))
        }
    }

    private var shouldShowLocationFooter: Bool {
        let store = UserDefaults(suiteName: widgetAppGroupID)
        guard let ownerKind = store?.string(forKey: preferredPrayerLockScreenFooterWidgetKindKey) else {
            return true
        }
        return ownerKind == widgetKind
    }
}

func widgetPrayerDisplayName(_ raw: String) -> String {
    localizedPrayerName(raw)
}

func widgetIsShurooq(_ raw: String) -> Bool {
    let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized == "syuruk" || normalized == "shurooq" || normalized == "sunrise"
}

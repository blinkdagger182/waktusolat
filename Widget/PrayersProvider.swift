import SwiftUI
import WidgetKit

private let widgetAppGroupID = "group.app.riskcreatives.waktu"
private let preferredPrayerLockScreenFooterWidgetKindKey = "preferredPrayerLockScreenFooterWidgetKind"

struct PrayersProvider: TimelineProvider {
    private let store = UserDefaults(suiteName: widgetAppGroupID)
    private let settings = Settings.shared
    private let minuteInterval: TimeInterval = 60
    private let fiveMinuteInterval: TimeInterval = 5 * 60
    private let maxDenseTimelineEntries = 180

    func placeholder(in context: Context) -> PrayersEntry { previewEntry() }

    func getSnapshot(in ctx: Context, completion: @escaping (PrayersEntry) -> Void) {
        if ctx.isPreview {
            completion(previewEntry())
        } else {
            let now = Date()
            let baseContext = loadBaseContext()
            completion(makeEntry(at: now, baseContext: baseContext))
        }
    }

    func getTimeline(in ctx: Context, completion: @escaping (Timeline<PrayersEntry>) -> Void) {
        let now = Date()
        let cal = Calendar.current
        let nextMidnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        let baseContext = loadBaseContext()
        let currentEntry = makeEntry(at: now, baseContext: baseContext)
        let nextPrayerRefresh = currentEntry.nextPrayer.flatMap { $0.time > now ? $0.time : nil }
        let displayTransitionRefresh = nextDisplayTransitionDate(after: now, baseContext: baseContext)
        let refreshBoundary = [nextPrayerRefresh, displayTransitionRefresh, nextMidnight].compactMap { $0 }.min() ?? nextMidnight
        let entries = makeTimelineEntries(
            startingFrom: now,
            refreshBoundary: refreshBoundary,
            baseContext: baseContext
        )

        completion(Timeline(entries: entries, policy: .after(refreshBoundary)))
    }

    private func loadBaseContext() -> (prayers: Prayers?, location: Location?, accent: AccentColor, isMalaysia: Bool) {
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

        settings.fetchPrayerTimes()

        let prayers = settings.prayers
        let location = settings.currentLocation
        let accent = settings.accentColor
        let isMalaysia = settings.shouldUseMalaysiaPrayerAPI(for: location)
        return (prayers, location, accent, isMalaysia)
    }

    private func makeTimelineEntries(
        startingFrom now: Date,
        refreshBoundary: Date,
        baseContext: (prayers: Prayers?, location: Location?, accent: AccentColor, isMalaysia: Bool)
    ) -> [PrayersEntry] {
        var entries = [makeEntry(at: now, baseContext: baseContext)]
        guard refreshBoundary > now else { return entries }

        let totalInterval = refreshBoundary.timeIntervalSince(now)
        let step = totalInterval / minuteInterval <= Double(maxDenseTimelineEntries)
            ? minuteInterval
            : fiveMinuteInterval

        var nextDate = now.addingTimeInterval(step)
        while nextDate < refreshBoundary {
            entries.append(makeEntry(at: nextDate, baseContext: baseContext))
            nextDate = nextDate.addingTimeInterval(step)
        }

        for transitionDate in exactDisplayTransitionDates(
            after: now,
            before: refreshBoundary,
            baseContext: baseContext
        ) {
            entries.append(makeEntry(at: transitionDate, baseContext: baseContext))
        }

        entries.sort { $0.date < $1.date }
        var dedupedEntries: [PrayersEntry] = []
        for entry in entries {
            if let last = dedupedEntries.last, abs(last.date.timeIntervalSince(entry.date)) < 1 {
                continue
            }
            dedupedEntries.append(entry)
        }

        return dedupedEntries
    }

    private func makeEntry(
        at date: Date,
        baseContext: (prayers: Prayers?, location: Location?, accent: AccentColor, isMalaysia: Bool)
    ) -> PrayersEntry {
        guard let obj = baseContext.prayers else {
            return emptyEntry(at: date, accent: baseContext.accent)
        }

        let inferred = inferCurrentAndNext(from: obj.prayers, at: date)

        return PrayersEntry(
            date: date,
            accentColor: baseContext.accent,
            currentCity: settings.effectivePrayerLocationDisplayName
                ?? (obj.city.isEmpty ? (baseContext.location?.city ?? "") : obj.city),
            prayers: obj.prayers,
            fullPrayers: obj.fullPrayers,
            currentPrayer: inferred.current,
            nextPrayer: inferred.next,
            hijriOffset: settings.hijriOffset,
            isMalaysia: baseContext.isMalaysia,
            travelingMode: settings.travelingMode
        )
    }

    private func emptyEntry(at date: Date, accent: AccentColor) -> PrayersEntry {
        .init(
            date: date,
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

    private func nextDisplayTransitionDate(
        after now: Date,
        baseContext: (prayers: Prayers?, location: Location?, accent: AccentColor, isMalaysia: Bool)
    ) -> Date? {
        exactDisplayTransitionDates(
            after: now,
            before: Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now),
            baseContext: baseContext
        ).first
    }

    private func exactDisplayTransitionDates(
        after now: Date,
        before boundary: Date,
        baseContext: (prayers: Prayers?, location: Location?, accent: AccentColor, isMalaysia: Bool)
    ) -> [Date] {
        guard
            baseContext.isMalaysia,
            let prayers = baseContext.prayers?.prayers
        else {
            return []
        }

        let helpers = PrayerDerivedTimes.shurooqHelpers(for: prayers, countryCode: "MY")
        return helpers.values
            .map(\.dhuha)
            .filter { $0 > now && $0 < boundary }
            .sorted()
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

func widgetPrayerDisplayInfo(_ prayer: Prayer, in entry: PrayersEntry) -> PrayerDisplayInfo {
    PrayerDerivedTimes.displayInfo(
        for: prayer,
        in: entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers,
        countryCode: entry.isMalaysia ? "MY" : nil,
        // Use the live render time so Dhuha promotion does not stay stuck on an
        // older timeline entry timestamp between WidgetKit refresh boundaries.
        now: Date()
    )
}

func widgetPrayerDisplayName(_ prayer: Prayer, in entry: PrayersEntry) -> String {
    localizedPrayerName(widgetPrayerDisplayInfo(prayer, in: entry).nameTransliteration)
}

func widgetPrayerDisplayTime(_ prayer: Prayer, in entry: PrayersEntry) -> Date {
    widgetPrayerDisplayInfo(prayer, in: entry).time
}

func widgetIsShurooq(_ prayer: Prayer, in entry: PrayersEntry) -> Bool {
    widgetPrayerDisplayInfo(prayer, in: entry).usesSecondarySunStyle
}

import Foundation

struct ZikirSelectionContext {
    enum Surface {
        case app
        case widget
        case lockScreenWidget

        var maxDisplayLength: Int {
            switch self {
            case .app:
                return 48
            case .widget:
                return 24
            case .lockScreenWidget:
                return 20
            }
        }
    }

    let date: Date
    let prayers: [Prayer]
    let surface: Surface
}

struct ZikirSelectionResult {
    let phrase: ZikirPhrase
    let bucket: ZikirTimeBucket
    let helperTitle: String
    let slotStart: Date
    let refreshDate: Date

    var accessibilityLabel: String {
        "\(helperTitle). \(phrase.textArabic). \(phrase.localizedTranslation())"
    }
}

private struct ZikirSelectionState: Codable {
    var recentIDs: [String] = []
    var slotSelections: [String: String] = [:]
    var slotOrder: [String] = []
}

private enum ZikirSharedStore {
    static let defaults = UserDefaults(suiteName: sharedAppGroupID)
    static let stateKey = "zikirSelectionState"
    static let slotLength: TimeInterval = 90 * 60
    static let maxRecentItems = 4
    static let maxStoredSlots = 32
}

enum ZikirSelector {
    static func select(for context: ZikirSelectionContext) -> ZikirSelectionResult {
        let resolver = ZikirBucketResolver(prayers: context.prayers, now: context.date)
        let bucketWindow = resolver.resolve()
        let slotStart = slotStartDate(for: context.date, within: bucketWindow)
        let slotKey = makeSlotKey(bucket: bucketWindow.bucket, slotStart: slotStart)
        let candidates = filteredCandidates(
            for: bucketWindow.bucket,
            isFriday: resolver.isFriday,
            maxDisplayLength: context.surface.maxDisplayLength
        )
        let fallbackPhrase = candidates.first ?? fallbackPhrase(for: bucketWindow.bucket)

        var state = loadState()
        if let existingID = state.slotSelections[slotKey],
           let existing = candidates.first(where: { $0.id == existingID }) ?? ZikirLibrary.all.first(where: { $0.id == existingID }) {
            let refreshDate = min(bucketWindow.end, slotStart.addingTimeInterval(ZikirSharedStore.slotLength))
            return ZikirSelectionResult(
                phrase: existing,
                bucket: bucketWindow.bucket,
                helperTitle: helperTitle(for: existing, slotKey: slotKey),
                slotStart: slotStart,
                refreshDate: refreshDate
            )
        }

        let phrase = choosePhrase(
            from: candidates.isEmpty ? [fallbackPhrase] : candidates,
            recentIDs: state.recentIDs,
            seed: slotKey
        )

        state.slotSelections[slotKey] = phrase.id
        state.slotOrder.removeAll(where: { $0 == slotKey })
        state.slotOrder.append(slotKey)
        state.recentIDs.removeAll(where: { $0 == phrase.id })
        state.recentIDs.append(phrase.id)

        if state.recentIDs.count > ZikirSharedStore.maxRecentItems {
            state.recentIDs.removeFirst(state.recentIDs.count - ZikirSharedStore.maxRecentItems)
        }

        if state.slotOrder.count > ZikirSharedStore.maxStoredSlots {
            let overflow = state.slotOrder.count - ZikirSharedStore.maxStoredSlots
            let removed = Array(state.slotOrder.prefix(overflow))
            state.slotOrder.removeFirst(overflow)
            removed.forEach { state.slotSelections.removeValue(forKey: $0) }
        }

        saveState(state)

        let refreshDate = min(bucketWindow.end, slotStart.addingTimeInterval(ZikirSharedStore.slotLength))
        return ZikirSelectionResult(
            phrase: phrase,
            bucket: bucketWindow.bucket,
            helperTitle: helperTitle(for: phrase, slotKey: slotKey),
            slotStart: slotStart,
            refreshDate: refreshDate
        )
    }

    private static func filteredCandidates(
        for bucket: ZikirTimeBucket,
        isFriday: Bool,
        maxDisplayLength: Int
    ) -> [ZikirPhrase] {
        ZikirLibrary
            .phrases(for: bucket, includeFridayBoosts: isFriday)
            .filter { $0.maxRecommendedLength <= maxDisplayLength }
    }

    private static func choosePhrase(from candidates: [ZikirPhrase], recentIDs: [String], seed: String) -> ZikirPhrase {
        let available: [ZikirPhrase]
        let recentSet = Set(recentIDs)
        let filtered = candidates.filter { !recentSet.contains($0.id) }
        if filtered.count >= max(2, min(4, candidates.count - 1)) {
            available = filtered
        } else {
            available = candidates
        }

        var generator = SeededGenerator(seed: stableSeed(for: seed))
        let weighted: [(phrase: ZikirPhrase, value: Double)] = available.map { phrase in
            let random = Double.random(in: 0..<1, using: &generator)
            let adjusted = max(1, phrase.weight + (phrase.isFridayBoost ? 1 : 0))
            let score = -log(max(random, 0.000_001)) / Double(adjusted)
            return (phrase, score)
        }

        return weighted.min(by: { $0.value < $1.value })?.phrase ?? candidates[0]
    }

    private static func slotStartDate(for date: Date, within window: ZikirBucketWindow) -> Date {
        guard date > window.start else { return window.start }
        let elapsed = date.timeIntervalSince(window.start)
        let slotIndex = Int(elapsed / ZikirSharedStore.slotLength)
        let candidate = window.start.addingTimeInterval(Double(slotIndex) * ZikirSharedStore.slotLength)
        return min(candidate, window.end)
    }

    private static func makeSlotKey(bucket: ZikirTimeBucket, slotStart: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
        return "\(bucket.rawValue)|\(formatter.string(from: slotStart))"
    }

    private static func loadState() -> ZikirSelectionState {
        guard
            let data = ZikirSharedStore.defaults?.data(forKey: ZikirSharedStore.stateKey),
            let decoded = try? Settings.decoder.decode(ZikirSelectionState.self, from: data)
        else {
            return ZikirSelectionState()
        }
        return decoded
    }

    private static func saveState(_ state: ZikirSelectionState) {
        guard let data = try? Settings.encoder.encode(state) else { return }
        ZikirSharedStore.defaults?.set(data, forKey: ZikirSharedStore.stateKey)
    }

    private static func fallbackPhrase(for bucket: ZikirTimeBucket) -> ZikirPhrase {
        ZikirLibrary.phrases(for: bucket, includeFridayBoosts: false).first
            ?? ZikirLibrary.all.first
            ?? .init(
                id: "fallback-subhanallah",
                helperTitles: ["A simple remembrance for this moment"],
                helperTitlesMS: ["Zikir ringkas untuk saat ini"],
                textArabic: "سُبْحَانَ اللَّهِ",
                translation: "Glory be to Allah.",
                translationMS: "Maha Suci Allah.",
                category: .morning,
                weight: 1,
                isFridayBoost: false,
                maxRecommendedLength: 18
            )
    }

    private static func stableSeed(for value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    private static func helperTitle(for phrase: ZikirPhrase, slotKey: String) -> String {
        let titles = phrase.localizedHelperTitles()
        guard !titles.isEmpty else { return "" }
        let seed = stableSeed(for: "\(slotKey)|helper")
        let index = Int(seed % UInt64(titles.count))
        return titles[index]
    }
}

private struct ZikirBucketWindow {
    let bucket: ZikirTimeBucket
    let start: Date
    let end: Date
}

private struct ZikirBucketResolver {
    let prayers: [Prayer]
    let now: Date

    private let calendar = Calendar.current

    var isFriday: Bool {
        calendar.component(.weekday, from: now) == 6
    }

    func resolve() -> ZikirBucketWindow {
        let fallback = fallbackWindow(for: now)
        guard !prayers.isEmpty else { return fallback }

        let fajr = prayer(named: ["fajr", "subuh"])
        let dhuhr = prayer(named: ["dhuhr", "zuhur", "jumuah"])
        let asr = prayer(named: ["asr", "asar"])
        let isha = prayer(named: ["isha", "isya", "isyak"])

        guard let fajr, let dhuhr, let asr, let isha else { return fallback }

        let nextDay = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let nextDayFajr = calendar.date(
            bySettingHour: calendar.component(.hour, from: fajr),
            minute: calendar.component(.minute, from: fajr),
            second: 0,
            of: nextDay
        ) ?? nextDay

        if now < fajr {
            let previousDay = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            let previousIsha = calendar.date(
                bySettingHour: calendar.component(.hour, from: isha),
                minute: calendar.component(.minute, from: isha),
                second: 0,
                of: previousDay
            ) ?? previousDay
            return .init(bucket: .night, start: previousIsha, end: fajr)
        }
        if now < dhuhr {
            return .init(bucket: .morning, start: fajr, end: dhuhr)
        }
        if now < asr {
            return .init(bucket: .midday, start: dhuhr, end: asr)
        }
        if now < isha {
            return .init(bucket: .evening, start: asr, end: isha)
        }

        return .init(bucket: .night, start: isha, end: nextDayFajr)
    }

    private func prayer(named names: [String]) -> Date? {
        prayers.first { prayer in
            let normalized = prayer.nameTransliteration
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return names.contains(normalized)
        }?.time
    }

    private func fallbackWindow(for date: Date) -> ZikirBucketWindow {
        let hour = calendar.component(.hour, from: date)
        let dayStart = calendar.startOfDay(for: date)

        if (5..<12).contains(hour) {
            return .init(bucket: .morning, start: dayStart.addingTimeInterval(5 * 3600), end: dayStart.addingTimeInterval(12 * 3600))
        }
        if (12..<16).contains(hour) {
            return .init(bucket: .midday, start: dayStart.addingTimeInterval(12 * 3600), end: dayStart.addingTimeInterval(16 * 3600))
        }
        if (16..<20).contains(hour) {
            return .init(bucket: .evening, start: dayStart.addingTimeInterval(16 * 3600), end: dayStart.addingTimeInterval(20 * 3600))
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        if hour < 5 {
            return .init(bucket: .night, start: dayStart, end: dayStart.addingTimeInterval(5 * 3600))
        }
        return .init(bucket: .night, start: dayStart.addingTimeInterval(20 * 3600), end: tomorrow.addingTimeInterval(5 * 3600))
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }
}

import SwiftUI
import WidgetKit
import Foundation

struct LockScreen4EntryView: View {
    var entry: PrayersProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
            } else {
                let prayers = Array(
                    entry.prayers
                        .suffix(Int(floor(Double(
                            entry.prayers.count / 2
                        ))))
                )
                
                ForEach(prayers) { prayer in
                    HStack {
                        Image(systemName: prayer.image)
                            .font(.caption)
                            .frame(width: 10, alignment: .center)
                        
                        Text(prayer.nameTransliteration)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer()
                        
                        Text(prayer.time, style: .time)
                            .fontWeight(.bold)
                    }
                    .foregroundColor((entry.currentPrayer?.nameTransliteration ?? "").contains(prayer.nameTransliteration) ? .primary : .secondary)
                }
            }
        }
        .font(.caption)
        .multilineTextAlignment(.leading)
        .lineLimit(1)
    }
}

struct LockScreen4Widget: Widget {
    let kind: String = "LockScreen4Widget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                if #available(iOS 17.0, *) {
                    LockScreen4EntryView(entry: entry)
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    LockScreen4EntryView(entry: entry)
                }
            }
            .supportedFamilies([.accessoryRectangular])
            .configurationDisplayName("Last 3 Prayer Times")
            .description("Shows the last three prayer times of the day")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                LockScreen4EntryView(entry: entry)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Last 3 Prayer Times")
            .description("Shows the last three prayer times of the day")
        }
        #endif
    }
}

struct InspiringVerse: Hashable {
    let text: String
    let surahName: String
    let reference: String

    var displayReference: String { "\(surahName) \(reference)" }
    var isLockScreenSafe: Bool {
        let textCount = text.count
        let refCount = displayReference.count
        return textCount <= 90 && refCount <= 24 && (textCount + refCount) <= 120
    }
}

private struct InspiringVerseReference: Hashable {
    let reference: String
    let theme: String
    let fallbackText: String?
}

private struct InspiringVerseReferencePayload: Decodable {
    let reference: String
    let theme: String
}

private struct QuotesJSONPayload: Decodable {
    let reference: String
    let ayat: String
}

private enum DailyInspirationPool {
    static let fallbackBaseReferences: [InspiringVerseReference] = [
        .init(reference: "94:5", theme: "hope", fallbackText: nil),
        .init(reference: "94:6", theme: "hope", fallbackText: nil),
        .init(reference: "2:286", theme: "trust", fallbackText: nil),
        .init(reference: "65:3", theme: "trust", fallbackText: nil),
        .init(reference: "2:152", theme: "remembrance", fallbackText: nil),
        .init(reference: "6:54", theme: "mercy", fallbackText: nil),
        .init(reference: "7:156", theme: "mercy", fallbackText: nil),
        .init(reference: "30:60", theme: "patience", fallbackText: nil),
        .init(reference: "2:153", theme: "patience", fallbackText: nil),
        .init(reference: "2:45", theme: "patience", fallbackText: nil),
        .init(reference: "3:159", theme: "trust", fallbackText: nil),
        .init(reference: "3:139", theme: "hope", fallbackText: nil),
        .init(reference: "4:96", theme: "mercy", fallbackText: nil),
        .init(reference: "3:150", theme: "trust", fallbackText: nil),
        .init(reference: "16:128", theme: "perseverance", fallbackText: nil),
        .init(reference: "50:16", theme: "remembrance", fallbackText: nil),
        .init(reference: "13:28", theme: "peace", fallbackText: nil),
        .init(reference: "11:88", theme: "trust", fallbackText: nil),
        .init(reference: "93:5", theme: "hope", fallbackText: nil),
        .init(reference: "93:6", theme: "mercy", fallbackText: nil),
        .init(reference: "17:70", theme: "gratitude", fallbackText: nil),
        .init(reference: "2:257", theme: "trust", fallbackText: nil),
        .init(reference: "14:7", theme: "gratitude", fallbackText: nil),
        .init(reference: "40:60", theme: "remembrance", fallbackText: nil),
        .init(reference: "5:93", theme: "mercy", fallbackText: nil),
        .init(reference: "7:56", theme: "mercy", fallbackText: nil),
        .init(reference: "2:185", theme: "hope", fallbackText: nil),
        .init(reference: "42:19", theme: "trust", fallbackText: nil),
        .init(reference: "93:3", theme: "hope", fallbackText: nil),
        .init(reference: "29:69", theme: "perseverance", fallbackText: nil),
        .init(reference: "50:39", theme: "patience", fallbackText: nil),
        .init(reference: "11:61", theme: "trust", fallbackText: nil),
        .init(reference: "65:2", theme: "trust", fallbackText: nil),
        .init(reference: "10:64", theme: "hope", fallbackText: nil),
        .init(reference: "10:58", theme: "gratitude", fallbackText: nil),
        .init(reference: "57:4", theme: "peace", fallbackText: nil),
        .init(reference: "7:180", theme: "remembrance", fallbackText: nil),
        .init(reference: "10:62", theme: "peace", fallbackText: nil),
        .init(reference: "99:7", theme: "perseverance", fallbackText: nil),
        .init(reference: "93:7", theme: "hope", fallbackText: nil)
    ]

    static let baseReferences: [InspiringVerseReference] = {
        if let loaded = loadFromQuotesJSON(), !loaded.isEmpty {
            return loaded
        }
        if let loaded = loadFromJSON(), !loaded.isEmpty {
            return loaded
        }
        return fallbackBaseReferences
    }()

    static let references: [InspiringVerseReference] = {
        let source = baseReferences
        guard !source.isEmpty else { return [] }

        if source.count >= 365 {
            return Array(source.prefix(365))
        }

        // Fill up to 365 daily reference slots if source list is smaller.
        return (0..<365).map { idx in
            let mixed = (idx * 37 + idx / 7 + 11) % source.count
            return source[mixed]
        }
    }()

    private static func loadFromJSON() -> [InspiringVerseReference]? {
        let possibleURLs: [URL?] = [
            Bundle.main.url(forResource: "QuranInspirationReferences", withExtension: "json"),
            Bundle.main.url(forResource: "QuranInspirationReferences", withExtension: "json", subdirectory: "Shared"),
            Bundle.main.url(forResource: "QuranInspirationReferences", withExtension: "json", subdirectory: "Resources/JSONs")
        ]

        guard let fileURL = possibleURLs.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode([InspiringVerseReferencePayload].self, from: data)
        else {
            return nil
        }

        let filtered = payload
            .filter { isSingleAyahReference($0.reference) }
            .map { InspiringVerseReference(reference: $0.reference, theme: $0.theme, fallbackText: nil) }

        return filtered.isEmpty ? nil : filtered
    }

    private static func loadFromQuotesJSON() -> [InspiringVerseReference]? {
        let possibleURLs: [URL?] = [
            Bundle.main.url(forResource: "quotes", withExtension: "json"),
            Bundle.main.url(forResource: "quotes", withExtension: "json", subdirectory: "Resources"),
            Bundle.main.url(forResource: "quotes", withExtension: "json", subdirectory: "Resources/JSONs")
        ]

        guard let fileURL = possibleURLs.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode([QuotesJSONPayload].self, from: data)
        else {
            return nil
        }

        var seen = Set<String>()
        var parsed: [InspiringVerseReference] = []
        for row in payload {
            guard isSingleAyahReference(row.reference) else { continue }
            if seen.insert(row.reference).inserted {
                parsed.append(.init(reference: row.reference, theme: "inspiration", fallbackText: row.ayat))
            }
        }

        return parsed.isEmpty ? nil : parsed
    }

    private static func isSingleAyahReference(_ reference: String) -> Bool {
        let comps = reference.split(separator: ":")
        guard comps.count == 2 else { return false }
        guard !comps[0].contains("-"), !comps[1].contains("-") else { return false }
        return Int(comps[0]) != nil && Int(comps[1]) != nil
    }
}

private struct DailyInspirationEntry: TimelineEntry {
    let date: Date
    let verse: InspiringVerse
}

private struct QuranAyahAPIResponse: Decodable {
    let status: String
    let data: QuranAyahData
}

private struct QuranAyahData: Decodable {
    let text: String
    let numberInSurah: Int
    let surah: QuranSurahData
}

private struct QuranSurahData: Decodable {
    let number: Int
    let englishName: String
}

private struct CachedDailyInspiration: Codable {
    let dayKey: String
    let reference: String
    let text: String
    let surahName: String
}

private struct DailyInspirationProvider: TimelineProvider {
    private let appGroup = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
    private let seedKey = "dailyInspirationUserSeed"
    private let cacheKey = "dailyInspirationCachedQuoteV1"

    func placeholder(in context: Context) -> DailyInspirationEntry {
        DailyInspirationEntry(date: Date(), verse: InspiringVerse(
            text: "For indeed, with hardship comes ease.",
            surahName: "Ash-Sharh",
            reference: "94:5"
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyInspirationEntry) -> Void) {
        resolveDailyVerse(for: Date()) { verse in
            completion(DailyInspirationEntry(date: Date(), verse: verse))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyInspirationEntry>) -> Void) {
        let now = Date()
        resolveDailyVerse(for: now) { verse in
            let current = DailyInspirationEntry(date: now, verse: verse)
            let next = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            ).addingTimeInterval(60)
            completion(Timeline(entries: [current], policy: .after(next)))
        }
    }

    private func resolveDailyVerse(for date: Date, completion: @escaping (InspiringVerse) -> Void) {
        let selectedReference = reference(for: date)
        let dayKey = dayKey(for: date)

        if let cached = loadCachedQuote(), cached.dayKey == dayKey, cached.reference == selectedReference.reference {
            completion(InspiringVerse(text: cached.text, surahName: cached.surahName, reference: cached.reference))
            return
        }

        Task {
            let emergency = fallbackVerse(for: selectedReference)
            let resolved = await fetchVerseFromAPI(reference: selectedReference.reference) ?? emergency
            saveCachedQuote(.init(
                dayKey: dayKey,
                reference: resolved.reference,
                text: resolved.text,
                surahName: resolved.surahName
            ))
            await MainActor.run {
                completion(resolved)
            }
        }
    }

    private func reference(for date: Date) -> InspiringVerseReference {
        let pool = DailyInspirationPool.references
        guard !pool.isEmpty else {
            return InspiringVerseReference(reference: "94:5", theme: "hope", fallbackText: "For indeed, with hardship comes ease.")
        }

        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let userSeed = loadUserSeed()
        let cycleIndex = (userSeed &+ UInt64(dayOfYear * 48271)) % 365
        return pool[Int(cycleIndex % UInt64(pool.count))]
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func loadCachedQuote() -> CachedDailyInspiration? {
        guard
            let data = appGroup?.data(forKey: cacheKey),
            let cached = try? JSONDecoder().decode(CachedDailyInspiration.self, from: data)
        else {
            return nil
        }
        return cached
    }

    private func saveCachedQuote(_ quote: CachedDailyInspiration) {
        guard let data = try? JSONEncoder().encode(quote) else { return }
        appGroup?.set(data, forKey: cacheKey)
    }

    private func fetchVerseFromAPI(reference: String) async -> InspiringVerse? {
        guard let url = URL(string: "https://api.alquran.cloud/v1/ayah/\(reference)/en.asad") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(QuranAyahAPIResponse.self, from: data)
            guard decoded.status.uppercased() == "OK" else { return nil }

            let normalizedText = decoded.data.text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let verse = InspiringVerse(
                text: normalizedText,
                surahName: decoded.data.surah.englishName,
                reference: reference
            )

            // Keep lock-screen-safe display as strict requirement.
            return verse.isLockScreenSafe ? verse : nil
        } catch {
            return nil
        }
    }

    private func loadUserSeed() -> UInt64 {
        if let number = appGroup?.object(forKey: seedKey) as? NSNumber {
            return number.uint64Value
        }
        if let existingInt = appGroup?.object(forKey: seedKey) as? Int {
            return UInt64(max(existingInt, 1))
        }
        if let existingString = appGroup?.string(forKey: seedKey), let parsed = UInt64(existingString) {
            return parsed
        }

        if let existingData = appGroup?.data(forKey: seedKey),
           let parsed = try? JSONDecoder().decode(UInt64.self, from: existingData) {
            return parsed
        }
        let newSeed = UInt64.random(in: 1...UInt64.max / 2)
        appGroup?.set(NSNumber(value: newSeed), forKey: seedKey)
        return newSeed
    }

    private func fallbackVerse(for selectedReference: InspiringVerseReference) -> InspiringVerse {
        let fallbackText = selectedReference.fallbackText ?? "For indeed, with hardship comes ease."
        return InspiringVerse(
            text: fallbackText,
            surahName: surahName(from: selectedReference.reference),
            reference: selectedReference.reference
        )
    }

    private func surahName(from reference: String) -> String {
        let comps = reference.split(separator: ":")
        guard comps.count == 2, let surah = Int(comps[0]), (1...114).contains(surah) else {
            return "Quran"
        }
        return SurahNames.english[surah - 1]
    }
}

private enum SurahNames {
    static let english: [String] = [
        "Al-Faatiha","Al-Baqara","Aal-i-Imraan","An-Nisaa","Al-Maaida","Al-An'aam","Al-A'raaf","Al-Anfaal","At-Tawba","Yunus","Hud","Yusuf","Ar-Ra'd","Ibrahim","Al-Hijr","An-Nahl","Al-Israa","Al-Kahf","Maryam","Taa-Haa","Al-Anbiyaa","Al-Hajj","Al-Muminoon","An-Noor","Al-Furqaan","Ash-Shu'araa","An-Naml","Al-Qasas","Al-Ankaboot","Ar-Room","Luqman","As-Sajda","Al-Ahzaab","Saba","Faatir","Yaseen","As-Saaffaat","Saad","Az-Zumar","Ghaafir","Fussilat","Ash-Shooraa","Az-Zukhruf","Ad-Dukhaan","Al-Jaathiya","Al-Ahqaaf","Muhammad","Al-Fath","Al-Hujuraat","Qaaf","Adh-Dhaariyaaat","At-Tur","An-Najm","Al-Qamar","Ar-Rahmaan","Al-Waaqia","Al-Hadid","Al-Mujaadila","Al-Hashr","Al-Mumtahana","As-Saff","Al-Jumu'a","Al-Munaafiqoon","At-Taghaabun","At-Talaaq","At-Tahrim","Al-Mulk","Al-Qalam","Al-Haaqqa","Al-Ma'aarij","Nooh","Al-Jinn","Al-Muzzammil","Al-Muddaththir","Al-Qiyaama","Al-Insaan","Al-Mursalaat","An-Naba","An-Naazi'aat","Abasa","At-Takwir","Al-Infitaar","Al-Mutaffifin","Al-Inshiqaaq","Al-Burooj","At-Taariq","Al-A'laa","Al-Ghaashiya","Al-Fajr","Al-Balad","Ash-Shams","Al-Lail","Ad-Dhuhaa","Ash-Sharh","At-Tin","Al-Alaq","Al-Qadr","Al-Bayyina","Az-Zalzala","Al-Aadiyaat","Al-Qaari'a","At-Takaathur","Al-Asr","Al-Humaza","Al-Fil","Quraish","Al-Maa'un","Al-Kawthar","Al-Kaafiroon","An-Nasr","Al-Masad","Al-Ikhlaas","Al-Falaq","An-Naas"
    ]
}

struct LockScreenVerseEntryView: View {
    let verse: InspiringVerse

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verse.displayReference)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundStyle(Color(red: 0.93, green: 0.76, blue: 0.43))
                .lineLimit(1)

            Text(verse.text)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(Color(red: 0.95, green: 0.83, blue: 0.57))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .widgetURL(deepLinkURL)
    }

    private var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "waktu"
        components.host = "quran"
        components.queryItems = [
            URLQueryItem(name: "reference", value: verse.reference)
        ]
        return components.url
    }
}

struct LockScreenVerseWidget: Widget {
    let kind: String = "LockScreenVerseWidget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: DailyInspirationProvider()) { entry in
                if #available(iOS 17.0, *) {
                    LockScreenVerseEntryView(verse: entry.verse)
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    LockScreenVerseEntryView(verse: entry.verse)
                }
            }
            .supportedFamilies([.accessoryRectangular])
            .configurationDisplayName("Daily Quran Inspiration")
            .description("Shows one uplifting Quran ayah daily, tailored per user.")
        } else {
            return StaticConfiguration(kind: kind, provider: DailyInspirationProvider()) { entry in
                LockScreenVerseEntryView(verse: entry.verse)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Daily Quran Inspiration")
            .description("Shows one uplifting Quran ayah daily, tailored per user.")
        }
        #endif
    }
}

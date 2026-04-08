import SwiftUI

struct LibraryDailyQuranQuote: Codable {
    let dayKey: String
    let reference: String
    let text: String
    let surahName: String
}

private struct LibraryQuranAyahAPIResponse: Decodable {
    let translationText: String
    let surahNameEnglish: String
}

private struct LibraryInspiringVerseReference: Hashable {
    let reference: String
    let theme: String
    let fallbackText: String?
}

private struct LibraryInspiringVerseReferencePayload: Decodable {
    let reference: String
    let theme: String
}

private struct LibraryQuotesJSONPayload: Decodable {
    let reference: String
    let ayat: String
}

private enum LibraryDailyInspirationPool {
    static let seedKey = "dailyInspirationUserSeed"

    static let fallbackBaseReferences: [LibraryInspiringVerseReference] = [
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

    static let baseReferences: [LibraryInspiringVerseReference] = {
        if let loaded = loadFromQuotesJSON(), !loaded.isEmpty {
            return loaded
        }
        if let loaded = loadFromJSON(), !loaded.isEmpty {
            return loaded
        }
        return fallbackBaseReferences
    }()

    static let references: [LibraryInspiringVerseReference] = {
        let source = baseReferences
        guard !source.isEmpty else { return [] }

        if source.count >= 365 {
            return Array(source.prefix(365))
        }

        return (0..<365).map { idx in
            let mixed = (idx * 37 + idx / 7 + 11) % source.count
            return source[mixed]
        }
    }()

    static func reference(for date: Date, defaults: UserDefaults?) -> LibraryInspiringVerseReference {
        let pool = references
        guard !pool.isEmpty else {
            return LibraryInspiringVerseReference(
                reference: "94:5",
                theme: "hope",
                fallbackText: "Sesungguhnya bersama kesukaran ada kemudahan."
            )
        }

        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let userSeed = loadUserSeed(defaults: defaults)
        let cycleIndex = (userSeed &+ UInt64(dayOfYear * 48271)) % 365
        return pool[Int(cycleIndex % UInt64(pool.count))]
    }

    private static func loadUserSeed(defaults: UserDefaults?) -> UInt64 {
        if let number = defaults?.object(forKey: seedKey) as? NSNumber {
            return number.uint64Value
        }
        if let existingInt = defaults?.object(forKey: seedKey) as? Int {
            return UInt64(max(existingInt, 1))
        }
        if let existingString = defaults?.string(forKey: seedKey), let parsed = UInt64(existingString) {
            return parsed
        }
        if let existingData = defaults?.data(forKey: seedKey),
           let parsed = try? JSONDecoder().decode(UInt64.self, from: existingData) {
            return parsed
        }

        let newSeed = UInt64.random(in: 1...UInt64.max / 2)
        defaults?.set(NSNumber(value: newSeed), forKey: seedKey)
        return newSeed
    }

    private static func loadFromJSON() -> [LibraryInspiringVerseReference]? {
        let possibleURLs: [URL?] = [
            Bundle.main.url(forResource: "QuranInspirationReferences", withExtension: "json"),
            Bundle.main.url(forResource: "QuranInspirationReferences", withExtension: "json", subdirectory: "Shared"),
            Bundle.main.url(forResource: "QuranInspirationReferences", withExtension: "json", subdirectory: "Resources/JSONs")
        ]

        guard let fileURL = possibleURLs.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode([LibraryInspiringVerseReferencePayload].self, from: data)
        else {
            return nil
        }

        let filtered = payload
            .filter { isSingleAyahReference($0.reference) }
            .map { LibraryInspiringVerseReference(reference: $0.reference, theme: $0.theme, fallbackText: nil) }

        return filtered.isEmpty ? nil : filtered
    }

    private static func loadFromQuotesJSON() -> [LibraryInspiringVerseReference]? {
        let possibleURLs: [URL?] = [
            Bundle.main.url(forResource: "quotes", withExtension: "json"),
            Bundle.main.url(forResource: "quotes", withExtension: "json", subdirectory: "Resources"),
            Bundle.main.url(forResource: "quotes", withExtension: "json", subdirectory: "Resources/JSONs")
        ]

        guard let fileURL = possibleURLs.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode([LibraryQuotesJSONPayload].self, from: data)
        else {
            return nil
        }

        var seen = Set<String>()
        var parsed: [LibraryInspiringVerseReference] = []
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

struct FullSurahSelection: Identifiable, Equatable {
    let surahNumber: Int
    let initialAyahNumber: Int?
    let dailyAyahNumber: Int?
    var id: String { "\(surahNumber):\(initialAyahNumber ?? 0):\(dailyAyahNumber ?? 0)" }
}

enum FullQuranResumeStorage {
    static let lastSurahKey = "fullQuranLastViewedSurahV1"
    static let lastAyahKey = "fullQuranLastViewedAyahV1"
    static let lastPlayedSurahKey = "fullQuranLastPlayedSurahV1"
    static let lastPlayedAyahKey = "fullQuranLastPlayedAyahV1"
}

private struct DailyQuranReferenceParts {
    let surahNumber: Int
    let ayahNumber: Int?
}

private struct LibrarySkeletonBlock: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("بِسْمِ ٱللَّٰهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
                .font(.custom(preferredQuranArabicFontName(settings: settings, size: 18), size: 18))
                .foregroundStyle(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack {
                Text(isMalayAppLanguage() ? "Refleksi Harian" : "Daily Reflection")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            VStack(spacing: 10) {
                Color.clear
                    .frame(height: 72)

                Color.clear
                    .frame(height: 86)

                Text(" ")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Color.clear.frame(height: 18)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(settings.accentColor.color.opacity(0.16))
                    .frame(height: 44)
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            settings.accentColor.color.opacity(0.04),
                            Color(.systemGray6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.32), lineWidth: 1)
        }
        .shadow(color: settings.accentColor.color.opacity(0.08), radius: 22, x: 0, y: 12)
    }
}

private struct LibrarySurahSkeletonRow: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.12))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 140, height: 14)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 90, height: 12)
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .redacted(reason: .placeholder)
    }
}


struct OtherView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.openURL) private var openURL
    @AppStorage(QuranContentLanguage.storageKey) private var quranLanguageCode = effectiveQuranContentLanguage().rawValue
    @State private var dailyQuranQuote: LibraryDailyQuranQuote?
    @State private var selectedFullSurah: FullSurahSelection?
    @State private var resumeSelection: FullSurahSelection?
    @State private var surahs: [QuranSurahIndexItem] = []
    @State private var isLoadingSurahs = true
    @State private var isLoadingDailyQuranQuote = true
    @State private var surahListErrorMessage: String?
    @State private var searchText = ""
    @State private var expandedSurahNumber: Int?
    @State private var dailyQuranArabicText: String?
    @State private var pinnedSurahNumbers: [Int] = []
    @State private var hasActivatedLibrary = false
    private let isActive: Bool
    private let onScrollOffsetChange: ((CGFloat) -> Void)?

    init(isActive: Bool = true, onScrollOffsetChange: ((CGFloat) -> Void)? = nil) {
        self.isActive = isActive
        self.onScrollOffsetChange = onScrollOffsetChange
    }

    private static let pinnedSurahsKey = "pinnedSurahNumbersV1"
    private static let maxPinnedSurahs = 3

    private var currentQuranLanguage: QuranContentLanguage {
        QuranContentLanguage(rawValue: quranLanguageCode) ?? effectiveQuranContentLanguage()
    }

    private var isSearchingSurahs: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredSurahs: [QuranSurahIndexItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return surahs }
        return surahs.filter {
            "\($0.number)".contains(query)
            || $0.englishName.lowercased().contains(query)
            || localizedSurahName(number: $0.number, englishName: $0.englishName).lowercased().contains(query)
            || $0.arabicName.contains(query)
        }
    }

    private func currentDayKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func loadDailyQuranQuoteFromCache() -> Bool {
        let defaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
        let languageAwareKey = "dailyInspirationCachedQuoteV3.\(quranContentLanguageCode())"
        guard
            let data = defaults?.data(forKey: languageAwareKey)
                ?? (!isMalayAppLanguage() ? defaults?.data(forKey: "dailyInspirationCachedQuoteV2") : nil)
                ?? (!isMalayAppLanguage() ? defaults?.data(forKey: "dailyInspirationCachedQuoteV1") : nil),
            let cached = try? JSONDecoder().decode(LibraryDailyQuranQuote.self, from: data),
            cached.dayKey == currentDayKey()
        else {
            dailyQuranQuote = nil
            return false
        }
        dailyQuranQuote = cached
        return true
    }

    @MainActor
    private func loadDailyQuranQuote() async {
        isLoadingDailyQuranQuote = true
        defer { isLoadingDailyQuranQuote = false }

        let loadedFromCache = loadDailyQuranQuoteFromCache()
        if loadedFromCache {
            await loadDailyQuranArabicIfNeeded()
            return
        }

        do {
            let fetched = try await fetchDailyQuranQuoteFromAPI()
            dailyQuranQuote = fetched
            saveDailyQuranQuoteToCache(fetched)
            await loadDailyQuranArabicIfNeeded()
        } catch {
            dailyQuranQuote = nil
            dailyQuranArabicText = nil
        }
    }

    private func saveDailyQuranQuoteToCache(_ quote: LibraryDailyQuranQuote) {
        guard let data = try? JSONEncoder().encode(quote) else { return }
        let defaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
        let languageAwareKey = "dailyInspirationCachedQuoteV3.\(quranContentLanguageCode())"
        defaults?.set(data, forKey: languageAwareKey)
    }

    private func fetchDailyQuranQuoteFromAPI(for date: Date = Date()) async throws -> LibraryDailyQuranQuote {
        let defaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
        let selectedReference = LibraryDailyInspirationPool.reference(for: date, defaults: defaults)
        let dayKey = currentDayKey(for: date)

        guard var components = URLComponents(url: quranProxyBaseURL(bundle: .main), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path += "/ayah/\(selectedReference.reference)"
        components.queryItems = [URLQueryItem(name: "lang", value: quranContentLanguageCode())]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(LibraryQuranAyahAPIResponse.self, from: data)
        let normalizedText = decoded.translationText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return LibraryDailyQuranQuote(
            dayKey: dayKey,
            reference: selectedReference.reference,
            text: normalizedText.isEmpty ? (selectedReference.fallbackText ?? decoded.translationText) : normalizedText,
            surahName: decoded.surahNameEnglish
        )
    }

    @MainActor
    private func loadDailyQuranArabicIfNeeded() async {
        guard let quote = dailyQuranQuote else {
            dailyQuranArabicText = nil
            return
        }

        do {
            dailyQuranArabicText = try await DailyQuranArabicAPI.fetchArabicText(reference: quote.reference)
        } catch {
            dailyQuranArabicText = nil
        }
    }

    private func openDailyQuranModal() {
        guard let reference = dailyQuranQuote?.reference else { return }
        var components = URLComponents()
        components.scheme = "waktu"
        components.host = "quran"
        components.queryItems = [URLQueryItem(name: "reference", value: reference)]
        guard let url = components.url else { return }
        openURL(url)
    }

    private func parseReference(_ reference: String) -> DailyQuranReferenceParts? {
        let parts = reference.split(separator: ":")
        guard let first = parts.first,
              let surah = Int(first),
              (1...114).contains(surah) else {
            return nil
        }
        let ayah: Int?
        if parts.count > 1, let parsedAyah = Int(parts[1]), parsedAyah > 0 {
            ayah = parsedAyah
        } else {
            ayah = nil
        }
        return DailyQuranReferenceParts(surahNumber: surah, ayahNumber: ayah)
    }

    private func openDailyQuranFullSurah() {
        guard let reference = dailyQuranQuote?.reference,
              let parsed = parseReference(reference) else { return }
        selectedFullSurah = FullSurahSelection(
            surahNumber: parsed.surahNumber,
            initialAyahNumber: parsed.ayahNumber,
            dailyAyahNumber: parsed.ayahNumber
        )
    }

    private func loadResumeSelection() {
        let defaults = UserDefaults.standard
        let playedSurah = defaults.integer(forKey: FullQuranResumeStorage.lastPlayedSurahKey)
        let playedAyah = defaults.integer(forKey: FullQuranResumeStorage.lastPlayedAyahKey)
        let viewedSurah = defaults.integer(forKey: FullQuranResumeStorage.lastSurahKey)
        let viewedAyah = defaults.integer(forKey: FullQuranResumeStorage.lastAyahKey)
        let surah = (1...114).contains(playedSurah) ? playedSurah : viewedSurah
        let ayah = (1...114).contains(playedSurah) ? playedAyah : viewedAyah
        guard (1...114).contains(surah) else {
            resumeSelection = nil
            return
        }
        resumeSelection = FullSurahSelection(
            surahNumber: surah,
            initialAyahNumber: ayah > 0 ? ayah : nil,
            dailyAyahNumber: nil
        )
    }

    @MainActor
    private func loadSurahsIfNeeded() async {
        guard surahs.isEmpty else { return }
        isLoadingSurahs = true
        surahListErrorMessage = nil
        defer { isLoadingSurahs = false }

        do {
            surahs = try await QuranSurahIndexAPI.fetchAll()
        } catch {
            let reason = error.localizedDescription
            if reason.isEmpty || reason == "The operation couldn’t be completed." {
                surahListErrorMessage = isMalayAppLanguage()
                    ? "Tidak dapat memuatkan senarai surah sekarang. Sila cuba lagi."
                    : "Unable to load the surah list right now. Please try again."
            } else {
                surahListErrorMessage = reason
            }
        }
    }

    @ViewBuilder
    private var quranIntroSection: some View {
        if !isSearchingSurahs {
            Section {
                LibraryIntroHeader()
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)

                if isLoadingDailyQuranQuote {
                    LibrarySkeletonBlock()
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
                        .listRowSeparator(.hidden)

                    LibrarySkeletonBlock()
                        .frame(height: 110)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 14, trailing: 16))
                        .listRowSeparator(.hidden)
                } else if let quote = dailyQuranQuote {
                    DailyQuranHeroCard(
                        quote: quote,
                        arabicText: dailyQuranArabicText,
                        shouldAnimateArabic: hasActivatedLibrary,
                        accentColor: settings.accentColor.color,
                        arabicFontName: preferredQuranArabicFontName(settings: settings, size: 29),
                        onOpenVerse: openDailyQuranModal,
                        onOpenSurah: openDailyQuranFullSurah
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparator(.hidden)
                } else {
                    Text(isMalayAppLanguage()
                         ? "Buka widget Al-Quran Harian sekali untuk memuatkan ayat hari ini di sini."
                         : "Open the Daily Quran widget once to load today’s verse here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
                        .listRowSeparator(.hidden)
                }

                if let resumeSelection {
                    QuranResumeCard(
                        surahTitle: surahTitle(for: resumeSelection.surahNumber),
                        surahNumber: resumeSelection.surahNumber,
                        ayahNumber: resumeSelection.initialAyahNumber,
                        totalAyahCount: QuranSurahVerseCounts.count(for: resumeSelection.surahNumber),
                        accentColor: settings.accentColor.color,
                        onResume: {
                            selectedFullSurah = resumeSelection
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 14, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    @ViewBuilder
    private var pinnedSurahsSection: some View {
        let pinnedSurahs = surahs.filter { pinnedSurahNumbers.contains($0.number) }
            .sorted { pinnedSurahNumbers.firstIndex(of: $0.number)! < pinnedSurahNumbers.firstIndex(of: $1.number)! }

        if !isSearchingSurahs && !pinnedSurahs.isEmpty {
            Section(header: HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(45))
                Text(isMalayAppLanguage() ? "SURAH DISEMATKAN" : "PINNED SURAHS")
            }) {
                ForEach(pinnedSurahs) { surah in
                    QuranSurahExpandableCard(
                        surah: surah,
                        isExpanded: expandedSurahNumber == surah.number,
                        accentColor: settings.accentColor.color,
                        progressAyah: loadLastReadAyah(for: surah.number),
                        totalAyahCount: QuranSurahVerseCounts.count(for: surah.number),
                        isPinned: true,
                        onToggle: {
                            withAnimation(.spring(response: 0.46, dampingFraction: 0.9)) {
                                expandedSurahNumber = expandedSurahNumber == surah.number ? nil : surah.number
                            }
                        },
                        onOpen: {
                            selectedFullSurah = FullSurahSelection(
                                surahNumber: surah.number,
                                initialAyahNumber: nil,
                                dailyAyahNumber: nil
                            )
                        },
                        onResume: {
                            selectedFullSurah = FullSurahSelection(
                                surahNumber: surah.number,
                                initialAyahNumber: loadLastReadAyah(for: surah.number),
                                dailyAyahNumber: nil
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation { togglePin(surahNumber: surah.number) }
                        } label: {
                            Label(isMalayAppLanguage() ? "Tanggalkan Pin" : "Unpin Surah", systemImage: "pin.slash")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var surahListSection: some View {
        Section(header: Text(isSearchingSurahs
                             ? (isMalayAppLanguage() ? "HASIL CARIAN SURAH" : "SURAH SEARCH RESULTS")
                             : (isMalayAppLanguage() ? "SENARAI SURAH" : "SURAH LIST"))) {
            if isLoadingSurahs {
                ForEach(0..<6, id: \.self) { _ in
                    LibrarySurahSkeletonRow()
                }
            } else if let surahListErrorMessage {
                Text(surahListErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredSurahs) { surah in
                    let isPinned = pinnedSurahNumbers.contains(surah.number)
                    let canPin = !isPinned && pinnedSurahNumbers.count < Self.maxPinnedSurahs
                    QuranSurahExpandableCard(
                        surah: surah,
                        isExpanded: expandedSurahNumber == surah.number,
                        accentColor: settings.accentColor.color,
                        progressAyah: loadLastReadAyah(for: surah.number),
                        totalAyahCount: QuranSurahVerseCounts.count(for: surah.number),
                        isPinned: isPinned,
                        onToggle: {
                            withAnimation(.spring(response: 0.46, dampingFraction: 0.9)) {
                                expandedSurahNumber = expandedSurahNumber == surah.number ? nil : surah.number
                            }
                        },
                        onOpen: {
                            selectedFullSurah = FullSurahSelection(
                                surahNumber: surah.number,
                                initialAyahNumber: nil,
                                dailyAyahNumber: nil
                            )
                        },
                        onResume: {
                            selectedFullSurah = FullSurahSelection(
                                surahNumber: surah.number,
                                initialAyahNumber: loadLastReadAyah(for: surah.number),
                                dailyAyahNumber: nil
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        if isPinned {
                            Button(role: .destructive) {
                                withAnimation { togglePin(surahNumber: surah.number) }
                            } label: {
                                Label(isMalayAppLanguage() ? "Tanggalkan Pin" : "Unpin Surah", systemImage: "pin.slash")
                            }
                        } else {
                            Button {
                                withAnimation { togglePin(surahNumber: surah.number) }
                            } label: {
                                Label(isMalayAppLanguage() ? "Semat Surah" : "Pin Surah", systemImage: "pin")
                            }
                            .disabled(!canPin)
                        }
                        if !canPin && !isPinned {
                            Text(isMalayAppLanguage()
                                 ? "Maksimum 3 surah disematkan"
                                 : "Maximum 3 surahs can be pinned")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                quranIntroSection
                pinnedSurahsSection
                surahListSection

                #if false
                Section(header: Text("ISLAMIC RESOURCES")) {
                    NavigationLink(destination: ArabicView()) {
                        Label(
                            title: { Text("Arabic Alphabet") },
                            icon: {
                                Image(systemName: "textformat.size.ar")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }
                    
                    NavigationLink(destination: AdhkarView()) {
                        Label(
                            title: { Text("Common Adhkar") },
                            icon: {
                                Image(systemName: "book.closed")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }

                    NavigationLink(destination: DuaView()) {
                        Label(
                            title: { Text("Common Duas") },
                            icon: {
                                Image(systemName: "text.book.closed")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }

                    NavigationLink(destination: TasbihView()) {
                        Label(
                            title: { Text("Tasbih Counter") },
                            icon: {
                                Image(systemName: "circles.hexagonpath.fill")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }

                    NavigationLink(destination: NamesView()) {
                        Label(
                            title: { Text("99 Names of Allah") },
                            icon: {
                                Image(systemName: "signature")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }
                    
                    #if !os(watchOS)
                    NavigationLink(destination: DateView()) {
                        Label(
                            title: { Text("Hijri Calendar Converter") },
                            icon: {
                                Image(systemName: "calendar")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }
                    #endif

                    NavigationLink(destination: WallpaperView()) {
                        Label(
                            title: { Text("Islamic Wallpapers") },
                            icon: {
                                Image(systemName: "photo.on.rectangle")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }
                }
                #endif
                
                #if false
                ProphetQuote()
                #endif
                
                #if false
                AlIslamAppsSection()
                #endif
            }
            .background(
                ScrollOffsetObserver { offset in
                    onScrollOffsetChange?(offset)
                }
            )
            .applyConditionalListStyle(defaultView: settings.defaultView)
            .navigationTitle(isMalayAppLanguage() ? "Pustaka" : "Library")
            .onAppear {
                if isActive {
                    hasActivatedLibrary = true
                }
                onScrollOffsetChange?(0)
                loadResumeSelection()
                loadPinnedSurahs()
                syncSharedQuranContentLanguagePreference(quranLanguageCode)
                Task { await loadSurahsIfNeeded() }
                Task { await loadDailyQuranQuote() }
            }
            .onChange(of: isActive) { active in
                if active {
                    hasActivatedLibrary = true
                }
            }
            .task(id: quranLanguageCode) {
                syncSharedQuranContentLanguagePreference(quranLanguageCode)
                dailyQuranQuote = nil
                dailyQuranArabicText = nil
                await loadDailyQuranQuote()
            }
            .onChange(of: selectedFullSurah) { selection in
                if selection == nil {
                    loadResumeSelection()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(QuranContentLanguage.allCases) { language in
                            Button {
                                quranLanguageCode = language.rawValue
                            } label: {
                                if quranLanguageCode == language.rawValue {
                                    Label(language.displayName, systemImage: "checkmark")
                                } else {
                                    Text(language.displayName)
                                }
                            }
                        }
                    } label: {
                        Text(currentQuranLanguage.shortLabel)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    .accessibilityLabel(isMalayAppLanguage() ? "Pilih bahasa Al-Quran" : "Choose Quran language")
                }
            }
            .sheet(item: $selectedFullSurah) { selection in
                NavigationView {
                    QuranSurahDetailsView(
                        surahNumber: selection.surahNumber,
                        initialAyahNumber: selection.initialAyahNumber,
                        dailyAyahNumber: selection.dailyAyahNumber
                    )
                        .environmentObject(settings)
                        .navigationTitle(surahTitle(for: selection.surahNumber))
                        .navigationBarTitleDisplayMode(.inline)
                        .interactiveDismissDisabled()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(isMalayAppLanguage() ? "Selesai" : "Done") {
                                    selectedFullSurah = nil
                                }
                            }
                        }
                }
            }
            .searchable(text: $searchText, prompt: isMalayAppLanguage() ? "Cari surah" : "Search surah")
        }
        .enablesScrollChromeHiding()
    }

    private func loadPinnedSurahs() {
        let stored = UserDefaults.standard.array(forKey: Self.pinnedSurahsKey) as? [Int] ?? []
        pinnedSurahNumbers = stored
    }

    private func savePinnedSurahs() {
        UserDefaults.standard.set(pinnedSurahNumbers, forKey: Self.pinnedSurahsKey)
    }

    private func togglePin(surahNumber: Int) {
        if let index = pinnedSurahNumbers.firstIndex(of: surahNumber) {
            pinnedSurahNumbers.remove(at: index)
        } else if pinnedSurahNumbers.count < Self.maxPinnedSurahs {
            pinnedSurahNumbers.append(surahNumber)
        }
        savePinnedSurahs()
    }

    private func loadLastReadAyah(for surahNumber: Int) -> Int? {
        let ayah = UserDefaults.standard.integer(forKey: "fullSurahLastReadAyahV1.\(surahNumber)")
        return ayah > 0 ? ayah : nil
    }

    private func surahTitle(for surahNumber: Int) -> String {
        if let surah = surahs.first(where: { $0.number == surahNumber }) {
            return localizedSurahName(number: surah.number, englishName: surah.englishName)
        }
        return isMalayAppLanguage() ? "Surah \(surahNumber)" : "Surah \(surahNumber)"
    }
}

#Preview {
    OtherView()
        .environmentObject(Settings.shared)
}

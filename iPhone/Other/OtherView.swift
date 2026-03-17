import SwiftUI
#if os(iOS)
import UIKit
#endif

private struct DailyQuranCachedQuote: Codable {
    let dayKey: String
    let reference: String
    let text: String
    let surahName: String
}

private struct FullSurahSelection: Identifiable {
    let surahNumber: Int
    let ayahNumber: Int?
    var id: String { "\(surahNumber):\(ayahNumber ?? 0)" }
}

struct OtherView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.openURL) private var openURL
    @State private var dailyQuranQuote: DailyQuranCachedQuote?
    @State private var selectedFullSurah: FullSurahSelection?

    private func loadDailyQuranQuote() {
        let defaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
        guard
            let data = defaults?.data(forKey: "dailyInspirationCachedQuoteV1"),
            let cached = try? JSONDecoder().decode(DailyQuranCachedQuote.self, from: data)
        else {
            dailyQuranQuote = nil
            return
        }
        dailyQuranQuote = cached
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

    private func parseReference(_ reference: String) -> (surah: Int, ayah: Int?)? {
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
        return (surah, ayah)
    }

    private func openFullSurahSheet() {
        guard let reference = dailyQuranQuote?.reference,
              let parsed = parseReference(reference) else { return }
        selectedFullSurah = FullSurahSelection(surahNumber: parsed.surah, ayahNumber: parsed.ayah)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("DAILY QURAN")) {
                    if let quote = dailyQuranQuote {
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: openDailyQuranModal) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "book.closed.fill")
                                            .foregroundColor(settings.accentColor.color)
                                        Text("\(quote.surahName) \(quote.reference)")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.primary)
                                    }
                                    Text(quote.text)
                                        .font(.footnote)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)

                            Button("Read Full Surah") {
                                openFullSurahSheet()
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(settings.accentColor.color)
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("Open the Daily Quran widget once to load today’s verse here.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

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
                
                ProphetQuote()
                
                #if false
                AlIslamAppsSection()
                #endif
            }
            .applyConditionalListStyle(defaultView: settings.defaultView)
            .navigationTitle("Resources")
            .onAppear(perform: loadDailyQuranQuote)
            .sheet(item: $selectedFullSurah) { selection in
                NavigationView {
                    QuranSurahDetailsView(
                        surahNumber: selection.surahNumber,
                        dailyAyahNumber: selection.ayahNumber
                    )
                        .environmentObject(settings)
                        .navigationTitle("Full Surah")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    selectedFullSurah = nil
                                }
                            }
                        }
                }
            }
        }
    }
}

struct ProphetQuote: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        Section(header: Text("PROPHET MUHAMMAD ﷺ QUOTE")) {
            VStack(alignment: .center) {
                ZStack {
                    Circle()
                        .strokeBorder(settings.accentColor.color, lineWidth: 1)
                        .frame(width: 60, height: 60)

                    Text("ﷺ")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(settings.accentColor.color)
                        .padding()
                }
                .padding(4)
                
                Text("“All mankind is from Adam and Eve, an Arab has no superiority over a non-Arab nor a non-Arab has any superiority over an Arab; also a white has no superiority over a black, nor a black has any superiority over a white except by piety and good action.“")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(settings.accentColor.color)
                
                Text("Farewell Sermon\nJumuah, 9 Dhul-Hijjah 10 AH\nFriday, 6 March 632 CE")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 1)
            }
        }
        #if !os(watchOS)
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = "All mankind is from Adam and Eve, an Arab has no superiority over a non-Arab nor a non-Arab has any superiority over an Arab; also a white has no superiority over a black, nor a black has any superiority over a white except by piety and good action.\n\n– Farewell Sermon\nJumuah, 9 Dhul-Hijjah 10 AH\nFriday, 6 March 632 CE"
            }) {
                Text("Copy Text")
                Image(systemName: "doc.on.doc")
            }
        }
        #endif
    }
}

struct AlIslamAppsSection: View {
    @EnvironmentObject var settings: Settings
    
    #if !os(watchOS)
    let spacing: CGFloat = 20
    #else
    let spacing: CGFloat = 10
    #endif

    var body: some View {
        Section(header: Text("AL-ISLAMIC APPS")) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.yellow.opacity(0.25), .green.opacity(0.25)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .primary.opacity(0.25), radius: 5, x: 0, y: 1)
                    .padding(.horizontal, -12)
                    #if !os(watchOS)
                    .padding(.vertical, -11)
                    #endif
                
                HStack(spacing: spacing) {
                    if let url = URL(string: "https://apps.apple.com/us/app/waktu-prayer-times-widgets/id6759585564") {
                        Card(title: "Al-Adhan", url: url)
                    }
                    if let url = URL(string: "https://apps.apple.com/us/app/al-islam-islamic-pillars/id6449729655") {
                        Card(title: "Al-Islam", url: url)
                    }
                    if let url = URL(string: "https://apps.apple.com/us/app/al-quran-beginner-quran/id6474894373") {
                        Card(title: "Al-Quran", url: url)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .scaledToFit()
                .padding(.vertical, 8)
                .padding(.horizontal)
            }
        }
    }
}

private struct Card: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.openURL) private var openURL
    
    let title: String
    let url: URL

    var body: some View {
        Button(action: {
            settings.hapticFeedback()
            
            openURL(url)
        }) {
            VStack {
                Image(title)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(15)
                    .shadow(radius: 4)

                #if !os(watchOS)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                #endif
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct QuranSurahDetailsView: View {
    let surahNumber: Int
    let dailyAyahNumber: Int?

    @EnvironmentObject private var settings: Settings
    @State private var details: QuranSurahDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pendingRestoreAyah: Int?
    @State private var didRestorePosition = false
    @State private var lastSavedAyah: Int?

    private var quranArabicFontName: String {
        let candidates = [
            settings.fontArabic,
            "KFGQPCUthmanicScriptHAFS",
            "Uthmani",
            "KFGQPC Uthmanic Script HAFS",
            "UthmanicHafs1 Ver09",
            "AmiriQuran-Regular",
            "Amiri Quran"
        ]
        #if os(iOS)
        for name in candidates where !name.isEmpty {
            if UIFont(name: name, size: 28) != nil {
                return name
            }
        }
        #endif
        return settings.fontArabic
    }

    private var dailyAyahTagTextColor: Color {
        #if os(iOS)
        let ui = UIColor(settings.accentColor.color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .white
        }
        let luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
        return luminance > 0.62 ? .black : .white
        #else
        return .white
        #endif
    }

    var body: some View {
        content(surahNumber: surahNumber)
        .task(id: surahNumber) {
            await loadSurah(surahNumber: surahNumber)
        }
    }

    private func content(surahNumber: Int) -> some View {
        Group {
            if isLoading {
                ProgressView("Loading Surah \(surahNumber)...")
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else if let details {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            Text("\(details.englishName) (\(details.arabicName))")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("Surah \(details.number) • \(details.ayahs.count) ayahs")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Divider()

                            ForEach(details.ayahs) { ayah in
                                let isDailyAyah = dailyAyahNumber == ayah.numberInSurah
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(ayah.numberInSurah)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.secondary)

                                    Text(ayah.arabicText)
                                        .font(.custom(quranArabicFontName, size: 30))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .multilineTextAlignment(.trailing)

                                    if let english = ayah.englishText, !english.isEmpty {
                                        Text(english)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.primary.opacity(0.04))
                                )
                                .overlay {
                                    if isDailyAyah {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(settings.accentColor.color, lineWidth: 2)
                                    }
                                }
                                .overlay(alignment: .topLeading) {
                                    if isDailyAyah {
                                        Text("Daily Ayat")
                                            .font(.caption2.weight(.bold))
                                            .foregroundColor(dailyAyahTagTextColor)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(settings.accentColor.color)
                                            )
                                            .padding(.leading, 10)
                                            .offset(y: -10)
                                    }
                                }
                                .id(ayah.numberInSurah)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: AyahMinYPreferenceKey.self,
                                            value: [ayah.numberInSurah: geo.frame(in: .named("surahScrollView")).minY]
                                        )
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    .coordinateSpace(name: "surahScrollView")
                    .onAppear {
                        guard !didRestorePosition else { return }
                        let target = pendingRestoreAyah ?? dailyAyahNumber
                        guard let target else {
                            didRestorePosition = true
                            return
                        }
                        DispatchQueue.main.async {
                            proxy.scrollTo(target, anchor: .top)
                            didRestorePosition = true
                        }
                    }
                    .onPreferenceChange(AyahMinYPreferenceKey.self) { positions in
                        guard didRestorePosition, !positions.isEmpty else { return }
                        // Prefer the ayah touching/crossing the top edge (more accurate resume point).
                        let topBoundary: CGFloat = 0
                        let atOrAboveTop = positions.filter { $0.value <= topBoundary + 1 }
                        let trackedAyah: Int?
                        if let crossingTop = atOrAboveTop.max(by: { $0.value < $1.value }) {
                            trackedAyah = crossingTop.key
                        } else {
                            trackedAyah = positions.min(by: { $0.value < $1.value })?.key
                        }
                        guard let trackedAyah else { return }
                        guard trackedAyah != lastSavedAyah else { return }
                        lastSavedAyah = trackedAyah
                        saveLastReadAyah(trackedAyah, for: surahNumber)
                    }
                }
            } else {
                Text("Loading Surah \(surahNumber)...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    @MainActor
    private func loadSurah(surahNumber: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        pendingRestoreAyah = loadLastReadAyah(for: surahNumber)
        didRestorePosition = false
        lastSavedAyah = pendingRestoreAyah

        do {
            details = try await QuranSurahAPI.fetchSurahDetails(surahNumber: surahNumber)
        } catch {
            details = nil
            let reason = error.localizedDescription
            if reason.isEmpty || reason == "The operation couldn’t be completed." {
                errorMessage = "Unable to load this surah right now. Please try again."
            } else {
                errorMessage = "Unable to load this surah right now. \(reason)"
            }
        }
    }

    private func storageKey(for surahNumber: Int) -> String {
        "fullSurahLastReadAyahV1.\(surahNumber)"
    }

    private func loadLastReadAyah(for surahNumber: Int) -> Int? {
        let ayah = UserDefaults.standard.integer(forKey: storageKey(for: surahNumber))
        return ayah > 0 ? ayah : nil
    }

    private func saveLastReadAyah(_ ayahNumber: Int, for surahNumber: Int) {
        guard ayahNumber > 0 else { return }
        UserDefaults.standard.set(ayahNumber, forKey: storageKey(for: surahNumber))
    }
}

private struct AyahMinYPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct QuranSurahDetails {
    struct Ayah: Identifiable {
        let numberInSurah: Int
        let arabicText: String
        let englishText: String?

        var id: Int { numberInSurah }
    }

    let number: Int
    let englishName: String
    let arabicName: String
    let ayahs: [Ayah]
}

private enum QuranSurahAPI {
    static func fetchSurahDetails(surahNumber: Int) async throws -> QuranSurahDetails {
        guard (1...114).contains(surahNumber) else {
            throw QuranSurahAPIError.invalidURL
        }

        async let arabicEdition = fetchEdition(surahNumber: surahNumber, edition: "ar.alafasy")
        async let englishEdition = fetchEdition(surahNumber: surahNumber, edition: "en.asad")
        let (arabic, english) = try await (arabicEdition, englishEdition)

        let englishByAyah = Dictionary(
            uniqueKeysWithValues: english.ayahs.map { ($0.numberInSurah, $0.text) }
        )

        let mergedAyahs = arabic.ayahs.map {
            QuranSurahDetails.Ayah(
                numberInSurah: $0.numberInSurah,
                arabicText: $0.text,
                englishText: englishByAyah[$0.numberInSurah]
            )
        }

        return QuranSurahDetails(
            number: arabic.surah.number,
            englishName: arabic.surah.englishName,
            arabicName: arabic.surah.name,
            ayahs: mergedAyahs
        )
    }

    private static func fetchEdition(surahNumber: Int, edition: String) async throws -> QuranSurahEditionData {
        guard let url = URL(string: "https://api.alquran.cloud/v1/surah/\(surahNumber)/\(edition)") else {
            throw QuranSurahAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw QuranSurahAPIError.badResponse
        }

        let decoded = try JSONDecoder().decode(QuranSurahEditionResponse.self, from: data)
        if let code = decoded.code, code != 200 {
            throw QuranSurahAPIError.badResponse
        }
        return decoded.data
    }
}

private enum QuranSurahAPIError: Error {
    case invalidURL
    case badResponse
}

private struct QuranSurahEditionResponse: Decodable {
    let code: Int?
    let data: QuranSurahEditionData

    private enum CodingKeys: String, CodingKey {
        case code
        case data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let intCode = try? c.decode(Int.self, forKey: .code) {
            code = intCode
        } else if let stringCode = try? c.decode(String.self, forKey: .code),
                  let intCode = Int(stringCode) {
            code = intCode
        } else {
            code = nil
        }
        data = try c.decode(QuranSurahEditionData.self, forKey: .data)
    }
}

private struct QuranSurahEditionData: Decodable {
    let surah: QuranSurahMeta
    let ayahs: [QuranSurahAyah]

    private enum CodingKeys: String, CodingKey {
        case surah
        case ayahs
        case number
        case name
        case englishName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let nestedSurah = try? c.decode(QuranSurahMeta.self, forKey: .surah) {
            surah = nestedSurah
        } else {
            surah = QuranSurahMeta(
                number: try c.decode(Int.self, forKey: .number),
                name: try c.decode(String.self, forKey: .name),
                englishName: try c.decode(String.self, forKey: .englishName)
            )
        }
        ayahs = try c.decode([QuranSurahAyah].self, forKey: .ayahs)
    }
}

private struct QuranSurahMeta: Decodable {
    let number: Int
    let name: String
    let englishName: String
}

private struct QuranSurahAyah: Decodable {
    let numberInSurah: Int
    let text: String
}

#Preview {
    OtherView()
        .environmentObject(Settings.shared)
}

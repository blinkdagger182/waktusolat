import SwiftUI
import AVFoundation
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

private enum FullQuranResumeStorage {
    static let lastSurahKey = "fullQuranLastViewedSurahV1"
    static let lastAyahKey = "fullQuranLastViewedAyahV1"
}

struct OtherView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.openURL) private var openURL
    @State private var dailyQuranQuote: DailyQuranCachedQuote?
    @State private var selectedFullSurah: FullSurahSelection?
    @State private var showQuranBrowser = false
    @State private var resumeSelection: FullSurahSelection?

    private func loadDailyQuranQuote() {
        let defaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
        guard
            let data = defaults?.data(forKey: "dailyInspirationCachedQuoteV2")
                ?? defaults?.data(forKey: "dailyInspirationCachedQuoteV1"),
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

    private func loadResumeSelection() {
        let defaults = UserDefaults.standard
        let surah = defaults.integer(forKey: FullQuranResumeStorage.lastSurahKey)
        let ayah = defaults.integer(forKey: FullQuranResumeStorage.lastAyahKey)
        guard (1...114).contains(surah) else {
            resumeSelection = nil
            return
        }
        resumeSelection = FullSurahSelection(
            surahNumber: surah,
            ayahNumber: ayah > 0 ? ayah : nil
        )
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text(isMalayAppLanguage() ? "AL-QURAN HARIAN" : "DAILY QURAN")) {
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

                            Button(isMalayAppLanguage() ? "Baca Surah Penuh" : "Read Full Surah") {
                                openFullSurahSheet()
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(settings.accentColor.color)
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text(isMalayAppLanguage()
                             ? "Buka widget Al-Quran Harian sekali untuk memuatkan ayat hari ini di sini."
                             : "Open the Daily Quran widget once to load today’s verse here.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text(isMalayAppLanguage() ? "AL-QURAN PENUH" : "FULL QURAN")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isMalayAppLanguage() ? "Al-Quran Penuh" : "Full Quran")
                                    .font(.headline)
                                Text(isMalayAppLanguage()
                                     ? "Terokai semua 114 surah, sambung bacaan terakhir, dan mainkan bacaan mengikut ayat."
                                     : "Browse all 114 surahs, resume your last position, and play recitation by ayah.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 12)

                            if let resumeSelection {
                                Button(isMalayAppLanguage() ? "Sambung" : "Resume") {
                                    selectedFullSurah = resumeSelection
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(settings.accentColor.color)
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            showQuranBrowser = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "books.vertical.fill")
                                    .foregroundStyle(settings.accentColor.color)
                                Text(isMalayAppLanguage() ? "Buka Senarai Surah" : "Open Surah Browser")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
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
            .navigationTitle(isMalayAppLanguage() ? "Pustaka" : "Library")
            .onAppear {
                loadDailyQuranQuote()
                loadResumeSelection()
            }
            .sheet(item: $selectedFullSurah) { selection in
                NavigationView {
                    QuranSurahDetailsView(
                        surahNumber: selection.surahNumber,
                        dailyAyahNumber: selection.ayahNumber
                    )
                        .environmentObject(settings)
                        .navigationTitle(isMalayAppLanguage() ? "Surah Penuh" : "Full Surah")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(isMalayAppLanguage() ? "Selesai" : "Done") {
                                    selectedFullSurah = nil
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showQuranBrowser) {
                NavigationView {
                    QuranSurahBrowserView(selectedSurah: $selectedFullSurah)
                        .environmentObject(settings)
                        .navigationTitle(isMalayAppLanguage() ? "Al-Quran" : "Quran")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(isMalayAppLanguage() ? "Selesai" : "Done") {
                                    showQuranBrowser = false
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
                Text(isMalayAppLanguage() ? "Salin Teks" : "Copy Text")
                Image(systemName: "doc.on.doc")
            }
        }
        #endif
    }
}

private struct QuranSurahBrowserView: View {
    @EnvironmentObject private var settings: Settings
    @Binding var selectedSurah: FullSurahSelection?
    @Environment(\.dismiss) private var dismiss
    @State private var surahs: [QuranSurahIndexItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var filteredSurahs: [QuranSurahIndexItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return surahs }
        return surahs.filter {
            "\($0.number)".contains(query)
            || $0.englishName.lowercased().contains(query)
            || $0.arabicName.contains(query)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(isMalayAppLanguage() ? "Memuatkan senarai surah..." : "Loading surah list...")
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
            } else {
                List(filteredSurahs) { surah in
                    Button {
                        selectedSurah = FullSurahSelection(surahNumber: surah.number, ayahNumber: nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(surah.number)")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(surah.englishName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(surah.arabicName)
                                    .font(.custom(preferredQuranArabicFontName(settings: settings, size: 18), size: 18))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .searchable(text: $searchText, prompt: isMalayAppLanguage() ? "Cari surah" : "Search surah")
            }
        }
        .task {
            await loadSurahs()
        }
    }

    @MainActor
    private func loadSurahs() async {
        guard surahs.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            surahs = try await QuranSurahIndexAPI.fetchAll()
        } catch {
            let reason = error.localizedDescription
            if reason.isEmpty || reason == "The operation couldn’t be completed." {
                errorMessage = isMalayAppLanguage()
                    ? "Tidak dapat memuatkan senarai surah sekarang. Sila cuba lagi."
                    : "Unable to load the surah list right now. Please try again."
            } else {
                errorMessage = reason
            }
        }
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
    @State private var recitationPlayer: AVQueuePlayer?
    @State private var isRecitationLoading = false
    @State private var isReciting = false
    @State private var recitationErrorMessage: String?
    @State private var recitationEndObserver: NSObjectProtocol?
    @State private var currentPlaybackAyah: Int?
    @State private var currentPlaybackWordPosition: Int?
    @State private var playbackAyahSequence: [Int] = []
    @State private var playbackSequenceIndex = 0
    @State private var playbackTimeObserver: Any?

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
        .onDisappear {
            stopRecitation()
        }
        .safeAreaInset(edge: .bottom) {
            if let details, recitationPlayer != nil || isRecitationLoading {
                QuranRecitationControlBar(
                    surahTitle: details.englishName,
                    ayahNumber: currentPlaybackAyah,
                    isReciting: isReciting,
                    isLoading: isRecitationLoading,
                    accentColor: settings.accentColor.color,
                    canGoBackward: canGoBackward,
                    canGoForward: canGoForward,
                    onPrevious: playPreviousAyah,
                    onPlayPause: toggleRecitation,
                    onNext: playNextAyah
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .background(.thinMaterial)
            }
        }
    }

    private var canGoBackward: Bool {
        guard let currentPlaybackAyah else { return false }
        return currentPlaybackAyah > 1
    }

    private var canGoForward: Bool {
        guard let details, let currentPlaybackAyah else { return false }
        return currentPlaybackAyah < details.ayahs.count
    }

    private func content(surahNumber: Int) -> some View {
        Group {
            if isLoading {
                ProgressView(isMalayAppLanguage()
                             ? "Memuatkan Surah \(surahNumber)..."
                             : "Loading Surah \(surahNumber)...")
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

                            Text(isMalayAppLanguage()
                                 ? "Surah \(details.number) • \(details.ayahs.count) ayat"
                                 : "Surah \(details.number) • \(details.ayahs.count) ayahs")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Button(action: toggleRecitation) {
                                    HStack(spacing: 8) {
                                        Image(systemName: isRecitationLoading ? "hourglass" : (isReciting ? "pause.fill" : "play.fill"))
                                        Text(isRecitationLoading
                                             ? (isMalayAppLanguage() ? "Memuatkan bacaan..." : "Loading recitation...")
                                             : (isReciting
                                                ? (isMalayAppLanguage() ? "Jeda Bacaan" : "Pause Recitation")
                                                : (isMalayAppLanguage() ? "Mainkan Bacaan" : "Play Recitation")))
                                    }
                                    .font(.footnote.weight(.semibold))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.primary.opacity(0.08))
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isRecitationLoading || details.ayahs.allSatisfy { $0.audioURL == nil })

                                if let recitationErrorMessage {
                                    Text(recitationErrorMessage)
                                        .font(.caption2)
                                        .foregroundStyle(.red.opacity(0.9))
                                        .lineLimit(2)
                                }
                            }

                            Divider()

                            ForEach(details.ayahs) { ayah in
                                let isDailyAyah = dailyAyahNumber == ayah.numberInSurah
                                let isPlayingAyah = currentPlaybackAyah == ayah.numberInSurah && isReciting
                                HStack(alignment: .top, spacing: 12) {
                                    AyahPlaybackCursor(
                                        isActive: isPlayingAyah,
                                        accentColor: settings.accentColor.color
                                    )
                                    .padding(.top, 6)

                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 8) {
                                            Text("\(ayah.numberInSurah)")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(isPlayingAyah ? settings.accentColor.color : .secondary)

                                            if isPlayingAyah {
                                                Text(isMalayAppLanguage() ? "Sedang dimainkan" : "Now playing")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(settings.accentColor.color)
                                            }
                                        }

                                        highlightedArabicText(for: ayah, isPlayingAyah: isPlayingAyah)
                                            .font(.custom(quranArabicFontName, size: 30))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .multilineTextAlignment(.trailing)

                                        if let translation = ayah.translationText, !translation.isEmpty {
                                            Text(translation)
                                                .font(.subheadline)
                                                .foregroundStyle(isPlayingAyah ? settings.accentColor.color : .primary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            isPlayingAyah
                                                ? settings.accentColor.color.opacity(0.12)
                                                : Color.primary.opacity(0.04)
                                        )
                                )
                                .overlay {
                                    if isPlayingAyah {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(settings.accentColor.color, lineWidth: 2)
                                    } else if isDailyAyah {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(settings.accentColor.color, lineWidth: 2)
                                    }
                                }
                                .overlay(alignment: .topLeading) {
                                    if isDailyAyah {
                                        Text(isMalayAppLanguage() ? "Ayat Harian" : "Daily Ayat")
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
                                .onTapGesture {
                                    playRecitation(fromAyah: ayah.numberInSurah)
                                }
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
                    .onChange(of: currentPlaybackAyah) { ayah in
                        guard let ayah else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(ayah, anchor: .center)
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
                        saveResumeSelection(surahNumber: surahNumber, ayahNumber: trackedAyah)
                    }
                }
            } else {
                Text(isMalayAppLanguage()
                     ? "Memuatkan Surah \(surahNumber)..."
                     : "Loading Surah \(surahNumber)...")
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
        saveResumeSelection(surahNumber: surahNumber, ayahNumber: pendingRestoreAyah ?? dailyAyahNumber)

        do {
            details = try await QuranSurahAPI.fetchSurahDetails(surahNumber: surahNumber)
        } catch {
            details = nil
            let reason = error.localizedDescription
            if reason.isEmpty || reason == "The operation couldn’t be completed." {
                errorMessage = isMalayAppLanguage()
                    ? "Tidak dapat memuatkan surah ini sekarang. Sila cuba lagi."
                    : "Unable to load this surah right now. Please try again."
            } else {
                errorMessage = isMalayAppLanguage()
                    ? "Tidak dapat memuatkan surah ini sekarang. \(reason)"
                    : "Unable to load this surah right now. \(reason)"
            }
        }
    }

    @MainActor
    private func toggleRecitation() {
        recitationErrorMessage = nil

        if let player = recitationPlayer {
            if isReciting {
                player.pause()
                isReciting = false
            } else {
                player.play()
                isReciting = true
            }
            return
        }

        let startingAyah = currentPlaybackAyah ?? pendingRestoreAyah ?? dailyAyahNumber ?? 1
        playRecitation(fromAyah: startingAyah)
    }

    @MainActor
    private func playRecitation(fromAyah ayahNumber: Int) {
        recitationErrorMessage = nil
        guard let details else { return }
        let validAyah = min(max(ayahNumber, 1), details.ayahs.count)
        let slice = details.ayahs.filter { $0.numberInSurah >= validAyah }
        let itemsWithAyah = slice.compactMap { ayah -> (Int, AVPlayerItem)? in
            guard let audioURL = ayah.audioURL, let url = URL(string: audioURL) else { return nil }
            return (ayah.numberInSurah, AVPlayerItem(url: url))
        }

        guard itemsWithAyah.isEmpty == false else {
            recitationErrorMessage = isMalayAppLanguage()
                ? "Bacaan belum tersedia untuk ayat ini."
                : "Recitation is not available for this ayah yet."
            return
        }

        isRecitationLoading = true
        stopRecitation()

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            recitationErrorMessage = isMalayAppLanguage() ? "Sesi audio gagal." : "Audio session failed."
        }
        #endif

        playbackAyahSequence = itemsWithAyah.map(\.0)
        playbackSequenceIndex = 0
        currentPlaybackAyah = playbackAyahSequence.first
        currentPlaybackWordPosition = details.ayahs.first(where: { $0.numberInSurah == validAyah })?.words.first?.position
        saveResumeSelection(surahNumber: surahNumber, ayahNumber: validAyah)

        let player = AVQueuePlayer(items: itemsWithAyah.map(\.1))
        recitationPlayer = player
        playbackTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { time in
            updateCurrentPlaybackWord(for: time)
        }
        recitationEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { _ in
            if playbackSequenceIndex + 1 < playbackAyahSequence.count {
                playbackSequenceIndex += 1
                let nextAyah = playbackAyahSequence[playbackSequenceIndex]
                currentPlaybackAyah = nextAyah
                currentPlaybackWordPosition = details.ayahs.first(where: { $0.numberInSurah == nextAyah })?.words.first?.position
                saveResumeSelection(surahNumber: surahNumber, ayahNumber: nextAyah)
            } else {
                isReciting = false
                currentPlaybackAyah = nil
                currentPlaybackWordPosition = nil
            }
        }
        player.play()
        isRecitationLoading = false
        isReciting = true
    }

    @MainActor
    private func stopRecitation() {
        if let playbackTimeObserver, let recitationPlayer {
            recitationPlayer.removeTimeObserver(playbackTimeObserver)
            self.playbackTimeObserver = nil
        }
        recitationPlayer?.pause()
        recitationPlayer?.removeAllItems()
        recitationPlayer = nil
        isReciting = false
        isRecitationLoading = false
        playbackAyahSequence = []
        playbackSequenceIndex = 0
        currentPlaybackAyah = nil
        currentPlaybackWordPosition = nil
        if let recitationEndObserver {
            NotificationCenter.default.removeObserver(recitationEndObserver)
            self.recitationEndObserver = nil
        }
    }

    @MainActor
    private func playPreviousAyah() {
        guard let currentPlaybackAyah else { return }
        playRecitation(fromAyah: max(currentPlaybackAyah - 1, 1))
    }

    @MainActor
    private func playNextAyah() {
        guard let details else { return }
        let current = currentPlaybackAyah ?? 1
        playRecitation(fromAyah: min(current + 1, details.ayahs.count))
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

    private func saveResumeSelection(surahNumber: Int, ayahNumber: Int?) {
        let defaults = UserDefaults.standard
        defaults.set(surahNumber, forKey: FullQuranResumeStorage.lastSurahKey)
        if let ayahNumber, ayahNumber > 0 {
            defaults.set(ayahNumber, forKey: FullQuranResumeStorage.lastAyahKey)
        }
    }

    private func highlightedArabicText(for ayah: QuranSurahDetails.Ayah, isPlayingAyah: Bool) -> Text {
        guard isPlayingAyah, !ayah.words.isEmpty else {
            return Text(ayah.arabicText)
                .foregroundColor(isPlayingAyah ? settings.accentColor.color : .primary)
        }

        let activePosition = currentPlaybackWordPosition
        return ayah.words.enumerated().reduce(Text("")) { partial, element in
            let (index, word) = element
            let cursor = activePosition == word.position
                ? Text("▏").foregroundColor(settings.accentColor.color)
                : Text("")
            let token = Text(word.textArabic)
                .foregroundColor(activePosition == word.position ? settings.accentColor.color : .primary)
            if index == 0 {
                return cursor + token
            }
            return partial + Text(" ") + cursor + token
        }
    }

    private func updateCurrentPlaybackWord(for time: CMTime) {
        guard
            let details,
            let currentPlaybackAyah,
            let ayah = details.ayahs.first(where: { $0.numberInSurah == currentPlaybackAyah }),
            !ayah.wordTimings.isEmpty
        else {
            return
        }

        let currentMs = max(0, Int((time.seconds * 1000).rounded()))
        if let activeTiming = ayah.wordTimings.first(where: { currentMs >= $0.startMs && currentMs <= $0.endMs }) {
            currentPlaybackWordPosition = activeTiming.wordPosition
            return
        }

        if let upcomingTiming = ayah.wordTimings.first(where: { currentMs < $0.startMs }) {
            currentPlaybackWordPosition = upcomingTiming.wordPosition
            return
        }

        currentPlaybackWordPosition = ayah.wordTimings.last?.wordPosition
    }
}

private struct AyahPlaybackCursor: View {
    let isActive: Bool
    let accentColor: Color

    @State private var isVisible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(isActive ? accentColor : Color.secondary.opacity(0.16))
            .frame(width: 3, height: isActive ? 46 : 28)
            .opacity(isActive ? (isVisible ? 1 : 0.2) : 1)
            .animation(
                isActive
                    ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.2),
                value: isVisible
            )
            .onAppear {
                guard isActive else { return }
                isVisible = false
            }
            .onChange(of: isActive) { active in
                if active {
                    isVisible = false
                } else {
                    isVisible = true
                }
            }
            .accessibilityHidden(true)
    }
}

private struct AyahMinYPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct QuranRecitationControlBar: View {
    let surahTitle: String
    let ayahNumber: Int?
    let isReciting: Bool
    let isLoading: Bool
    let accentColor: Color
    let canGoBackward: Bool
    let canGoForward: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    private var subtitleText: String {
        if isLoading {
            return isMalayAppLanguage() ? "Memuatkan bacaan..." : "Loading recitation..."
        }
        if let ayahNumber {
            return isMalayAppLanguage() ? "Ayat \(ayahNumber)" : "Ayah \(ayahNumber)"
        }
        return isMalayAppLanguage() ? "Sedia untuk dimainkan" : "Ready to play"
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(surahTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(subtitleText)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isLoading || !canGoBackward)
                .foregroundStyle(canGoBackward ? Color.primary : Color.secondary.opacity(0.45))

                Button(action: onPlayPause) {
                    ZStack {
                        Circle()
                            .fill(accentColor)
                        Image(systemName: isLoading ? "hourglass" : (isReciting ? "pause.fill" : "play.fill"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .accessibilityLabel(isReciting
                    ? (isMalayAppLanguage() ? "Jeda bacaan" : "Pause recitation")
                    : (isMalayAppLanguage() ? "Mainkan bacaan" : "Play recitation"))

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isLoading || !canGoForward)
                .foregroundStyle(canGoForward ? Color.primary : Color.secondary.opacity(0.45))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct QuranSurahDetails {
    struct Ayah: Identifiable {
        let numberInSurah: Int
        let arabicText: String
        let translationText: String?
        let audioURL: String?
        let words: [Word]
        let wordTimings: [WordTiming]

        var id: Int { numberInSurah }
    }

    struct Word: Decodable, Hashable {
        let position: Int
        let textArabic: String
    }

    struct WordTiming: Decodable, Hashable {
        let wordPosition: Int
        let startMs: Int
        let endMs: Int
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

        let decoded = try await fetchSurah(surahNumber: surahNumber)

        return QuranSurahDetails(
            number: decoded.number,
            englishName: decoded.englishName,
            arabicName: decoded.arabicName,
            ayahs: decoded.ayahs.map {
                QuranSurahDetails.Ayah(
                    numberInSurah: $0.numberInSurah,
                    arabicText: $0.arabicText,
                    translationText: $0.translationText,
                    audioURL: $0.audioURL,
                    words: $0.words ?? [],
                    wordTimings: $0.wordTimings ?? []
                )
            }
        )
    }

    private static func fetchSurah(surahNumber: Int) async throws -> QuranSurahProxyResponse {
        guard var components = URLComponents(url: quranProxyBaseURL(), resolvingAgainstBaseURL: false) else {
            throw QuranSurahAPIError.invalidURL
        }
        components.path += "/surah/\(surahNumber)"
        components.queryItems = [
            URLQueryItem(name: "lang", value: quranContentLanguageCode())
        ]
        guard let url = components.url else {
            throw QuranSurahAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw QuranSurahAPIError.badResponse
        }

        return try JSONDecoder().decode(QuranSurahProxyResponse.self, from: data)
    }
}

private enum QuranSurahAPIError: Error {
    case invalidURL
    case badResponse
}

private struct QuranSurahProxyResponse: Decodable {
    let number: Int
    let englishName: String
    let arabicName: String
    let ayahs: [QuranSurahProxyAyah]
}

private struct QuranSurahIndexItem: Decodable, Identifiable {
    let number: Int
    let englishName: String
    let arabicName: String

    var id: Int { number }
}

private struct QuranSurahIndexResponse: Decodable {
    let chapters: [QuranSurahIndexItem]

    var data: [QuranSurahIndexItem] { chapters }
}

private enum QuranSurahIndexAPI {
    static func fetchAll() async throws -> [QuranSurahIndexItem] {
        guard let url = URL(string: "\(quranProxyBaseURL().absoluteString)/chapters") else {
            throw QuranSurahAPIError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw QuranSurahAPIError.badResponse
        }
        let decoded = try JSONDecoder().decode(QuranSurahIndexResponse.self, from: data)
        return decoded.data
    }
}

private struct QuranSurahProxyAyah: Decodable {
    let numberInSurah: Int
    let arabicText: String
    let translationText: String?
    let audioURL: String?
    let words: [QuranSurahDetails.Word]?
    let wordTimings: [QuranSurahDetails.WordTiming]?
}

private func preferredQuranArabicFontName(settings: Settings, size: CGFloat) -> String {
    #if os(iOS)
    let candidates = [
        settings.fontArabic,
        "KFGQPCUthmanicScriptHAFS",
        "Uthmani",
        "KFGQPC Uthmanic Script HAFS",
        "UthmanicHafs1 Ver09",
        "AmiriQuran-Regular",
        "Amiri Quran"
    ]
    for name in candidates where !name.isEmpty {
        if UIFont(name: name, size: size) != nil {
            return name
        }
    }
    #endif
    return settings.fontArabic
}

#Preview {
    OtherView()
        .environmentObject(Settings.shared)
}

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

private struct DailyQuranArabicPayload: Decodable {
    let arabicText: String?
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

private struct DailyQuranReferenceParts {
    let surahNumber: Int
    let ayahNumber: Int?
}

struct OtherView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.openURL) private var openURL
    @State private var dailyQuranQuote: DailyQuranCachedQuote?
    @State private var selectedFullSurah: FullSurahSelection?
    @State private var resumeSelection: FullSurahSelection?
    @State private var surahs: [QuranSurahIndexItem] = []
    @State private var isLoadingSurahs = true
    @State private var surahListErrorMessage: String?
    @State private var searchText = ""
    @State private var expandedSurahNumber: Int?
    @State private var dailyQuranArabicText: String?

    private var filteredSurahs: [QuranSurahIndexItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return surahs }
        return surahs.filter {
            "\($0.number)".contains(query)
            || $0.englishName.lowercased().contains(query)
            || $0.arabicName.contains(query)
        }
    }

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
        selectedFullSurah = FullSurahSelection(surahNumber: parsed.surahNumber, ayahNumber: parsed.ayahNumber)
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
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text(isMalayAppLanguage() ? "AL-QURAN HARIAN" : "DAILY QURAN")) {
                    if let quote = dailyQuranQuote {
                        VStack(alignment: .center, spacing: 12) {
                            Button(action: openDailyQuranModal) {
                                VStack(alignment: .center, spacing: 10) {
                                    if let dailyQuranArabicText, !dailyQuranArabicText.isEmpty {
                                        Text(dailyQuranArabicText)
                                            .font(.custom(preferredQuranArabicFontName(settings: settings, size: 28), size: 28))
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    }

                                    Text(quote.text)
                                        .font(.title3.weight(.semibold))
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    Text("\(quote.surahName) \(quote.reference)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.thinMaterial)
                                )
                            }
                            .buttonStyle(.plain)

                            Button(isMalayAppLanguage() ? "Baca Surah Penuh" : "Read Full Surah", action: openDailyQuranFullSurah)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(settings.accentColor.color)
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
                    if let resumeSelection {
                        Button(isMalayAppLanguage() ? "Sambung Bacaan Terakhir" : "Resume Last Reading") {
                            selectedFullSurah = resumeSelection
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(settings.accentColor.color)
                        .buttonStyle(.plain)
                    }

                    if isLoadingSurahs {
                        ProgressView(isMalayAppLanguage() ? "Memuatkan senarai surah..." : "Loading surah list...")
                    } else if let surahListErrorMessage {
                        Text(surahListErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredSurahs) { surah in
                            QuranSurahExpandableCard(
                                surah: surah,
                                isExpanded: expandedSurahNumber == surah.number,
                                accentColor: settings.accentColor.color,
                                progressAyah: loadLastReadAyah(for: surah.number),
                                onToggle: {
                                    withAnimation(.spring(response: 0.46, dampingFraction: 0.9)) {
                                        expandedSurahNumber = expandedSurahNumber == surah.number ? nil : surah.number
                                    }
                                },
                                onOpen: {
                                    selectedFullSurah = FullSurahSelection(surahNumber: surah.number, ayahNumber: nil)
                                },
                                onResume: {
                                    selectedFullSurah = FullSurahSelection(surahNumber: surah.number, ayahNumber: loadLastReadAyah(for: surah.number))
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                        }
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
                
                #if false
                ProphetQuote()
                #endif
                
                #if false
                AlIslamAppsSection()
                #endif
            }
            .applyConditionalListStyle(defaultView: settings.defaultView)
            .navigationTitle(isMalayAppLanguage() ? "Pustaka" : "Library")
            .onAppear {
                loadDailyQuranQuote()
                loadResumeSelection()
                Task { await loadSurahsIfNeeded() }
                Task { await loadDailyQuranArabicIfNeeded() }
            }
            .sheet(item: $selectedFullSurah) { selection in
                NavigationView {
                    QuranSurahDetailsView(
                        surahNumber: selection.surahNumber,
                        dailyAyahNumber: selection.ayahNumber
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
    }

    private func loadLastReadAyah(for surahNumber: Int) -> Int? {
        let ayah = UserDefaults.standard.integer(forKey: "fullSurahLastReadAyahV1.\(surahNumber)")
        return ayah > 0 ? ayah : nil
    }

    private func surahTitle(for surahNumber: Int) -> String {
        if let surah = surahs.first(where: { $0.number == surahNumber }) {
            return surah.englishName
        }
        return isMalayAppLanguage() ? "Surah \(surahNumber)" : "Surah \(surahNumber)"
    }
}

private struct QuranSurahExpandableCard: View {
    let surah: QuranSurahIndexItem
    let isExpanded: Bool
    let accentColor: Color
    let progressAyah: Int?
    let onToggle: () -> Void
    let onOpen: () -> Void
    let onResume: () -> Void

    private var totalAyahCount: Int? {
        QuranSurahVerseCounts.count(for: surah.number)
    }

    private var progressFraction: CGFloat? {
        guard let progressAyah, let totalAyahCount, totalAyahCount > 0 else { return nil }
        let clamped = min(max(progressAyah, 0), totalAyahCount)
        return CGFloat(clamped) / CGFloat(totalAyahCount)
    }

    private var progressText: String? {
        guard let progressAyah else { return nil }
        return isMalayAppLanguage()
            ? "Ayat terakhir: \(progressAyah)"
            : "Last focused ayah: \(progressAyah)"
    }

    private var metadataText: String {
        isMalayAppLanguage()
            ? "Surah \(surah.number)"
            : "Surah \(surah.number)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: 48, height: 48)
                        if let progressFraction {
                            Circle()
                                .trim(from: 0, to: progressFraction)
                                .stroke(
                                    accentColor,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 48, height: 48)
                        }
                        Text("\(surah.number)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(surah.englishName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(surah.arabicName)
                            .font(.custom(preferredQuranArabicFontName(settings: .shared, size: 22), size: 22))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(metadataText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            if let progressText {
                                Text(progressText)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(accentColor)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.trailing, 8)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 2)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Text(
                        isMalayAppLanguage()
                            ? "Buka surah penuh, atau sambung dari ayat terakhir yang anda tumpukan."
                            : "Open the full surah, or continue from the last ayah you focused on."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button(action: onOpen) {
                            Text(isMalayAppLanguage() ? "Buka Surah" : "Open Surah")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)

                        if progressAyah != nil {
                            Button(action: onResume) {
                                Text(isMalayAppLanguage() ? "Sambung" : "Resume")
                                    .font(.footnote.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(accentColor.opacity(0.16))
                                    )
                                    .foregroundStyle(accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.leading, 62)
                .padding(.trailing, 4)
                .padding(.bottom, 16)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .move(edge: .top))))
            }

            Divider()
                .padding(.leading, 62)
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.46, dampingFraction: 0.9), value: isExpanded)
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
            if let details, currentPlaybackAyah != nil || recitationPlayer != nil || isRecitationLoading {
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
                                let isActiveAyah = currentPlaybackAyah == ayah.numberInSurah
                                let isPlayingAyah = isActiveAyah && isReciting
                                let isCompletedAyah = currentPlaybackAyah.map { ayah.numberInSurah < $0 } ?? false
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text("\(ayah.numberInSurah)")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle((isActiveAyah || isCompletedAyah) ? settings.accentColor.color : .secondary)

                                        if isPlayingAyah {
                                            Text(isMalayAppLanguage() ? "Sedang dimainkan" : "Now playing")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(settings.accentColor.color)
                                        } else if isActiveAyah {
                                            Text(isMalayAppLanguage() ? "Dijeda" : "Paused")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(settings.accentColor.color)
                                        }
                                    }

                                    InteractiveArabicAyahTextView(
                                        words: ayah.words,
                                        fallbackText: ayah.arabicText,
                                        highlightedWordPosition: isActiveAyah
                                            ? currentPlaybackWordPosition
                                            : (isCompletedAyah ? (ayah.words.last?.position ?? Int.max) : nil),
                                        cursorWordPosition: isActiveAyah && !isReciting ? currentPlaybackWordPosition : nil,
                                        fontName: quranArabicFontName,
                                        fontSize: 30,
                                        accentColor: settings.accentColor.color,
                                        fullyHighlighted: isCompletedAyah,
                                        onTapWord: { wordPosition in
                                            playRecitation(fromAyah: ayah.numberInSurah, startingWordPosition: wordPosition)
                                        }
                                    )
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                    if let translation = ayah.translationText, !translation.isEmpty {
                                        Text(translation)
                                            .font(.subheadline)
                                            .foregroundStyle((isActiveAyah || isCompletedAyah) ? settings.accentColor.color : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            isActiveAyah
                                                ? settings.accentColor.color.opacity(0.12)
                                                : (isCompletedAyah
                                                    ? settings.accentColor.color.opacity(0.06)
                                                    : Color.primary.opacity(0.04))
                                        )
                                )
                                .overlay {
                                    if isActiveAyah {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(settings.accentColor.color, lineWidth: 2)
                                    } else if isCompletedAyah {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(settings.accentColor.color.opacity(0.35), lineWidth: 1)
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
            let focusedAyah = pendingRestoreAyah ?? dailyAyahNumber
            currentPlaybackAyah = focusedAyah
            if let focusedAyah,
               let focusedAyahDetails = details?.ayahs.first(where: { $0.numberInSurah == focusedAyah }) {
                currentPlaybackWordPosition = focusedAyahDetails.words.first?.position
            } else {
                currentPlaybackWordPosition = nil
            }
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
    private func playRecitation(fromAyah ayahNumber: Int, startingWordPosition: Int? = nil) {
        recitationErrorMessage = nil
        guard let details else { return }
        let validAyah = min(max(ayahNumber, 1), details.ayahs.count)
        let startingAyahDetails = details.ayahs.first(where: { $0.numberInSurah == validAyah })
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

        let resolvedStartingWordPosition = resolvedWordPosition(
            requested: startingWordPosition,
            in: startingAyahDetails
        )

        playbackAyahSequence = itemsWithAyah.map(\.0)
        playbackSequenceIndex = 0
        currentPlaybackAyah = playbackAyahSequence.first
        currentPlaybackWordPosition = resolvedStartingWordPosition ?? startingAyahDetails?.words.first?.position
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
                let nextAyahDetails = details.ayahs.first(where: { $0.numberInSurah == nextAyah })
                currentPlaybackWordPosition = nextAyahDetails?.words.first?.position
                saveResumeSelection(surahNumber: surahNumber, ayahNumber: nextAyah)
            } else {
                isReciting = false
            }
        }
        player.play()
        if let startMs = wordStartMs(for: startingAyahDetails, wordPosition: resolvedStartingWordPosition) {
            player.seek(to: CMTime(value: CMTimeValue(startMs), timescale: 1000))
        }
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

    private func wordStartMs(for ayah: QuranSurahDetails.Ayah?, wordPosition: Int?) -> Int? {
        guard let ayah, let wordPosition else { return nil }
        return ayah.wordTimings.first(where: { $0.wordPosition == wordPosition })?.startMs
    }

    private func resolvedWordPosition(requested: Int?, in ayah: QuranSurahDetails.Ayah?) -> Int? {
        guard let requested, let ayah else { return requested }
        if ayah.wordTimings.contains(where: { $0.wordPosition == requested }) {
            return requested
        }
        if let nextAvailable = ayah.wordTimings.first(where: { $0.wordPosition >= requested }) {
            return nextAvailable.wordPosition
        }
        return ayah.wordTimings.last?.wordPosition ?? requested
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

private struct AyahMinYPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

#if os(iOS)
private struct InteractiveArabicAyahTextView: UIViewRepresentable {
    let words: [QuranSurahDetails.Word]
    let fallbackText: String
    let highlightedWordPosition: Int?
    let cursorWordPosition: Int?
    let fontName: String
    let fontSize: CGFloat
    let accentColor: Color
    let fullyHighlighted: Bool
    let onTapWord: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapWord: onTapWord)
    }

    func makeUIView(context: Context) -> InteractiveArabicTextView {
        let view = InteractiveArabicTextView()
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = false
        view.isScrollEnabled = false
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.maximumNumberOfLines = 0
        view.textContainer.lineBreakMode = .byWordWrapping
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.delegateProxy = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.textView = view
        return view
    }

    func updateUIView(_ uiView: InteractiveArabicTextView, context: Context) {
        context.coordinator.onTapWord = onTapWord
        context.coordinator.textView = uiView
        uiView.configure(
            words: words,
            fallbackText: fallbackText,
            highlightedWordPosition: highlightedWordPosition,
            cursorWordPosition: cursorWordPosition,
            fontName: fontName,
            fontSize: fontSize,
            accentColor: UIColor(accentColor)
            ,
            fullyHighlighted: fullyHighlighted
        )
    }

    final class Coordinator: NSObject {
        var onTapWord: (Int) -> Void
        weak var textView: InteractiveArabicTextView?

        init(onTapWord: @escaping (Int) -> Void) {
            self.onTapWord = onTapWord
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView else { return }
            let point = gesture.location(in: textView)
            if let wordPosition = textView.wordPosition(at: point) {
                onTapWord(wordPosition)
            }
        }
    }
}

private final class InteractiveArabicTextView: UITextView {
    weak var delegateProxy: InteractiveArabicAyahTextView.Coordinator?
    private let wordPositionAttribute = NSAttributedString.Key("waktuWordPosition")
    private var cursorLayer: CALayer?

    override var intrinsicContentSize: CGSize {
        let fitting = sizeThatFits(CGSize(width: bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 64, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: fitting.height)
    }

    func configure(
        words: [QuranSurahDetails.Word],
        fallbackText: String,
        highlightedWordPosition: Int?,
        cursorWordPosition: Int?,
        fontName: String,
        fontSize: CGFloat,
        accentColor: UIColor,
        fullyHighlighted: Bool
    ) {
        let attributed = NSMutableAttributedString()
        let textColor = UIColor.label
        let baseFont = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)

        if words.isEmpty {
            attributed.append(NSAttributedString(string: fallbackText, attributes: [
                .font: baseFont,
                .foregroundColor: fullyHighlighted ? accentColor : textColor,
            ]))
        } else {
            for (index, word) in words.enumerated() {
                if index > 0 {
                    attributed.append(NSAttributedString(string: " ", attributes: [
                        .font: baseFont,
                        .foregroundColor: textColor,
                    ]))
                }

                var attrs: [NSAttributedString.Key: Any] = [
                    .font: baseFont,
                    .foregroundColor: textColor,
                    wordPositionAttribute: word.position,
                ]

                if let highlightedWordPosition, word.position <= highlightedWordPosition {
                    attrs[.foregroundColor] = accentColor
                }

                attributed.append(NSAttributedString(string: word.textArabic, attributes: attrs))
            }
        }

        attributedText = attributed
        textAlignment = .right
        semanticContentAttribute = .forceRightToLeft
        typingAttributes = [
            .font: baseFont,
            .foregroundColor: textColor,
        ]

        DispatchQueue.main.async {
            self.invalidateIntrinsicContentSize()
            self.superview?.invalidateIntrinsicContentSize()
            self.updateCursor(for: cursorWordPosition, color: accentColor)
        }
    }

    func wordPosition(at point: CGPoint) -> Int? {
        let adjustedPoint = CGPoint(
            x: point.x - textContainerInset.left,
            y: point.y - textContainerInset.top
        )

        let directIndex = layoutManager.characterIndex(
            for: adjustedPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        if directIndex < textStorage.length,
           let directHit = textStorage.attribute(wordPositionAttribute, at: directIndex, effectiveRange: nil) as? Int {
            return directHit
        }

        var bestMatch: (position: Int, distance: CGFloat)?

        textStorage.enumerateAttribute(wordPositionAttribute, in: NSRange(location: 0, length: textStorage.length)) { value, range, _ in
            guard let position = value as? Int else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            layoutManager.enumerateEnclosingRects(
                forGlyphRange: glyphRange,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: textContainer
            ) { rect, _ in
                let expanded = rect.insetBy(dx: -8, dy: -6)
                if expanded.contains(adjustedPoint) {
                    bestMatch = (position, 0)
                    return
                }

                let clampedX = min(max(adjustedPoint.x, expanded.minX), expanded.maxX)
                let clampedY = min(max(adjustedPoint.y, expanded.minY), expanded.maxY)
                let dx = adjustedPoint.x - clampedX
                let dy = adjustedPoint.y - clampedY
                let distance = sqrt((dx * dx) + (dy * dy))

                guard bestMatch == nil || distance < bestMatch!.distance else { return }
                bestMatch = (position, distance)
            }
        }

        guard let bestMatch else { return nil }
        return bestMatch.position
    }

    private func updateCursor(for activeWordPosition: Int?, color: UIColor) {
        cursorLayer?.removeFromSuperlayer()
        cursorLayer = nil

        guard let activeWordPosition else { return }
        guard let range = rangeForWordPosition(activeWordPosition) else { return }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textContainerInset.left
        rect.origin.y += textContainerInset.top

        let cursor = CALayer()
        cursor.backgroundColor = color.cgColor
        cursor.cornerRadius = 1
        cursor.frame = CGRect(
            x: max(rect.minX, textContainerInset.left),
            y: rect.minY + 1,
            width: 2,
            height: max(rect.height - 2, 18)
        )

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0.2
        animation.duration = 0.55
        animation.autoreverses = true
        animation.repeatCount = .infinity
        cursor.add(animation, forKey: "blink")

        layer.addSublayer(cursor)
        cursorLayer = cursor
    }

    private func rangeForWordPosition(_ wordPosition: Int) -> NSRange? {
        var found: NSRange?
        textStorage.enumerateAttribute(wordPositionAttribute, in: NSRange(location: 0, length: textStorage.length)) { value, range, stop in
            if let position = value as? Int, position == wordPosition {
                found = range
                stop.pointee = true
            }
        }
        return found
    }
}
#else
private struct InteractiveArabicAyahTextView: View {
    let words: [QuranSurahDetails.Word]
    let fallbackText: String
    let highlightedWordPosition: Int?
    let cursorWordPosition: Int?
    let fontName: String
    let fontSize: CGFloat
    let accentColor: Color
    let fullyHighlighted: Bool
    let onTapWord: (Int) -> Void

    var body: some View {
        Text(fallbackText)
            .font(.custom(fontName, size: fontSize))
            .foregroundStyle(fullyHighlighted ? accentColor : .primary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
    }
}
#endif

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

private enum QuranSurahVerseCounts {
    private static let counts: [Int] = [
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111,
        43, 52, 99, 128, 111, 110, 98, 135, 112, 78, 118, 64,
        77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83,
        182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29,
        18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
        14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28,
        20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25,
        22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19,
        5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3,
        6, 3, 5, 4, 5, 6
    ]

    static func count(for surahNumber: Int) -> Int? {
        guard (1...counts.count).contains(surahNumber) else { return nil }
        return counts[surahNumber - 1]
    }
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

private enum DailyQuranArabicAPI {
    static func fetchArabicText(reference: String) async throws -> String? {
        guard var components = URLComponents(url: quranProxyBaseURL(), resolvingAgainstBaseURL: false) else {
            throw QuranSurahAPIError.invalidURL
        }
        components.path += "/ayah/\(reference)"
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
        let decoded = try JSONDecoder().decode(DailyQuranArabicPayload.self, from: data)
        return decoded.arabicText?
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    OtherView()
        .environmentObject(Settings.shared)
}

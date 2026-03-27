import SwiftUI

struct LibraryDailyQuranQuote: Codable {
    let dayKey: String
    let reference: String
    let text: String
    let surahName: String
}

struct FullSurahSelection: Identifiable {
    let surahNumber: Int
    let ayahNumber: Int?
    var id: String { "\(surahNumber):\(ayahNumber ?? 0)" }
}

enum FullQuranResumeStorage {
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
    @State private var dailyQuranQuote: LibraryDailyQuranQuote?
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
            let cached = try? JSONDecoder().decode(LibraryDailyQuranQuote.self, from: data)
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
                Section {
                    LibraryIntroHeader()
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowSeparator(.hidden)

                    if let quote = dailyQuranQuote {
                        DailyQuranHeroCard(
                            quote: quote,
                            arabicText: dailyQuranArabicText,
                            accentColor: settings.accentColor.color,
                            arabicFontName: preferredQuranArabicFontName(settings: settings, size: 29),
                            onOpenVerse: openDailyQuranModal,
                            onOpenSurah: openDailyQuranFullSurah
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 10, trailing: 0))
                        .listRowSeparator(.hidden)
                    } else {
                        Text(isMalayAppLanguage()
                             ? "Buka widget Al-Quran Harian sekali untuk memuatkan ayat hari ini di sini."
                             : "Open the Daily Quran widget once to load today’s verse here.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 10, trailing: 0))
                            .listRowSeparator(.hidden)
                    }

                    if let resumeSelection {
                        QuranResumeCard(
                            surahTitle: surahTitle(for: resumeSelection.surahNumber),
                            surahNumber: resumeSelection.surahNumber,
                            ayahNumber: resumeSelection.ayahNumber,
                            totalAyahCount: QuranSurahVerseCounts.count(for: resumeSelection.surahNumber),
                            accentColor: settings.accentColor.color,
                            onResume: {
                                selectedFullSurah = resumeSelection
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                }

                Section(header: Text(isMalayAppLanguage() ? "SENARAI SURAH" : "SURAH LIST")) {
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
                                totalAyahCount: QuranSurahVerseCounts.count(for: surah.number),
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

#Preview {
    OtherView()
        .environmentObject(Settings.shared)
}

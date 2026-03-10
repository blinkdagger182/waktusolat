import SwiftUI
import WidgetKit
import StoreKit
import AVFoundation

extension Notification.Name {
    static let debugShowDailyQuranWidgetIntro = Notification.Name("debugShowDailyQuranWidgetIntro")
}

@main
struct AlAdhanApp: App {
    @StateObject private var settings = Settings.shared
    @StateObject private var namesData = NamesViewModel.shared
    @StateObject private var revenueCat = RevenueCatManager.shared
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("firstLaunchSheet") var firstLaunchSheet: Bool = true
    @AppStorage("didShowDailyQuranWidgetIntroV1") private var didShowDailyQuranWidgetIntro = false
    @State var showAdhanSheet: Bool = false
    @State private var showDailyQuranWidgetIntro = false
    
    @State private var isLaunching = true
    @State private var quranDeepLink: QuranDeepLinkPayload?

    init() {
        RevenueCatManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isLaunching {
                    LaunchScreen(isLaunching: $isLaunching)
                } else if settings.firstLaunch {
                    SplashScreen()
                } else {
                    TabView {
                        AdhanView()
                            .tabItem {
                                Image(systemName: "safari")
                                Text("Azan")
                            }

                        SettingsView()
                            .tabItem {
                                Image(systemName: "gearshape")
                                Text("Settings")
                            }
                    }
                    .onAppear {
                        if firstLaunchSheet {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation {
                                    showAdhanSheet = true
                                }
                            }
                        } else {
                            presentDailyQuranWidgetIntroIfNeeded()
                        }
                    }
                    .sheet(
                        isPresented: $showAdhanSheet,
                        onDismiss: {
                            firstLaunchSheet = false
                            presentDailyQuranWidgetIntroIfNeeded()
                        }) {
                        AdhanSetupSheet()
                            .environmentObject(settings)
                            .accentColor(settings.accentColor.color)
                            .tint(settings.accentColor.color)
                            .preferredColorScheme(settings.colorScheme)
                            .transition(.opacity)
                    }
                }
            }
            //.statusBarHidden(true)
            .environmentObject(settings)
            .environmentObject(namesData)
            .environmentObject(revenueCat)
            .accentColor(settings.accentColor.color)
            .tint(settings.accentColor.color)
            .preferredColorScheme(settings.colorScheme)
            .transition(.opacity)
            .animation(.easeInOut, value: isLaunching)
            .animation(.easeInOut, value: settings.firstLaunch)
            .appReviewPrompt()
            .appVersionGate()
            .onOpenURL { url in
                guard let payload = QuranDeepLinkParser.parse(url: url) else { return }
                quranDeepLink = payload
            }
            .sheet(item: $quranDeepLink) { payload in
                QuranVerseDetailsModal(reference: payload.reference)
                    .environmentObject(settings)
                    .preferredColorScheme(settings.colorScheme)
            }
            .overlay {
                if showDailyQuranWidgetIntro {
                    DailyQuranWidgetIntroModal(
                        onDismiss: {
                            showDailyQuranWidgetIntro = false
                            didShowDailyQuranWidgetIntro = true
                        }
                    )
                    .environmentObject(settings)
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .onAppear {
                withAnimation {
                    settings.fetchPrayerTimes()
                }
                if !settings.firstLaunch {
                    settings.requestLocationAuthorization()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .debugShowDailyQuranWidgetIntro)) { _ in
                showDailyQuranWidgetIntro = true
            }
        }
        .onChange(of: settings.accentColor) { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: settings.prayerCalculation) { _ in
            settings.fetchPrayerTimes(force: true)
        }
        .onChange(of: settings.hanafiMadhab) { _ in
            settings.fetchPrayerTimes(force: true)
        }
        .onChange(of: settings.travelingMode) { _ in
            settings.fetchPrayerTimes(force: true)
        }
        .onChange(of: settings.hijriOffset) { _ in
            settings.updateDates()
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: settings.firstLaunch) { isFirstLaunch in
            if !isFirstLaunch {
                settings.requestLocationAuthorization()
                presentDailyQuranWidgetIntroIfNeeded()
            }
        }
    }

    private func presentDailyQuranWidgetIntroIfNeeded() {
        guard !didShowDailyQuranWidgetIntro else { return }
        guard !settings.firstLaunch else { return }
        guard !showAdhanSheet else { return }
        guard !showDailyQuranWidgetIntro else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard !didShowDailyQuranWidgetIntro else { return }
            showDailyQuranWidgetIntro = true
        }
    }
}

private struct QuranDeepLinkPayload: Identifiable {
    let reference: String
    var id: String { reference }
}

private struct DailyQuranWidgetIntroModal: View {
    let onDismiss: () -> Void

    @State private var selectedIndex = 0
    @State private var config = MarketingModalConfig.defaultValue

    var body: some View {
        ZStack {
            Color.black.opacity(0.46)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 64, height: 64)

                        Image("CurrentAppIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(.top, -8)

                    Text("NEW WIDGET AVAILABLE")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .tracking(1.0)

                    Text(config.title)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)

                    TabView(selection: $selectedIndex) {
                        ForEach(Array(config.slides.enumerated()), id: \.offset) { index, slide in
                            DailyQuranIntroSlideCard(slide: slide)
                                .tag(index)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .tabViewStyle(.page(indexDisplayMode: .always))

                    Text(config.subtitle)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.82))
                        .padding(.horizontal, 8)

                    Button(action: onDismiss) {
                        Text(config.ctaText)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color("lightPink"), Color("hotPink")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(white: 0.10).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .onTapGesture {
                    // Swallow taps inside modal content; dismiss only via background or CTA.
                }
            }
        }
        .task {
            await loadRemoteConfig()
        }
    }

    private func loadRemoteConfig() async {
        let url = MarketingModalConfigURLResolver.resolve()
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(MarketingModalConfig.self, from: data)
            guard !decoded.slides.isEmpty else { return }
            config = decoded
        } catch {
            // Keep local default config when remote source is unavailable.
        }
    }
}

private enum MarketingModalConfigURLResolver {
    private static let defaultURL = "https://blinkdagger182.github.io/waktusolat/marketing-modal.json"

    static func resolve() -> URL {
        if let fromInfo = Bundle.main.object(forInfoDictionaryKey: "MarketingModalConfigURL") as? String,
           let url = URL(string: fromInfo),
           !fromInfo.isEmpty {
            return url
        }
        return URL(string: defaultURL)!
    }
}

private struct MarketingModalConfig: Codable {
    let title: String
    let subtitle: String
    let ctaText: String
    let slides: [DailyQuranIntroSlide]

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case ctaText = "cta_text"
        case slides
    }

    static let defaultValue = MarketingModalConfig(
        title: "Daily Quran Inspiration",
        subtitle: "Add it from Lock Screen > Customize > Widgets > Waktu",
        ctaText: "Got it",
        slides: [
            DailyQuranIntroSlide(
                title: "Daily Quran Widget",
                subtitle: "One inspiring ayah every day.",
                imageAsset: nil,
                imageURL: "https://blinkdagger182.github.io/waktusolat/images/IMG_9653.jpg?v=2"
            ),
            DailyQuranIntroSlide(
                title: "Tap For Full Verse",
                subtitle: "Open Waktu to see full details and translation.",
                imageAsset: nil,
                imageURL: "https://blinkdagger182.github.io/waktusolat/images/IMG_9655.jpg?v=2"
            )
        ]
    )
}

private struct DailyQuranIntroSlide: Codable {
    let title: String
    let subtitle: String
    let imageAsset: String?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case imageAsset = "image_asset"
        case imageURL = "image_url"
    }
}

private struct DailyQuranIntroSlideCard: View {
    let slide: DailyQuranIntroSlide

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let remoteURL = slide.imageURL, let url = URL(string: remoteURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .clipped()
                    default:
                        fallbackGradient
                    }
                }
            } else if let bundledImage = loadBundledImage(named: slide.imageAsset) {
                Image(uiImage: bundledImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .clipped()
            } else {
                fallbackGradient
            }

            LinearGradient(
                colors: [Color.black.opacity(0.02), Color.black.opacity(0.44)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(slide.title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                Text(slide.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(2)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [
                Color("lightPink").opacity(0.75),
                Color("hotPink").opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func loadBundledImage(named: String?) -> UIImage? {
        guard let named, !named.isEmpty else { return nil }

        if let image = UIImage(named: named) {
            return image
        }

        let nsName = named as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension
        if !base.isEmpty, !ext.isEmpty,
           let url = Bundle.main.url(forResource: base, withExtension: ext),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        let exts = ["png", "jpg", "jpeg", "webp", "heic"]
        for ext in exts {
            if let url = Bundle.main.url(forResource: named, withExtension: ext),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }
}

private enum QuranDeepLinkParser {
    static func parse(url: URL) -> QuranDeepLinkPayload? {
        guard
            url.scheme?.lowercased() == "waktu",
            url.host?.lowercased() == "quran",
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        components.queryItems = components.queryItems ?? []
        guard
            let reference = components.queryItems?.first(where: { $0.name == "reference" })?.value,
            isSingleAyah(reference)
        else {
            return nil
        }

        return QuranDeepLinkPayload(reference: reference)
    }

    private static func isSingleAyah(_ reference: String) -> Bool {
        let comps = reference.split(separator: ":")
        guard comps.count == 2 else { return false }
        guard !comps[0].contains("-"), !comps[1].contains("-") else { return false }
        guard let surah = Int(comps[0]), let ayah = Int(comps[1]) else { return false }
        return (1...114).contains(surah) && ayah > 0
    }
}

private struct QuranVerseDetailsModal: View {
    let reference: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settings: Settings

    @State private var isLoading = true
    @State private var details: QuranVerseDetails?
    @State private var errorMessage: String?
    @State private var player: AVPlayer?
    @State private var currentAudioURL: String?
    @State private var playbackEndObserver: NSObjectProtocol?
    @State private var isAudioLoading = false
    @State private var isPlaying = false
    @State private var audioErrorMessage: String?
    @State private var didFinishPlayback = false

    var body: some View {
        NavigationView {
            ZStack {
                themeBackgroundGradient
                .ignoresSafeArea()

                Group {
                    if isLoading {
                        ProgressView("Loading verse...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else if let details {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 14) {
                                verseHeader(details)
                                verseCard(details)
                                metadataGrid(details)
                                footerSource
                            }
                            .padding(16)
                            .frame(maxWidth: 620)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } else {
                        VStack(spacing: 10) {
                            Text("Unable to load verse details.")
                                .font(.headline)
                            Text(errorMessage ?? "Please try again.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding()
                    }
                }
            }
            .navigationTitle("Daily Quran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: reference) {
            await loadVerseDetails()
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private func verseHeader(_ details: QuranVerseDetails) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(details.surahNameEnglish)
                .font(.title2.weight(.bold))
                .foregroundStyle(colorScheme == .dark ? .white : .black)

            Text("\(details.surahNameArabic) • \(details.reference)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.64))
        }
    }

    private func verseCard(_ details: QuranVerseDetails) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let arabic = details.arabicText, !arabic.isEmpty {
                Text(arabic)
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.9))
            }

            Text("“\(details.englishText)”")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .lineSpacing(3)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            if let audioURL = details.audioURL, !audioURL.isEmpty {
                HStack(spacing: 10) {
                    Button(action: { togglePlayback(audioURL: audioURL) }) {
                        HStack(spacing: 8) {
                            Image(systemName: isAudioLoading ? "hourglass" : (isPlaying ? "pause.fill" : "play.fill"))
                            Text(isAudioLoading ? "Loading audio..." : (isPlaying ? "Pause Recitation" : "Play Recitation"))
                                .fontWeight(.semibold)
                        }
                        .font(.footnote)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isAudioLoading)

                    if let audioErrorMessage {
                        Text(audioErrorMessage)
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.9))
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metadataGrid(_ details: QuranVerseDetails) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            metaTile("Reference", details.reference)
            metaTile("Surah", details.surahNameEnglish)
            metaTile("Juz", details.juz.map(String.init) ?? "-")
            metaTile("Page", details.page.map(String.init) ?? "-")
            metaTile("Hizb Quarter", details.hizbQuarter.map(String.init) ?? "-")
            metaTile("Revelation", details.revelationType ?? "-")
        }
    }

    private func metaTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.60) : Color.black.opacity(0.55))
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.94) : Color.black.opacity(0.82))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var cardBackground: some ShapeStyle {
        colorScheme == .dark
            ? LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [Color.white.opacity(0.95), Color.white.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08)
    }

    private var themeBackgroundGradient: LinearGradient {
        let accent = settings.accentColor.color
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    accent.opacity(0.30),
                    Color.black.opacity(0.90),
                    accent.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                accent.opacity(0.20),
                Color.white,
                accent.opacity(0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var footerSource: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .overlay(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10))
            Text("Source")
                .font(.caption.weight(.semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.70) : Color.black.opacity(0.60))
            Text("Verse details and recitation are fetched live from AlQuran Cloud.")
                .font(.caption)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.82) : Color.black.opacity(0.72))
            Text("Text edition: en.asad • Audio edition: ar.alafasy")
                .font(.caption2)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.54))
            HStack(spacing: 12) {
                Link("API Docs", destination: URL(string: "https://alquran.cloud/api")!)
                Link("Open Verse Endpoint", destination: URL(string: "https://api.alquran.cloud/v1/ayah/\(reference)/en.asad")!)
            }
            .font(.caption2.weight(.semibold))
        }
        .padding(.top, 4)
    }

    @MainActor
    private func loadVerseDetails() async {
        isLoading = true
        errorMessage = nil
        details = nil

        do {
            details = try await QuranVerseAPI.fetchDetails(reference: reference)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func togglePlayback(audioURL: String) {
        audioErrorMessage = nil

        if currentAudioURL == audioURL, let player {
            if isPlaying {
                player.pause()
                isPlaying = false
            } else {
                let restartAndPlay = {
                    player.play()
                    isPlaying = true
                    didFinishPlayback = false
                }

                if didFinishPlayback {
                    player.seek(to: .zero) { _ in
                        restartAndPlay()
                    }
                } else {
                    restartAndPlay()
                }
            }
            return
        }

        guard let url = URL(string: audioURL) else {
            audioErrorMessage = "Invalid audio URL."
            return
        }

        stopPlayback()
        isAudioLoading = true

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            audioErrorMessage = "Audio session failed."
        }

        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        currentAudioURL = audioURL

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
            didFinishPlayback = true
        }

        newPlayer.play()
        isPlaying = true
        isAudioLoading = false
        didFinishPlayback = false
    }

    private func stopPlayback() {
        player?.pause()
        player = nil
        currentAudioURL = nil
        isPlaying = false
        isAudioLoading = false
        didFinishPlayback = false
        if let observer = playbackEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackEndObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private struct QuranVerseDetails {
    let reference: String
    let englishText: String
    let arabicText: String?
    let surahNameEnglish: String
    let surahNameArabic: String
    let revelationType: String?
    let juz: Int?
    let page: Int?
    let hizbQuarter: Int?
    let audioURL: String?

    var displayReference: String { "\(surahNameEnglish) \(reference)" }
}

private enum QuranVerseAPI {
    static func fetchDetails(reference: String) async throws -> QuranVerseDetails {
        async let english = fetchEdition(reference: reference, edition: "en.asad")
        async let arabic = fetchEdition(reference: reference, edition: "ar.alafasy")

        let en = try await english
        let ar = try? await arabic

        let englishText = normalize(en.data.text)
        let arabicText = ar.map { normalize($0.data.text) }
        return QuranVerseDetails(
            reference: reference,
            englishText: englishText,
            arabicText: arabicText,
            surahNameEnglish: en.data.surah.englishName,
            surahNameArabic: en.data.surah.name,
            revelationType: en.data.surah.revelationType,
            juz: en.data.juz,
            page: en.data.page,
            hizbQuarter: en.data.hizbQuarter,
            audioURL: ar?.data.audio ?? ar?.data.audioSecondary?.first
        )
    }

    private static func fetchEdition(reference: String, edition: String) async throws -> QuranEditionResponse {
        guard let url = URL(string: "https://api.alquran.cloud/v1/ayah/\(reference)/\(edition)") else {
            throw QuranVerseAPIError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw QuranVerseAPIError.badResponse
        }
        let decoded = try JSONDecoder().decode(QuranEditionResponse.self, from: data)
        guard decoded.status.uppercased() == "OK" else {
            throw QuranVerseAPIError.badResponse
        }
        return decoded
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum QuranVerseAPIError: LocalizedError {
    case invalidURL
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid verse URL."
        case .badResponse:
            return "Quran API returned an invalid response."
        }
    }
}

private struct QuranEditionResponse: Decodable {
    let status: String
    let data: QuranEditionAyahData
}

private struct QuranEditionAyahData: Decodable {
    let text: String
    let juz: Int?
    let page: Int?
    let hizbQuarter: Int?
    let audio: String?
    let audioSecondary: [String]?
    let surah: QuranEditionSurahData
}

private struct QuranEditionSurahData: Decodable {
    let englishName: String
    let name: String
    let revelationType: String?
}

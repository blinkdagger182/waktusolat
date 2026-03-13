import SwiftUI
import WidgetKit
import StoreKit
import AVFoundation
import UIKit

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
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: "appLaunchCountV1") + 1, forKey: "appLaunchCountV1")
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
        let url = MarketingModalConfigURLResolver.resolveNoCacheURL()
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")

            let session = URLSession(configuration: .ephemeral)
            let (data, _) = try await session.data(for: request)
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

    static func resolveNoCacheURL() -> URL {
        let url = resolve()
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = components.queryItems ?? []
        let stamp = String(Int(Date().timeIntervalSince1970 / 60))
        items.removeAll(where: { $0.name == "_nocache" })
        items.append(URLQueryItem(name: "_nocache", value: stamp))
        components.queryItems = items
        return components.url ?? url
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
                imageURL: "https://blinkdagger182.github.io/waktusolat/images/IMG_9653.jpg?v=4"
            ),
            DailyQuranIntroSlide(
                title: "Tap For Full Verse",
                subtitle: "Open Waktu to see full details and translation.",
                imageAsset: nil,
                imageURL: "https://blinkdagger182.github.io/waktusolat/images/ayat-recitation.png?v=4"
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
        GeometryReader { geo in
            let size = geo.size

            ZStack(alignment: .bottomLeading) {
                imageBackground
                    .frame(width: size.width, height: size.height, alignment: .center)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.02), Color.black.opacity(0.44)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: size.width, height: size.height)

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
            .frame(width: size.width, height: size.height)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    private var imageBackground: some View {
        if let remoteURL = slide.imageURL, let url = cacheBustedImageURL(remoteURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackGradient
                }
            }
        } else if let bundledImage = loadBundledImage(named: slide.imageAsset) {
            Image(uiImage: bundledImage)
                .resizable()
                .scaledToFill()
        } else {
            fallbackGradient
        }
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

    private func cacheBustedImageURL(_ raw: String) -> URL? {
        guard var components = URLComponents(string: raw) else { return URL(string: raw) }
        var items = components.queryItems ?? []
        let stamp = String(Int(Date().timeIntervalSince1970 / 60))
        items.removeAll(where: { $0.name == "_nocache" })
        items.append(URLQueryItem(name: "_nocache", value: stamp))
        components.queryItems = items
        return components.url
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
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showSharePreview = false

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
        for name in candidates where !name.isEmpty {
            if UIFont(name: name, size: 36) != nil {
                return name
            }
        }
        return settings.fontArabic
    }

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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: presentSharePreview) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(details == nil || isLoading)
                }
            }
        }
        .task(id: reference) {
            await loadVerseDetails()
        }
        .onDisappear {
            stopPlayback()
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityShareSheet(activityItems: shareItems)
        }
        .sheet(isPresented: $showSharePreview) {
            if let details {
                QuranSharePreviewSheet(
                    colorScheme: colorScheme,
                    previewImageFor: { variant in
                        renderSharePreview(details: details, variant: variant)
                    },
                    onShare: { variant in
                        shareSelectedVariant(variant, details: details)
                    }
                )
            }
        }
    }

    private func verseHeader(_ details: QuranVerseDetails) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(details.surahNameEnglish)
                .font(.title2.weight(.bold))
                .foregroundStyle(colorScheme == .dark ? .white : .black)

            Text("\(details.surahNameArabic) • \(details.reference)")
                .font(.custom(quranArabicFontName, size: 18))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.64))
        }
    }

    private func verseCard(_ details: QuranVerseDetails) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let arabic = details.arabicText, !arabic.isEmpty {
                Text(arabic)
                    .font(.custom(quranArabicFontName, size: 36))
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(10)
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

    private func presentSharePreview() {
        guard details != nil else { return }
        showSharePreview = true
    }

    @MainActor
    private func shareSelectedVariant(_ variant: QuranShareVariant, details: QuranVerseDetails) {
        let previewImage = renderSharePreview(details: details, variant: variant)
        let caption = shareCaption(details: details, variant: variant)
        shareItems = [previewImage, caption]
        showSharePreview = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showShareSheet = true
        }
    }

    @MainActor
    private func renderSharePreview(details: QuranVerseDetails, variant: QuranShareVariant) -> UIImage {
        let card: AnyView
        switch variant {
        case .fullVerse:
            card = AnyView(
                DailyQuranSharePreviewCard(
                    details: details,
                    colorScheme: colorScheme,
                    accent: settings.accentColor.color,
                    quranArabicFontName: quranArabicFontName
                )
            )
        case .englishTranslation:
            card = AnyView(
                DailyQuranEnglishTranslationSharePreviewCard(
                    details: details,
                    colorScheme: colorScheme,
                    accent: settings.accentColor.color
                )
            )
        case .summary:
            card = AnyView(
                DailyQuranSummarySharePreviewCard(
                    details: details,
                    colorScheme: colorScheme,
                    accent: settings.accentColor.color,
                    summaryText: lockScreenStyleSummary(details.englishText)
                )
            )
        }

        let size: CGSize = {
            switch variant {
            case .summary:
                return CGSize(width: 900, height: 1100)
            case .fullVerse, .englishTranslation:
                return CGSize(width: 1080, height: 1350)
            }
        }()

        let controller = UIHostingController(
            rootView: card
                .frame(width: size.width, height: size.height)
                .clipped()
        )
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    private func summarizedVerse(_ text: String, maxLen: Int) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > maxLen else { return cleaned }
        return String(cleaned.prefix(maxLen)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private func lockScreenStyleSummary(_ text: String) -> String {
        summarizedVerse(text, maxLen: 90)
    }

    private func shareCaption(details: QuranVerseDetails, variant: QuranShareVariant) -> String {
        let appLink = "https://blinkdagger182.github.io/waktusolat/"
        let referenceLine = "Surah \(details.surahNameEnglish) (\(details.reference))"
        switch variant {
        case .fullVerse:
            return """
Quran reflection from \(referenceLine).
\(details.englishText)

Read more in Waktu: \(appLink)
"""
        case .englishTranslation:
            return """
English translation from \(referenceLine).
\(details.englishText)

Read more in Waktu: \(appLink)
"""
        case .summary:
            return """
Quran reflection from \(referenceLine).
Summary: \(lockScreenStyleSummary(details.englishText))

Read more in Waktu: \(appLink)
"""
        }
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

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum QuranShareVariant: Int, CaseIterable, Identifiable {
    case fullVerse
    case englishTranslation
    case summary

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fullVerse: return "Full Verse"
        case .englishTranslation: return "English Translation"
        case .summary: return "Summary"
        }
    }
}

private struct QuranSharePreviewSheet: View {
    let colorScheme: ColorScheme
    let previewImageFor: (QuranShareVariant) -> UIImage
    let onShare: (QuranShareVariant) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedVariant: QuranShareVariant = .fullVerse
    @State private var previewFull: UIImage?
    @State private var previewEnglish: UIImage?
    @State private var previewSummary: UIImage?

    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                if let previewFull, let previewEnglish, let previewSummary {
                    TabView(selection: $selectedVariant) {
                        previewImageCard(previewFull)
                            .tag(QuranShareVariant.fullVerse)
                        previewImageCard(previewEnglish)
                            .tag(QuranShareVariant.englishTranslation)
                        previewImageCard(previewSummary)
                            .tag(QuranShareVariant.summary)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                } else {
                    ProgressView("Preparing previews...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Button(action: { onShare(selectedVariant) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share \(selectedVariant.title)")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .navigationTitle("Share Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .background(colorScheme == .dark ? Color.black.ignoresSafeArea() : Color.white.ignoresSafeArea())
        }
        .onAppear {
            if previewFull == nil { previewFull = previewImageFor(.fullVerse) }
            if previewEnglish == nil { previewEnglish = previewImageFor(.englishTranslation) }
            if previewSummary == nil { previewSummary = previewImageFor(.summary) }
        }
    }

    @ViewBuilder
    private func previewImageCard(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 14)
            .padding(.top, 6)
    }
}

private struct DailyQuranSharePreviewCard: View {
    let details: QuranVerseDetails
    let colorScheme: ColorScheme
    let accent: Color
    let quranArabicFontName: String

    private var arabicLength: Int { details.arabicText?.count ?? 0 }
    private var englishLength: Int { details.englishText.count }

    private var arabicFontSize: CGFloat {
        switch arabicLength {
        case 0..<90: return 58
        case 90..<150: return 50
        case 150..<220: return 45
        default: return 40
        }
    }

    private var englishFontSize: CGFloat {
        switch englishLength {
        case 0..<120: return 30
        case 120..<220: return 26
        case 220..<320: return 23
        default: return 21
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accent.opacity(colorScheme == .dark ? 0.28 : 0.18),
                    colorScheme == .dark ? Color.black : Color.white,
                    accent.opacity(colorScheme == .dark ? 0.20 : 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Quran")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.92))
                    Text("\(details.surahNameArabic) • \(details.reference)")
                        .font(.custom(quranArabicFontName, size: 30))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.62))
                }

                VStack(alignment: .leading, spacing: 16) {
                    if let arabic = details.arabicText, !arabic.isEmpty {
                        Text(arabic)
                            .font(.custom(quranArabicFontName, size: arabicFontSize))
                            .lineSpacing(11)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.97) : Color.black.opacity(0.93))
                    }

                    Text("“\(details.englishText)”")
                        .font(.system(size: englishFontSize, weight: .semibold, design: .rounded))
                        .lineSpacing(6)
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82))
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08), lineWidth: 2)
                )

                Spacer()

                HStack {
                    Text(details.reference)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("Waktu")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.76) : Color.black.opacity(0.66))
            }
            .padding(42)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DailyQuranEnglishTranslationSharePreviewCard: View {
    let details: QuranVerseDetails
    let colorScheme: ColorScheme
    let accent: Color

    private var englishLength: Int { details.englishText.count }
    private var isDark: Bool { colorScheme == .dark }
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(isDark ? 0.28 : 0.18),
                isDark ? Color.black : Color.white,
                accent.opacity(isDark ? 0.20 : 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    private var titleColor: Color { isDark ? Color.white.opacity(0.96) : Color.black.opacity(0.92) }
    private var subtitleColor: Color { isDark ? Color.white.opacity(0.72) : Color.black.opacity(0.62) }
    private var bodyColor: Color { isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.83) }
    private var footerColor: Color { isDark ? Color.white.opacity(0.76) : Color.black.opacity(0.66) }
    private var cardFill: Color { isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.9) }
    private var cardStroke: Color { isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08) }
    private var englishFontSize: CGFloat {
        switch englishLength {
        case 0..<120: return 32
        case 120..<220: return 28
        case 220..<320: return 24
        default: return 21
        }
    }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("English Translation")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(titleColor)
                    Text("Surah \(details.surahNameEnglish) • \(details.reference)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(subtitleColor)
                }

                Text("“\(details.englishText)”")
                    .font(.system(size: englishFontSize, weight: .semibold, design: .rounded))
                    .lineSpacing(8)
                    .foregroundStyle(bodyColor)
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(cardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(cardStroke, lineWidth: 2)
                    )

                Spacer()

                HStack {
                    Text(details.reference)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("Waktu")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                .foregroundStyle(footerColor)
            }
            .padding(42)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DailyQuranSummarySharePreviewCard: View {
    let details: QuranVerseDetails
    let colorScheme: ColorScheme
    let accent: Color
    let summaryText: String

    private var summaryReferenceLine: String {
        "\(details.surahNameEnglish) \(details.reference),"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accent.opacity(colorScheme == .dark ? 0.28 : 0.18),
                    colorScheme == .dark ? Color.black : Color.white,
                    accent.opacity(colorScheme == .dark ? 0.20 : 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 26) {
                Text("Daily Quran")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.92))

                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    Text(summaryReferenceLine)
                        .font(.system(size: 33, weight: .bold, design: .rounded))
                        .lineSpacing(6)
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.85))
                    Text(summaryText)
                        .font(.system(size: 35, weight: .semibold, design: .rounded))
                        .lineSpacing(9)
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.94) : Color.black.opacity(0.83))
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08), lineWidth: 2)
                )

                Spacer()

                HStack {
                    Text(details.reference)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("Waktu")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.76) : Color.black.opacity(0.66))
            }
            .padding(56)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

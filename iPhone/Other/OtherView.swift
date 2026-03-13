import SwiftUI
#if os(iOS)
import WebKit
#endif

private struct DailyQuranCachedQuote: Codable {
    let dayKey: String
    let reference: String
    let text: String
    let surahName: String
}

struct OtherView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.openURL) private var openURL
    @State private var dailyQuranQuote: DailyQuranCachedQuote?
    @State private var fullSurahURL: URL?
    @State private var showFullSurahWebView = false

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

    private func surahNumber(from reference: String) -> Int? {
        guard let first = reference.split(separator: ":").first,
              let surah = Int(first),
              (1...114).contains(surah) else {
            return nil
        }
        return surah
    }

    private func openFullSurahWebView() {
        guard let reference = dailyQuranQuote?.reference,
              let surah = surahNumber(from: reference),
              let url = URL(string: "https://quran.com/\(surah)") else { return }
        fullSurahURL = url
        showFullSurahWebView = true
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
                                openFullSurahWebView()
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
                .sheet(isPresented: $showFullSurahWebView) {
                    NavigationView {
                        QuranWebContainerView(url: fullSurahURL)
                            .navigationTitle("Full Surah")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showFullSurahWebView = false
                                    }
                                }
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
                
                ProphetQuote()
                
                #if false
                AlIslamAppsSection()
                #endif
            }
            .applyConditionalListStyle(defaultView: settings.defaultView)
            .navigationTitle("Resources")
            .onAppear(perform: loadDailyQuranQuote)
            
            ArabicView()
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

private struct QuranWebContainerView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                QuranWebView(url: url)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Unable to open the full surah link.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #if os(iOS)
                .background(Color(.systemGroupedBackground))
                #endif
            }
        }
    }
}

#if os(iOS)
private struct QuranWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .onDrag
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }
}
#else
private struct QuranWebView: View {
    let url: URL

    var body: some View {
        Text("Web view is only available on iOS.")
            .foregroundStyle(.secondary)
    }
}
#endif

#Preview {
    OtherView()
        .environmentObject(Settings.shared)
}

import SwiftUI
#if os(iOS)
import UIKit
import PhotosUI
import WebKit
import AudioToolbox
#endif
#if DEBUG && canImport(Inject)
import Inject
#endif
#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

#if os(iOS)
private typealias WidgetPreviewImage = UIImage
#else
private struct WidgetPreviewImage {}
#endif

extension View {
    @ViewBuilder
    func hotReloadable() -> some View {
        #if DEBUG && canImport(Inject)
        self.enableInjection()
        #else
        self
        #endif
    }
}

#if canImport(RevenueCat)
@MainActor
final class RevenueCatManager: NSObject, ObservableObject, PurchasesDelegate {
    static let shared = RevenueCatManager()

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published private(set) var hasPremiumWidgetsUnlocked = premiumWidgetsUnlocked()
    @Published var lastErrorMessage: String?

    private let apiKey = "appl_QOZtAKefwKDyLWNlFADoOQkLgcl"
    let entitlementID = "buy_me_kopi"
    private(set) var isConfigured = false
    private let premiumWidgetThreshold = Decimal(string: "9.90") ?? 9.90

    private override init() {
        super.init()
    }

    func configure() {
        guard !isConfigured else { return }
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        isConfigured = true

        Task {
            await refreshCustomerInfo()
            await refreshOfferings()
        }
    }

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor [weak self] in
            self?.customerInfo = customerInfo
            self?.syncSharedPremiumWidgetAccess()
        }
    }

    func refreshCustomerInfo() async {
        do {
            customerInfo = try await Purchases.shared.customerInfo()
            syncSharedPremiumWidgetAccess()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshOfferings() async {
        do {
            offerings = try await Purchases.shared.offerings()
            #if DEBUG
            let ids = offerings?.all.keys.sorted() ?? []
            print("RevenueCat offerings:", ids, "current:", offerings?.current?.identifier ?? "nil")
            #endif
            syncSharedPremiumWidgetAccess()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    var hasBuyMeKopi: Bool {
        customerInfo?.entitlements[entitlementID]?.isActive == true
    }

    func restorePurchases() {
        Purchases.shared.restorePurchases { [weak self] info, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastErrorMessage = error.localizedDescription
                    return
                }
                self.customerInfo = info
                self.syncSharedPremiumWidgetAccess()
            }
        }
    }

    func clearLastError() {
        lastErrorMessage = nil
    }

    private func syncSharedPremiumWidgetAccess() {
        guard let defaults = UserDefaults(suiteName: sharedAppGroupID) else { return }

        let availablePackages = offerings?.all.values.flatMap(\.availablePackages) ?? []
        let eligibleProductIDs = Set(
            availablePackages
                .filter { $0.storeProduct.price >= premiumWidgetThreshold }
                .map { $0.storeProduct.productIdentifier }
        )

        if !eligibleProductIDs.isEmpty {
            defaults.set(Array(eligibleProductIDs).sorted(), forKey: premiumWidgetEligibleProductIDsStorageKey)
        }

        let storedEligibleProductIDs = Set(defaults.stringArray(forKey: premiumWidgetEligibleProductIDsStorageKey) ?? [])
        let purchasedProductIDs = Set(customerInfo?.allPurchasedProductIdentifiers ?? [])
        let unlocked = !storedEligibleProductIDs.isDisjoint(with: purchasedProductIDs)

        defaults.set(unlocked, forKey: premiumWidgetsUnlockedStorageKey)
        hasPremiumWidgetsUnlocked = unlocked
    }
}
#else
@MainActor
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    @Published private(set) var hasPremiumWidgetsUnlocked = premiumWidgetsUnlocked()
    @Published var lastErrorMessage: String?
    let entitlementID = "buy_me_kopi"
    var hasBuyMeKopi: Bool { false }

    func configure() {
        lastErrorMessage = "RevenueCat SDK not available in this build."
    }

    func refreshCustomerInfo() async {}
    func refreshOfferings() async {}
    func restorePurchases() {}
    func clearLastError() { lastErrorMessage = nil }
}
#endif

private struct SupportToastDebugOption: Identifiable, Codable {
    let triggerKey: String
    let message: String

    var id: String { triggerKey }

    var debugLabel: String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? triggerKey : trimmed
    }

    enum CodingKeys: String, CodingKey {
        case triggerKey = "trigger_key"
        case message
    }

    static let defaultOptions: [SupportToastDebugOption] = [
        SupportToastDebugOption(triggerKey: "generic_debug", message: "Enjoying Waktu? Support it."),
        SupportToastDebugOption(triggerKey: "launch_5", message: "Love Waktu? Help keep it running."),
        SupportToastDebugOption(triggerKey: "launch_6", message: "Use Waktu daily? Support this month's costs."),
        SupportToastDebugOption(triggerKey: "streak_7", message: "7 days in a row. Help keep Waktu going."),
        SupportToastDebugOption(triggerKey: "eid_pool", message: "Eid pool is live. Keep Waktu running."),
        SupportToastDebugOption(triggerKey: "monthly_pool", message: "This month's pool is open. Keep Waktu accurate."),
    ]
}

private enum SupportToastDebugLoader {
    private static let cacheKey = "supportToastDebugOptionsCachedPayloadV1"
    private static let cacheTimeKey = "supportToastDebugOptionsLastFetchTimeV1"
    private static let defaults = UserDefaults.standard
    #if DEBUG
    private static let cacheTTL: TimeInterval = 0
    #else
    private static let cacheTTL: TimeInterval = 60 * 30
    #endif

    static func load() async -> [SupportToastDebugOption] {
        if let cached = cachedIfFresh() {
            return cached
        }

        do {
            let url = resolveNoCacheURL()
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")

            let session = URLSession(configuration: .ephemeral)
            let (data, _) = try await session.data(for: request)
            guard let payload = String(data: data, encoding: .utf8) else {
                return SupportToastDebugOption.defaultOptions
            }

            defaults.set(payload, forKey: cacheKey)
            defaults.set(Date().timeIntervalSince1970, forKey: cacheTimeKey)

            let decoded = try JSONDecoder().decode([SupportToastDebugOption].self, from: data)
            return decoded.isEmpty ? SupportToastDebugOption.defaultOptions : decoded
        } catch {
            return cachedIfFresh() ?? decode(from: defaults.string(forKey: cacheKey) ?? "") ?? SupportToastDebugOption.defaultOptions
        }
    }

    private static func cachedIfFresh() -> [SupportToastDebugOption]? {
        let age = Date().timeIntervalSince1970 - defaults.double(forKey: cacheTimeKey)
        guard age < cacheTTL else { return nil }
        return decode(from: defaults.string(forKey: cacheKey) ?? "")
    }

    private static func decode(from payload: String) -> [SupportToastDebugOption]? {
        guard let data = payload.data(using: .utf8), !payload.isEmpty else { return nil }
        return try? JSONDecoder().decode([SupportToastDebugOption].self, from: data)
    }

    private static func resolveURL() -> URL {
        if let fromInfo = Bundle.main.object(forInfoDictionaryKey: "SupportPromoScheduleURL") as? String,
           let url = URL(string: fromInfo),
           !fromInfo.isEmpty {
            return url
        }

        return URL(string: "https://api-waktusolat.vercel.app/api/support/toasts/schedule")!
    }

    private static func resolveNoCacheURL() -> URL {
        let url = resolveURL()
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = components.queryItems ?? []
        let stamp = String(Int(Date().timeIntervalSince1970 / 60))
        items.removeAll(where: { $0.name == "_nocache" })
        items.append(URLQueryItem(name: "_nocache", value: stamp))
        components.queryItems = items
        return components.url ?? url
    }
}

private struct WidgetSettingsRemoteConfig: Decodable {
    let showWidgetSettingsMenu: Bool
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case showWidgetSettingsMenu = "showWidgetSettingsMenu"
        case updatedAt = "updatedAt"
    }
}

private enum WidgetSettingsRemoteConfigLoader {
    private static let cacheKey = "widgetSettingsRemoteConfigCachedPayloadV1"
    private static let cacheTimeKey = "widgetSettingsRemoteConfigLastFetchTimeV1"
    private static let defaults = UserDefaults.standard
    #if DEBUG
    private static let cacheTTL: TimeInterval = 0
    #else
    private static let cacheTTL: TimeInterval = 60 * 30
    #endif

    static func load(force: Bool) async -> WidgetSettingsRemoteConfig {
        if !force, let cached = cachedIfFresh() {
            return cached
        }

        do {
            let url = resolveNoCacheURL()
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")

            let session = URLSession(configuration: .ephemeral)
            let (data, _) = try await session.data(for: request)
            let decoded = try JSONDecoder().decode(WidgetSettingsRemoteConfig.self, from: data)

            if let payload = String(data: data, encoding: .utf8) {
                defaults.set(payload, forKey: cacheKey)
                defaults.set(Date().timeIntervalSince1970, forKey: cacheTimeKey)
            }

            return decoded
        } catch {
            return cachedIfFresh() ?? decode(from: defaults.string(forKey: cacheKey) ?? "") ?? WidgetSettingsRemoteConfig(showWidgetSettingsMenu: false, updatedAt: nil)
        }
    }

    private static func cachedIfFresh() -> WidgetSettingsRemoteConfig? {
        let age = Date().timeIntervalSince1970 - defaults.double(forKey: cacheTimeKey)
        guard age < cacheTTL else { return nil }
        return decode(from: defaults.string(forKey: cacheKey) ?? "")
    }

    private static func decode(from payload: String) -> WidgetSettingsRemoteConfig? {
        guard let data = payload.data(using: .utf8), !payload.isEmpty else { return nil }
        return try? JSONDecoder().decode(WidgetSettingsRemoteConfig.self, from: data)
    }

    private static func resolveURL() -> URL {
        if let fromInfo = Bundle.main.object(forInfoDictionaryKey: "WidgetSettingsConfigURL") as? String,
           let url = URL(string: fromInfo),
           !fromInfo.isEmpty {
            return url
        }

        return URL(string: "https://api-waktusolat.vercel.app/api/settings/widgets")!
    }

    private static func resolveNoCacheURL() -> URL {
        let url = resolveURL()
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = components.queryItems ?? []
        items.removeAll(where: { $0.name == "_nocache" })
        items.append(URLQueryItem(name: "_nocache", value: String(Int(Date().timeIntervalSince1970 / 60))))
        components.queryItems = items
        return components.url ?? url
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var revenueCat: RevenueCatManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("donationSuccessCount") private var donationSuccessCount: Int = 0
    @AppStorage("appLaunchCountV1") private var appLaunchCount: Int = 0
    @AppStorage(AppLanguage.storageKey) private var appLanguageCode = AppLanguage.system.rawValue
    @AppStorage("remoteWidgetSettingsMenuEnabled") private var remoteWidgetSettingsMenuEnabled = false
    
    @State private var showingCredits = false
    @State private var showingAdhanSetup = false
    @State private var showingPaywall = false
    @State private var showingSupportToastDebugPicker = false
    @State private var supportToastDebugOptions = SupportToastDebugOption.defaultOptions
    @State private var showDonationCelebration = false
    @State private var hasInitializedEntitlementState = false
    @State private var lastKnownDonationState = false
    private let paywallOfferingIdentifier = "Waktu Donation"

    private func postUIHeartbeat() {
        NotificationCenter.default.post(name: .uiContentHeartbeat, object: nil)
    }

    var body: some View {
        ZStack {
            NavigationView {
                List {
                    Section(header: Text("PRAYER")) {
                        Button {
                            settings.hapticFeedback()
                            showingAdhanSetup = true
                        } label: {
                            Label("Waktu Solat Setup", systemImage: "moon.stars.fill")
                                .foregroundColor(settings.accentColor.color)
                        }

                        NavigationLink {
                            SettingsAdhanView(showNotifications: true)
                                .environmentObject(settings)
                        } label: {
                            Label("Waktu Solat Settings", systemImage: "bell.and.waves.left.and.right")
                                .foregroundColor(settings.accentColor.color)
                        }

                        if remoteWidgetSettingsMenuEnabled {
                            NavigationLink {
                                WidgetPreviewGalleryView()
                                    .environmentObject(settings)
                            } label: {
                                Label("Widgets", systemImage: "square.grid.2x2")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        }
                    }

                    /*
                    Section(header: Text("PROFILE")) {
                        NavigationLink {
                            SettingsProfileView()
                        } label: {
                            Label("Profile", systemImage: "person.crop.circle")
                                .foregroundColor(settings.accentColor.color)
                        }
                    }
                    */

                    Section(header: Text("APPEARANCE")) {
                        SettingsAppearanceView()
                    }

                    Section(header: Text("CREDITS")) {
                        Text("Made by developers at Risk Creatives, powered by the Waktu Solat Project API.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        #if !os(watchOS)
                        Button(action: {
                            settings.hapticFeedback()
                            
                            showingCredits = true
                        }) {
                            Label("View Credits", systemImage: "scroll.fill")
                                .font(.subheadline)
                                .foregroundColor(settings.accentColor.color)
                        }
                        .sheet(isPresented: $showingCredits) {
                            CreditsView()
                        }
                        #endif
                        
                        VersionNumber()
                            .font(.subheadline)
                    }

                    Section(header: Text("SUPPORT")) {
                        Button {
                            openDonationPaywall()
                        } label: {
                            Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
                                .foregroundColor(settings.accentColor.color)
                        }

                        if donationSuccessCount > 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(donationImpactMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Spacer()
                                    Button(donationImpactCTA) {
                                        openDonationPaywall()
                                    }
                                    .font(.caption2.weight(.semibold))
                                    Spacer()
                                }
                            }
                        }
                    }

                    #if DEBUG
                    Section(header: Text("Debug: WIDGETS")) {
                        NavigationLink {
                            WidgetPreviewDebugView()
                        } label: {
                            Label("Aura Backgrounds (6 Waktu)", systemImage: "rectangle.grid.1x2")
                                .foregroundColor(settings.accentColor.color)
                        }

                        Button {
                            showingSupportToastDebugPicker = true
                        } label: {
                            Label("Trigger Support Toast", systemImage: "heart.fill")
                                .foregroundColor(settings.accentColor.color)
                        }
                    }
                    #endif
                }
                .navigationTitle("Settings")
                .applyConditionalListStyle(defaultView: true)
            }
            .navigationViewStyle(.stack)

            if showDonationCelebration {
                DonationCelebrationOverlay()
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
                    .zIndex(1)
            }
        }
        .task {
            revenueCat.configure()
            await revenueCat.refreshCustomerInfo()
            await revenueCat.refreshOfferings()
            await loadSupportToastDebugOptions()
            await refreshRemoteWidgetSettingsMenu(force: false)
            lastKnownDonationState = revenueCat.hasBuyMeKopi
            hasInitializedEntitlementState = true
        }
        .onChange(of: revenueCat.hasBuyMeKopi) { newValue in
            // Keep entitlement state in sync, but do not trigger celebration here.
            // Celebration is intentionally limited to fresh purchases only.
            lastKnownDonationState = newValue
        }
        .sheet(isPresented: $showingPaywall, onDismiss: {
            NotificationCenter.default.post(name: .supportDonationPaywallDismissed, object: nil)
        }) {
            paywallSheet
        }
        .sheet(isPresented: $showingAdhanSetup) {
            AdhanSetupSheet()
                .id(settings.colorScheme == nil ? "system" : String(describing: settings.colorScheme!))
                .environmentObject(settings)
                .accentColor(settings.accentColor.color)
                .tint(settings.accentColor.color)
                .preferredColorScheme(settings.colorScheme)
        }
        .alert("Purchase Error", isPresented: Binding(
            get: { revenueCat.lastErrorMessage != nil },
            set: { if !$0 { revenueCat.clearLastError() } }
        )) {
            Button("OK", role: .cancel) {
                revenueCat.clearLastError()
            }
        } message: {
            Text(revenueCat.lastErrorMessage ?? "Unknown error")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSupportDonationPaywall)) { _ in
            openDonationPaywall()
        }
        .onAppear {
            postUIHeartbeat()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                postUIHeartbeat()
                Task {
                    await loadSupportToastDebugOptions()
                    await refreshRemoteWidgetSettingsMenu(force: false)
                }
            }
        }
        .confirmationDialog(
            "Trigger Support Toast",
            isPresented: $showingSupportToastDebugPicker,
            titleVisibility: .visible
        ) {
            ForEach(supportToastDebugOptions) { option in
                Button(option.debugLabel) {
                    NotificationCenter.default.post(name: .debugShowSupportPromoToastVariant, object: option.triggerKey)
                }
            }
            Button("Malaysia Location Toast") {
                NotificationCenter.default.post(name: .debugShowMalaysiaLocationToast, object: nil)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func handleDonationCompleted(countDonation: Bool) {
        if countDonation {
            donationSuccessCount += 1
        }
        showingPaywall = false
        playDonationSuccessEffects()

        // Delay a little so celebration is visible after paywall dismissal in TestFlight/App Store builds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                showDonationCelebration = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showDonationCelebration = false
            }
        }
    }

    private func playDonationSuccessEffects() {
        #if os(iOS)
        let haptic = UINotificationFeedbackGenerator()
        haptic.prepare()
        haptic.notificationOccurred(.success)
        settings.hapticFeedback()
        AudioServicesPlaySystemSound(1025)
        #endif
    }

    private func openDonationPaywall() {
        settings.hapticFeedback()
        Task {
            await revenueCat.refreshOfferings()
            if revenueCat.offerings?.all[paywallOfferingIdentifier] != nil {
                showingPaywall = true
            } else {
                let available = revenueCat.offerings?.all.keys.sorted().joined(separator: ", ") ?? "none"
                revenueCat.lastErrorMessage = "Offering '\(paywallOfferingIdentifier)' not found. Available offerings: \(available)"
            }
        }
    }

    private func loadSupportToastDebugOptions() async {
        supportToastDebugOptions = await SupportToastDebugLoader.load()
    }

    private func refreshRemoteWidgetSettingsMenu(force: Bool) async {
        let config = await WidgetSettingsRemoteConfigLoader.load(force: force)
        remoteWidgetSettingsMenuEnabled = config.showWidgetSettingsMenu
    }
    
    private var donationImpactMessage: String {
        let count = max(donationSuccessCount, 0)
        let style = max(appLaunchCount, 0) % 6

        switch style {
        case 0:
            return "You helped run the server for \(count) extra \(count == 1 ? "day" : "days")."
        case 1:
            let hours = count * 2
            return "You bought enough coffee to keep the developer awake for \(hours) \(hours == 1 ? "hour" : "hours")."
        case 2:
            let qaHours = Double(count) * 0.75
            return String(format: "Your support funded %.2f extra hours of prayer-time accuracy checks.", qaHours)
        case 3:
            let widgets = Double(count) * 0.125
            return String(format: "You helped add %.3f widget to the app ecosystem.", widgets)
        case 4:
            let sessions = count * 5
            return "You gave the team around \(sessions) extra focus sessions to improve the app."
        default:
            let fixes = count * 4
            return "You helped fund about \(fixes) extra fixes and quality improvements."
        }
    }

    private var donationImpactCTA: String {
        switch max(appLaunchCount, 0) % 6 {
        case 0:
            return "Add more server hours"
        case 1:
            return "Add more awake hours"
        case 2:
            return "Support accuracy checks"
        case 3:
            return "Help add more widgets"
        case 4:
            return "Support app improvements"
        default:
            return "Support more fixes"
        }
    }

    @ViewBuilder
    private var paywallSheet: some View {
        #if canImport(RevenueCatUI)
        if let selectedOffering = revenueCat.offerings?.all[paywallOfferingIdentifier] {
            PaywallView(offering: selectedOffering, displayCloseButton: true)
                .onPurchaseCompleted { _ in
                    DispatchQueue.main.async {
                        handleDonationCompleted(countDonation: true)
                    }
                }
                .onRestoreCompleted { _ in
                    DispatchQueue.main.async {
                        // Restore should not trigger celebration or increment counter.
                        showingPaywall = false
                    }
                }
        } else {
            NavigationView {
                Text("Offering '\(paywallOfferingIdentifier)' was not returned by RevenueCat.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .navigationTitle("Support")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        #else
        NavigationView {
            Text("RevenueCatUI not installed.")
                .foregroundColor(.secondary)
                .navigationTitle("Support")
                .navigationBarTitleDisplayMode(.inline)
        }
        #endif
    }
}

private struct DonationCelebrationOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.22),
                    Color.yellow.opacity(0.2),
                    Color.green.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if !reduceMotion {
                ConfettiBurstView()
                    .ignoresSafeArea()
            }

            VStack(spacing: 12) {
                Image(systemName: "hands.sparkles.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.yellow, .orange)
                    .scaleEffect(pulse ? 1.08 : 0.92)

                Text("Donation Successful")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Text("JazakAllah Khair. Your support keeps this app alive.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 28)
            }
            .padding(.vertical, 28)
            .frame(maxWidth: 360)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .orange.opacity(0.25), radius: 24, x: 0, y: 12)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct ConfettiBurstView: View {
    @State private var animate = false
    private let pieces = Array(0..<36)
    private let colors: [Color] = [.yellow, .orange, .green, .blue, .pink, .mint]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors[index % colors.count])
                        .frame(width: 6, height: 12)
                        .rotationEffect(.degrees(animate ? Double.random(in: 240...720) : 0))
                        .position(
                            x: animate ? CGFloat.random(in: 0...geometry.size.width) : geometry.size.width / 2,
                            y: animate ? geometry.size.height + 40 : -20
                        )
                        .opacity(animate ? 0.95 : 0)
                        .animation(
                            .easeOut(duration: Double.random(in: 1.2...2.0))
                            .delay(Double(index) * 0.015),
                            value: animate
                        )
                }
            }
        }
        .onAppear { animate = true }
    }
}

private struct SettingsProfileView: View {
    @EnvironmentObject var settings: Settings
    private let cannyRequestURL = URL(string: "https://risk-creatives-enterprise.canny.io/feature-requests")

    var body: some View {
        List {
            Section(header: Text("PROFILE")) {
                NavigationLink {
                    SettingsWebContainerView(
                        title: "Request a Feature",
                        url: cannyRequestURL
                    )
                } label: {
                    Label("Request a feature", systemImage: "lightbulb")
                        .foregroundColor(settings.accentColor.color)
                }

                NavigationLink {
                    SettingsComingSoonView(
                        title: "Roadmap",
                        message: "Roadmap is coming soon."
                    )
                } label: {
                    Label("Roadmap", systemImage: "map")
                        .foregroundColor(settings.accentColor.color)
                }

                NavigationLink {
                    SettingsComingSoonView(
                        title: "What's New",
                        message: "What's new updates are coming soon."
                    )
                } label: {
                    Label("What's new", systemImage: "sparkles")
                        .foregroundColor(settings.accentColor.color)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .applyConditionalListStyle(defaultView: true)
    }
}

private struct SettingsComingSoonView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsWebContainerView: View {
    let title: String
    let url: URL?

    var body: some View {
        Group {
            if let url {
                CannyWebView(url: url)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Request form URL is not configured yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if os(iOS)
private struct CannyWebView: UIViewRepresentable {
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
private struct CannyWebView: View {
    let url: URL

    var body: some View {
        Text("Web view is only available on iOS.")
            .foregroundStyle(.secondary)
    }
}
#endif

struct SettingsAppearanceView: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        #if !os(watchOS)
        Picker("Color Theme", selection: $settings.colorSchemeString.animation(.easeInOut)) {
            Text("System").tag("system")
            Text("Light").tag("light")
            Text("Dark").tag("dark")
        }
        .font(.subheadline)
        .pickerStyle(SegmentedPickerStyle())
        #endif
        
        VStack(alignment: .leading) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                ForEach(accentColors, id: \.self) { accentColor in
                    Circle()
                        .fill(accentColor.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(settings.accentColor == accentColor ? Color.primary : Color.clear, lineWidth: 1)
                        )
                        .onTapGesture {
                            settings.hapticFeedback()
                            
                            withAnimation {
                                settings.accentColor = accentColor
                            }
                        }
                }
            }
            .padding(.vertical)
            
            #if !os(watchOS)
            Text("Anas ibn Malik (may Allah be pleased with him) said, “The most beloved of colors to the Messenger of Allah (peace be upon him) was green.”")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 2)
            #endif
        }

        /*
        #if !os(watchOS)
        VStack(alignment: .leading) {
            Toggle("Default List View", isOn: $settings.defaultView.animation(.easeInOut))
                .font(.subheadline)
                .tint(settings.accentColor.toggleTint)

            Text("The default list view is the standard interface found in many of Apple's first party apps, including Notes. This setting applies everywhere in the app except here in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 2)
        }
        #endif

        VStack(alignment: .leading) {
            Toggle("Haptic Feedback", isOn: $settings.hapticOn.animation(.easeInOut))
                .font(.subheadline)
                .tint(settings.accentColor.toggleTint)
        }
        */
    }
}

#if os(iOS)
private struct AuraImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedImage: $selectedImage)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var selectedImage: UIImage?

        init(selectedImage: Binding<UIImage?>) {
            _selectedImage = selectedImage
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let itemProvider = results.first?.itemProvider else { return }

            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

private struct AuraImageCropperView: View {
    let sourceImage: UIImage
    let aspectRatio: CGFloat
    let onSave: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var gestureStartScale: CGFloat = 1
    @State private var cropSize: CGSize = .zero

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                let width = geo.size.width - 32
                let height = min(geo.size.height * 0.65, width / aspectRatio)
                let size = CGSize(width: width, height: height)

                ZStack {
                    Color.black.opacity(0.88).ignoresSafeArea()

                    VStack(spacing: 18) {
                        ZStack {
                            Color.black.opacity(0.35)

                            Image(uiImage: sourceImage)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(dragGesture(in: size))
                                .simultaneousGesture(pinchGesture(in: size))
                        }
                        .frame(width: size.width, height: size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                        )
                        .onAppear {
                            cropSize = size
                            initializeScale(for: size)
                        }
                        .onChange(of: size) { newSize in
                            cropSize = newSize
                            initializeScale(for: newSize)
                        }

                        Text("Drag and zoom to fit the Aura widget.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let cropped = cropImage() {
                            onSave(cropped)
                        }
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func initializeScale(for size: CGSize) {
        let fitSize = fittedImageSize(for: size)
        let minScaleX = size.width / max(fitSize.width, 1)
        let minScaleY = size.height / max(fitSize.height, 1)
        baseScale = max(1, minScaleX, minScaleY)
        scale = max(scale, baseScale)
        gestureStartScale = scale
        clampOffset(in: size)
    }

    private func fittedImageSize(for size: CGSize) -> CGSize {
        let imageRatio = sourceImage.size.width / max(sourceImage.size.height, 1)
        let frameRatio = size.width / max(size.height, 1)
        if imageRatio > frameRatio {
            let width = size.width
            return CGSize(width: width, height: width / imageRatio)
        } else {
            let height = size.height
            return CGSize(width: height * imageRatio, height: height)
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                clampOffset(in: size)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func pinchGesture(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(baseScale, min(6, gestureStartScale * value))
                clampOffset(in: size)
            }
            .onEnded { _ in
                gestureStartScale = scale
                clampOffset(in: size)
                lastOffset = offset
            }
    }

    private func clampOffset(in size: CGSize) {
        let fit = fittedImageSize(for: size)
        let scaled = CGSize(width: fit.width * scale, height: fit.height * scale)
        let limitX = max(0, (scaled.width - size.width) / 2)
        let limitY = max(0, (scaled.height - size.height) / 2)
        offset.width = min(max(offset.width, -limitX), limitX)
        offset.height = min(max(offset.height, -limitY), limitY)
    }

    private func cropImage() -> UIImage? {
        guard cropSize.width > 0, cropSize.height > 0 else { return nil }

        let fit = fittedImageSize(for: cropSize)
        let scaled = CGSize(width: fit.width * scale, height: fit.height * scale)

        let imageOriginInCrop = CGPoint(
            x: (cropSize.width - scaled.width) / 2 + offset.width,
            y: (cropSize.height - scaled.height) / 2 + offset.height
        )

        let pixelsPerPointX = sourceImage.size.width / max(scaled.width, 1)
        let pixelsPerPointY = sourceImage.size.height / max(scaled.height, 1)

        let cropRectInImage = CGRect(
            x: (0 - imageOriginInCrop.x) * pixelsPerPointX,
            y: (0 - imageOriginInCrop.y) * pixelsPerPointY,
            width: cropSize.width * pixelsPerPointX,
            height: cropSize.height * pixelsPerPointY
        ).integral

        let boundedRect = cropRectInImage.intersection(
            CGRect(origin: .zero, size: sourceImage.size)
        )

        guard
            boundedRect.width > 0,
            boundedRect.height > 0,
            let cgImage = sourceImage.cgImage?.cropping(to: boundedRect)
        else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: sourceImage.scale, orientation: sourceImage.imageOrientation)
    }
}
#endif

struct VersionNumber: View {
    @EnvironmentObject var settings: Settings
    
    var width: CGFloat?
    
    var body: some View {
        HStack {
            if let width = width {
                Text("Version:")
                    .frame(width: width)
            } else {
                Text("Version")
            }
            
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                .foregroundColor(settings.accentColor.color)
                .padding(.leading, -4)
        }
        .foregroundColor(.primary)
    }
}

private struct WidgetPreviewDebugView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme
    #if DEBUG && canImport(Inject)
    @ObserveInjection var inject
    #endif
    #if os(iOS)
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingCropper = false
    @State private var selectedPrayerKey: AuraPrayerBackgroundKey?
    @State private var imageErrorMessage: String?
    @State private var expandedCardKey: AuraPrayerBackgroundKey?
    #endif

    private let waktuCards: [WidgetPreviewCardModel] = AuraPrayerBackgroundKey.allCases.enumerated().map { index, key in
        let sampleTimes = [("5:52", "AM", "In 3 hrs 7 mins"),
                           ("7:08", "AM", "In 4 hrs 23 mins"),
                           ("1:23", "PM", "In 8 hrs 38 mins"),
                           ("4:46", "PM", "In 12 hrs 1 min"),
                           ("7:26", "PM", "In 14 hrs 41 mins"),
                           ("8:39", "PM", "In 15 hrs 54 mins")]
        let sample = sampleTimes[min(index, sampleTimes.count - 1)]
        return .init(
            key: key,
            title: key.title,
            time: sample.0,
            period: sample.1,
            countdown: sample.2,
            assetName: key.defaultAssetName
        )
    }

    private var regionModeTitle: String {
        switch settings.prayerRegionDebugOverride {
        case 1:
            return "Force Malaysia API"
        case 2:
            return "Force Global (Adhan)"
        default:
            return settings.shouldUseMalaysiaPrayerAPI(for: settings.currentLocation)
                ? "Auto: Malaysia API"
                : "Auto: Global (Adhan)"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Prayer Region Debug")
                        .font(.headline)

                    Picker("Prayer Region Debug", selection: $settings.prayerRegionDebugOverride) {
                        Text("Auto").tag(0)
                        Text("Malaysia").tag(1)
                        Text("Global").tag(2)
                    }
                    .pickerStyle(.segmented)

                    Text(regionModeTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let location = settings.currentPhoneLocationName ?? settings.currentPrayerAreaName {
                        Text("Current location: \(location)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let waktuZone = settings.currentIndonesiaWaktuZoneName {
                        Text("Waktu zone: \(waktuZone)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if settings.isResolvingIndonesiaWaktuZone {
                        Text("Waktu zone: resolving...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                ForEach(waktuCards) { card in
                    #if os(iOS)
                    ZStack(alignment: .top) {
                        WidgetPreviewCard(
                            model: card,
                            customImage: customImage(for: card.key)
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedCardKey == card.key {
                                    expandedCardKey = nil
                                } else {
                                    expandedCardKey = card.key
                                }
                            }
                        }

                        if expandedCardKey == card.key {
                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Button {
                                        settings.hapticFeedback()
                                        selectedPrayerKey = card.key
                                        showingImagePicker = true
                                    } label: {
                                        Text("Upload")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(uploadButtonTint)
                                    .foregroundStyle(uploadButtonTextColor)

                                    Button {
                                        settings.hapticFeedback()
                                        let success = settings.applyCustomAuraBackgroundToAll(from: card.key)
                                        if !success {
                                            imageErrorMessage = "Could not apply this background to all prayer times."
                                        }
                                    } label: {
                                        Text("All")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(uploadButtonTint)
                                    .foregroundStyle(uploadButtonTextColor)
                                    .disabled(!settings.hasCustomAuraBackground(for: card.key))

                                    Button(role: .destructive) {
                                        settings.hapticFeedback()
                                        settings.removeCustomAuraBackground(for: card.key)
                                    } label: {
                                        Text("Reset")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(!settings.hasCustomAuraBackground(for: card.key))
                                }
                                .frame(maxWidth: .infinity, alignment: .center)

                                Text("\(card.title) background")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.95))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    #else
                    WidgetPreviewCard(
                        model: card,
                        customImage: customImage(for: card.key)
                    )
                    #endif
                }
            }
            .padding()
        }
        .navigationTitle("Widget Preview")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .hotReloadable()
        #if os(iOS)
        .sheet(isPresented: $showingImagePicker) {
            AuraImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingCropper) {
            if let selectedImage {
                AuraImageCropperView(
                    sourceImage: selectedImage,
                    aspectRatio: 2.12
                ) { cropped in
                    guard let key = selectedPrayerKey else { return }
                    let saved = settings.saveCustomAuraBackground(cropped, for: key)
                    if !saved {
                        imageErrorMessage = "Could not save the cropped image."
                    }
                    self.selectedImage = nil
                }
            }
        }
        .onChange(of: selectedImage) { newValue in
            if newValue != nil {
                showingCropper = true
            }
        }
        .alert("Image Error", isPresented: Binding(
            get: { imageErrorMessage != nil },
            set: { if !$0 { imageErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                imageErrorMessage = nil
            }
        } message: {
            Text(imageErrorMessage ?? "Unknown image error.")
        }
        #endif
    }

    #if os(iOS)
    private var uploadButtonTint: Color {
        settings.accentColor.toggleTint
    }

    private var uploadButtonTextColor: Color {
        switch settings.accentColor {
        case .yellow, .mint, .cyan:
            return .black
        case .adaptive:
            return colorScheme == .dark ? .white : .primary
        default:
            return .primary
        }
    }

    private func customImage(for key: AuraPrayerBackgroundKey) -> WidgetPreviewImage? {
        _ = settings.auraBackgroundVersion
        return settings.customAuraBackgroundImage(for: key)
    }
    #else
    private func customImage(for key: AuraPrayerBackgroundKey) -> WidgetPreviewImage? {
        nil
    }
    #endif
}

private struct WidgetPreviewCardModel: Identifiable {
    let id = UUID()
    let key: AuraPrayerBackgroundKey
    let title: String
    let time: String
    let period: String
    let countdown: String
    let assetName: String
}

private struct WidgetPreviewCard: View {
    let model: WidgetPreviewCardModel
    let customImage: WidgetPreviewImage?

    var body: some View {
        ZStack(alignment: .leading) {
            #if os(iOS)
            if let customImage {
                Image(uiImage: customImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                Image(model.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            #else
            Image(model.assetName)
                .resizable()
                .scaledToFill()
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipped()
            #endif

            LinearGradient(
                colors: [Color.black.opacity(0.12), Color.black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.headline)
                    Text(model.title)
                        .font(.title2.weight(.bold))
                }
                .foregroundColor(.white)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(model.time)
                        .font(.system(size: 46, weight: .bold))
                    Text(model.period)
                        .font(.title2.weight(.semibold))
                }
                .foregroundColor(.white)

                Text(model.countdown)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white.opacity(0.95))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

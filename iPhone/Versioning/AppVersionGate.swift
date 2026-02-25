import SwiftUI

private struct VersionConfig: Codable {
    let latestVersion: String
    let minSupportedVersion: String
    let appStoreURL: String
    let softMessage: String?
    let forceMessage: String?
    let enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
        case minSupportedVersion = "min_supported_version"
        case appStoreURL = "app_store_url"
        case softMessage = "soft_message"
        case forceMessage = "force_message"
        case enabled
    }
}

private struct AppVersionGateModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @AppStorage("versionCheckLastFetchTime") private var lastFetchTime: Double = 0
    @AppStorage("versionCheckCachedPayload") private var cachedPayload: String = ""

    @State private var isChecking = false
    @State private var updateURL: URL?
    @State private var softMessage: String?
    @State private var forceMessage: String?
    @State private var showSoftUpdateAlert = false
    @State private var showForceUpdateScreen = false

    // Host this file publicly (GitHub raw, Cloudflare Pages, etc.).
    // You can override this by adding VersionCheckConfigURL in Info-Main.plist.
    private let defaultConfigURL = "https://raw.githubusercontent.com/blinkdagger182/waktusolat/main/version-check.json"
    private let cacheTTL: TimeInterval = 60 * 60 * 24

    func body(content: Content) -> some View {
        content
            .onAppear { runCheckIfNeeded(force: false) }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    runCheckIfNeeded(force: false)
                }
            }
            .alert("Update Available", isPresented: $showSoftUpdateAlert) {
                Button("Later", role: .cancel) { }
                Button("Update Now") {
                    if let updateURL { openURL(updateURL) }
                }
            } message: {
                Text(softMessage ?? "A newer version is available.")
            }
            .fullScreenCover(isPresented: $showForceUpdateScreen) {
                VStack(spacing: 16) {
                    Text("Update Required")
                        .font(.title2.bold())
                    Text(forceMessage ?? "Please update to continue using the app.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)

                    Button {
                        if let updateURL { openURL(updateURL) }
                    } label: {
                        Text("Update Now")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                }
                .interactiveDismissDisabled(true)
            }
    }

    private func runCheckIfNeeded(force: Bool) {
        guard !isChecking else { return }
        isChecking = true

        Task {
            defer { isChecking = false }
            await fetchAndEvaluate(force: force)
        }
    }

    private func fetchAndEvaluate(force: Bool) async {
        do {
            if !force, let cached = cachedConfigIfFresh() {
                evaluate(cached)
                return
            }

            let configURL = resolvedConfigURL()
            let (data, _) = try await URLSession.shared.data(from: configURL)
            guard let payload = String(data: data, encoding: .utf8) else { return }

            cachedPayload = payload
            lastFetchTime = Date().timeIntervalSince1970

            let decoder = JSONDecoder()
            let config = try decoder.decode(VersionConfig.self, from: data)
            evaluate(config)
        } catch {
            if let cached = decodeConfig(from: cachedPayload) {
                evaluate(cached)
            }
        }
    }

    private func resolvedConfigURL() -> URL {
        if let fromInfo = Bundle.main.object(forInfoDictionaryKey: "VersionCheckConfigURL") as? String,
           let url = URL(string: fromInfo),
           !fromInfo.isEmpty {
            return url
        }
        return URL(string: defaultConfigURL)!
    }

    private func cachedConfigIfFresh() -> VersionConfig? {
        let age = Date().timeIntervalSince1970 - lastFetchTime
        guard age < cacheTTL else { return nil }
        return decodeConfig(from: cachedPayload)
    }

    private func decodeConfig(from payload: String) -> VersionConfig? {
        guard let data = payload.data(using: .utf8), !payload.isEmpty else { return nil }
        return try? JSONDecoder().decode(VersionConfig.self, from: data)
    }

    private func evaluate(_ config: VersionConfig) {
        guard config.enabled ?? true else { return }
        guard let installed = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        guard let appStoreURL = URL(string: config.appStoreURL) else { return }

        updateURL = appStoreURL

        if isVersion(installed, lowerThan: config.minSupportedVersion) {
            forceMessage = config.forceMessage ?? "A new version is required to continue."
            showForceUpdateScreen = true
            showSoftUpdateAlert = false
            return
        }

        if isVersion(installed, lowerThan: config.latestVersion) {
            softMessage = config.softMessage ?? "A newer version is available."
            if !showForceUpdateScreen {
                showSoftUpdateAlert = true
            }
        }
    }

    private func isVersion(_ lhs: String, lowerThan rhs: String) -> Bool {
        let l = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let r = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(l.count, r.count)
        for i in 0..<count {
            let lv = i < l.count ? l[i] : 0
            let rv = i < r.count ? r[i] : 0
            if lv < rv { return true }
            if lv > rv { return false }
        }
        return false
    }
}

extension View {
    func appVersionGate() -> some View {
        modifier(AppVersionGateModifier())
    }
}

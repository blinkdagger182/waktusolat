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
    private enum UpdateModalKind: String, Identifiable {
        case soft
        case force
        var id: String { rawValue }
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @AppStorage("versionCheckLastFetchTime") private var lastFetchTime: Double = 0
    @AppStorage("versionCheckCachedPayload") private var cachedPayload: String = ""
    @AppStorage("versionCheckLastSoftPromptVersion") private var lastSoftPromptVersion: String = ""
    @AppStorage("versionCheckLastSoftPromptTime") private var lastSoftPromptTime: Double = 0

    @State private var isChecking = false
    @State private var updateURL: URL?
    @State private var softMessage: String?
    @State private var forceMessage: String?
    @State private var activeModal: UpdateModalKind?

    // Host this file publicly (GitHub raw, Cloudflare Pages, etc.).
    // You can override this by adding VersionCheckConfigURL in Info-Main.plist.
    private let defaultConfigURL = "https://raw.githubusercontent.com/blinkdagger182/waktusolat/main/version-check.json"
    #if DEBUG
    private let cacheTTL: TimeInterval = 0
    private let softPromptCooldown: TimeInterval = 0
    #else
    private let cacheTTL: TimeInterval = 60 * 60 * 24
    private let softPromptCooldown: TimeInterval = 60 * 60 * 24
    #endif

    func body(content: Content) -> some View {
        content
            .onAppear { runCheckIfNeeded(force: false) }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    runCheckIfNeeded(force: false)
                }
            }
            .overlay {
                if let mode = activeModal {
                    UpdatePromptModal(
                        isForce: mode == .force,
                        title: mode == .force ? "Update Required" : "New Update Is Available",
                        message: mode == .force
                            ? (forceMessage ?? "Please update Waktu to continue.")
                            : (softMessage ?? "A newer version of Waktu is available."),
                        onUpdate: {
                            if let updateURL {
                                openURL(updateURL)
                            }
                        },
                        onDismiss: {
                            activeModal = nil
                        }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
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
            activeModal = .force
            return
        }

        if isVersion(installed, lowerThan: config.latestVersion) {
            softMessage = config.softMessage ?? "A newer version is available."
            if activeModal != .force && shouldShowSoftPrompt(for: config.latestVersion) {
                lastSoftPromptVersion = config.latestVersion
                lastSoftPromptTime = Date().timeIntervalSince1970
                activeModal = .soft
            }
        }
    }

    private func shouldShowSoftPrompt(for latestVersion: String) -> Bool {
        if lastSoftPromptVersion != latestVersion {
            return true
        }
        return Date().timeIntervalSince1970 - lastSoftPromptTime >= softPromptCooldown
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

private struct UpdatePromptModal: View {
    let isForce: Bool
    let title: String
    let message: String
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isForce {
                        onDismiss()
                    }
                }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    if !isForce {
                        HStack {
                            Spacer()
                            Button(action: onDismiss) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(10)
                                    .background(Color.white.opacity(0.12), in: Circle())
                            }
                        }
                    }

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
                    .padding(.top, isForce ? 0 : -8)

                    Text(title.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .tracking(1.0)

                    Text("Update your application to the latest version")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)

                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.82))
                        .padding(.horizontal, 8)

                    Button(action: onUpdate) {
                        Text("Update Now")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .padding(.top, 4)

                    if !isForce {
                        Button("Not now", action: onDismiss)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 2)
                    }
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
            }
        }
    }
}

extension View {
    func appVersionGate() -> some View {
        modifier(AppVersionGateModifier())
    }
}

import SwiftUI
import WidgetKit
import StoreKit
import AVFoundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let debugShowDailyQuranWidgetIntro = Notification.Name("debugShowDailyQuranWidgetIntro")
    static let debugShowSupportPromoToast = Notification.Name("debugShowSupportPromoToast")
    static let debugShowSupportPromoToastVariant = Notification.Name("debugShowSupportPromoToastVariant")
    static let debugShowMalaysiaLocationToast = Notification.Name("debugShowMalaysiaLocationToast")
    static let openSupportDonationPaywall = Notification.Name("openSupportDonationPaywall")
    static let uiContentHeartbeat = Notification.Name("uiContentHeartbeat")
}

@main
struct AlAdhanApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private enum AppTab: Hashable {
        case adhan
        case settings
    }

    @StateObject private var settings = Settings.shared
    @StateObject private var namesData = NamesViewModel.shared
    @StateObject private var revenueCat = RevenueCatManager.shared
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("firstLaunchSheet") var firstLaunchSheet: Bool = true
    @AppStorage("didShowDailyQuranWidgetIntroV1") private var didShowDailyQuranWidgetIntro = false
    @AppStorage("didTriggerFirstRunNotificationPromptV1") private var didTriggerFirstRunNotificationPrompt = false
    @AppStorage("remoteUIRecoveryEnabled") private var remoteUIRecoveryEnabled = true
    @AppStorage(AppLanguage.storageKey) private var appLanguageCode = AppLanguage.system.rawValue
    @State var showAdhanSheet: Bool = false
    @State private var showDailyQuranWidgetIntro = false
    
    @State private var isLaunching = true
    @State private var quranDeepLink: QuranDeepLinkPayload?
    @State private var selectedTab: AppTab = .adhan
    @State private var showSupportPromoToast = false
    @State private var showMalaysiaLocationToast = false
    @State private var pendingFirstRunNotificationPrompt = false
    @State private var supportPromoMessage = ""
    @State private var supportPromoPoolProgress: SupportPromoPoolProgress?
    @State private var supportPromoCountdownStart = Date()
    @State private var supportPromoAutoDismissAfter: TimeInterval = 8
    @State private var malaysiaLocationToastPayload: MalaysiaLocationToastPayload?
    @State private var malaysiaLocationToastCountdownStart = Date()
    @State private var malaysiaZoneCatalog: [String: MalaysiaZoneMetadata] = [:]
    @State private var supportPromoSchedule = SupportPromoRemoteConfig.initialSchedule
    @State private var rootRefreshToken = UUID()
    @State private var lastUIHeartbeatAt = Date.distantPast
    @State private var lastSceneActiveAt = Date.distantPast
    @State private var lastUIRecoveryAt = Date.distantPast
    @State private var uiRecoveryTask: Task<Void, Never>?
    @State private var showUnsupportedRegionModal = false

    init() {
        RevenueCatManager.shared.configure()
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: "appLaunchCountV1") + 1, forKey: "appLaunchCountV1")
        syncSharedAppLanguagePreference(defaults.string(forKey: AppLanguage.storageKey))
        Self.updateSupportPromoUsageStats(using: defaults)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isLaunching {
                    LaunchScreen(isLaunching: $isLaunching)
                } else if settings.firstLaunch {
                    SplashScreen()
                } else {
                    TabView(selection: $selectedTab) {
                        AdhanView()
                            .tabItem {
                                Image(systemName: "safari")
                                Text("Azan")
                            }
                            .tag(AppTab.adhan)

                        SettingsView()
                            .tabItem {
                                Image(systemName: "gearshape")
                                Text("Settings")
                            }
                            .tag(AppTab.settings)
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
                            presentSupportPromoToastIfNeeded()
                        }
                    }
                    .sheet(
                        isPresented: $showAdhanSheet,
                        onDismiss: {
                            firstLaunchSheet = false
                            presentDailyQuranWidgetIntroIfNeeded()
                            pendingFirstRunNotificationPrompt = true
                            scheduleFirstRunNotificationPromptIfNeeded()
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
            .id(rootRefreshToken)
            //.statusBarHidden(true)
            .environmentObject(settings)
            .environmentObject(namesData)
            .environmentObject(revenueCat)
            .environment(\.locale, appLocale(for: appLanguageCode))
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
                            scheduleFirstRunNotificationPromptIfNeeded()
                        }
                    )
                    .environmentObject(settings)
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .overlay {
                if showUnsupportedRegionModal {
                    UnsupportedRegionModal(
                        storefrontRegionName: storefrontRegionName,
                        onRefreshLocation: { settings.requestLocationAuthorization() }
                    )
                    .environmentObject(settings)
                    .transition(.opacity)
                    .zIndex(50)
                }
            }
            .overlay(alignment: .top) {
                if showSupportPromoToast || (showMalaysiaLocationToast && malaysiaLocationToastPayload != nil) {
                    VStack(spacing: 8) {
                        if showSupportPromoToast {
                            SupportPromoToast(
                                message: supportPromoMessage,
                                poolProgress: supportPromoPoolProgress,
                                countdownStartDate: supportPromoCountdownStart,
                                autoDismissAfter: supportPromoAutoDismissAfter,
                                onSupport: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showSupportPromoToast = false
                                    }
                                    selectedTab = .settings
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        NotificationCenter.default.post(name: .openSupportDonationPaywall, object: nil)
                                    }
                                },
                                onDismiss: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showSupportPromoToast = false
                                    }
                                }
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if showMalaysiaLocationToast, let malaysiaLocationToastPayload {
                            MalaysiaLocationToast(
                                payload: malaysiaLocationToastPayload,
                                countdownStartDate: malaysiaLocationToastCountdownStart,
                                autoDismissAfter: 7,
                                onDismiss: dismissMalaysiaLocationToast
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.top, 10)
                    .zIndex(19)
                }
            }
            .onAppear {
                withAnimation {
                    settings.fetchPrayerTimes()
                }
                settings.refreshPrayerLockScreenWidgetCount()
                refreshSupportPromoConfigIfNeeded(force: false)
                if !settings.firstLaunch {
                    settings.requestLocationAuthorization()
                }
                scheduleUIRecoveryWatchdog()
                updateUnsupportedRegionModalVisibility()
            }
            .onReceive(NotificationCenter.default.publisher(for: .uiContentHeartbeat)) { _ in
                lastUIHeartbeatAt = Date()
            }
            .onReceive(NotificationCenter.default.publisher(for: .debugShowDailyQuranWidgetIntro)) { _ in
                showDailyQuranWidgetIntro = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .debugShowSupportPromoToast)) { _ in
                guard !isLaunching else { return }
                Task {
                    await presentSupportPromoToast(
                        for: supportPromoSchedule.first(where: { $0.triggerKey == "generic_debug" }) ?? .genericDebug,
                        markAsShown: false
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .debugShowSupportPromoToastVariant)) { note in
                guard !isLaunching else { return }
                let variant = (note.object as? String) ?? "generic"
                Task {
                    await presentSupportPromoToast(
                        for: resolvedDebugSupportPromoItem(for: variant),
                        markAsShown: false
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .debugShowMalaysiaLocationToast)) { _ in
                guard !isLaunching else { return }
                Task {
                    await presentDebugMalaysiaLocationToast()
                }
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
        .onChange(of: appLanguageCode) { _ in
            syncSharedAppLanguagePreference(appLanguageCode)
            rootRefreshToken = UUID()
            settings.updateDates()
            WidgetCenter.shared.reloadAllTimelines()
        }
            .onChange(of: settings.prayersData) { _ in
                Task {
                    await handleMalaysiaZoneChange()
                }
            }
            .onChange(of: settings.currentLocation?.city) { _ in
                Task {
                    await handleMalaysiaZoneChange()
                }
            }
            .onChange(of: settings.firstLaunch) { isFirstLaunch in
                if !isFirstLaunch {
                    settings.requestLocationAuthorization()
                    refreshSupportPromoConfigIfNeeded(force: false)
                    presentDailyQuranWidgetIntroIfNeeded()
                    pendingFirstRunNotificationPrompt = true
                    scheduleFirstRunNotificationPromptIfNeeded()
                }
                updateUnsupportedRegionModalVisibility()
            }
            .onChange(of: selectedTab) { newTab in
                if newTab == .adhan {
                    scheduleFirstRunNotificationPromptIfNeeded()
                }
            }
            .onChange(of: settings.currentLocation?.countryCode) { _ in
                updateUnsupportedRegionModalVisibility()
            }
        .onChange(of: scenePhase) { phase in
            if phase == .active, !settings.firstLaunch {
                settings.requestLocationAuthorization()
            }
            if phase == .active {
                settings.refreshPrayerLockScreenWidgetCount()
                lastSceneActiveAt = Date()
                refreshSupportPromoConfigIfNeeded(force: false)
                scheduleUIRecoveryWatchdog()
                updateUnsupportedRegionModalVisibility()
                scheduleFirstRunNotificationPromptIfNeeded()
            }
        }
    }

    private var storefrontRegionName: String {
        let code = SKPaymentQueue.default().storefront?.countryCode ?? ""
        switch code {
        case "MYS": return "Malaysia"
        case "SGP": return "Singapore"
        case "GBR": return "United Kingdom"
        case "USA": return "United States"
        case "IDN": return "Indonesia"
        default: return "the supported regions"
        }
    }

    private func updateUnsupportedRegionModalVisibility() {
        guard !settings.firstLaunch else {
            showUnsupportedRegionModal = false
            return
        }
        guard let location = settings.currentLocation else {
            showUnsupportedRegionModal = false
            return
        }
        let code = location.countryCode?.uppercased() ?? ""
        let supportedCodes = [
            "MY", "SG", "ID",
            "US", "CA", "GB", "FR",
            "JP", "KR", "CN", "PT", "RU"
        ]
        withAnimation {
            showUnsupportedRegionModal = !code.isEmpty && !supportedCodes.contains(code)
        }
    }

    private func scheduleUIRecoveryWatchdog() {
        uiRecoveryTask?.cancel()
        guard remoteUIRecoveryEnabled else { return }
        guard !isLaunching, !settings.firstLaunch else { return }

        let activeStartedAt = lastSceneActiveAt == .distantPast ? Date() : lastSceneActiveAt
        let requiredHeartbeatAfter = Date()
        if lastSceneActiveAt == .distantPast {
            lastSceneActiveAt = activeStartedAt
        }

        uiRecoveryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            guard scenePhase == .active else { return }
            guard remoteUIRecoveryEnabled else { return }
            guard !isLaunching, !settings.firstLaunch else { return }
            guard lastUIHeartbeatAt < requiredHeartbeatAfter else { return }
            guard Date().timeIntervalSince(lastUIRecoveryAt) > 20 else { return }
            performSafeUIRecovery()
        }
    }

    @MainActor
    private func performSafeUIRecovery() {
        lastUIRecoveryAt = Date()
        showAdhanSheet = false
        showDailyQuranWidgetIntro = false
        showSupportPromoToast = false
        showMalaysiaLocationToast = false
        quranDeepLink = nil
        selectedTab = .adhan
        lastUIHeartbeatAt = .distantPast
        rootRefreshToken = UUID()
        settings.fetchPrayerTimes(force: true)
        scheduleUIRecoveryWatchdog()
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

    private static func updateSupportPromoUsageStats(using defaults: UserDefaults) {
        let calendar = Calendar(identifier: .gregorian)
        let dayStart = calendar.startOfDay(for: Date())
        let dayStamp = dayStart.timeIntervalSince1970
        let lastDayStamp = defaults.double(forKey: "supportPromoLastActiveDayStampV1")

        guard dayStamp != lastDayStamp else { return }

        let previousStreak = defaults.integer(forKey: "supportPromoActiveDayStreakV1")
        let streak: Int

        let lastDayDate = Date(timeIntervalSince1970: lastDayStamp)
        if lastDayStamp > 0,
           let expectedNext = calendar.date(byAdding: .day, value: 1, to: lastDayDate),
           calendar.isDate(expectedNext, inSameDayAs: dayStart) {
            streak = previousStreak + 1
        } else {
            streak = 1
        }

        defaults.set(dayStamp, forKey: "supportPromoLastActiveDayStampV1")
        defaults.set(streak, forKey: "supportPromoActiveDayStreakV1")
    }

    private func supportPromoLastShownKey(for triggerKey: String) -> String {
        "supportPromoLastShownAtV1.\(triggerKey)"
    }

    private func supportPromoResetsAfter30Days(_ triggerKey: String) -> Bool {
        switch triggerKey {
        case "launch_5", "launch_6", "streak_7":
            return true
        default:
            return false
        }
    }

    private func lastShownDate(for triggerKey: String, defaults: UserDefaults) -> Date? {
        let timestamp = defaults.double(forKey: supportPromoLastShownKey(for: triggerKey))
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func markSupportPromoShown(_ triggerKey: String, defaults: UserDefaults) {
        defaults.set(Date().timeIntervalSince1970, forKey: supportPromoLastShownKey(for: triggerKey))
    }

    private func refreshSupportPromoConfigIfNeeded(force: Bool) {
        Task {
            let schedule = await SupportPromoRemoteConfig.loadSchedule(force: force)
            await MainActor.run {
                supportPromoSchedule = schedule
                presentSupportPromoToastIfNeeded()
            }
        }
    }

    private func presentSupportPromoToastIfNeeded() {
        guard !isLaunching else { return }
        guard !settings.firstLaunch else { return }
        guard !pendingFirstRunNotificationPrompt else { return }
        guard !showAdhanSheet else { return }
        guard !showDailyQuranWidgetIntro else { return }
        guard !showSupportPromoToast else { return }

        let defaults = UserDefaults.standard
        let launchCount = defaults.integer(forKey: "appLaunchCountV1")
        let streak = defaults.integer(forKey: "supportPromoActiveDayStreakV1")
        var shownTriggers = Set(defaults.stringArray(forKey: "supportPromoShownTriggersV1") ?? [])

        for triggerKey in shownTriggers where supportPromoResetsAfter30Days(triggerKey) {
            if let lastShownAt = lastShownDate(for: triggerKey, defaults: defaults),
               Date().timeIntervalSince(lastShownAt) >= (30 * 24 * 60 * 60) {
                shownTriggers.remove(triggerKey)
            }
        }

        guard let selectedItem = supportPromoSchedule.first(where: { item in
            isEligibleSupportPromoItem(
                item,
                launchCount: launchCount,
                streak: streak,
                shownTriggers: shownTriggers
            )
        }) else { return }

        if selectedItem.showOnce {
            shownTriggers.insert(selectedItem.triggerKey)
            defaults.set(Array(shownTriggers), forKey: "supportPromoShownTriggersV1")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard !showDailyQuranWidgetIntro else { return }
            Task {
                await presentSupportPromoToast(for: selectedItem)
            }
        }
    }

    private func isEligibleSupportPromoItem(
        _ item: SupportPromoScheduleItem,
        launchCount: Int,
        streak: Int,
        shownTriggers: Set<String>
    ) -> Bool {
        guard item.isEnabled else { return false }
        guard item.audience != .debug else { return false }
        guard !(item.showOnce && shownTriggers.contains(item.triggerKey)) else { return false }
        let defaults = UserDefaults.standard

        if let minimumHoursBetweenShows = item.minimumHoursBetweenShows,
           let lastShownAt = lastShownDate(for: item.triggerKey, defaults: defaults),
           Date().timeIntervalSince(lastShownAt) < (minimumHoursBetweenShows * 60 * 60) {
            return false
        }

        switch item.variant {
        case .launch:
            guard let minLaunchCount = item.minLaunchCount else { return false }
            return launchCount >= minLaunchCount
        case .streak:
            guard let minActiveDayStreak = item.minActiveDayStreak else { return false }
            return streak >= minActiveDayStreak
        case .eidPool:
            guard isOnOrAfterFirstShawwal else { return false }
            if let minLaunchCount = item.minLaunchCount, launchCount < minLaunchCount {
                return false
            }
            if let minActiveDayStreak = item.minActiveDayStreak, streak < minActiveDayStreak {
                return false
            }
            return true
        case .monthlyPool, .generic:
            if let minLaunchCount = item.minLaunchCount, launchCount < minLaunchCount {
                return false
            }
            if let minActiveDayStreak = item.minActiveDayStreak, streak < minActiveDayStreak {
                return false
            }
            return true
        }
    }

    private func resolvedDebugSupportPromoItem(for variant: String) -> SupportPromoScheduleItem {
        if let directMatch = supportPromoSchedule.first(where: { $0.triggerKey == variant }) {
            return directMatch
        }

        switch variant {
        case "launch-5":
            return supportPromoSchedule.first(where: { $0.triggerKey == "launch_5" }) ?? .launch5
        case "launch-6":
            return supportPromoSchedule.first(where: { $0.triggerKey == "launch_6" }) ?? .launch6
        case "streak-7":
            return supportPromoSchedule.first(where: { $0.triggerKey == "streak_7" }) ?? .streak7
        case "eid-pool":
            return supportPromoSchedule.first(where: { $0.triggerKey == "eid_pool" }) ?? .eidPool
        case "month-pool":
            return supportPromoSchedule.first(where: { $0.triggerKey == "monthly_pool" }) ?? .monthlyPool
        default:
            return supportPromoSchedule.first(where: { $0.triggerKey == "generic_debug" }) ?? .genericDebug
        }
    }

    private var isOnOrAfterFirstShawwal: Bool {
        let prayerSource = settings.prayers?.fullPrayers.isEmpty == false
            ? settings.prayers?.fullPrayers
            : settings.prayers?.prayers
        let referenceDate = Settings.islamicReferenceDate(now: Date(), prayers: prayerSource ?? [])
        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        let components = hijriCalendar.dateComponents([.month, .day], from: referenceDate)
        guard let month = components.month, let day = components.day else { return false }
        return month == 10 && day >= 1
    }

    @MainActor
    private func presentSupportPromoToast(for item: SupportPromoScheduleItem, markAsShown: Bool = true) async {
        supportPromoMessage = item.message
        supportPromoAutoDismissAfter = item.autoDismissSeconds
        supportPromoCountdownStart = Date()
        if markAsShown {
            markSupportPromoShown(item.triggerKey, defaults: UserDefaults.standard)
        }

        if item.hasProgress {
            let poolSnapshot = await SupportPromoRemoteConfig.loadPoolSnapshot(force: false)
            supportPromoPoolProgress = SupportPromoPoolProgress(snapshot: poolSnapshot, variant: item.variant)
        } else {
            supportPromoPoolProgress = nil
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            showSupportPromoToast = true
        }
    }

    private func scheduleFirstRunNotificationPromptIfNeeded(delay: TimeInterval = 0.45) {
        guard pendingFirstRunNotificationPrompt else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Task {
                await requestFirstRunNotificationPromptIfNeeded()
            }
        }
    }

    @MainActor
    private func requestFirstRunNotificationPromptIfNeeded() async {
        guard pendingFirstRunNotificationPrompt else { return }
        guard !didTriggerFirstRunNotificationPrompt else {
            pendingFirstRunNotificationPrompt = false
            return
        }
        guard !settings.firstLaunch else { return }
        guard selectedTab == .adhan else { return }
        guard !showAdhanSheet else { return }
        guard !showDailyQuranWidgetIntro else { return }
        guard !showSupportPromoToast else { return }

        let authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if authorizationStatus == .notDetermined {
            didTriggerFirstRunNotificationPrompt = true
            pendingFirstRunNotificationPrompt = false
            _ = await settings.requestNotificationAuthorization()
            presentSupportPromoToastIfNeeded()
        } else {
            didTriggerFirstRunNotificationPrompt = true
            pendingFirstRunNotificationPrompt = false
            presentSupportPromoToastIfNeeded()
        }
    }

    @MainActor
    private func dismissMalaysiaLocationToast() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showMalaysiaLocationToast = false
        }
    }

    @MainActor
    private func presentDebugMalaysiaLocationToast() async {
        if let zoneCode = settings.currentMalaysiaWaktuZoneName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
           let info = await malaysiaZoneInfo(for: zoneCode) {
            malaysiaLocationToastPayload = MalaysiaLocationToastPayload(
                stateName: info.displayStateName,
                locationName: settings.currentPhoneLocationName ?? info.displayStateName,
                zoneLabel: info.fullLabel,
                iconAssetName: info.stateIconAssetName
            )
        } else {
            malaysiaLocationToastPayload = MalaysiaLocationToastPayload(
                stateName: "Johor",
                locationName: settings.currentPhoneLocationName ?? "Johor Bahru, Johor",
                zoneLabel: "JHR01 · Johor · Pulau Aur dan Pulau Pemanggil",
                iconAssetName: "StateJohor"
            )
        }

        malaysiaLocationToastCountdownStart = Date()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            showMalaysiaLocationToast = true
        }
    }

    @MainActor
    private func handleMalaysiaZoneChange() async {
        guard scenePhase == .active else { return }
        guard !settings.firstLaunch else { return }
        guard settings.currentLocation?.countryCode?.uppercased() == "MY" else { return }
        guard let zoneCode = settings.currentMalaysiaWaktuZoneName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
              !zoneCode.isEmpty else { return }
        guard let info = await malaysiaZoneInfo(for: zoneCode) else { return }

        let defaults = UserDefaults.standard
        let previousState = defaults.string(forKey: Self.lastObservedMalaysiaStateKey)
        let previousZone = defaults.string(forKey: Self.lastObservedMalaysiaZoneKey)
        let resolvedPreviousState: String?
        if let previousState {
            resolvedPreviousState = previousState
        } else {
            resolvedPreviousState = await previousMalaysiaStateName(for: previousZone)
        }
        defaults.set(info.normalizedStateName, forKey: Self.lastObservedMalaysiaStateKey)
        defaults.set(zoneCode, forKey: Self.lastObservedMalaysiaZoneKey)

        guard previousZone != zoneCode else { return }
        guard let resolvedPreviousState, resolvedPreviousState != info.normalizedStateName else { return }

        malaysiaLocationToastPayload = MalaysiaLocationToastPayload(
            stateName: info.displayStateName,
            locationName: settings.currentPhoneLocationName ?? info.displayStateName,
            zoneLabel: info.fullLabel,
            iconAssetName: info.stateIconAssetName
        )
        malaysiaLocationToastCountdownStart = Date()

        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
            showMalaysiaLocationToast = true
        }
    }

    @MainActor
    private func malaysiaZoneInfo(for zoneCode: String) async -> MalaysiaZoneMetadata? {
        let normalizedCode = zoneCode.uppercased()
        if let info = malaysiaZoneCatalog[normalizedCode] {
            return info
        }

        guard let url = URL(string: "https://api-waktusolat.vercel.app/zones") else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode([MalaysiaZoneMetadata].self, from: data)
            let catalog = Dictionary(uniqueKeysWithValues: decoded.map { ($0.jakimCode.uppercased(), $0) })
            malaysiaZoneCatalog = catalog
            return catalog[normalizedCode]
        } catch {
            logger.debug("Failed to load Malaysia zone catalog: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    private func previousMalaysiaStateName(for previousZone: String?) async -> String? {
        guard let previousZone else {
            return nil
        }
        let normalizedZone = previousZone
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedZone.isEmpty else {
            return nil
        }
        return await malaysiaZoneInfo(for: normalizedZone)?.normalizedStateName
    }

    private static let lastObservedMalaysiaStateKey = "lastObservedMalaysiaStateNameV1"
    private static let lastObservedMalaysiaZoneKey = "lastObservedMalaysiaZoneCodeV1"

}

private struct QuranDeepLinkPayload: Identifiable {
    let reference: String
    var id: String { reference }
}

private struct SupportPromoPoolProgress {
    let variant: SupportPromoVariant
    let title: String
    let current: Double
    let target: Double
    let subtitle: String

    var fraction: Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    var amountLabel: String {
        "RM\(Self.formatAmount(current)) / RM\(Self.formatAmount(target))"
    }

    init(snapshot: SupportPromoPoolSnapshot, variant: SupportPromoVariant) {
        self.variant = variant
        switch variant {
        case .eidPool:
            title = "Eid Giving Pool"
            subtitle = "Simple, ad-free, and for everyone"
        case .monthlyPool:
            title = "Monthly Support Pool"
            subtitle = "Powered by the community"
        case .generic, .launch, .streak:
            title = "Support Pool"
            subtitle = "Powered by the community"
        }

        current = snapshot.totalAmount
        target = snapshot.targetAmount
    }

    private static func formatAmount(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return value.formatted(.number.precision(.fractionLength(2)))
    }
}

private struct MalaysiaZoneMetadata: Decodable, Identifiable {
    let jakimCode: String
    let negeri: String
    let daerah: String

    var id: String { jakimCode }

    var fullLabel: String {
        "\(jakimCode) · \(displayStateName) · \(daerah)"
    }

    var displayStateName: String {
        switch normalizedStateName {
        case "Kuala Lumpur":
            return "Kuala Lumpur"
        case "Negeri Sembilan":
            return "Negeri Sembilan"
        case "Pulau Pinang":
            return "Pulau Pinang"
        default:
            return negeri
        }
    }

    var normalizedStateName: String {
        let value = negeri
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "wilayah persekutuan ", with: "")

        switch value.lowercased() {
        case "johor":
            return "Johor"
        case "kedah":
            return "Kedah"
        case "kelantan":
            return "Kelantan"
        case "kuala lumpur":
            return "Kuala Lumpur"
        case "labuan":
            return "Labuan"
        case "melaka":
            return "Melaka"
        case "negeri sembilan":
            return "Negeri Sembilan"
        case "pahang":
            return "Pahang"
        case "pulau pinang", "penang":
            return "Pulau Pinang"
        case "perak":
            return "Perak"
        case "perlis":
            return "Perlis"
        case "putrajaya":
            return "Putrajaya"
        case "sabah":
            return "Sabah"
        case "sarawak":
            return "Sarawak"
        case "selangor":
            return "Selangor"
        case "terengganu":
            return "Terengganu"
        default:
            return negeri
        }
    }

    var stateIconAssetName: String? {
        switch normalizedStateName {
        case "Johor":
            return "StateJohor"
        case "Kedah":
            return "StateKedah"
        case "Kelantan":
            return "StateKelantan"
        case "Kuala Lumpur":
            return "StateKualaLumpur"
        case "Labuan":
            return "StateLabuan"
        case "Melaka":
            return "StateMelaka"
        case "Negeri Sembilan":
            return "StateNegeriSembilan"
        case "Pahang":
            return "StatePahang"
        case "Pulau Pinang":
            return "StatePulauPinang"
        case "Perak":
            return "StatePerak"
        case "Perlis":
            return "StatePerlis"
        case "Putrajaya":
            return "StatePutrajaya"
        case "Sabah":
            return "StateSabah"
        case "Sarawak":
            return "StateSarawak"
        case "Selangor":
            return "StateSelangor"
        case "Terengganu":
            return "StateTerengganu"
        default:
            return nil
        }
    }
}

private struct MalaysiaLocationToastPayload: Identifiable, Equatable {
    let stateName: String
    let locationName: String
    let zoneLabel: String
    let iconAssetName: String?

    var id: String {
        "\(stateName)|\(locationName)|\(zoneLabel)"
    }
}

private struct SupportPromoToast: View {
    let message: String
    let poolProgress: SupportPromoPoolProgress?
    let countdownStartDate: Date
    let autoDismissAfter: TimeInterval
    let onSupport: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if poolProgress?.variant == .eidPool {
                Image("Ketupat")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .font(.subheadline.weight(.bold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.subheadline)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)

                if let poolProgress {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(poolProgress.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        GeometryReader { proxy in
                            let width = max(proxy.size.width, 0)
                            Capsule()
                                .fill(Color.orange.opacity(0.18))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(.orange)
                                        .frame(width: width * poolProgress.fraction)
                                }
                        }
                        .frame(height: 6)

                        Text("\(poolProgress.amountLabel) • \(poolProgress.subtitle)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Button("Support") {
                    onSupport()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .overlay(
            TimelineView(.periodic(from: countdownStartDate, by: 0.05)) { context in
                let elapsed = max(0, context.date.timeIntervalSince(countdownStartDate))
                let progress = max(0, min(1, 1 - (elapsed / autoDismissAfter)))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .inset(by: 1.1)
                    .trim(from: 0, to: progress)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 14)
        .task(id: countdownStartDate) {
            try? await Task.sleep(nanoseconds: UInt64(autoDismissAfter * 1_000_000_000))
            await MainActor.run {
                onDismiss()
            }
        }
    }
}

private struct MalaysiaLocationToast: View {
    let payload: MalaysiaLocationToastPayload
    let countdownStartDate: Date
    let autoDismissAfter: TimeInterval
    let onDismiss: () -> Void

    private var isMalay: Bool {
        effectiveAppLanguageCode().hasPrefix("ms")
    }

    private var titleText: String {
        isMalay ? "Lokasi Malaysia dikemas kini" : "Malaysia location updated"
    }

    private var locationLabelText: String {
        isMalay ? "Lokasi" : "Location"
    }

    private var waktuZoneLabelText: String {
        isMalay ? "Zon waktu solat" : "Waktu zone"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack {
                Group {
                    if let iconAssetName = payload.iconAssetName {
                        Image(iconAssetName)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "mappin.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.red)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(payload.stateName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(locationLabelText): \(payload.locationName)")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("\(waktuZoneLabelText): \(payload.zoneLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            VStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .overlay(
            TimelineView(.periodic(from: countdownStartDate, by: 0.05)) { context in
                let elapsed = max(0, context.date.timeIntervalSince(countdownStartDate))
                let progress = max(0, min(1, 1 - (elapsed / autoDismissAfter)))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .inset(by: 1.1)
                    .trim(from: 0, to: progress)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 14)
        .task(id: countdownStartDate) {
            try? await Task.sleep(nanoseconds: UInt64(autoDismissAfter * 1_000_000_000))
            await MainActor.run {
                onDismiss()
            }
        }
    }
}

private enum SupportPromoAudience: String, Codable {
    case debug
    case production
    case all
}

private enum SupportPromoVariant: String, Codable {
    case generic
    case launch
    case streak
    case eidPool = "eid_pool"
    case monthlyPool = "monthly_pool"
}

private struct SupportPromoScheduleItem: Codable, Identifiable {
    let triggerKey: String
    let isEnabled: Bool
    let audience: SupportPromoAudience
    let title: String?
    let message: String
    let variant: SupportPromoVariant
    let minLaunchCount: Int?
    let minActiveDayStreak: Int?
    let minimumHoursBetweenShows: Double?
    let showOnce: Bool
    let priority: Int
    let hasProgress: Bool
    let autoDismissSeconds: TimeInterval

    var id: String { triggerKey }

    enum CodingKeys: String, CodingKey {
        case triggerKey = "trigger_key"
        case isEnabled = "is_enabled"
        case audience
        case title
        case message
        case variant
        case minLaunchCount = "min_launch_count"
        case minActiveDayStreak = "min_active_day_streak"
        case minimumHoursBetweenShows = "minimum_hours_between_shows"
        case showOnce = "show_once"
        case priority
        case hasProgress = "has_progress"
        case autoDismissSeconds = "auto_dismiss_seconds"
    }

    static let genericDebug = SupportPromoScheduleItem(
        triggerKey: "generic_debug",
        isEnabled: true,
        audience: .debug,
        title: nil,
        message: "Enjoying Waktu? Support it.",
        variant: .generic,
        minLaunchCount: nil,
        minActiveDayStreak: nil,
        minimumHoursBetweenShows: 24,
        showOnce: false,
        priority: 100,
        hasProgress: false,
        autoDismissSeconds: 8
    )

    static let launch5 = SupportPromoScheduleItem(
        triggerKey: "launch_5",
        isEnabled: true,
        audience: .production,
        title: nil,
        message: "Love Waktu? Help keep it running.",
        variant: .launch,
        minLaunchCount: 5,
        minActiveDayStreak: nil,
        minimumHoursBetweenShows: nil,
        showOnce: true,
        priority: 10,
        hasProgress: false,
        autoDismissSeconds: 8
    )

    static let launch6 = SupportPromoScheduleItem(
        triggerKey: "launch_6",
        isEnabled: true,
        audience: .production,
        title: nil,
        message: "Use Waktu daily? Support this month's costs.",
        variant: .launch,
        minLaunchCount: 6,
        minActiveDayStreak: nil,
        minimumHoursBetweenShows: nil,
        showOnce: true,
        priority: 20,
        hasProgress: false,
        autoDismissSeconds: 8
    )

    static let streak7 = SupportPromoScheduleItem(
        triggerKey: "streak_7",
        isEnabled: true,
        audience: .production,
        title: nil,
        message: "7 days in a row. Help keep Waktu going.",
        variant: .streak,
        minLaunchCount: nil,
        minActiveDayStreak: 7,
        minimumHoursBetweenShows: nil,
        showOnce: true,
        priority: 30,
        hasProgress: false,
        autoDismissSeconds: 8
    )

    static let eidPool = SupportPromoScheduleItem(
        triggerKey: "eid_pool",
        isEnabled: true,
        audience: .production,
        title: nil,
        message: "This Eid, let's share a little goodness together.\nIf Waktu has helped you stay closer to your prayers, consider contributing. Even a small amount makes a difference.\nYour support keeps Waktu simple, ad-free, and for everyone.",
        variant: .eidPool,
        minLaunchCount: nil,
        minActiveDayStreak: nil,
        minimumHoursBetweenShows: nil,
        showOnce: true,
        priority: 40,
        hasProgress: true,
        autoDismissSeconds: 8
    )

    static let monthlyPool = SupportPromoScheduleItem(
        triggerKey: "monthly_pool",
        isEnabled: false,
        audience: .production,
        title: nil,
        message: "This month's pool is open. Keep Waktu accurate.",
        variant: .monthlyPool,
        minLaunchCount: nil,
        minActiveDayStreak: nil,
        minimumHoursBetweenShows: 168,
        showOnce: false,
        priority: 50,
        hasProgress: true,
        autoDismissSeconds: 8
    )
}

private struct SupportPromoPoolSnapshot: Codable {
    let month: String
    let monthStart: String
    let totalAmount: Double
    let targetAmount: Double
    let capAmount: Double
    let progress: Double

    enum CodingKeys: String, CodingKey {
        case month
        case monthStart
        case totalAmount
        case targetAmount
        case capAmount
        case progress
    }

    static let fallback = SupportPromoPoolSnapshot(
        month: "",
        monthStart: "",
        totalAmount: 0,
        targetAmount: 150,
        capAmount: 1000,
        progress: 0
    )
}

private enum SupportPromoRemoteConfig {
    private static let defaults = UserDefaults.standard
    private static let scheduleCacheKey = "supportPromoScheduleCachedPayloadV1"
    private static let scheduleCacheTimeKey = "supportPromoScheduleLastFetchTimeV1"
    private static let poolCacheKey = "supportPromoPoolCachedPayloadV1"
    private static let poolCacheTimeKey = "supportPromoPoolLastFetchTimeV1"
    #if DEBUG
    private static let scheduleCacheTTL: TimeInterval = 0
    private static let poolCacheTTL: TimeInterval = 0
    #else
    private static let scheduleCacheTTL: TimeInterval = 60 * 30
    private static let poolCacheTTL: TimeInterval = 60 * 10
    #endif

    static let defaultSchedule: [SupportPromoScheduleItem] = [
        .launch5,
        .launch6,
        .streak7,
        .eidPool,
        .monthlyPool,
        .genericDebug,
    ]

    static var initialSchedule: [SupportPromoScheduleItem] {
        if let cached = decodeSchedule(from: defaults.string(forKey: scheduleCacheKey) ?? "") {
            return sanitizeSchedule(cached)
        }

        return defaultSchedule
    }

    static func loadSchedule(force: Bool) async -> [SupportPromoScheduleItem] {
        if !force, let cached = cachedScheduleIfFresh() {
            return sanitizeSchedule(cached)
        }

        let url = SupportPromoConfigURLResolver.resolveScheduleNoCacheURL()

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")

            let session = URLSession(configuration: .ephemeral)
            let (data, _) = try await session.data(for: request)
            guard let payload = String(data: data, encoding: .utf8) else {
                return defaultSchedule
            }

            defaults.set(payload, forKey: scheduleCacheKey)
            defaults.set(Date().timeIntervalSince1970, forKey: scheduleCacheTimeKey)

            let decoded = try JSONDecoder().decode([SupportPromoScheduleItem].self, from: data)
            return sanitizeSchedule(decoded)
        } catch {
            if let cached = decodeSchedule(from: defaults.string(forKey: scheduleCacheKey) ?? "") {
                return sanitizeSchedule(cached)
            }

            return defaultSchedule
        }
    }

    static func loadPoolSnapshot(force: Bool) async -> SupportPromoPoolSnapshot {
        if !force, let cached = cachedPoolIfFresh() {
            return cached
        }

        let url = SupportPromoConfigURLResolver.resolvePoolNoCacheURL()

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")

            let session = URLSession(configuration: .ephemeral)
            let (data, _) = try await session.data(for: request)
            guard let payload = String(data: data, encoding: .utf8) else {
                return .fallback
            }

            defaults.set(payload, forKey: poolCacheKey)
            defaults.set(Date().timeIntervalSince1970, forKey: poolCacheTimeKey)

            return try JSONDecoder().decode(SupportPromoPoolSnapshot.self, from: data)
        } catch {
            return cachedPoolIfFresh() ?? decodePool(from: defaults.string(forKey: poolCacheKey) ?? "") ?? .fallback
        }
    }

    private static func cachedScheduleIfFresh() -> [SupportPromoScheduleItem]? {
        let age = Date().timeIntervalSince1970 - defaults.double(forKey: scheduleCacheTimeKey)
        guard age < scheduleCacheTTL else { return nil }
        return decodeSchedule(from: defaults.string(forKey: scheduleCacheKey) ?? "")
    }

    private static func cachedPoolIfFresh() -> SupportPromoPoolSnapshot? {
        let age = Date().timeIntervalSince1970 - defaults.double(forKey: poolCacheTimeKey)
        guard age < poolCacheTTL else { return nil }
        return decodePool(from: defaults.string(forKey: poolCacheKey) ?? "")
    }

    private static func decodeSchedule(from payload: String) -> [SupportPromoScheduleItem]? {
        guard let data = payload.data(using: .utf8), !payload.isEmpty else { return nil }
        return try? JSONDecoder().decode([SupportPromoScheduleItem].self, from: data)
    }

    private static func decodePool(from payload: String) -> SupportPromoPoolSnapshot? {
        guard let data = payload.data(using: .utf8), !payload.isEmpty else { return nil }
        return try? JSONDecoder().decode(SupportPromoPoolSnapshot.self, from: data)
    }

    private static func sanitizeSchedule(_ schedule: [SupportPromoScheduleItem]) -> [SupportPromoScheduleItem] {
        let merged = Dictionary(uniqueKeysWithValues: defaultSchedule.map { ($0.triggerKey, $0) })
            .merging(Dictionary(uniqueKeysWithValues: schedule.map { ($0.triggerKey, $0) })) { _, remote in remote }

        return merged.values.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.triggerKey < rhs.triggerKey
            }
            return lhs.priority < rhs.priority
        }
    }
}

private enum SupportPromoConfigURLResolver {
    private static let defaultScheduleURL = "https://api-waktusolat.vercel.app/api/support/toasts/schedule"
    private static let defaultPoolURL = "https://api-waktusolat.vercel.app/api/donations/pool/current"

    static func resolveScheduleURL() -> URL {
        if let fromInfo = Bundle.main.object(forInfoDictionaryKey: "SupportPromoScheduleURL") as? String,
           let url = URL(string: fromInfo),
           !fromInfo.isEmpty {
            return url
        }

        return URL(string: defaultScheduleURL)!
    }

    static func resolvePoolURL() -> URL {
        if let fromInfo = Bundle.main.object(forInfoDictionaryKey: "SupportPromoPoolURL") as? String,
           let url = URL(string: fromInfo),
           !fromInfo.isEmpty {
            return url
        }

        return URL(string: defaultPoolURL)!
    }

    static func resolveScheduleNoCacheURL() -> URL {
        nocacheURL(from: resolveScheduleURL())
    }

    static func resolvePoolNoCacheURL() -> URL {
        nocacheURL(from: resolvePoolURL())
    }

    private static func nocacheURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = components.queryItems ?? []
        let stamp = String(Int(Date().timeIntervalSince1970 / 60))
        items.removeAll(where: { $0.name == "_nocache" })
        items.append(URLQueryItem(name: "_nocache", value: stamp))
        components.queryItems = items
        return components.url ?? url
    }
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
    private static let defaultURL = "https://blinkdagger182.github.io/waktu-config/marketing-modal.json"

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
        title: "Live Notification",
        subtitle: "Add it from Lock Screen > Customize > Widgets > Waktu",
        ctaText: "Got it",
        slides: [
            DailyQuranIntroSlide(
                title: "Live Notification",
                subtitle: "See the next prayer countdown and reminders right from your Lock Screen.",
                imageAsset: nil,
                imageURL: "https://blinkdagger182.github.io/waktu-config/images/live-notification-marketing-banner.png?v=1"
            ),
            DailyQuranIntroSlide(
                title: "Daily Quran Widget",
                subtitle: "One inspiring ayah every day.",
                imageAsset: nil,
                imageURL: "https://blinkdagger182.github.io/waktu-config/images/IMG_9653.jpg?v=4"
            ),
            DailyQuranIntroSlide(
                title: "Tap For Full Verse",
                subtitle: "Open Waktu to see full details and translation.",
                imageAsset: nil,
                imageURL: "https://blinkdagger182.github.io/waktu-config/images/ayat-recitation.png?v=4"
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

    enum AlternateCodingKeys: String, CodingKey {
        case imageTitle = "image_title"
        case imageSubtitle = "image_subtitle"
    }

    init(title: String, subtitle: String, imageAsset: String?, imageURL: String?) {
        self.title = title
        self.subtitle = subtitle
        self.imageAsset = imageAsset
        self.imageURL = imageURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let alternate = try decoder.container(keyedBy: AlternateCodingKeys.self)
        self.title =
            (try? container.decode(String.self, forKey: .title)) ??
            (try? alternate.decode(String.self, forKey: .imageTitle)) ??
            "Update"
        self.subtitle =
            (try? container.decode(String.self, forKey: .subtitle)) ??
            (try? alternate.decode(String.self, forKey: .imageSubtitle)) ??
            ""
        self.imageAsset = try? container.decodeIfPresent(String.self, forKey: .imageAsset)
        self.imageURL = try? container.decodeIfPresent(String.self, forKey: .imageURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(imageAsset, forKey: .imageAsset)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
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

                if showSharePreview, let details {
                    QuranSharePreviewOverlay(
                        previewImageFor: { variant in
                            renderSharePreview(details: details, variant: variant)
                        },
                        onShare: { variant in
                            shareSelectedVariant(variant, details: details)
                        },
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSharePreview = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(10)
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

            Text("“\(details.translationText)”")
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
            Text(appLocalized("Text edition: %@ • Audio edition: ar.alafasy", currentQuranTranslationEditionLabel()))
                .font(.caption2)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.54))
            HStack(spacing: 12) {
                Link("API Docs", destination: URL(string: "https://alquran.cloud/api")!)
                Link("Open Verse Endpoint", destination: URL(string: "https://api.alquran.cloud/v1/ayah/\(reference)/\(currentQuranTranslationEdition())")!)
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
        withAnimation(.easeInOut(duration: 0.2)) {
            showSharePreview = true
        }
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
                    summaryText: lockScreenSummaryText(details: details)
                )
            )
        }

        let size: CGSize = {
            switch variant {
            case .fullVerse:
                return CGSize(width: 1080, height: 1350)
            case .englishTranslation:
                return CGSize(width: 780, height: 780)
            case .summary:
                return CGSize(width: 780, height: 780)
            }
        }()

        let controller = UIHostingController(
            rootView: card
                .frame(width: size.width, height: size.height)
                .clipped()
                .ignoresSafeArea()
        )
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        controller.view.insetsLayoutMarginsFromSafeArea = false
        controller.view.layoutMargins = .zero
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

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

    private func lockScreenSummaryText(details: QuranVerseDetails) -> String {
        let normalizedPrimary = details.translationText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let referenceLabel = "\(details.surahNameEnglish) \(details.reference)"

        let isLockScreenSafe = normalizedPrimary.count <= 90
            && referenceLabel.count <= 24
            && (normalizedPrimary.count + referenceLabel.count) <= 120
        if isLockScreenSafe {
            return normalizedPrimary
        }

        if let fallback = LockScreenSummaryFallback.text(for: details.reference) {
            return fallback
        }

        return summarizedVerse(normalizedPrimary, maxLen: 90)
    }

    private func shareCaption(details: QuranVerseDetails, variant: QuranShareVariant) -> String {
        let appLink = "https://apps.apple.com/us/app/waktu-prayer-times-widgets/id6759585564"
        let referenceLine = "Surah \(details.surahNameEnglish) (\(details.reference))"
        switch variant {
        case .fullVerse:
            return """
Quran reflection from \(referenceLine).
\(details.translationText)

Get Waktu on the App Store: \(appLink)
"""
        case .englishTranslation:
            return """
Bahasa Melayu translation from \(referenceLine).
\(details.translationText)

Get Waktu on the App Store: \(appLink)
"""
        case .summary:
            return """
Quran reflection from \(referenceLine).
Summary: \(lockScreenSummaryText(details: details))

Get Waktu on the App Store: \(appLink)
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
        case .englishTranslation: return "Bahasa Melayu Translation"
        case .summary: return "Summary"
        }
    }
}

private struct QuranSharePreviewOverlay: View {
    let previewImageFor: (QuranShareVariant) -> UIImage
    let onShare: (QuranShareVariant) -> Void
    let onClose: () -> Void

    @State private var selectedVariant: QuranShareVariant = .fullVerse
    @State private var previewFull: UIImage?
    @State private var previewEnglish: UIImage?
    @State private var previewSummary: UIImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.46)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    HStack {
                        Text("Share Preview")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(8)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    if let previewFull, let previewEnglish, let previewSummary {
                        TabView(selection: $selectedVariant) {
                            previewImageCard(previewFull)
                                .tag(QuranShareVariant.fullVerse)
                            previewImageCard(previewEnglish)
                                .tag(QuranShareVariant.englishTranslation)
                            previewImageCard(previewSummary)
                                .tag(QuranShareVariant.summary)
                        }
                        .frame(height: 420)
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                    } else {
                        ProgressView("Preparing previews...")
                            .frame(maxWidth: .infinity, minHeight: 280)
                    }

                    Button(action: { onShare(selectedVariant) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share \(selectedVariant.title)")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color("lightPink"), Color("hotPink")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(white: 0.10).opacity(0.94))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .onTapGesture { }
            }
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
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
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
    private var englishLength: Int { details.translationText.count }

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

                    Text("“\(details.translationText)”")
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

                HStack {
                    Text(details.reference)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Waktu")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.76) : Color.black.opacity(0.66))
            }
            .padding(42)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

private struct DailyQuranEnglishTranslationSharePreviewCard: View {
    let details: QuranVerseDetails
    let colorScheme: ColorScheme
    let accent: Color

    private var englishLength: Int { details.translationText.count }
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
    private var englishFontSize: CGFloat { QuranShareTypography.bodyFontSize(for: englishLength) }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bahasa Melayu Translation")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(titleColor)
                    Text("Surah \(details.surahNameEnglish) • \(details.reference)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(subtitleColor)
                }

                Text("“\(details.translationText)”")
                    .font(.system(size: englishFontSize, weight: .semibold, design: .rounded))
                    .lineSpacing(6)
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

                HStack {
                    Text(details.reference)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Waktu")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(footerColor)
            }
            .padding(34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
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

    private var summaryFontSize: CGFloat {
        min(QuranShareTypography.bodyFontSize(for: details.translationText.count), 24)
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

            VStack(alignment: .leading, spacing: 18) {
                Text("Daily Quran")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.92))

                VStack(alignment: .leading, spacing: 14) {
                    Text(summaryReferenceLine)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .lineSpacing(6)
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.85))
                    Text(summaryText)
                        .font(.system(size: summaryFontSize, weight: .semibold, design: .rounded))
                        .lineSpacing(4)
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
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text(details.reference)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 24, weight: .semibold))
                        Text("Waktu")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.76) : Color.black.opacity(0.66))
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

private enum QuranShareTypography {
    static func bodyFontSize(for length: Int) -> CGFloat {
        switch length {
        case 0..<120: return 30
        case 120..<220: return 26
        case 220..<320: return 23
        default: return 21
        }
    }
}

private enum LockScreenSummaryFallback {
    private struct Row: Decodable {
        let reference: String
        let ayat: String
    }

    private static let byReference: [String: String] = {
        let possibleURLs: [URL?] = [
            Bundle.main.url(forResource: "quotes", withExtension: "json"),
            Bundle.main.url(forResource: "quotes", withExtension: "json", subdirectory: "Resources"),
            Bundle.main.url(forResource: "quotes", withExtension: "json", subdirectory: "Resources/JSONs")
        ]

        guard let fileURL = possibleURLs.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode([Row].self, from: data)
        else {
            return [:]
        }

        var mapped: [String: String] = [:]
        for row in payload {
            let text = row.ayat
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            mapped[row.reference] = text
        }
        return mapped
    }()

    static func text(for reference: String) -> String? {
        byReference[reference]
    }
}

private struct QuranVerseDetails {
    let reference: String
    let translationText: String
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
        async let translation = fetchEdition(reference: reference, edition: currentQuranTranslationEdition())
        async let arabic = fetchEdition(reference: reference, edition: "ar.alafasy")

        let translated = try await translation
        let ar = try? await arabic

        let translationText = normalize(translated.data.text)
        let arabicText = ar.map { normalize($0.data.text) }
        return QuranVerseDetails(
            reference: reference,
            translationText: translationText,
            arabicText: arabicText,
            surahNameEnglish: translated.data.surah.englishName,
            surahNameArabic: translated.data.surah.name,
            revelationType: translated.data.surah.revelationType,
            juz: translated.data.juz,
            page: translated.data.page,
            hizbQuarter: translated.data.hizbQuarter,
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

private struct UnsupportedRegionModal: View {
    @EnvironmentObject private var settings: Settings
    let storefrontRegionName: String
    let onRefreshLocation: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.56)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "location.slash.circle.fill")
                    .font(.system(size: 42))
                    .foregroundColor(settings.accentColor.color)

                Text("Outside Supported Region")
                    .font(.title3.bold())

                Text("Waktu Solat currently only supports \(storefrontRegionName). We detected your location outside the supported region.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Button(action: onRefreshLocation) {
                    Text("Refresh Location")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.accentColor.color)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 32)
        }
    }
}

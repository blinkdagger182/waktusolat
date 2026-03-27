import SwiftUI
import os
import Adhan
import CoreLocation
#if os(iOS)
import UIKit
import WidgetKit
#endif

let logger = Logger(subsystem: "app.riskcreatives.waktu", category: "Waktu Solat")

enum NotificationSoundOption: String, CaseIterable, Identifiable {
    case iosDefault = "ios_default"
    case azan = "azan"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iosDefault: return appLocalized("iOS Default")
        case .azan: return appLocalized("Azan")
        }
    }
}

enum PrayerNotificationMessageStyle: String, CaseIterable, Identifiable {
    case standard
    case gentle
    case concise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return appLocalized("Standard")
        case .gentle:
            return appLocalized("Gentle")
        case .concise:
            return appLocalized("Concise")
        }
    }

    var summary: String {
        switch self {
        case .standard:
            return appLocalized("Shows the full prayer reminder with time and location.")
        case .gentle:
            return appLocalized("Uses softer wording while keeping the prayer time clear.")
        case .concise:
            return appLocalized("Keeps the reminder short with just the essentials.")
        }
    }
}

enum ZikirNotificationMessageStyle: String, CaseIterable, Identifiable {
    case guided
    case reflective
    case concise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guided:
            return appLocalized("Guided")
        case .reflective:
            return appLocalized("Reflective")
        case .concise:
            return appLocalized("Concise")
        }
    }

    var summary: String {
        switch self {
        case .guided:
            return appLocalized("Shows a short helper line, the Arabic zikir, and its meaning.")
        case .reflective:
            return appLocalized("Highlights the meaning first, followed by the Arabic phrase.")
        case .concise:
            return appLocalized("Keeps the zikir notification minimal and glanceable.")
        }
    }
}

enum AuraPrayerBackgroundKey: String, CaseIterable, Identifiable {
    case subuh
    case syuruk
    case zuhur
    case asar
    case maghrib
    case isyak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .subuh: return localizedPrayerName("Fajr")
        case .syuruk: return localizedPrayerName("Shurooq")
        case .zuhur: return localizedPrayerName("Dhuhr")
        case .asar: return localizedPrayerName("Asr")
        case .maghrib: return localizedPrayerName("Maghrib")
        case .isyak: return localizedPrayerName("Isha")
        }
    }

    var defaultAssetName: String {
        switch self {
        case .subuh: return "SubuhWidgetBackground"
        case .syuruk: return "SyurukWidgetBackground"
        case .zuhur: return "ZuhurWidgetBackground"
        case .asar: return "AsarWidgetBackground"
        case .maghrib: return "MaghribWidgetBackground"
        case .isyak: return "IsyakWidgetBackground"
        }
    }

    var storageFileName: String {
        "aura-custom-background-\(rawValue).jpg"
    }
}

enum PrayerLocationMode: String, Codable {
    case auto
    case manual
}

final class Settings: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = Settings()
    #if os(iOS)
    private static let prayerLockScreenWidgetKinds: Set<String> = [
        "LockScreen1Widget",
        "LockScreen2Widget",
        "LockScreen3Widget",
        "LockScreen4Widget",
        "LockScreen5Widget",
        "LockScreen6Widget"
    ]
    private static let prayerLockScreenFooterCapableKinds: [String] = [
        "LockScreen5Widget",
        "LockScreen6Widget",
        "LockScreen2Widget",
        "LockScreen3Widget",
        "LockScreen4Widget"
    ]
    private static let preferredPrayerLockScreenFooterWidgetKindKey = "preferredPrayerLockScreenFooterWidgetKind"
    private static let activePrayerLocationDisplayNameKey = "activePrayerLocationDisplayName"
    private static let activePrayerZoneIdentifierKey = "activePrayerZoneIdentifier"
    private static let activePrayerModeKey = "activePrayerMode"
    static let malaysiaWaktuZoneCodeKey = "lastKnownMalaysiaZone"
    #endif

    /// Set by AppDelegate (main app only) so extension targets don't reference UIApplication.shared.
    static var registerForRemoteNotificationsHandler: (() -> Void)?
    static var syncLiveActivityEnrollmentHandler: (() -> Void)?
    private let appGroupUserDefaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
    #if os(iOS)
    var liveActivitySyncTimer: Timer?
    var liveActivityLifecycleObservers: [NSObjectProtocol] = []
    #endif
    var locationRefreshTimeoutWorkItem: DispatchWorkItem?
    var isRefreshingLocation = false
    var lastLocationAuthorizationRequestAt: Date?
    var lastNotificationScheduleSignature: String?
    var lastNotificationScheduleAt: Date?
    
    static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .millisecondsSince1970
        return enc
    }()

    static let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .millisecondsSince1970
        return dec
    }()

    static func islamicReferenceDate(now: Date = Date(), prayers: [Prayer]) -> Date {
        guard let maghribToday = maghribPrayerTime(on: now, prayers: prayers) else {
            return now
        }
        if now >= maghribToday {
            return Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        }
        return now
    }

    private static func maghribPrayerTime(on date: Date, prayers: [Prayer]) -> Date? {
        let cal = Calendar.current
        return prayers
            .filter { cal.isDate($0.time, inSameDayAs: date) }
            .first(where: { prayer in
                let name = prayer.nameTransliteration.lowercased()
                return name.contains("maghrib") || name.contains("magrib") || name.contains("sunset")
            })?
            .time
    }

    static func effectiveHijriOffset(baseOffset: Int, location: Location?) -> Int {
        if baseOffset != 0 { return baseOffset }
        return baseOffset + regionalHijriAdjustment(location: location)
    }

    static func effectiveHijriOffset(baseOffset: Int, isMalaysia: Bool) -> Int {
        if baseOffset != 0 { return baseOffset }
        return baseOffset + (isMalaysia ? -1 : 0)
    }

    static func regionalHijriAdjustment(location: Location?) -> Int {
        guard let location else { return -1 }
        if location.countryCode?.uppercased() == "MY" {
            return -1
        }

        let latitude = location.latitude
        let longitude = location.longitude
        let west = (latitude >= 0.7 && latitude <= 7.6) && (longitude >= 99.5 && longitude <= 104.7)
        let east = (latitude >= 0.7 && latitude <= 7.6) && (longitude >= 109.4 && longitude <= 119.4)
        return (west || east) ? -1 : 0
    }
    
    private override init() {
        let seededLegacyWidgetStyles = Self.seedLegacyWidgetStyleDefaultsIfNeeded(defaults: appGroupUserDefaults)
        self.accentColor = AccentColor.fromStoredValue(appGroupUserDefaults?.string(forKey: "accentColor"))
        self.prayersData = appGroupUserDefaults?.data(forKey: "prayersData") ?? Data()
        self.travelingMode = appGroupUserDefaults?.bool(forKey: "travelingMode") ?? false
        self.hanafiMadhab = appGroupUserDefaults?.bool(forKey: "hanafiMadhab") ?? false
        self.prayerCalculation = appGroupUserDefaults?.string(forKey: "prayerCalculation") ?? "Auto (By Location)"
        self.hijriOffset = appGroupUserDefaults?.integer(forKey: "hijriOffset") ?? 0
        self.activePrayerLocationDisplayName = appGroupUserDefaults?.string(forKey: Self.activePrayerLocationDisplayNameKey)
        self.activePrayerZoneIdentifier = appGroupUserDefaults?.string(forKey: Self.activePrayerZoneIdentifierKey)
        self.activePrayerMode = PrayerLocationMode(
            rawValue: appGroupUserDefaults?.string(forKey: Self.activePrayerModeKey) ?? ""
        ) ?? .auto
        self.malaysiaWaktuZoneCode = UserDefaults.standard.string(forKey: Self.malaysiaWaktuZoneCodeKey)
        
        if let locationData = appGroupUserDefaults?.data(forKey: "currentLocation") {
            do {
                let location = try Self.decoder.decode(Location.self, from: locationData)
                currentLocation = location
            } catch {
                logger.debug("Failed to decode location: \(error)")
            }
        }

        if let prayerAreaData = appGroupUserDefaults?.data(forKey: "resolvedPrayerArea") {
            do {
                resolvedPrayerArea = try Self.decoder.decode(ResolvedPrayerArea.self, from: prayerAreaData)
            } catch {
                logger.debug("Failed to decode resolved prayer area: \(error)")
            }
        }

        if let homeLocationData = appGroupUserDefaults?.data(forKey: "homeLocationData") {
            do {
                let homeLocation = try Self.decoder.decode(Location.self, from: homeLocationData)
                self.homeLocation = homeLocation
            } catch {
                logger.debug("Failed to decode home location: \(error)")
            }
        }
        
        super.init()
        restoreMalaysiaWaktuZoneFromCacheIfNeeded()
        Self.locationManager.delegate = self
        #if os(iOS)
        if seededLegacyWidgetStyles {
            WidgetCenter.shared.reloadAllTimelines()
        }
        configurePassiveLocationMonitoring()
        refreshCustomAuraBackgroundState()
        configureLiveActivitySyncLifecycle()
        #endif
    }

    private static func seedLegacyWidgetStyleDefaultsIfNeeded(defaults: UserDefaults?) -> Bool {
        guard let defaults else { return false }
        let legacyDefaults: [(String, String)] = [
            (NextPrayerCircleStyle.storageKey, NextPrayerCircleStyle.classic.rawValue),
            (LockScreenPrayerTimesStyle.storageKey, LockScreenPrayerTimesStyle.prayerTimelineWithLocation.rawValue),
            (PrayerListWidgetStyle.storageKey, PrayerListWidgetStyle.classic.rawValue),
            (LockScreenPrayerCountdownBarStyle.storageKey, LockScreenPrayerCountdownBarStyle.withLocation.rawValue),
            (WidgetZikirAlignment.storageKey, WidgetZikirAlignment.center.rawValue),
            (DailyVerseWidgetStyle.storageKey, DailyVerseWidgetStyle.classic.rawValue)
        ]

        var didSeed = false
        for (key, value) in legacyDefaults where defaults.string(forKey: key) == nil {
            defaults.set(value, forKey: key)
            didSeed = true
        }

        return didSeed
    }
    
    func hapticFeedback() {
        #if os(iOS)
        if hapticOn { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        #endif
        
        #if os(watchOS)
        if hapticOn { WKInterfaceDevice.current().play(.click) }
        #endif
    }
    
    @AppStorage("hijriDate") internal var hijriDateData: String?
    var hijriDate: HijriDate? {
        get {
            guard let hijriDateData = hijriDateData,
                  let data = hijriDateData.data(using: .utf8) else {
                return nil
            }
            return try? Self.decoder.decode(HijriDate.self, from: data)
        }
        set {
            if let newValue = newValue {
                let encoded = try? Self.encoder.encode(newValue)
                hijriDateData = encoded.flatMap { String(data: $0, encoding: .utf8) }
            } else {
                hijriDateData = nil
            }
        }
    }
    
    @Published var prayersData: Data {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            if !prayersData.isEmpty {
                appGroupUserDefaults?.setValue(prayersData, forKey: "prayersData")
            }
        }
    }
    var prayers: Prayers? {
        get {
            return try? Self.decoder.decode(Prayers.self, from: prayersData)
        }
        set {
            prayersData = (try? Self.encoder.encode(newValue)) ?? Data()
        }
    }
    
    @AppStorage("currentPrayerData") var currentPrayerData: Data?
    @Published var currentPrayer: Prayer? {
        didSet {
            currentPrayerData = try? Self.encoder.encode(currentPrayer)
        }
    }

    @AppStorage("nextPrayerData") var nextPrayerData: Data?
    @Published var nextPrayer: Prayer? {
        didSet {
            nextPrayerData = try? Self.encoder.encode(nextPrayer)
        }
    }
    
    @Published var accentColor: AccentColor {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            appGroupUserDefaults?.setValue(accentColor.rawValue, forKey: "accentColor")
        }
    }
    
    @Published var travelingMode: Bool {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            appGroupUserDefaults?.setValue(travelingMode, forKey: "travelingMode")
        }
    }
    
    @Published var currentLocation: Location? {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            guard let location = currentLocation else {
                appGroupUserDefaults?.removeObject(forKey: "lastLocationUpdatedAt")
                invalidateMalaysiaZoneState()
                resolvedPrayerArea = nil
                return
            }
            let previous = oldValue
            let movedMaterially = previous.map {
                abs($0.latitude - location.latitude) > 0.02 ||
                abs($0.longitude - location.longitude) > 0.02
            } ?? false
            let wasMalaysia = previous?.countryCode?.uppercased() == "MY"
            let isMalaysia = location.countryCode?.uppercased() == "MY"
            if movedMaterially && (wasMalaysia || isMalaysia) {
                invalidateMalaysiaZoneState()
            }
            if location.countryCode?.uppercased() != "ID" {
                resolvedPrayerArea = nil
            } else if let previous,
                      resolvedPrayerArea != nil,
                      (abs(previous.latitude - location.latitude) > 0.02 ||
                       abs(previous.longitude - location.longitude) > 0.02) {
                resolvedPrayerArea = nil
            }
            do {
                let locationData = try Self.encoder.encode(location)
                appGroupUserDefaults?.setValue(locationData, forKey: "currentLocation")
                appGroupUserDefaults?.set(Date(), forKey: "lastLocationUpdatedAt")
            } catch {
                logger.debug("Failed to encode location: \(error)")
            }
        }
    }

    @Published var activePrayerLocationDisplayName: String? {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            let normalized = activePrayerLocationDisplayName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let normalized, !normalized.isEmpty {
                appGroupUserDefaults?.setValue(normalized, forKey: Self.activePrayerLocationDisplayNameKey)
            } else {
                appGroupUserDefaults?.removeObject(forKey: Self.activePrayerLocationDisplayNameKey)
            }
        }
    }

    @Published var activePrayerZoneIdentifier: String? {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            let normalized = activePrayerZoneIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            if let normalized, !normalized.isEmpty {
                appGroupUserDefaults?.setValue(normalized, forKey: Self.activePrayerZoneIdentifierKey)
            } else {
                appGroupUserDefaults?.removeObject(forKey: Self.activePrayerZoneIdentifierKey)
            }
        }
    }

    @Published var activePrayerMode: PrayerLocationMode {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            appGroupUserDefaults?.setValue(activePrayerMode.rawValue, forKey: Self.activePrayerModeKey)
        }
    }

    @Published var malaysiaWaktuZoneCode: String?

    @Published var resolvedPrayerArea: ResolvedPrayerArea? {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            guard let resolvedPrayerArea else {
                appGroupUserDefaults?.removeObject(forKey: "resolvedPrayerArea")
                return
            }
            do {
                let data = try Self.encoder.encode(resolvedPrayerArea)
                appGroupUserDefaults?.setValue(data, forKey: "resolvedPrayerArea")
            } catch {
                logger.debug("Failed to encode resolved prayer area: \(error)")
            }
        }
    }

    #if os(iOS)
    @Published var configuredPrayerLockScreenWidgetCount: Int = 0

    var hasMultiplePrayerLockScreenWidgetsConfigured: Bool {
        configuredPrayerLockScreenWidgetCount >= 2
    }

    func refreshPrayerLockScreenWidgetCount() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            let count: Int
            let preferredFooterOwnerKind: String?
            switch result {
            case .success(let widgets):
                let kinds = widgets.map(\.kind)
                let prayerKinds = kinds.filter { Self.prayerLockScreenWidgetKinds.contains($0) }
                let footerKinds = prayerKinds.filter { Self.prayerLockScreenFooterCapableKinds.contains($0) }
                let uniqueFooterKinds = Set(footerKinds)

                count = footerKinds.count

                if footerKinds.count <= 1 {
                    preferredFooterOwnerKind = footerKinds.first
                } else if uniqueFooterKinds.count == 1 {
                    // Multiple copies of the same widget kind cannot be distinguished in the extension,
                    // so hide the footer everywhere to avoid duplicate location labels.
                    preferredFooterOwnerKind = nil
                } else {
                    preferredFooterOwnerKind = Self.prayerLockScreenFooterCapableKinds.first(where: {
                        uniqueFooterKinds.contains($0)
                    })
                }
            case .failure(let error):
                logger.debug("Failed to inspect widget configurations: \(error.localizedDescription)")
                count = 0
                preferredFooterOwnerKind = nil
            }

            DispatchQueue.main.async {
                self.configuredPrayerLockScreenWidgetCount = count
                if let preferredFooterOwnerKind {
                    self.appGroupUserDefaults?.setValue(
                        preferredFooterOwnerKind,
                        forKey: Self.preferredPrayerLockScreenFooterWidgetKindKey
                    )
                } else {
                    self.appGroupUserDefaults?.removeObject(forKey: Self.preferredPrayerLockScreenFooterWidgetKindKey)
                }
            }
        }
    }
    #endif

    var currentPrayerAreaName: String? {
        if isManualPrayerLocationMode,
           let activePrayerLocationDisplayName,
           !activePrayerLocationDisplayName.isEmpty {
            return activePrayerLocationDisplayName
        }
        if shouldUseIndonesiaPrayerAPI(for: currentLocation) {
            return resolvedPrayerArea?.displayName
        }
        return currentLocation?.city
    }

    var currentPhoneLocationName: String? {
        currentLocation?.city
    }

    var currentIndonesiaWaktuZoneName: String? {
        guard shouldUseIndonesiaPrayerAPI(for: currentLocation),
              let resolvedPrayerArea else {
            return nil
        }
        return resolvedPrayerArea.displayName
    }

    var currentMalaysiaWaktuZoneName: String? {
        guard shouldUseMalaysiaPrayerAPI(for: currentLocation) else { return nil }
        let normalizedStoredZone = malaysiaWaktuZoneCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        if let normalizedStoredZone, !normalizedStoredZone.isEmpty {
            return normalizedStoredZone
        }

        let normalizedActiveZone = activePrayerZoneIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        if let normalizedActiveZone, !normalizedActiveZone.isEmpty {
            return normalizedActiveZone
        }

        return nil
    }

    var isResolvingIndonesiaWaktuZone: Bool {
        shouldUseIndonesiaPrayerAPI(for: currentLocation) &&
        currentLocation != nil &&
        resolvedPrayerArea == nil
    }

    var currentPrayerAreaSubtitle: String? {
        if shouldPromptSetAutoForPrayerLocationMismatch {
            return currentPhoneLocationName
        }
        guard shouldUseIndonesiaPrayerAPI(for: currentLocation),
              let resolvedPrayerArea,
              let phoneLocation = currentLocation?.city,
              phoneLocation != resolvedPrayerArea.displayName else {
            return nil
        }
        return phoneLocation
    }

    var currentWaktuZoneName: String? {
        currentIndonesiaWaktuZoneName ?? currentMalaysiaWaktuZoneName
    }

    var currentPrayerZoneIdentifier: String? {
        if shouldUseIndonesiaPrayerAPI(for: currentLocation) {
            let manualRegion = debugIndonesiaRegionId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !manualRegion.isEmpty {
                return manualRegion
            }
            return resolvedPrayerArea?.regionId
        }

        let manualZone = debugMalaysiaZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !manualZone.isEmpty {
            return manualZone
        }
        return currentMalaysiaWaktuZoneName
    }

    var shouldDisplayWaktuZoneTag: Bool {
        shouldUseMalaysiaPrayerAPI(for: currentLocation) || shouldUseIndonesiaPrayerAPI(for: currentLocation)
    }

    var isResolvingAnyWaktuZone: Bool {
        guard !isManualPrayerLocationMode else { return false }
        return isResolvingIndonesiaWaktuZone ||
            (shouldUseMalaysiaPrayerAPI(for: currentLocation) && currentMalaysiaWaktuZoneName == nil)
    }

    var effectivePrayerLocationDisplayName: String? {
        currentPrayerAreaName ?? activePrayerLocationDisplayName ?? currentLocation?.city
    }

    var isManualPrayerLocationMode: Bool {
        let selectedMode = UserDefaults.standard.integer(forKey: "waktuZoneModeSelection")
        if selectedMode == 1 {
            return true
        }
        return !debugMalaysiaZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !debugIndonesiaRegionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var shouldPromptSetAutoForPrayerLocationMismatch: Bool {
        guard isManualPrayerLocationMode else { return false }
        guard let active = effectivePrayerLocationDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              let phone = currentPhoneLocationName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !active.isEmpty,
              !phone.isEmpty else {
            return false
        }
        return active.caseInsensitiveCompare(phone) != .orderedSame
    }

    var prayerLocationMismatchMessage: String {
        let pinned = effectivePrayerLocationDisplayName ?? appLocalized("Unknown")
        return appLocalized("You're in a new location. Prayer times are still set to %@.", pinned)
    }

    var prayerLocationAutoPromptText: String {
        appLocalized("Set to Auto to update.")
    }

    func setActivePrayerContext(
        locationDisplayName: String?,
        zoneIdentifier: String?,
        mode: PrayerLocationMode
    ) {
        activePrayerMode = mode
        activePrayerLocationDisplayName = locationDisplayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        activePrayerZoneIdentifier = zoneIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    func syncActivePrayerContextAfterPrayerRefresh(
        fallbackLocationDisplayName: String?,
        zoneIdentifier: String?
    ) {
        let mode: PrayerLocationMode = isManualPrayerLocationMode ? .manual : .auto
        let displayName: String?

        if mode == .manual,
           let activePrayerLocationDisplayName,
           !activePrayerLocationDisplayName.isEmpty {
            displayName = activePrayerLocationDisplayName
        } else {
            displayName = fallbackLocationDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        setActivePrayerContext(
            locationDisplayName: displayName,
            zoneIdentifier: zoneIdentifier,
            mode: mode
        )
    }

    func setPrayerLocationModeToAuto() {
        UserDefaults.standard.set(0, forKey: "waktuZoneModeSelection")
        debugMalaysiaZoneCode = ""
        debugIndonesiaRegionId = ""
        activePrayerMode = .auto
        fetchPrayerTimes(force: true)
    }
    
    @Published var homeLocation: Location? {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            guard let homeLocation = homeLocation else {
                appGroupUserDefaults?.removeObject(forKey: "homeLocationData")
                return
            }
            do {
                let homeLocationData = try Self.encoder.encode(homeLocation)
                appGroupUserDefaults?.set(homeLocationData, forKey: "homeLocationData")
            } catch {
                logger.debug("Failed to encode home location: \(error)")
            }
        }
    }
    
    @Published var hanafiMadhab: Bool {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            appGroupUserDefaults?.setValue(hanafiMadhab, forKey: "hanafiMadhab")
        }
    }
    
    @Published var prayerCalculation: String {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            appGroupUserDefaults?.setValue(prayerCalculation, forKey: "prayerCalculation")
        }
    }
    
    @Published var hijriOffset: Int {
        didSet {
            guard Bundle.main.bundleIdentifier?.contains("Widget") != true else { return }
            appGroupUserDefaults?.setValue(hijriOffset, forKey: "hijriOffset")
        }
    }

    @AppStorage("favoriteLetterData") private var favoriteLetterData = Data()
    var favoriteLetters: [LetterData] {
        get {
            (try? Self.decoder.decode([LetterData].self, from: favoriteLetterData)) ?? []
        }
        set {
            favoriteLetterData = (try? Self.encoder.encode(newValue)) ?? Data()
        }
    }
    
    @AppStorage("firstLaunch") var firstLaunch = true
    
    @AppStorage("dateNotifications") var dateNotifications = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    
    @AppStorage("lastScheduledHijriYear") private var lastScheduledHijriYear: Int = 0
    
    var hijriCalendar: Calendar = {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "ar")
        return calendar
    }()
    
    var specialEvents: [(String, DateComponents, String, String)] {
        let currentHijriYear = hijriCalendar.component(.year, from: Date())
        return [
            (appLocalized("Islamic New Year"), DateComponents(year: currentHijriYear, month: 1, day: 1), appLocalized("Start of Hijri year"), appLocalized("The first day of the Islamic calendar; no special acts of worship or celebration are prescribed.")),
            (appLocalized("Day Before Ashura"), DateComponents(year: currentHijriYear, month: 1, day: 9), appLocalized("Recommended to fast"), appLocalized("The Prophet ﷺ intended to fast the 9th to differ from the Jews, making it Sunnah to do so before Ashura.")),
            (appLocalized("Day of Ashura"), DateComponents(year: currentHijriYear, month: 1, day: 10), appLocalized("Recommended to fast"), appLocalized("Ashura marks the day Allah saved Musa (Moses) and the Israelites from Pharaoh; fasting expiates sins of the previous year.")),

            (appLocalized("First Day of Ramadan"), DateComponents(year: currentHijriYear, month: 9, day: 1), appLocalized("Begin obligatory fast"), appLocalized("The month of fasting begins; all Muslims must fast from Fajr (dawn) to Maghrib (sunset).")),
            (appLocalized("Last 10 Nights of Ramadan"), DateComponents(year: currentHijriYear, month: 9, day: 21), appLocalized("Seek Laylatul Qadr"), appLocalized("The most virtuous nights of the year; increase worship as these nights are beloved to Allah and contain Laylatul Qadr.")),
            (appLocalized("27th Night of Ramadan"), DateComponents(year: currentHijriYear, month: 9, day: 27), appLocalized("Likely Laylatul Qadr"), appLocalized("A strong possibility for Laylatul Qadr — the Night of Decree when the Qur’an was sent down — though not confirmed.")),
            (appLocalized("Eid Al-Fitr"), DateComponents(year: currentHijriYear, month: 10, day: 1), appLocalized("Celebration of ending the fast"), appLocalized("Celebration marking the end of Ramadan; fasting is prohibited on this day; encouraged to fast 6 days in Shawwal.")),

            (appLocalized("First 10 Days of Dhul-Hijjah"), DateComponents(year: currentHijriYear, month: 12, day: 1), appLocalized("Most beloved days"), appLocalized("The best days for righteous deeds; fasting and dhikr are highly encouraged.")),
            (appLocalized("Beginning of Hajj"), DateComponents(year: currentHijriYear, month: 12, day: 8), appLocalized("Pilgrimage begins"), appLocalized("Pilgrims begin the rites of Hajj, heading to Mina to start the sacred journey.")),
            (appLocalized("Day of Arafah"), DateComponents(year: currentHijriYear, month: 12, day: 9), appLocalized("Recommended to fast"), appLocalized("Fasting for non-pilgrims expiates sins of the past and coming year.")),
            (appLocalized("Eid Al-Adha"), DateComponents(year: currentHijriYear, month: 12, day: 10), appLocalized("Celebration of sacrifice during Hajj"), appLocalized("The day of sacrifice; fasting is not allowed and sacrifice of an animal is offered.")),
            (appLocalized("End of Eid Al-Adha"), DateComponents(year: currentHijriYear, month: 12, day: 13), appLocalized("Hajj and Eid end"), appLocalized("Final day of Eid Al-Adha; pilgrims and non-pilgrims return to daily life.")),
        ]
    }
    
    @AppStorage("showCurrentInfo") var showCurrentInfo: Bool = false
    @AppStorage("showNextInfo") var showNextInfo: Bool = false
    
    @Published var datePrayers: [Prayer]?
    @Published var dateFullPrayers: [Prayer]?
    @Published var changedDate = false
    
    @AppStorage("hapticOn") var hapticOn: Bool = true
    
    @AppStorage("defaultView") var defaultView: Bool = true
    
    @AppStorage("colorSchemeString") var colorSchemeString: String = "system"
    var colorScheme: ColorScheme? {
        get {
            return colorSchemeFromString(colorSchemeString)
        }
        set {
            colorSchemeString = colorSchemeToString(newValue)
        }
    }
    
    @AppStorage("travelAutomatic") var travelAutomatic: Bool = true
    @AppStorage("travelTurnOffAutomatic") var travelTurnOffAutomatic: Bool = false
    @AppStorage("travelTurnOnAutomatic") var travelTurnOnAutomatic: Bool = false
    /// Set by the UI when the user toggles Traveling Mode; fetchPrayerTimes skips checkIfTraveling once so we don’t override or notify.
    var travelingModeManuallyToggled: Bool = false
    
    @AppStorage("showLocationAlert") var showLocationAlert: Bool = false {
        willSet { objectWillChange.send() }
    }
    @AppStorage("showNotificationAlert") var showNotificationAlert: Bool = false
    @AppStorage("notificationSoundOptionRaw") var notificationSoundOptionRaw: String = NotificationSoundOption.iosDefault.rawValue {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("prayerNotificationMessageStyleRaw") var prayerNotificationMessageStyleRaw: String = PrayerNotificationMessageStyle.standard.rawValue {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("zikirNotificationsEnabled") var zikirNotificationsEnabled: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("zikirNotificationMessageStyleRaw") var zikirNotificationMessageStyleRaw: String = ZikirNotificationMessageStyle.guided.rawValue {
        didSet { self.fetchPrayerTimes(notification: true) }
    }

    var notificationSoundOption: NotificationSoundOption {
        get {
            switch notificationSoundOptionRaw {
            case NotificationSoundOption.iosDefault.rawValue:
                return .iosDefault
            case "allahuakbar_only", "full_azan", NotificationSoundOption.azan.rawValue:
                return .azan
            default:
                return .iosDefault
            }
        }
        set { setNotificationSoundOption(newValue) }
    }

    func setNotificationSoundOption(_ option: NotificationSoundOption) {
        objectWillChange.send()
        notificationSoundOptionRaw = option.rawValue
    }

    var prayerNotificationMessageStyle: PrayerNotificationMessageStyle {
        get { PrayerNotificationMessageStyle(rawValue: prayerNotificationMessageStyleRaw) ?? .standard }
        set { prayerNotificationMessageStyleRaw = newValue.rawValue }
    }

    var zikirNotificationMessageStyle: ZikirNotificationMessageStyle {
        get { ZikirNotificationMessageStyle(rawValue: zikirNotificationMessageStyleRaw) ?? .guided }
        set { zikirNotificationMessageStyleRaw = newValue.rawValue }
    }
    
    @AppStorage("locationNeverAskAgain") var locationNeverAskAgain = false
    @AppStorage("notificationNeverAskAgain") var notificationNeverAskAgain = false
    @AppStorage("liveNextPrayerEnabled") var liveNextPrayerEnabled: Bool = false {
        didSet {
            self.fetchPrayerTimes(force: false)
            Self.syncLiveActivityEnrollmentHandler?()
        }
    }
    @AppStorage("liveActivityLeadMinutes") var liveActivityLeadMinutes: Int = 5 {
        didSet { self.fetchPrayerTimes(force: false) }
    }
    @AppStorage("liveActivityFajrEnabled") var liveActivityFajrEnabled: Bool = true {
        didSet { self.fetchPrayerTimes(force: false) }
    }
    @AppStorage("liveActivitySunriseEnabled") var liveActivitySunriseEnabled: Bool = true {
        didSet { self.fetchPrayerTimes(force: false) }
    }
    @AppStorage("liveActivityDhuhrEnabled") var liveActivityDhuhrEnabled: Bool = true {
        didSet { self.fetchPrayerTimes(force: false) }
    }
    @AppStorage("liveActivityAsrEnabled") var liveActivityAsrEnabled: Bool = true {
        didSet { self.fetchPrayerTimes(force: false) }
    }
    @AppStorage("liveActivityMaghribEnabled") var liveActivityMaghribEnabled: Bool = true {
        didSet { self.fetchPrayerTimes(force: false) }
    }
    @AppStorage("liveActivityIshaEnabled") var liveActivityIshaEnabled: Bool = true {
        didSet { self.fetchPrayerTimes(force: false) }
    }
    @AppStorage("liveActivityDhuhrAsrEnabled") var liveActivityDhuhrAsrEnabled: Bool = true {
        didSet { self.fetchPrayerTimes(force: false) }
    }
    @AppStorage("liveActivityMaghribIshaEnabled") var liveActivityMaghribIshaEnabled: Bool = true {
        didSet { self.fetchPrayerTimes(force: false) }
    }
    // 0: Auto detect by coordinates, 1: Force Malaysia API, 2: Force coordinate-based Adhan.
    @AppStorage("prayerRegionDebugOverride") var prayerRegionDebugOverride: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }
    // DEBUG helper: when set, Malaysia prayer times are fetched by explicit JAKIM zone via /v2/solat/{zone}.
    @AppStorage("debugMalaysiaZoneCode") var debugMalaysiaZoneCode: String = "" {
        didSet { self.fetchPrayerTimes(force: true) }
    }
    @AppStorage("debugIndonesiaRegionId") var debugIndonesiaRegionId: String = "" {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("naggingMode") var naggingMode: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingStartOffset") var naggingStartOffset: Int = 30 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    
    @AppStorage("preNotificationFajr") var preNotificationFajr: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationFajr") var notificationFajr: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingFajr") var naggingFajr: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetFajr") var offsetFajr: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("preNotificationSunrise") var preNotificationSunrise: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationSunrise") var notificationSunrise: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingSunrise") var naggingSunrise: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetSunrise") var offsetSunrise: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("preNotificationDhuhr") var preNotificationDhuhr: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationDhuhr") var notificationDhuhr: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingDhuhr") var naggingDhuhr: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetDhuhr") var offsetDhuhr: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("preNotificationAsr") var preNotificationAsr: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationAsr") var notificationAsr: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingAsr") var naggingAsr: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetAsr") var offsetAsr: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("preNotificationMaghrib") var preNotificationMaghrib: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationMaghrib") var notificationMaghrib: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingMaghrib") var naggingMaghrib: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetMaghrib") var offsetMaghrib: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("preNotificationIsha") var preNotificationIsha: Int = 0 {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("notificationIsha") var notificationIsha: Bool = true {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("naggingIsha") var naggingIsha: Bool = false {
        didSet { self.fetchPrayerTimes(notification: true) }
    }
    @AppStorage("offsetIsha") var offsetIsha: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }
    
    @AppStorage("offsetDhurhAsr") var offsetDhurhAsr: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }
    @AppStorage("offsetMaghribIsha") var offsetMaghribIsha: Int = 0 {
        didSet { self.fetchPrayerTimes(force: true) }
    }

    @AppStorage("useFontArabic") var useFontArabic = true
    
    @AppStorage("fontArabic") var fontArabic: String = "KFGQPCUthmanicScriptHAFS"

    @Published var auraBackgroundVersion: Int = 0

    func toggleLetterFavorite(letterData: LetterData) {
        withAnimation {
            if isLetterFavorite(letterData: letterData) {
                favoriteLetters.removeAll(where: { $0.id == letterData.id })
            } else {
                favoriteLetters.append(letterData)
            }
        }
    }

    func isLetterFavorite(letterData: LetterData) -> Bool {
        return favoriteLetters.contains(where: {$0.id == letterData.id})
    }
    
    func colorSchemeFromString(_ colorScheme: String) -> ColorScheme? {
        switch colorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    func colorSchemeToString(_ colorScheme: ColorScheme?) -> String {
        switch colorScheme {
        case .light:
            return "light"
        case .dark:
            return "dark"
        default:
            return "system"
        }
    }

    #if os(iOS)
    private func auraContainerURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.app.riskcreatives.waktu")
    }

    func customAuraBackgroundURL(for key: AuraPrayerBackgroundKey) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.app.riskcreatives.waktu")?
            .appendingPathComponent(key.storageFileName)
    }

    func refreshCustomAuraBackgroundState() {
        auraBackgroundVersion += 1
    }

    func hasCustomAuraBackground(for key: AuraPrayerBackgroundKey) -> Bool {
        guard let url = customAuraBackgroundURL(for: key) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func customAuraBackgroundImage(for key: AuraPrayerBackgroundKey) -> UIImage? {
        guard
            let url = customAuraBackgroundURL(for: key),
            FileManager.default.fileExists(atPath: url.path),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return UIImage(data: data)
    }

    @discardableResult
    func saveCustomAuraBackground(_ image: UIImage, for key: AuraPrayerBackgroundKey, compressionQuality: CGFloat = 0.88) -> Bool {
        guard
            let containerURL = auraContainerURL(),
            let data = image.jpegData(compressionQuality: compressionQuality)
        else {
            return false
        }

        do {
            let url = containerURL.appendingPathComponent(key.storageFileName)
            try data.write(to: url, options: [.atomic])
            refreshCustomAuraBackgroundState()
            WidgetCenter.shared.reloadTimelines(ofKind: "GraphicPrayerWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "GraphicPrayerSquareWidget")
            return true
        } catch {
            logger.error("Failed to save custom aura background: \(error.localizedDescription)")
            return false
        }
    }

    func removeCustomAuraBackground(for key: AuraPrayerBackgroundKey) {
        guard let url = customAuraBackgroundURL(for: key) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        refreshCustomAuraBackgroundState()
        WidgetCenter.shared.reloadTimelines(ofKind: "GraphicPrayerWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "GraphicPrayerSquareWidget")
    }

    @discardableResult
    func applyCustomAuraBackgroundToAll(from sourceKey: AuraPrayerBackgroundKey, compressionQuality: CGFloat = 0.88) -> Bool {
        guard
            let sourceImage = customAuraBackgroundImage(for: sourceKey),
            let containerURL = auraContainerURL(),
            let data = sourceImage.jpegData(compressionQuality: compressionQuality)
        else {
            return false
        }

        var didWrite = false
        for key in AuraPrayerBackgroundKey.allCases {
            let url = containerURL.appendingPathComponent(key.storageFileName)
            do {
                try data.write(to: url, options: [.atomic])
                didWrite = true
            } catch {
                logger.error("Failed applying custom aura background to \(key.rawValue): \(error.localizedDescription)")
            }
        }

        if didWrite {
            refreshCustomAuraBackgroundState()
            WidgetCenter.shared.reloadAllTimelines()
        }

        return didWrite
    }
    #endif
}

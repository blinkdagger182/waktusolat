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
        case .iosDefault: return "iOS Default"
        case .azan: return "Azan"
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
        case .subuh: return "Fajr"
        case .syuruk: return "Shurooq"
        case .zuhur: return "Dhuhr"
        case .asar: return "Asr"
        case .maghrib: return "Maghrib"
        case .isyak: return "Isha"
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

final class Settings: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = Settings()
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
        self.accentColor = AccentColor.fromStoredValue(appGroupUserDefaults?.string(forKey: "accentColor"))
        self.prayersData = appGroupUserDefaults?.data(forKey: "prayersData") ?? Data()
        self.travelingMode = appGroupUserDefaults?.bool(forKey: "travelingMode") ?? false
        self.hanafiMadhab = appGroupUserDefaults?.bool(forKey: "hanafiMadhab") ?? false
        self.prayerCalculation = appGroupUserDefaults?.string(forKey: "prayerCalculation") ?? "Auto (By Location)"
        self.hijriOffset = appGroupUserDefaults?.integer(forKey: "hijriOffset") ?? 0
        
        if let locationData = appGroupUserDefaults?.data(forKey: "currentLocation") {
            do {
                let location = try Self.decoder.decode(Location.self, from: locationData)
                currentLocation = location
            } catch {
                logger.debug("Failed to decode location: \(error)")
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
        Self.locationManager.delegate = self
        #if os(iOS)
        configurePassiveLocationMonitoring()
        refreshCustomAuraBackgroundState()
        configureLiveActivitySyncLifecycle()
        #endif
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
            guard let location = currentLocation else { return }
            do {
                let locationData = try Self.encoder.encode(location)
                appGroupUserDefaults?.setValue(locationData, forKey: "currentLocation")
            } catch {
                logger.debug("Failed to encode location: \(error)")
            }
        }
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
            ("Islamic New Year", DateComponents(year: currentHijriYear, month: 1, day: 1), "Start of Hijri year", "The first day of the Islamic calendar; no special acts of worship or celebration are prescribed."),
            ("Day Before Ashura", DateComponents(year: currentHijriYear, month: 1, day: 9), "Recommended to fast", "The Prophet ﷺ intended to fast the 9th to differ from the Jews, making it Sunnah to do so before Ashura."),
            ("Day of Ashura", DateComponents(year: currentHijriYear, month: 1, day: 10), "Recommended to fast", "Ashura marks the day Allah saved Musa (Moses) and the Israelites from Pharaoh; fasting expiates sins of the previous year."),
            
            ("First Day of Ramadan", DateComponents(year: currentHijriYear, month: 9, day: 1), "Begin obligatory fast", "The month of fasting begins; all Muslims must fast from Fajr (dawn) to Maghrib (sunset)."),
            ("Last 10 Nights of Ramadan", DateComponents(year: currentHijriYear, month: 9, day: 21), "Seek Laylatul Qadr", "The most virtuous nights of the year; increase worship as these nights are beloved to Allah and contain Laylatul Qadr."),
            ("27th Night of Ramadan", DateComponents(year: currentHijriYear, month: 9, day: 27), "Likely Laylatul Qadr", "A strong possibility for Laylatul Qadr — the Night of Decree when the Qur’an was sent down — though not confirmed."),
            ("Eid Al-Fitr", DateComponents(year: currentHijriYear, month: 10, day: 1), "Celebration of ending the fast", "Celebration marking the end of Ramadan; fasting is prohibited on this day; encouraged to fast 6 days in Shawwal."),
            
            ("First 10 Days of Dhul-Hijjah", DateComponents(year: currentHijriYear, month: 12, day: 1), "Most beloved days", "The best days for righteous deeds; fasting and dhikr are highly encouraged."),
            ("Beginning of Hajj", DateComponents(year: currentHijriYear, month: 12, day: 8), "Pilgrimage begins", "Pilgrims begin the rites of Hajj, heading to Mina to start the sacred journey."),
            ("Day of Arafah", DateComponents(year: currentHijriYear, month: 12, day: 9), "Recommended to fast", "Fasting for non-pilgrims expiates sins of the past and coming year."),
            ("Eid Al-Adha", DateComponents(year: currentHijriYear, month: 12, day: 10), "Celebration of sacrifice during Hajj", "The day of sacrifice; fasting is not allowed and sacrifice of an animal is offered."),
            ("End of Eid Al-Adha", DateComponents(year: currentHijriYear, month: 12, day: 13), "Hajj and Eid end", "Final day of Eid Al-Adha; pilgrims and non-pilgrims return to daily life."),
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
    
    @AppStorage("locationNeverAskAgain") var locationNeverAskAgain = false
    @AppStorage("notificationNeverAskAgain") var notificationNeverAskAgain = false
    @AppStorage("liveNextPrayerEnabled") var liveNextPrayerEnabled: Bool = false {
        didSet { self.fetchPrayerTimes(force: false) }
    }
    @AppStorage("liveActivityLeadMinutes") var liveActivityLeadMinutes: Int = 30 {
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

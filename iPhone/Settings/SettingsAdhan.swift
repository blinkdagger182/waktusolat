import SwiftUI
import CoreLocation
import UserNotifications
import WidgetKit
import Adhan
#if os(iOS)
import UIKit
#endif
#if os(iOS) && canImport(ActivityKit)
import ActivityKit
#endif

#if os(iOS) && canImport(ActivityKit)
@available(iOS 16.2, *)
struct PrayerLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var prayerName: String
        var city: String
        var prayerTime: Date
        var startedAt: Date
    }

    var activityID: String
}

@available(iOS 16.2, *)
@MainActor
final class PrayerLiveActivityCoordinator {
    static let shared = PrayerLiveActivityCoordinator()
    private var startedAtByPrayerKey: [String: Date] = [:]
    private var autoDismissTask: Task<Void, Never>?
    private let reachedPrayerGraceSeconds: TimeInterval = 90

    /// Set by the main app to register the live activity push token with the backend.
    /// Not called by the Widget extension (which also compiles this file).
    var onPushToken: ((_ pushToken: String, _ prayerName: String, _ city: String, _ prayerTime: Date) -> Void)?

    private init() {}

    private func scheduleAutoDismiss(for prayerKey: String, at prayerTime: Date, graceSeconds: TimeInterval? = nil) {
        autoDismissTask?.cancel()
        let delay = max(1, prayerTime.timeIntervalSinceNow + (graceSeconds ?? reachedPrayerGraceSeconds))

        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            guard self.startedAtByPrayerKey.keys.first == prayerKey else { return }
            self.stopAllActivities()
        }
    }

    private func endAll() {
        for activity in Activity<PrayerLiveActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func stopAllActivities() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        startedAtByPrayerKey.removeAll()
        endAll()
    }

    func sync(
        nextPrayer: Prayer?,
        city: String?,
        isFeatureEnabled: Bool
    ) {
        if let existing = Activity<PrayerLiveActivityAttributes>.activities.first {
            let existingPrayerTime = existing.content.state.prayerTime
            let shouldPreserveReachedPrayer = Date() < existingPrayerTime.addingTimeInterval(reachedPrayerGraceSeconds)
            if shouldPreserveReachedPrayer {
                let existingPrayerKey = "\(existing.content.state.prayerName)|\(Int(existingPrayerTime.timeIntervalSince1970))"
                if startedAtByPrayerKey[existingPrayerKey] == nil {
                    startedAtByPrayerKey = [existingPrayerKey: existing.content.state.startedAt]
                }
                scheduleAutoDismiss(for: existingPrayerKey, at: existingPrayerTime)
                return
            }
        }

        guard isFeatureEnabled,
              ActivityAuthorizationInfo().areActivitiesEnabled,
              let nextPrayer,
              let city,
              !city.isEmpty else {
            startedAtByPrayerKey.removeAll()
            endAll()
            return
        }

        let prayerKey = "\(nextPrayer.nameTransliteration)|\(Int(nextPrayer.time.timeIntervalSince1970))"
        let startedAt = startedAtByPrayerKey[prayerKey] ?? Date()
        startedAtByPrayerKey = [prayerKey: startedAt]
        scheduleAutoDismiss(for: prayerKey, at: nextPrayer.time)

        let state = PrayerLiveActivityAttributes.ContentState(
            prayerName: nextPrayer.nameTransliteration,
            city: city,
            prayerTime: nextPrayer.time,
            startedAt: startedAt
        )

        // Mark stale exactly at prayer time so Widget rendering can switch to "It's time..." reliably.
        let staleDate = nextPrayer.time

        if let existing = Activity<PrayerLiveActivityAttributes>.activities.first {
            Task {
                let content = ActivityContent(state: state, staleDate: staleDate)
                await existing.update(content)
            }
            return
        }

        let attributes = PrayerLiveActivityAttributes(activityID: "next-prayer")
        do {
            let content = ActivityContent(state: state, staleDate: staleDate)
            let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
            observePushToken(activity: activity, state: state)
        } catch {
            logger.debug("Live Activity request failed: \(error.localizedDescription)")
        }
    }

    private func observePushToken(
        activity: Activity<PrayerLiveActivityAttributes>,
        state: PrayerLiveActivityAttributes.ContentState
    ) {
        Task {
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                logger.debug("✅ Live Activity push token: \(token)")
                onPushToken?(token, state.prayerName, state.city, state.prayerTime)
            }
        }
    }

    func startDebugActivity(
        city: String,
        prayerName: String = "Test Prayer",
        minutesUntilPrayer: Int = 2,
        debugPrayerTime: Date? = nil
    ) {
        let now = Date()
        let end = debugPrayerTime ?? (Calendar.current.date(byAdding: .minute, value: max(1, minutesUntilPrayer), to: now) ?? now.addingTimeInterval(120))
        let state = PrayerLiveActivityAttributes.ContentState(
            prayerName: prayerName,
            city: city,
            prayerTime: end,
            startedAt: now
        )

        let attributes = PrayerLiveActivityAttributes(activityID: "next-prayer")
        do {
            let content = ActivityContent(state: state, staleDate: end)
            if let existing = Activity<PrayerLiveActivityAttributes>.activities.first {
                Task {
                    await existing.update(content)
                }
            } else {
                let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
                observePushToken(activity: activity, state: state)
            }
        } catch {
            logger.debug("Debug Live Activity request failed: \(error.localizedDescription)")
        }

        // Auto-dismiss debug activity shortly after target time to avoid stale/loader states.
        let autoDismissDelay = max(1, end.timeIntervalSince(now) + 8)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(autoDismissDelay * 1_000_000_000))
            self.stopAllActivities()
        }
    }
}
#endif

extension Settings {
    static let locationManager: CLLocationManager = {
        let lm = CLLocationManager()
        lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
        lm.distanceFilter = 500
        return lm
    }()
    
    private static let geocoder = CLGeocoder()
    private static var cachedPlacemark: (coord: CLLocationCoordinate2D, city: String)?
    private static let geocodeActor = GeocodeActor()
    
    private static let oneMile: CLLocationDistance = 1609.34   // m
    private static let halfMile: CLLocationDistance = 500      // m
    private static let maxAge: TimeInterval = 180              // s
    private static let maxAcceptableAccuracyKnownLocation: CLLocationAccuracy = 800
    private static let maxAcceptableAccuracyFirstFix: CLLocationAccuracy = 1500
    private static let minCoordinateUpdateDistance: CLLocationDistance = 300
    
    private static let travelThresholdM: CLLocationDistance = 48 * oneMile   // ≈ 77 112 m

    private var locationRefreshTimeoutSeconds: TimeInterval { 15 }

    #if os(iOS)
    func configurePassiveLocationMonitoring() {
        let status = Self.locationManager.authorizationStatus

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                Self.locationManager.startMonitoringSignificantLocationChanges()
            }
            Self.locationManager.startMonitoringVisits()
        default:
            Self.locationManager.stopMonitoringSignificantLocationChanges()
            Self.locationManager.stopMonitoringVisits()
        }
    }
    #endif

    private func beginLocationRefresh(using manager: CLLocationManager) {
        locationRefreshTimeoutWorkItem?.cancel()
        isRefreshingLocation = true

        // One-shot can return stale points; keep a short active window for a fresh fix.
        manager.requestLocation()
        manager.startUpdatingLocation()

        let timeout = DispatchWorkItem { [weak self, weak manager] in
            guard let self, let manager else { return }
            self.isRefreshingLocation = false
            manager.stopUpdatingLocation()
        }
        locationRefreshTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + locationRefreshTimeoutSeconds, execute: timeout)
    }

    private func endLocationRefresh(using manager: CLLocationManager) {
        locationRefreshTimeoutWorkItem?.cancel()
        locationRefreshTimeoutWorkItem = nil
        isRefreshingLocation = false
        manager.stopUpdatingLocation()
    }
    
    // AUTHORIZATION CHANGES
    func locationManager(_ mgr: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        #if os(iOS)
        configurePassiveLocationMonitoring()
        #endif

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            showLocationAlert = false
            beginLocationRefresh(using: mgr)
            
        case .denied where !locationNeverAskAgain:
            showLocationAlert = true

        case .restricted, .notDetermined:
            logger.debug("Location authorization is restricted or not determined.")
            break

        default: break
        }
    }
    
    // MAIN LOCATION CALLBACK
    func locationManager(_ mgr: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        let candidates = locs
            .filter { $0.horizontalAccuracy > 0 }
            .filter { abs($0.timestamp.timeIntervalSinceNow) <= Self.maxAge }
            .sorted { $0.horizontalAccuracy < $1.horizontalAccuracy }

        guard let loc = candidates.first else { return }

        let maxAccuracy = (currentLocation == nil)
            ? Self.maxAcceptableAccuracyFirstFix
            : Self.maxAcceptableAccuracyKnownLocation
        guard loc.horizontalAccuracy <= maxAccuracy else { return }

        if let cur = currentLocation {
            let prev = CLLocation(latitude: cur.latitude, longitude: cur.longitude)
            let distance = prev.distance(from: loc)
            let minimumMovement = max(250, min(Self.halfMile, loc.horizontalAccuracy * 1.5))
            if distance < minimumMovement { return }
        }

        Task { @MainActor in
            await updateCity(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            fetchPrayerTimes(force: false)
            endLocationRefresh(using: mgr)
        }
    }

    // ERROR HANDLER
    func locationManager(_ mgr: CLLocationManager, didFailWithError err: Error) {
        logger.error("CLLocationManager failed: \(err.localizedDescription)")
    }

    #if os(iOS)
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard CLLocationCoordinate2DIsValid(visit.coordinate) else { return }

        Task { @MainActor in
            await updateCity(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
            fetchPrayerTimes(force: false)
        }
    }
    #endif

    // PERMISSION REQUEST
    func requestLocationAuthorization() {
        let now = Date()
        if let last = lastLocationAuthorizationRequestAt, now.timeIntervalSince(last) < 2 {
            return
        }
        lastLocationAuthorizationRequestAt = now

        switch Self.locationManager.authorizationStatus {
        case .notDetermined:
            Self.locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            #if os(iOS)
            configurePassiveLocationMonitoring()
            #endif
            beginLocationRefresh(using: Self.locationManager)
        default:
            break
        }
    }
    
    actor GeocodeActor {
        private let gc = CLGeocoder()
        func placemark(for location: CLLocation) async throws -> CLPlacemark? {
            if gc.isGeocoding { gc.cancelGeocode() }
            return try await gc.reverseGeocodeLocation(location).first
        }
    }
    
    /// Reverse‑geocode utilities
    @MainActor
    func updateCity(latitude: Double, longitude: Double, attempt: Int = 0, maxAttempts: Int = 3) async {
        let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        if let cached = Self.cachedPlacemark,
           CLLocation(latitude: cached.coord.latitude, longitude: cached.coord.longitude)
             .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude)) < 100,
           cached.city == currentLocation?.city {
            return
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)

        do {
            guard let placemark = try await Self.geocodeActor.placemark(for: location) else {
                throw CLError(.geocodeFoundNoResult)
            }

            let newCity: String = {
                let cityLike = placemark.locality
                           ?? placemark.subLocality
                           ?? placemark.subAdministrativeArea
                           ?? placemark.name
                let region = placemark.administrativeArea ?? placemark.country
                if let c = cityLike, let r = region { return "\(c), \(r)" }
                if let c = cityLike { return c }
                if let r = region { return r }
                return "(\(latitude.stringRepresentation), \(longitude.stringRepresentation))"
            }()
            let countryCode = placemark.isoCountryCode?.uppercased()

            let movedEnoughForCoordinateUpdate: Bool = {
                guard let currentLocation else { return true }
                let previous = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                return previous.distance(from: location) >= Self.minCoordinateUpdateDistance
            }()

            if newCity != currentLocation?.city
                || countryCode != currentLocation?.countryCode
                || movedEnoughForCoordinateUpdate {
                withAnimation {
                    currentLocation = Location(
                        city: newCity,
                        latitude: latitude,
                        longitude: longitude,
                        countryCode: countryCode
                    )
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }

            Self.cachedPlacemark = (coord, newCity)

        } catch {
            logger.warning("Geocode attempt \(attempt+1) failed: \(error.localizedDescription)")
            guard attempt + 1 < maxAttempts else {
                withAnimation {
                    currentLocation = Location(city: "(\(latitude.stringRepresentation), \(longitude.stringRepresentation))",
                                               latitude: latitude, longitude: longitude, countryCode: nil)
                    WidgetCenter.shared.reloadAllTimelines()
                }
                return
            }
            let delay = UInt64(pow(2.0, Double(attempt)) * 2_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            await updateCity(latitude: latitude, longitude: longitude, attempt: attempt + 1, maxAttempts: maxAttempts)
        }
    }
    
    private static let travelingNotificationId = "WaktuSolat.TravelingMode"

    func checkIfTraveling() {
        guard Bundle.main.bundleIdentifier?.contains("Widget") != true,
              travelAutomatic,
              let currentLocation = currentLocation,
              let homeLocation = homeLocation,
              currentLocation.latitude != 1000,
              currentLocation.longitude != 1000
        else { return }

        let here  = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let home  = CLLocation(latitude: homeLocation.latitude, longitude: homeLocation.longitude)
        let miles = here.distance(from: home) / 1609.34
        let isAway = miles >= 48

        if isAway {
            if !travelingMode {
                withAnimation { travelingMode = true }
                travelTurnOffAutomatic = false
                travelTurnOnAutomatic  = true
                #if !os(watchOS)
                let content = UNMutableNotificationContent()
                content.title = "Waktu Solat"
                content.body  = "Traveling mode automatically turned on at \(currentLocation.city)"
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let req = UNNotificationRequest(identifier: Self.travelingNotificationId, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(req)
                #endif
            }
        } else {
            if travelingMode {
                withAnimation { travelingMode = false }
                travelTurnOnAutomatic  = false
                travelTurnOffAutomatic = true
                #if !os(watchOS)
                let content = UNMutableNotificationContent()
                content.title = "Waktu Solat"
                content.body  = "Traveling mode automatically turned off at \(currentLocation.city)"
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let req = UNNotificationRequest(identifier: Self.travelingNotificationId, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(req)
                #endif
            }
        }
    }
    
    private static let hijriCalendarAR: Calendar = {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.locale = Locale(identifier: "ar")
        return c
    }()

    private static let hijriFormatterAR: DateFormatter = {
        let f = DateFormatter()
        f.calendar = hijriCalendarAR
        f.locale   = Locale(identifier: "ar")
        f.dateFormat = "d MMMM، yyyy"
        return f
    }()

    private static let hijriFormatterEN: DateFormatter = {
        let f = DateFormatter()
        f.calendar = hijriCalendarAR
        f.locale   = Locale(identifier: "en")
        f.dateStyle = .long
        return f
    }()
    
    private static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = .current
        return c
    }()
    
    @inline(__always)
    func arabicNumberString<S: StringProtocol>(from ascii: S) -> String {
        var out = String();  out.reserveCapacity(ascii.count)
        for ch in ascii {
            if let d = ch.asciiDigitValue {
                out.unicodeScalars.append(UnicodeScalar(0x0660 + d)!)   // ٠…٩
            } else {
                out.append(ch)
            }
        }
        return out
    }

    func formatArabicDate(_ date: Date) -> String {
        arabicNumberString(from: DateFormatter.timeAR.string(from: date))
    }

    func formatDate(_ date: Date) -> String {
        DateFormatter.timeEN.string(from: date)
    }
    
    func updateDates() {
        let now = Date()
        let sourcePrayers = prayers?.fullPrayers.isEmpty == false ? prayers?.fullPrayers : prayers?.prayers
        let referenceDate = Settings.islamicReferenceDate(now: now, prayers: sourcePrayers ?? [])

        let effectiveOffset = Settings.effectiveHijriOffset(baseOffset: hijriOffset, location: currentLocation)
        let base = Self.hijriCalendarAR.date(byAdding: .day, value: effectiveOffset, to: referenceDate) ?? referenceDate
        let arabic = arabicNumberString(from: Self.hijriFormatterAR.string(from: base)) + " هـ"
        let english = Self.hijriFormatterEN.string(from: base)

        if let h = hijriDate,
           h.date.isSameDay(as: referenceDate),
           h.english == english,
           h.arabic == arabic {
            return
        }

        withAnimation {
            hijriDate = HijriDate(english: english, arabic: arabic, date: referenceDate)
        }
    }
    
    private struct GPSPrayerDay: Codable {
        let day: Int
        let fajr: TimeInterval
        let syuruk: TimeInterval
        let dhuhr: TimeInterval
        let asr: TimeInterval
        let maghrib: TimeInterval
        let isha: TimeInterval
    }

    private struct GPSMonthResponse: Codable {
        let zone: String
        let location: String?
        let province: String?
        let timezone: String?
        let year: Int
        let month: String?
        let monthNumber: Int
        let prayers: [GPSPrayerDay]

        enum CodingKeys: String, CodingKey {
            case zone
            case regionId = "region_id"
            case location
            case province
            case timezone
            case year
            case month
            case monthNumber = "month_number"
            case prayers
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let zoneValue = try container.decodeIfPresent(String.self, forKey: .zone) {
                zone = zoneValue
            } else {
                zone = try container.decode(String.self, forKey: .regionId)
            }
            location = try container.decodeIfPresent(String.self, forKey: .location)
            province = try container.decodeIfPresent(String.self, forKey: .province)
            timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
            year = try container.decode(Int.self, forKey: .year)
            month = try container.decodeIfPresent(String.self, forKey: .month)

            if let monthNumber = try container.decodeIfPresent(Int.self, forKey: .monthNumber) {
                self.monthNumber = monthNumber
            } else if let month {
                switch month.uppercased() {
                case "JAN": monthNumber = 1
                case "FEB": monthNumber = 2
                case "MAR": monthNumber = 3
                case "APR": monthNumber = 4
                case "MAY": monthNumber = 5
                case "JUN": monthNumber = 6
                case "JUL": monthNumber = 7
                case "AUG": monthNumber = 8
                case "SEP": monthNumber = 9
                case "OCT": monthNumber = 10
                case "NOV": monthNumber = 11
                case "DEC": monthNumber = 12
                default:
                    monthNumber = 0
                }
            } else {
                monthNumber = 0
            }

            prayers = try container.decode([GPSPrayerDay].self, forKey: .prayers)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(zone, forKey: .zone)
            try container.encodeIfPresent(location, forKey: .location)
            try container.encodeIfPresent(province, forKey: .province)
            try container.encodeIfPresent(timezone, forKey: .timezone)
            try container.encode(year, forKey: .year)
            try container.encodeIfPresent(month, forKey: .month)
            try container.encode(monthNumber, forKey: .monthNumber)
            try container.encode(prayers, forKey: .prayers)
        }
    }

    private struct AlAdhanTimings: Codable {
        let fajr: String
        let sunrise: String
        let dhuhr: String
        let asr: String
        let maghrib: String
        let isha: String

        enum CodingKeys: String, CodingKey {
            case fajr = "Fajr"
            case sunrise = "Sunrise"
            case dhuhr = "Dhuhr"
            case asr = "Asr"
            case maghrib = "Maghrib"
            case isha = "Isha"
        }
    }

    private struct AlAdhanGregorianDate: Codable {
        let date: String
    }

    private struct AlAdhanDate: Codable {
        let gregorian: AlAdhanGregorianDate
    }

    private struct AlAdhanMeta: Codable {
        let timezone: String?
    }

    private struct AlAdhanDayResponse: Codable {
        let timings: AlAdhanTimings
        let date: AlAdhanDate
        let meta: AlAdhanMeta?
    }

    private struct AlAdhanMonthResponse: Codable {
        let code: Int
        let status: String
        let data: [AlAdhanDayResponse]
    }

    private enum GPSAPIError: LocalizedError {
        case invalidURL
        case badHTTPStatus(Int)
        case noMonthData

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid GPS endpoint URL."
            case .badHTTPStatus(let status):
                return "GPS API returned HTTP \(status)."
            case .noMonthData:
                return "No cached month data available."
            }
        }
    }

    private enum AlAdhanAPIError: LocalizedError {
        case invalidURL
        case badHTTPStatus(Int)
        case apiError(Int, String)
        case noMonthData

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid AlAdhan endpoint URL."
            case .badHTTPStatus(let status):
                return "AlAdhan API returned HTTP \(status)."
            case .apiError(let code, let status):
                return "AlAdhan API error \(code): \(status)"
            case .noMonthData:
                return "No cached AlAdhan month data available."
            }
        }
    }

    private static let gpsAPIBase = "https://api-waktusolat.vercel.app/v2/solat/gps"
    private static let malaysiaZoneAPIBase = "https://api-waktusolat.vercel.app/v2/solat"
    private static let indonesiaGPSAPIBase = "https://api-waktusolat.vercel.app/indonesia/v1/solat/gps"
    private static let indonesiaRegionAPIBase = "https://api-waktusolat.vercel.app/indonesia/v1/solat"
    private static let alAdhanAPIBase = "https://api.aladhan.com/v1/calendar"
    private static let appGroupId = "group.app.riskcreatives.waktu"
    private static let jakimSupportedYear = 2026
    private static let legacyMonthCacheKey = "waktusolat.gps.month.cache.v1"
    private static let monthCacheKeyPrefix = "waktusolat.gps.month.cache.v2."
    private static var monthCacheInMemory: [String: GPSMonthResponse] = [:]
    private static let alAdhanMonthCacheKeyPrefix = "aladhan.month.cache.v1."
    private static var alAdhanMonthCacheInMemory: [String: AlAdhanMonthResponse] = [:]
    
    private struct NotifPrefs {
        let enabled: ReferenceWritableKeyPath<Settings, Bool>
        let preMinutes: ReferenceWritableKeyPath<Settings, Int>
        let nagging: ReferenceWritableKeyPath<Settings, Bool>
    }
    
    private struct Proto {
        let ar, tr, en, img, rakah, sunnahB, sunnahA: String
    }

    private static let prayerProtos: [String: Proto] = [
        "Fajr":      .init(ar:"الفَجْر",  tr:"Fajr",   en:"Dawn",     img:"sunrise",       rakah:"2", sunnahB:"2", sunnahA:"0"),
        "Sunrise":   .init(ar:"الشُرُوق", tr:"Shurooq",en:"Sunrise",  img:"sunrise.fill",  rakah:"0", sunnahB:"0", sunnahA:"0"),
        "Dhuhr":     .init(ar:"الظُهْر",  tr:"Dhuhr",  en:"Noon",     img:"sun.max",       rakah:"4", sunnahB:"2 and 2", sunnahA:"2"),
        "Asr":       .init(ar:"العَصْر",  tr:"Asr",    en:"Afternoon",img:"sun.min",       rakah:"4", sunnahB:"0", sunnahA:"0"),
        "Maghrib":   .init(ar:"المَغْرِب",tr:"Maghrib",en:"Sunset",   img:"sunset",        rakah:"3", sunnahB:"0", sunnahA:"2"),
        "Isha":      .init(ar:"العِشَاء", tr:"Isha",   en:"Night",    img:"moon",          rakah:"4", sunnahB:"0", sunnahA:"2"),
        // grouped (travel) variants
        "Dhuhr/Asr":     .init(ar:"الظُهْر وَالْعَصْر", tr:"Dhuhr/Asr",   en:"Daytime",   img:"sun.max", rakah:"2 and 2", sunnahB:"0", sunnahA:"0"),
        "Maghrib/Isha":     .init(ar:"المَغْرِب وَالْعِشَاء", tr:"Maghrib/Isha", en:"Nighttime", img:"sunset", rakah:"3 and 2",sunnahB:"0", sunnahA:"0")
    ]
    
    @inline(__always)
    private func prayer(from key: String, time: Date) -> Prayer {
        let p = Self.prayerProtos[key]!
        return Prayer(
            nameArabic: p.ar,
            nameTransliteration: p.tr,
            nameEnglish: p.en,
            time: time,
            image: p.img,
            rakah: p.rakah,
            sunnahBefore: p.sunnahB,
            sunnahAfter: p.sunnahA
        )
    }

    private func appGroupStore() -> UserDefaults? {
        UserDefaults(suiteName: Self.appGroupId)
    }

    private func normalizeCoordinate(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    private func gpsURL(latitude: Double, longitude: Double, for date: Date? = nil) -> URL? {
        guard var components = URLComponents(string: "\(Self.gpsAPIBase)/\(normalizeCoordinate(latitude))/\(normalizeCoordinate(longitude))") else {
            return nil
        }

        if let date {
            let comps = Self.gregorian.dateComponents([.year, .month], from: date)
            guard let year = comps.year, let month = comps.month else {
                return nil
            }
            components.queryItems = [
                URLQueryItem(name: "year", value: String(year)),
                URLQueryItem(name: "month", value: String(month))
            ]
        }

        return components.url
    }

    private func indonesiaGPSURL(latitude: Double, longitude: Double, for date: Date? = nil) -> URL? {
        guard var components = URLComponents(string: "\(Self.indonesiaGPSAPIBase)/\(normalizeCoordinate(latitude))/\(normalizeCoordinate(longitude))") else {
            return nil
        }

        if let date {
            let comps = Self.gregorian.dateComponents([.year, .month], from: date)
            guard let year = comps.year, let month = comps.month else {
                return nil
            }
            components.queryItems = [
                URLQueryItem(name: "year", value: String(year)),
                URLQueryItem(name: "month", value: String(month))
            ]
        }

        return components.url
    }

    private func indonesiaRegionURL(regionId: String, for date: Date? = nil) -> URL? {
        let normalizedRegionId = regionId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRegionId.isEmpty,
              var components = URLComponents(string: "\(Self.indonesiaRegionAPIBase)/\(normalizedRegionId)") else {
            return nil
        }

        if let date {
            let comps = Self.gregorian.dateComponents([.year, .month], from: date)
            guard let year = comps.year, let month = comps.month else {
                return nil
            }
            components.queryItems = [
                URLQueryItem(name: "year", value: String(year)),
                URLQueryItem(name: "month", value: String(month))
            ]
        }

        return components.url
    }
    
    private func malaysiaZoneURL(zone: String, for date: Date? = nil) -> URL? {
        let normalizedZone = zone.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedZone.isEmpty,
              var components = URLComponents(string: "\(Self.malaysiaZoneAPIBase)/\(normalizedZone)") else {
            return nil
        }

        if let date {
            let comps = Self.gregorian.dateComponents([.year, .month], from: date)
            guard let year = comps.year, let month = comps.month else {
                return nil
            }
            components.queryItems = [
                URLQueryItem(name: "year", value: String(year)),
                URLQueryItem(name: "month", value: String(month))
            ]
        }

        return components.url
    }

    private func decodeMonthCache(from data: Data) -> GPSMonthResponse? {
        try? JSONDecoder().decode(GPSMonthResponse.self, from: data)
    }

    private func monthCacheKey(for year: Int, month: Int) -> String {
        "\(Self.monthCacheKeyPrefix)\(year)-\(String(format: "%02d", month))"
    }

    func invalidateMalaysiaZoneState(for date: Date = Date()) {
        UserDefaults.standard.removeObject(forKey: "lastKnownMalaysiaZone")

        let comps = Self.gregorian.dateComponents([.year, .month], from: date)
        guard let year = comps.year, let month = comps.month else { return }

        let key = monthCacheKey(for: year, month: month)
        Self.monthCacheInMemory.removeValue(forKey: key)
        appGroupStore()?.removeObject(forKey: key)
        appGroupStore()?.removeObject(forKey: Self.legacyMonthCacheKey)
    }

    private func loadMonthCache(for date: Date) -> GPSMonthResponse? {
        let comps = Self.gregorian.dateComponents([.year, .month], from: date)
        guard let year = comps.year, let month = comps.month else { return nil }

        let key = monthCacheKey(for: year, month: month)
        if let inMemory = Self.monthCacheInMemory[key] {
            return inMemory
        }

        if let data = appGroupStore()?.data(forKey: key),
           let cached = decodeMonthCache(from: data) {
            Self.monthCacheInMemory[key] = cached
            return cached
        }

        // One-time compatibility fallback with legacy single-month cache.
        if let legacyData = appGroupStore()?.data(forKey: Self.legacyMonthCacheKey),
           let legacy = decodeMonthCache(from: legacyData),
           legacy.year == year,
           legacy.monthNumber == month {
            saveMonthCache(legacy)
            return legacy
        }

        return nil
    }

    private func saveMonthCache(_ month: GPSMonthResponse) {
        let key = monthCacheKey(for: month.year, month: month.monthNumber)
        Self.monthCacheInMemory[key] = month
        guard let data = try? JSONEncoder().encode(month) else { return }
        appGroupStore()?.setValue(data, forKey: key)
        // Keep legacy key warm for compatibility with existing widget/app installs.
        appGroupStore()?.setValue(data, forKey: Self.legacyMonthCacheKey)
        // Persist zone for push notification targeting (Malaysia/SG only)
        if !shouldUseIndonesiaPrayerAPI(for: currentLocation) {
            UserDefaults.standard.set(month.zone, forKey: "lastKnownMalaysiaZone")
            resolvedPrayerArea = nil
        } else {
            UserDefaults.standard.set(month.zone, forKey: "lastKnownIndonesiaRegionId")
            if let location = month.location,
               let province = month.province,
               let timezone = month.timezone {
                resolvedPrayerArea = ResolvedPrayerArea(
                    regionId: month.zone,
                    location: location,
                    province: province,
                    timezone: timezone,
                    resolvedBy: "polygon-or-fallback"
                )
            }
        }
    }

    private func isSameYearMonth(_ date: Date, as month: GPSMonthResponse) -> Bool {
        let comps = Self.gregorian.dateComponents([.year, .month], from: date)
        return comps.year == month.year && comps.month == month.monthNumber
    }

    private func dayPayload(for date: Date) -> GPSPrayerDay? {
        guard let month = loadMonthCache(for: date),
              isSameYearMonth(date, as: month) else {
            return nil
        }
        let day = Self.gregorian.component(.day, from: date)
        return month.prayers.first(where: { $0.day == day })
    }

    static let globalCalculationMethods: [String] = [
        "Auto (By Location)",
        "Islamic Society of North America (ISNA)",
        "Muslim World League",
        "Majlis Ugama Islam Singapura, Singapore",
        "Jabatan Kemajuan Islam Malaysia (JAKIM)",
        "Moonsighting Committee Worldwide",
    ]

    private func alAdhanMethodId(for selection: String) -> Int {
        switch selection {
        case "Auto (By Location)": return recommendedAlAdhanMethodId(countryCode: currentLocation?.countryCode)
        case "Jafari / Shia Ithna-Ashari": return 0
        case "University of Islamic Sciences, Karachi", "Karachi": return 1
        case "Islamic Society of North America (ISNA)", "Islamic Society of North America", "North America": return 2
        case "Muslim World League": return 3
        case "Umm Al-Qura University, Makkah", "Umm Al-Qura": return 4
        case "Egyptian General Authority of Survey", "Egyptian": return 5
        case "Institute of Geophysics, University of Tehran", "Tehran": return 7
        case "Gulf Region": return 8
        case "Kuwait": return 9
        case "Qatar": return 10
        case "Majlis Ugama Islam Singapura, Singapore", "Singapore": return 11
        case "Union Organization islamic de France": return 12
        case "Diyanet İşleri Başkanlığı, Turkey", "Turkey": return 13
        case "Spiritual Administration of Muslims of Russia": return 14
        case "Moonsighting Committee Worldwide", "Moonsighting Committee": return 15
        case "Dubai (experimental)", "Dubai": return 16
        case "Jabatan Kemajuan Islam Malaysia (JAKIM)": return 17
        case "Tunisia": return 18
        case "Algeria": return 19
        case "KEMENAG - Kementerian Agama Republik Indonesia": return 20
        case "Morocco": return 21
        case "Comunidade Islamica de Lisboa": return 22
        case "Ministry of Awqaf, Islamic Affairs and Holy Places, Jordan": return 23
        default: return 3
        }
    }

    private func recommendedAlAdhanMethodId(countryCode: String?) -> Int {
        guard let countryCode else { return 3 }
        switch countryCode.uppercased() {
        case "MY": return 17
        case "SG": return 11
        case "ID": return 20
        case "FR", "GB", "JP", "KR", "CN", "PT", "RU": return 3
        case "US", "CA": return 2
        default: return 3
        }
    }

    private func effectiveAlAdhanMethodId(for location: Location?) -> Int {
        if prayerCalculation == "Auto (By Location)" {
            return recommendedAlAdhanMethodId(countryCode: location?.countryCode)
        }
        return alAdhanMethodId(for: prayerCalculation)
    }

    private func alAdhanURL(
        latitude: Double,
        longitude: Double,
        year: Int,
        month: Int,
        methodId: Int,
        school: Int
    ) -> URL? {
        guard var components = URLComponents(string: "\(Self.alAdhanAPIBase)/\(year)/\(month)") else {
            return nil
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "latitude", value: normalizeCoordinate(latitude)),
            URLQueryItem(name: "longitude", value: normalizeCoordinate(longitude)),
            URLQueryItem(name: "method", value: String(methodId)),
            URLQueryItem(name: "school", value: String(school)),
            URLQueryItem(name: "latitudeAdjustmentMethod", value: "3")
        ]
        if methodId == 15 {
            queryItems.append(URLQueryItem(name: "shafaq", value: "general"))
        }
        components.queryItems = queryItems
        return components.url
    }

    private func alAdhanMonthCacheKey(
        year: Int,
        month: Int,
        latitude: Double,
        longitude: Double,
        methodId: Int,
        school: Int
    ) -> String {
        let lat = normalizeCoordinate(latitude)
        let lon = normalizeCoordinate(longitude)
        return "\(Self.alAdhanMonthCacheKeyPrefix)\(year)-\(String(format: "%02d", month)).\(lat).\(lon).m\(methodId).s\(school)"
    }

    private func loadAlAdhanMonthCache(
        for date: Date,
        latitude: Double,
        longitude: Double,
        methodId: Int,
        school: Int
    ) -> AlAdhanMonthResponse? {
        let comps = Self.gregorian.dateComponents([.year, .month], from: date)
        guard let year = comps.year, let month = comps.month else { return nil }
        let key = alAdhanMonthCacheKey(
            year: year,
            month: month,
            latitude: latitude,
            longitude: longitude,
            methodId: methodId,
            school: school
        )

        if let inMemory = Self.alAdhanMonthCacheInMemory[key] {
            return inMemory
        }
        guard let data = appGroupStore()?.data(forKey: key),
              let cached = try? JSONDecoder().decode(AlAdhanMonthResponse.self, from: data) else {
            return nil
        }
        Self.alAdhanMonthCacheInMemory[key] = cached
        return cached
    }

    private func saveAlAdhanMonthCache(
        _ monthResponse: AlAdhanMonthResponse,
        date: Date,
        latitude: Double,
        longitude: Double,
        methodId: Int,
        school: Int
    ) {
        let comps = Self.gregorian.dateComponents([.year, .month], from: date)
        guard let year = comps.year, let month = comps.month else { return }
        let key = alAdhanMonthCacheKey(
            year: year,
            month: month,
            latitude: latitude,
            longitude: longitude,
            methodId: methodId,
            school: school
        )
        Self.alAdhanMonthCacheInMemory[key] = monthResponse
        guard let data = try? JSONEncoder().encode(monthResponse) else { return }
        appGroupStore()?.setValue(data, forKey: key)
    }

    private func alAdhanDayPayload(
        for date: Date,
        latitude: Double,
        longitude: Double,
        methodId: Int,
        school: Int
    ) -> AlAdhanDayResponse? {
        guard let monthResponse = loadAlAdhanMonthCache(
            for: date,
            latitude: latitude,
            longitude: longitude,
            methodId: methodId,
            school: school
        ) else {
            return nil
        }

        let day = Self.gregorian.component(.day, from: date)
        return monthResponse.data.first { payload in
            let parts = payload.date.gregorian.date.split(separator: "-")
            guard let dayPart = parts.first, let payloadDay = Int(dayPart) else { return false }
            return payloadDay == day
        }
    }

    private func hasAlAdhanDayPayload(for date: Date, location: Location) -> Bool {
        let methodId = effectiveAlAdhanMethodId(for: location)
        let school = hanafiMadhab ? 1 : 0
        return alAdhanDayPayload(
            for: date,
            latitude: location.latitude,
            longitude: location.longitude,
            methodId: methodId,
            school: school
        ) != nil
    }

    private func isLikelyMalaysiaCoordinate(latitude: Double, longitude: Double) -> Bool {
        // Exclude Singapore — its coordinates overlap the peninsular bounding box
        let isSingapore = (latitude >= 1.13 && latitude <= 1.48) && (longitude >= 103.60 && longitude <= 104.10)
        if isSingapore { return false }
        // Peninsular Malaysia
        let west = (latitude >= 0.7 && latitude <= 7.6) && (longitude >= 99.5 && longitude <= 104.7)
        // East Malaysia (Sabah/Sarawak/Labuan)
        let east = (latitude >= 0.7 && latitude <= 7.6) && (longitude >= 109.4 && longitude <= 119.4)
        return west || east
    }

    private var isJAKIMMethodSelected: Bool {
        let normalized = prayerCalculation.lowercased()
        guard normalized.contains("jakim") || normalized == "malaysian prayer times/ jakim" else { return false }
        // JAKIM is only sticky in Malaysia — don't lock users from other countries into the Malaysia path
        if let countryCode = currentLocation?.countryCode?.uppercased(), countryCode != "MY" {
            return false
        }
        return true
    }
    
    private var debugMalaysiaZoneOverride: String? {
        let trimmed = debugMalaysiaZoneCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.uppercased()
    }

    private var debugIndonesiaRegionOverride: String? {
        let trimmed = debugIndonesiaRegionId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func shouldUseIndonesiaPrayerAPI(for location: Location?) -> Bool {
        guard prayerRegionDebugOverride == 0, debugMalaysiaZoneOverride == nil else { return false }
        return location?.countryCode?.uppercased() == "ID"
    }

    func shouldUseMalaysiaPrayerAPI(for location: Location?) -> Bool {
        if debugMalaysiaZoneOverride != nil {
            return true
        }

        // Explicit method selection should always respect JAKIM/Malaysia API,
        // even when debug override was previously forced to Global.
        if isJAKIMMethodSelected {
            return true
        }

        switch prayerRegionDebugOverride {
        case 1:
            return true
        case 2:
            return false
        default:
            break
        }

        guard let location else { return true }
        // Prefer country code when available — coordinate bounding box overlaps Singapore
        if let countryCode = location.countryCode?.uppercased() {
            return countryCode == "MY" || countryCode == "SG"
        }
        return isLikelyMalaysiaCoordinate(latitude: location.latitude, longitude: location.longitude)
    }

    func isDateSupportedByJAKIM(_ date: Date) -> Bool {
        // Indonesia has data for all years — no year restriction applies
        if shouldUseIndonesiaPrayerAPI(for: currentLocation) { return true }
        guard shouldUseMalaysiaPrayerAPI(for: currentLocation) else { return true }
        return Self.gregorian.component(.year, from: date) == Self.jakimSupportedYear
    }

    var supportedJAKIMYear: Int {
        Self.jakimSupportedYear
    }

    private func dateFromUnix(_ value: TimeInterval) -> Date {
        Date(timeIntervalSince1970: value)
    }

    private func fallbackCalculationMethod(for location: Location?) -> CalculationMethod {
        switch effectiveAlAdhanMethodId(for: location) {
        case 1: return .karachi
        case 2: return .northAmerica
        case 3: return .muslimWorldLeague
        case 4: return .ummAlQura
        case 5: return .egyptian
        case 7: return .tehran
        case 8: return .dubai
        case 9: return .kuwait
        case 10: return .qatar
        case 11: return .singapore
        case 12: return .muslimWorldLeague
        case 13: return .turkey
        case 14: return .muslimWorldLeague
        case 15: return .moonsightingCommittee
        case 16: return .dubai
        case 17: return .singapore
        case 18: return .muslimWorldLeague
        case 19: return .muslimWorldLeague
        case 20: return .singapore
        case 21: return .muslimWorldLeague
        case 22: return .muslimWorldLeague
        case 23: return .muslimWorldLeague
        case 0, 6, 99:
            return .muslimWorldLeague
        default:
            return .muslimWorldLeague
        }
    }

    private func getCoordinatePrayerTimes(for date: Date, location: Location, fullPrayers: Bool = false) -> [Prayer]? {
        var params = fallbackCalculationMethod(for: location).params
        params.madhab = hanafiMadhab ? .hanafi : .shafi

        let components = Self.gregorian.dateComponents([.year, .month, .day], from: date)
        let coordinates = Coordinates(latitude: location.latitude, longitude: location.longitude)

        guard let computed = PrayerTimes(
            coordinates: coordinates,
            date: components,
            calculationParameters: params
        ) else {
            return nil
        }

        let baseFajr = computed.fajr
        let baseSunrise = computed.sunrise
        let baseDhuhr = computed.dhuhr
        let baseAsr = computed.asr
        let baseMaghrib = computed.maghrib
        let baseIsha = computed.isha

        let fajr = baseFajr
        let sunrise = baseSunrise
        let dhuhr = baseDhuhr
        let asr = baseAsr
        let maghrib = baseMaghrib
        let isha = baseIsha
        let dhAsr = baseDhuhr
        let mgIsha = baseMaghrib

        let isFriday = Self.gregorian.component(.weekday, from: date) == 6

        if fullPrayers || !travelingMode {
            var list: [Prayer] = [
                prayer(from: "Fajr", time: fajr),
                prayer(from: "Sunrise", time: sunrise),
            ]

            if isFriday {
                list.append(
                    Prayer(
                        nameArabic: "الجُمُعَة",
                        nameTransliteration: "Jumuah",
                        nameEnglish: "Friday",
                        time: dhuhr,
                        image: "sun.max.fill",
                        rakah: "2",
                        sunnahBefore: "0",
                        sunnahAfter: "2 and 2"
                    )
                )
            } else {
                list.append(prayer(from: "Dhuhr", time: dhuhr))
            }

            list += [
                prayer(from: "Asr", time: asr),
                prayer(from: "Maghrib", time: maghrib),
                prayer(from: "Isha", time: isha),
            ]
            return list
        }

        return [
            prayer(from: "Fajr", time: fajr),
            prayer(from: "Sunrise", time: sunrise),
            prayer(from: "Dhuhr/Asr", time: dhAsr),
            prayer(from: "Maghrib/Isha", time: mgIsha),
        ]
    }

    @MainActor
    private func fetchMonthFromAPI(latitude: Double, longitude: Double, for date: Date? = nil) async throws {
        if let zone = debugMalaysiaZoneOverride {
            guard let url = malaysiaZoneURL(zone: zone, for: date) else {
                throw GPSAPIError.invalidURL
            }

            logger.debug("Malaysia API request (zone override): \(url.absoluteString)")

            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            logger.debug("Malaysia API response status (zone override): \(status)")
            guard status == 200 else {
                throw GPSAPIError.badHTTPStatus(status)
            }

            let decoded = try JSONDecoder().decode(GPSMonthResponse.self, from: data)
            logger.debug("Malaysia API decoded payload (zone override): zone=\(decoded.zone), year=\(decoded.year), month=\(decoded.month ?? "nil"), days=\(decoded.prayers.count)")
            saveMonthCache(decoded)
            return
        }

        if let regionId = debugIndonesiaRegionOverride {
            guard let url = indonesiaRegionURL(regionId: regionId, for: date) else {
                throw GPSAPIError.invalidURL
            }

            logger.debug("Indonesia API request (region override): \(url.absoluteString)")

            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            logger.debug("Indonesia API response status (region override): \(status)")
            guard status == 200 else {
                throw GPSAPIError.badHTTPStatus(status)
            }

            let decoded = try JSONDecoder().decode(GPSMonthResponse.self, from: data)
            logger.debug("Indonesia API decoded payload (region override): zone=\(decoded.zone), year=\(decoded.year), month=\(decoded.month ?? "nil"), days=\(decoded.prayers.count)")
            saveMonthCache(decoded)
            return
        }

        let isIndonesia = shouldUseIndonesiaPrayerAPI(for: currentLocation)
        guard let url = isIndonesia
            ? indonesiaGPSURL(latitude: latitude, longitude: longitude, for: date)
            : gpsURL(latitude: latitude, longitude: longitude, for: date)
        else {
            throw GPSAPIError.invalidURL
        }

        logger.debug("\(isIndonesia ? "Indonesia" : "Malaysia") API request (gps): \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        logger.debug("Malaysia API response status (gps): \(status)")
        guard status == 200 else {
            throw GPSAPIError.badHTTPStatus(status)
        }

        let decoded = try JSONDecoder().decode(GPSMonthResponse.self, from: data)
        logger.debug("Malaysia API decoded payload (gps): zone=\(decoded.zone), year=\(decoded.year), month=\(decoded.month ?? "nil"), days=\(decoded.prayers.count)")
        saveMonthCache(decoded)
    }

    @MainActor
    private func fetchMonthFromAlAdhan(latitude: Double, longitude: Double, for date: Date) async throws {
        let comps = Self.gregorian.dateComponents([.year, .month], from: date)
        guard let year = comps.year, let month = comps.month else {
            throw AlAdhanAPIError.invalidURL
        }
        let methodId = effectiveAlAdhanMethodId(for: currentLocation)
        let school = hanafiMadhab ? 1 : 0

        guard let url = alAdhanURL(
            latitude: latitude,
            longitude: longitude,
            year: year,
            month: month,
            methodId: methodId,
            school: school
        ) else {
            throw AlAdhanAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else {
            throw AlAdhanAPIError.badHTTPStatus(status)
        }

        let decoded = try JSONDecoder().decode(AlAdhanMonthResponse.self, from: data)
        guard decoded.code == 200 else {
            throw AlAdhanAPIError.apiError(decoded.code, decoded.status)
        }

        saveAlAdhanMonthCache(
            decoded,
            date: date,
            latitude: latitude,
            longitude: longitude,
            methodId: methodId,
            school: school
        )
    }

    private func parseAlAdhanTime(_ raw: String, on date: Date, timezone: String?) -> Date? {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 5 else { return nil }
        let hhmm = String(clean.prefix(5))
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }

        var calendar = Self.gregorian
        calendar.timeZone = timezone.flatMap(TimeZone.init(identifier:)) ?? .current
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return calendar.date(from: comps)
    }

    private func getAlAdhanPrayerTimes(for date: Date, location: Location, fullPrayers: Bool = false) -> [Prayer]? {
        let methodId = effectiveAlAdhanMethodId(for: location)
        let school = hanafiMadhab ? 1 : 0
        guard let dayResponse = alAdhanDayPayload(
            for: date,
            latitude: location.latitude,
            longitude: location.longitude,
            methodId: methodId,
            school: school
        ) else {
            return nil
        }

        let timezone = dayResponse.meta?.timezone
        guard
            let baseFajr = parseAlAdhanTime(dayResponse.timings.fajr, on: date, timezone: timezone),
            let baseSunrise = parseAlAdhanTime(dayResponse.timings.sunrise, on: date, timezone: timezone),
            let baseDhuhr = parseAlAdhanTime(dayResponse.timings.dhuhr, on: date, timezone: timezone),
            let baseAsr = parseAlAdhanTime(dayResponse.timings.asr, on: date, timezone: timezone),
            let baseMaghrib = parseAlAdhanTime(dayResponse.timings.maghrib, on: date, timezone: timezone),
            let baseIsha = parseAlAdhanTime(dayResponse.timings.isha, on: date, timezone: timezone)
        else {
            return nil
        }

        let fajr = baseFajr
        let sunrise = baseSunrise
        let dhuhr = baseDhuhr
        let asr = baseAsr
        let maghrib = baseMaghrib
        let isha = baseIsha
        let dhAsr = baseDhuhr
        let mgIsha = baseMaghrib

        let isFriday = Self.gregorian.component(.weekday, from: date) == 6

        if fullPrayers || !travelingMode {
            var list: [Prayer] = [
                prayer(from: "Fajr", time: fajr),
                prayer(from: "Sunrise", time: sunrise),
            ]

            if isFriday {
                list.append(
                    Prayer(
                        nameArabic: "الجُمُعَة",
                        nameTransliteration: "Jumuah",
                        nameEnglish: "Friday",
                        time: dhuhr,
                        image: "sun.max.fill",
                        rakah: "2",
                        sunnahBefore: "0",
                        sunnahAfter: "2 and 2"
                    )
                )
            } else {
                list.append(prayer(from: "Dhuhr", time: dhuhr))
            }

            list += [
                prayer(from: "Asr", time: asr),
                prayer(from: "Maghrib", time: maghrib),
                prayer(from: "Isha", time: isha),
            ]
            return list
        }

        return [
            prayer(from: "Fajr", time: fajr),
            prayer(from: "Sunrise", time: sunrise),
            prayer(from: "Dhuhr/Asr", time: dhAsr),
            prayer(from: "Maghrib/Isha", time: mgIsha),
        ]
    }
    
    /// Uses cached GPS endpoint month payload. Returns nil when cache is missing.
    func getPrayerTimes(for date: Date, fullPrayers: Bool = false) -> [Prayer]? {
        if let location = currentLocation,
           !shouldUseMalaysiaPrayerAPI(for: location),
           !shouldUseIndonesiaPrayerAPI(for: location) {
            if let apiBacked = getAlAdhanPrayerTimes(for: date, location: location, fullPrayers: fullPrayers) {
                return apiBacked
            }
            return getCoordinatePrayerTimes(for: date, location: location, fullPrayers: fullPrayers)
        }

        guard let day = dayPayload(for: date) else { return nil }

        let baseFajr = dateFromUnix(day.fajr)
        let baseSunrise = dateFromUnix(day.syuruk)
        let baseDhuhr = dateFromUnix(day.dhuhr)
        let baseAsr = dateFromUnix(day.asr)
        let baseMaghrib = dateFromUnix(day.maghrib)
        let baseIsha = dateFromUnix(day.isha)

        let fajr = baseFajr
        let sunrise = baseSunrise
        let dhuhr = baseDhuhr
        let asr = baseAsr
        let maghrib = baseMaghrib
        let isha = baseIsha
        let dhAsr = baseDhuhr
        let mgIsha = baseMaghrib

        let isFriday = Self.gregorian.component(.weekday, from: date) == 6

        if fullPrayers || !travelingMode {
            var list: [Prayer] = [
                prayer(from: "Fajr", time: fajr),
                prayer(from: "Sunrise", time: sunrise),
            ]

            if isFriday {
                list.append(
                    Prayer(
                        nameArabic: "الجُمُعَة",
                        nameTransliteration: "Jumuah",
                        nameEnglish: "Friday",
                        time: dhuhr,
                        image: "sun.max.fill",
                        rakah: "2",
                        sunnahBefore: "0",
                        sunnahAfter: "2 and 2"
                    )
                )
            } else {
                list.append(prayer(from: "Dhuhr", time: dhuhr))
            }

            list += [
                prayer(from: "Asr", time: asr),
                prayer(from: "Maghrib", time: maghrib),
                prayer(from: "Isha", time: isha),
            ]
            return list
        }

        return [
            prayer(from: "Fajr", time: fajr),
            prayer(from: "Sunrise", time: sunrise),
            prayer(from: "Dhuhr/Asr", time: dhAsr),
            prayer(from: "Maghrib/Isha", time: mgIsha),
        ]
    }

    @MainActor
    func refreshDatePrayers(for date: Date) async {
        let usesIndonesiaPipeline = shouldUseIndonesiaPrayerAPI(for: currentLocation)
        let usesMalaysiaPipeline = shouldUseMalaysiaPrayerAPI(for: currentLocation)
        let usesZonePipeline = usesMalaysiaPipeline || usesIndonesiaPipeline

        guard isDateSupportedByJAKIM(date) else {
            datePrayers = []
            dateFullPrayers = []
            return
        }

        if let loc = currentLocation,
           loc.latitude != 1000,
           loc.longitude != 1000,
           Bundle.main.bundleIdentifier?.contains("Widget") != true {
            let missingDayData = usesZonePipeline
                ? (dayPayload(for: date) == nil)
                : !hasAlAdhanDayPayload(for: date, location: loc)
            guard missingDayData else {
                datePrayers = getPrayerTimes(for: date) ?? []
                dateFullPrayers = getPrayerTimes(for: date, fullPrayers: true) ?? []
                return
            }
            do {
                if usesZonePipeline {
                    try await fetchMonthFromAPI(latitude: loc.latitude, longitude: loc.longitude, for: date)
                } else {
                    try await fetchMonthFromAlAdhan(latitude: loc.latitude, longitude: loc.longitude, for: date)
                }
            } catch {
                logger.error("Date prayer refresh fetch failed: \(error.localizedDescription)")
            }
        }

        datePrayers = getPrayerTimes(for: date) ?? []
        dateFullPrayers = getPrayerTimes(for: date, fullPrayers: true) ?? []
    }

    func fetchPrayerTimes(force: Bool = false, notification: Bool = false, calledFrom: StaticString = #function, completion: (() -> Void)? = nil) {
        updateDates()
        
        guard let loc = currentLocation, loc.latitude  != 1000, loc.longitude != 1000 else {
            logger.debug("No valid location – skip refresh")
            completion?()
            return
        }
        
        if force || loc.city.contains("(") {
            Task { @MainActor in
                await updateCity(latitude: loc.latitude, longitude: loc.longitude)
            }
        }
        
        let isWidget = Bundle.main.bundleIdentifier?.contains("Widget") == true
        if !isWidget, travelAutomatic, homeLocation != nil, !travelingModeManuallyToggled {
            travelingModeManuallyToggled = false
            checkIfTraveling()
        } else if travelingModeManuallyToggled {
            travelingModeManuallyToggled = false
        }
        
        // Decide if we need fresh prayers
        let today      = Date()
        let stored     = prayers
        let usesIndonesiaPipeline = shouldUseIndonesiaPrayerAPI(for: loc)
        let usesMalaysiaPipeline = shouldUseMalaysiaPrayerAPI(for: loc)
        let usesZonePipeline = usesMalaysiaPipeline || usesIndonesiaPipeline
        let unresolvedIndonesiaZone = usesIndonesiaPipeline && resolvedPrayerArea == nil
        let staleCity  = unresolvedIndonesiaZone || stored?.city != currentPrayerAreaName
        let staleDate  = !(stored?.day.isSameDay(as: today) ?? false)
        let emptyList  = stored?.prayers.isEmpty ?? true
        let missingCacheForToday = usesZonePipeline
            ? (dayPayload(for: today) == nil)
            : !hasAlAdhanDayPayload(for: today, location: loc)
        let needsRefresh = force || stored == nil || staleCity || staleDate || emptyList
        let needsNetworkFetch = force || missingCacheForToday || unresolvedIndonesiaZone
        let needsFetch = needsRefresh || needsNetworkFetch
        
        if needsFetch {
            if isWidget {
                logger.debug("Widget context detected; using cached prayersData only")
                if let todayPrayers = getPrayerTimes(for: today),
                   let fullPrayers = getPrayerTimes(for: today, fullPrayers: true) {
                    prayers = Prayers(
                        day: today,
                        city: currentPrayerAreaName ?? loc.city,
                        prayers: todayPrayers,
                        fullPrayers: fullPrayers,
                        setNotification: false
                    )
                }
                updateCurrentAndNextPrayer()
                completion?()
                return
            }

            if !usesZonePipeline {
                if needsNetworkFetch {
                    logger.debug("Fetching prayer times from AlAdhan API – caller: \(calledFrom)")
                } else {
                    logger.debug("Using cached AlAdhan month data – caller: \(calledFrom)")
                }

                Task { @MainActor in
                    if needsNetworkFetch {
                        do {
                            try await fetchMonthFromAlAdhan(latitude: loc.latitude, longitude: loc.longitude, for: today)
                            logger.debug("AlAdhan API prayer month fetched successfully")
                        } catch {
                            logger.error("AlAdhan API fetch failed. Falling back to local Adhan calculation: \(error.localizedDescription)")
                        }
                    }

                    let todayPrayers = getPrayerTimes(for: today)
                    let fullPrayers = getPrayerTimes(for: today, fullPrayers: true)

                    if let todayPrayers, let fullPrayers {
                        prayers = Prayers(
                            day: today,
                            city: currentPrayerAreaName ?? loc.city,
                            prayers: todayPrayers,
                            fullPrayers: fullPrayers,
                            setNotification: false
                        )
                    }

                    schedulePrayerTimeNotifications()
                    printAllScheduledNotifications()
                    WidgetCenter.shared.reloadAllTimelines()
                    updateCurrentAndNextPrayer()
                    completion?()
                }
                return
            }

            if needsNetworkFetch {
                logger.debug("Fetching prayer times from GPS API – caller: \(calledFrom)")
            } else {
                logger.debug("Using cached GPS month data – caller: \(calledFrom)")
            }

            Task { @MainActor in
                if needsNetworkFetch {
                    do {
                        try await fetchMonthFromAPI(latitude: loc.latitude, longitude: loc.longitude, for: today)
                        logger.debug("GPS API prayer month fetched successfully")
                    } catch {
                        logger.error("GPS API fetch failed. Falling back to cached prayers data: \(error.localizedDescription)")
                    }
                }

                let todayPrayers = getPrayerTimes(for: today)
                let fullPrayers = getPrayerTimes(for: today, fullPrayers: true)

                if let todayPrayers, let fullPrayers {
                    prayers = Prayers(
                        day: today,
                        city: currentPrayerAreaName ?? loc.city,
                        prayers: todayPrayers,
                        fullPrayers: fullPrayers,
                        setNotification: false
                    )
                } else if prayers == nil {
                    logger.error("\(GPSAPIError.noMonthData.localizedDescription)")
                }

                schedulePrayerTimeNotifications()
                printAllScheduledNotifications()
                WidgetCenter.shared.reloadAllTimelines()
                updateCurrentAndNextPrayer()
                completion?()
            }
            return
        } else if notification {
            schedulePrayerTimeNotifications()
            printAllScheduledNotifications()
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        updateCurrentAndNextPrayer()
        completion?()
    }
    
    func updateCurrentAndNextPrayer() {
        guard let p = prayers?.prayers, !p.isEmpty else {
            logger.debug("No prayer list to compute current/next")
            syncLiveNextPrayerActivity()
            return
        }

        let now = Date()

        let nextIdx = p.firstIndex { $0.time > now }

        if let i = nextIdx {
            nextPrayer = p[i]
            currentPrayer = i == 0 ? p.last : p[i-1]
        } else {
            // past last prayer – peek at tomorrow for “next”
            currentPrayer = p.last
            if let tmr = Calendar.current.date(byAdding: .day, value: 1, to: now),
               let firstTomorrow = getPrayerTimes(for: tmr)?.first {
                nextPrayer = firstTomorrow
            } else {
                nextPrayer = nil
            }
        }

        syncLiveNextPrayerActivity()
    }

    private func isNotificationEnabled(for prayer: Prayer?) -> Bool {
        guard let prayer else { return false }
        switch prayer.nameTransliteration {
        case "Fajr":
            return notificationFajr
        case "Shurooq":
            return notificationSunrise
        case "Dhuhr", "Jumuah", "Dhuhr/Asr":
            return notificationDhuhr
        case "Asr":
            return notificationAsr
        case "Maghrib", "Maghrib/Isha":
            return notificationMaghrib
        case "Isha":
            return notificationIsha
        default:
            return false
        }
    }

    private func isLiveActivityPrayerEnabled(for prayer: Prayer?) -> Bool {
        guard let prayer else { return false }
        switch prayer.nameTransliteration {
        case "Fajr":
            return liveActivityFajrEnabled
        case "Shurooq":
            return liveActivitySunriseEnabled
        case "Dhuhr", "Jumuah":
            return liveActivityDhuhrEnabled
        case "Asr":
            return liveActivityAsrEnabled
        case "Maghrib":
            return liveActivityMaghribEnabled
        case "Isha":
            return liveActivityIshaEnabled
        case "Dhuhr/Asr":
            return liveActivityDhuhrAsrEnabled
        case "Maghrib/Isha":
            return liveActivityMaghribIshaEnabled
        default:
            return false
        }
    }

    private func isWithinLiveActivityLeadWindow(for prayer: Prayer?) -> Bool {
        guard let prayer else { return false }
        let leadMinutes = max(0, liveActivityLeadMinutes)
        let threshold = prayer.time.addingTimeInterval(-Double(leadMinutes) * 60)
        return Date() >= threshold
    }

    private func syncLiveNextPrayerActivity() {
        #if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            let next = nextPrayer
            let city = currentPrayerAreaName
            let enabled = liveNextPrayerEnabled
            let prayerEnabled = isLiveActivityPrayerEnabled(for: nextPrayer)
            let inWindow = isWithinLiveActivityLeadWindow(for: nextPrayer)
            // Keep a running push-to-start activity alive even if we're outside the
            // normal lead window — tapping the notification opens the app before the
            // window starts, and we must not kill the activity until prayer time passes.
            let hasRunning = !Activity<PrayerLiveActivityAttributes>.activities.isEmpty
            let prayerNotPassed = next.map { Date() < $0.time } ?? false
            let hasReachedPrayerStillVisible = Activity<PrayerLiveActivityAttributes>.activities.contains {
                Date() < $0.content.state.prayerTime.addingTimeInterval(90)
            }
            Task { @MainActor in
                PrayerLiveActivityCoordinator.shared.sync(
                    nextPrayer: next,
                    city: city,
                    isFeatureEnabled: enabled && (hasReachedPrayerStillVisible || (prayerEnabled && (inWindow || (hasRunning && prayerNotPassed))))
                )
            }
        }
        #endif
    }

    func shouldRegisterPushToStartTokenNow(now: Date = Date()) -> Bool {
        guard liveNextPrayerEnabled,
              let prayer = nextPrayer,
              isLiveActivityPrayerEnabled(for: prayer) else {
            return false
        }

        let leadMinutes = max(0, liveActivityLeadMinutes)
        let threshold = prayer.time.addingTimeInterval(-Double(leadMinutes) * 60)
        return now >= threshold && now < prayer.time
    }

    /// Best-effort trigger date used by background refresh scheduling to keep
    /// Live Activity in sync even when the app is not foregrounded.
    func nextLiveActivityTriggerDate(from now: Date = Date()) -> Date? {
        guard liveNextPrayerEnabled else { return nil }

        guard
            let upcoming = prayers?.prayers
                .sorted(by: { $0.time < $1.time })
                .first(where: { $0.time > now }),
            isLiveActivityPrayerEnabled(for: upcoming)
        else {
            return nil
        }

        let leadMinutes = max(0, liveActivityLeadMinutes)
        return upcoming.time.addingTimeInterval(-Double(leadMinutes) * 60)
    }

    #if os(iOS)
    func configureLiveActivitySyncLifecycle() {
        guard liveActivityLifecycleObservers.isEmpty else { return }

        let center = NotificationCenter.default
        liveActivityLifecycleObservers = [
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.startLiveActivitySyncTimer()
                self?.updateCurrentAndNextPrayer()
            },
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.stopLiveActivitySyncTimer()
            },
            center.addObserver(
                forName: UIApplication.significantTimeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateCurrentAndNextPrayer()
            },
            center.addObserver(
                forName: .NSCalendarDayChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateCurrentAndNextPrayer()
            }
        ]

        startLiveActivitySyncTimer()
    }

    private func nextLiveActivitySyncInterval() -> TimeInterval {
        guard liveNextPrayerEnabled,
              let prayer = nextPrayer,
              isLiveActivityPrayerEnabled(for: prayer) else {
            return 300
        }

        let now = Date()
        let leadMinutes = max(0, liveActivityLeadMinutes)
        let threshold = prayer.time.addingTimeInterval(-Double(leadMinutes) * 60)
        let secondsToThreshold = threshold.timeIntervalSince(now)
        let secondsToPrayer = prayer.time.timeIntervalSince(now)

        if secondsToPrayer <= 0 {
            return 30
        }

        if secondsToThreshold > 3600 {
            return 300
        }
        if secondsToThreshold > 900 {
            return 120
        }
        if secondsToThreshold > 300 {
            return 60
        }
        if secondsToThreshold > 0 {
            return 30
        }

        // Already inside lead window.
        if secondsToPrayer > 300 {
            return 30
        }
        return 15
    }

    private func startLiveActivitySyncTimer() {
        stopLiveActivitySyncTimer()
        let interval = nextLiveActivitySyncInterval()
        liveActivitySyncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.updateCurrentAndNextPrayer()
            self?.startLiveActivitySyncTimer()
        }
        if let timer = liveActivitySyncTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopLiveActivitySyncTimer() {
        liveActivitySyncTimer?.invalidate()
        liveActivitySyncTimer = nil
    }
    #endif

    func startDebugLiveNextPrayerActivity(
        prayerName: String = "Test Prayer",
        minutesUntilPrayer: Int = 2,
        debugPrayerTime: Date? = nil
    ) {
        #if DEBUG && os(iOS) && canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        let city = currentPrayerAreaName ?? currentLocation?.city ?? "Current Location"
        Task { @MainActor in
            PrayerLiveActivityCoordinator.shared.startDebugActivity(
                city: city,
                prayerName: prayerName,
                minutesUntilPrayer: minutesUntilPrayer,
                debugPrayerTime: debugPrayerTime
            )
        }
        #endif
    }

    func stopDebugLiveNextPrayerActivity() {
        #if DEBUG && os(iOS) && canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        Task { @MainActor in
            PrayerLiveActivityCoordinator.shared.stopAllActivities()
        }
        #endif
    }
    
    @MainActor
    func requestNotificationAuthorization() async -> Bool {
        #if os(watchOS)
        return true
        #else
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus

        switch status {
        case .authorized:
            showNotificationAlert = false
            return true

        case .denied:
            showNotificationAlert = !notificationNeverAskAgain
            logger.debug("Notification permission denied")
            return false

        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                showNotificationAlert = !granted && !notificationNeverAskAgain
                if granted {
                    // Register for APNs push token now that permission is granted and
                    // the UI is ready. Routed via callback so extension targets compile.
                    DispatchQueue.main.async {
                        Settings.registerForRemoteNotificationsHandler?()
                    }
                    fetchPrayerTimes(notification: true)
                }
                return granted
            } catch {
                logger.error("Notification request failed: \(error.localizedDescription)")
                showNotificationAlert = !notificationNeverAskAgain
                return false
            }

        default:
            return false
        }
        #endif
    }
    
    func requestNotificationAuthorization(completion: (() -> Void)? = nil) {
        Task { @MainActor in
            _ = await requestNotificationAuthorization()
            completion?()
        }
    }
    
    func printAllScheduledNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { (requests) in
            for request in requests {
                logger.debug("\(request.content.body)")
            }
        }
    }

    /// Normalises Malaysian API names ("Subuh", "Syuruk", "Zuhur", "Asar", "Isyak")
    /// to the canonical English keys used in notifTable.
    static func canonicalPrayerName(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
        case "subuh":                    return "Fajr"
        case "syuruk", "shurooq":        return "Shurooq"
        case "zuhur":                    return "Dhuhr"
        case "asar":                     return "Asr"
        case "isyak", "isya":            return "Isha"
        default:                         return raw
        }
    }

    /// Static lookup table
    private static let notifTable: [String: NotifPrefs] = [
        "Fajr":          .init(enabled: \.notificationFajr,  preMinutes: \.preNotificationFajr,  nagging: \.naggingFajr),
        "Shurooq":       .init(enabled: \.notificationSunrise, preMinutes: \.preNotificationSunrise, nagging: \.naggingSunrise),
        "Dhuhr":         .init(enabled: \.notificationDhuhr, preMinutes: \.preNotificationDhuhr, nagging: \.naggingDhuhr),
        "Dhuhr/Asr":     .init(enabled: \.notificationDhuhr, preMinutes: \.preNotificationDhuhr, nagging: \.naggingDhuhr),
        "Jumuah":        .init(enabled: \.notificationDhuhr, preMinutes: \.preNotificationDhuhr, nagging: \.naggingDhuhr),
        "Asr":           .init(enabled: \.notificationAsr,   preMinutes: \.preNotificationAsr,   nagging: \.naggingAsr),
        "Maghrib":       .init(enabled: \.notificationMaghrib, preMinutes: \.preNotificationMaghrib, nagging: \.naggingMaghrib),
        "Maghrib/Isha":  .init(enabled: \.notificationMaghrib, preMinutes: \.preNotificationMaghrib, nagging: \.naggingMaghrib),
        "Isha":          .init(enabled: \.notificationIsha,  preMinutes: \.preNotificationIsha,  nagging: \.naggingIsha)
    ]

    /// Pre‑computes the full list of minutes‑before offsets for a prayer.
    private func offsets(for prefs: NotifPrefs) -> [Int] {
        var result: [Int] = []

        // “at time” alert
        if self[keyPath: prefs.enabled] { result.append(0) }

        // user‑defined single offset
        let minutes = self[keyPath: prefs.preMinutes]
        if self[keyPath: prefs.enabled], minutes > 0 {
            result.append(minutes)
        }

        // nagging offsets (if globally on *and* per‑prayer nagging on)
        if naggingMode && self[keyPath: prefs.nagging] {
            result += naggingCascade(start: naggingStartOffset)
        }
        return result
    }

    /// Generates exponential‑type cascade: 30,15,10,5 (by default)
    private func naggingCascade(start: Int) -> [Int] {
        guard start > 0 else { return [] }
        var m = start
        var out: [Int] = []
        while m > 15 { out.append(m); m -= 15 }
        if m >= 5  { out.append(m) }
        out += [10,5].filter { $0 < start }
        return out
    }

    private func scheduleRefreshNag(
        inDays offset: Int = 2,
        hour: Int = 12,
        minute: Int = 0,
        using center: UNUserNotificationCenter = .current()
    ) {
        guard let day = Calendar.current.date(byAdding: .day, value: offset, to: Date()) else { return }

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute

        guard (Calendar.current.date(from: comps) ?? Date.distantPast) > Date() else { return }

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Waktu Solat"
        content.body  = "Please open the app to refresh today’s prayer times and notifications."
        content.sound = .default

        // Unique per-day id so we don’t collide across days
        let id = String(format: "RefreshReminder-%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)

        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(req) { error in
            if let error { logger.debug("Refresh reminder add failed: \(error.localizedDescription)") }
        }
    }

    func schedulePrayerTimeNotifications() {
        #if os(watchOS)
        return
        #else
        guard let city = currentPrayerAreaName ?? currentLocation?.city, let prayerObj = prayers
        else { return }

        let scheduleDay = Calendar.current.startOfDay(for: prayerObj.day).timeIntervalSince1970
        let prayerTimesSignature = prayerObj.prayers
            .map { "\($0.nameTransliteration)=\(Int($0.time.timeIntervalSince1970 / 60))" }
            .joined(separator: ",")

        let scheduleSignature = [
            "day:\(Int(scheduleDay))",
            "city:\(city)",
            "times:\(prayerTimesSignature)",
            "dateNotif:\(dateNotifications)",
            "nagMode:\(naggingMode)",
            "nagStart:\(naggingStartOffset)",
            "f:\(notificationFajr)-\(preNotificationFajr)-\(naggingFajr)",
            "s:\(notificationSunrise)-\(preNotificationSunrise)-\(naggingSunrise)",
            "d:\(notificationDhuhr)-\(preNotificationDhuhr)-\(naggingDhuhr)",
            "a:\(notificationAsr)-\(preNotificationAsr)-\(naggingAsr)",
            "m:\(notificationMaghrib)-\(preNotificationMaghrib)-\(naggingMaghrib)",
            "i:\(notificationIsha)-\(preNotificationIsha)-\(naggingIsha)"
        ].joined(separator: "|")

        if let lastSig = lastNotificationScheduleSignature,
           lastSig == scheduleSignature {
            // Do not clear/re-add identical schedules; this can cause missed alerts near trigger time.
            return
        }

        lastNotificationScheduleSignature = scheduleSignature
        lastNotificationScheduleAt = Date()

        logger.debug("Scheduling prayer time notifications")
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        
        if dateNotifications {
            for event in specialEvents {
                scheduleNotification(for: event)
            }
        }

        for prayer in prayerObj.prayers {
            guard let prefs = Self.notifTable[Self.canonicalPrayerName(prayer.nameTransliteration)] else { continue }

            for minutes in offsets(for: prefs) {
                scheduleNotification(
                    for: prayer,
                    preNotificationTime: minutes == 0 ? nil : minutes,
                    city: city
                )
            }
        }
        
        let futureDays = naggingMode ? 1 : 3
        if futureDays > 0 {
            for dayOffset in 1...futureDays {
                let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: prayerObj.day) ?? Date()
                guard let list = getPrayerTimes(for: date) else { continue }
                
                for prayer in list {
                    guard let prefs = Self.notifTable[Self.canonicalPrayerName(prayer.nameTransliteration)] else { continue }
                    
                    for minutes in offsets(for: prefs) {
                        scheduleNotification(
                            for: prayer,
                            preNotificationTime: minutes == 0 ? nil : minutes,
                            city: city
                        )
                    }
                }
            }
        }

        if naggingMode {
            scheduleRefreshNag(inDays: 1, using: center)
        }
        scheduleRefreshNag(inDays: 2, using: center)
        scheduleRefreshNag(inDays: 3, using: center)
        
        prayers?.setNotification = true
        #endif
    }
    
    private func buildBody(prayer: Prayer, minutesBefore: Int?, city: String) -> String {
        let englishPart: String = {
            switch prayer.nameTransliteration {
            case "Shurooq":
                return " (end of Fajr)"
            case "Jumuah":
                return " (Friday)"
            default:
                return ""
            }
        }()

        if let m = minutesBefore {
            // “n m until …”
            return "\(m)m until \(prayer.nameTransliteration)\(englishPart) in \(city)"
                 + (travelingMode ? " (traveling)" : "")
                 + " [\(formatDate(prayer.time))]"
        } else if prayer.nameTransliteration == "Fajr",
                  let list = prayers?.prayers, list.count > 1 {
            // Special Fajr “ends at …” text
            return "Time for \(prayer.nameTransliteration)\(englishPart)"
                 + " at \(formatDate(prayer.time)) in \(city)"
                 + (travelingMode ? " (traveling)" : "")
                 + " [ends at \(formatDate(list[1].time))]"
        } else {
            return "Time for \(prayer.nameTransliteration)\(englishPart)"
                 + " at \(formatDate(prayer.time)) in \(city)"
                 + (travelingMode ? " (traveling)" : "")
        }
    }

    private func availableSoundName(candidates: [String]) -> UNNotificationSoundName? {
        for name in candidates {
            let ns = name as NSString
            let base = ns.deletingPathExtension
            let ext = ns.pathExtension
            guard !base.isEmpty, !ext.isEmpty else { continue }
            if Bundle.main.url(forResource: base, withExtension: ext) != nil {
                return UNNotificationSoundName(rawValue: name)
            }
        }
        return nil
    }

    private func prayerNotificationSound(for prayer: Prayer, minutesBefore: Int?) -> UNNotificationSound {
        if prayer.nameTransliteration == "Shurooq" {
            return .default
        }

        if let minutesBefore, minutesBefore > 0 {
            return .default
        }

        switch notificationSoundOption {
        case .iosDefault:
            return .default
        case .azan:
            let candidates = ["azan_waktu.mp3"]
            if let name = availableSoundName(candidates: candidates) {
                return UNNotificationSound(named: name)
            }
            return .default
        }
    }

    func scheduleNotification(for prayer: Prayer, preNotificationTime minutes: Int?, city: String, using center: UNUserNotificationCenter = .current()) {
        let triggerTime: Date = {
            if let m = minutes, m != 0 {
                return Calendar.current.date(byAdding: .minute, value: -m, to: prayer.time) ?? prayer.time
            }
            return prayer.time
        }()
        let now = Date()
        if triggerTime <= now {
            // If we rescheduled right around the threshold, still deliver an immediate alert.
            guard now.timeIntervalSince(triggerTime) <= 90 else { return }
        }

        let content = UNMutableNotificationContent()
        content.title = "Waktu Solat"
        content.body = buildBody(prayer: prayer, minutesBefore: minutes, city: city)
        content.sound = prayerNotificationSound(for: prayer, minutesBefore: minutes)

        let id: String
        let trigger: UNNotificationTrigger
        if triggerTime > now {
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerTime)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            id = "\(prayer.nameTransliteration)-\(minutes ?? 0)-\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let day = Calendar.current.dateComponents([.year, .month, .day], from: now)
            id = "\(prayer.nameTransliteration)-\(minutes ?? 0)-late-\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
        }
        let req  = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(req) { error in
            if let error { logger.debug("Notification add failed: \(error.localizedDescription)") }
        }
    }
    
    func scheduleNotification(for event: (String, DateComponents, String, String)) {
        let (titleText, hijriComps, eventSubTitle, _) = event
        
        if let hijriDate = hijriCalendar.date(from: hijriComps) {
            let gregorianCalendar = Calendar(identifier: .gregorian)
            var gregorianComps = gregorianCalendar.dateComponents([.year, .month, .day], from: hijriDate)
            gregorianComps.hour = 9
            gregorianComps.minute = 0
            
            guard
                let finalDate = gregorianCalendar.date(from: gregorianComps),
                finalDate > Date()
            else {
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "Waktu Solat"
            content.body = "\(titleText) (\(eventSubTitle))"
            content.sound = .default
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: gregorianComps, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    logger.debug("Failed to schedule special event notification: \(error)")
                }
            }
        }
    }
    
    @inline(__always)
    private func binding<T>(_ key: ReferenceWritableKeyPath<Settings, T>, default value: T) -> Binding<T> {
        Binding(
            get: { self[keyPath: key] },
            set: { self[keyPath: key] = $0 }
        )
    }

    func currentNotification(prayerTime: Prayer) -> Binding<Bool> {
        guard let prefs = Self.notifTable[Self.canonicalPrayerName(prayerTime.nameTransliteration)] else {
            return .constant(false)
        }
        return binding(prefs.enabled, default: false)
    }

    func currentPreNotification(prayerTime: Prayer) -> Binding<Int> {
        guard let prefs = Self.notifTable[Self.canonicalPrayerName(prayerTime.nameTransliteration)] else {
            return .constant(0)
        }
        return binding(prefs.preMinutes, default: 0)
    }

    func shouldShowFilledBell(prayerTime: Prayer) -> Bool {
        guard let prefs = Self.notifTable[Self.canonicalPrayerName(prayerTime.nameTransliteration)] else { return false }
        // Filled bell = both notifications are active:
        // 1) exact prayer-time notification (enabled == true), and
        // 2) pre-notification before prayer (preMinutes > 0).
        return self[keyPath: prefs.enabled] && self[keyPath: prefs.preMinutes] > 0
    }

    func shouldShowOutlinedBell(prayerTime: Prayer) -> Bool {
        guard let prefs = Self.notifTable[Self.canonicalPrayerName(prayerTime.nameTransliteration)] else { return false }
        // Outlined bell = exact prayer-time notification only (no pre-notification).
        return self[keyPath: prefs.enabled] && self[keyPath: prefs.preMinutes] == 0
    }
}

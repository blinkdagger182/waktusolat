import Foundation
import Combine
import WidgetKit
#if canImport(WatchConnectivity)
import WatchConnectivity

@MainActor
final class WatchConnectivitySyncManager: NSObject, ObservableObject, WCSessionDelegate {
    private enum Keys {
        static let prayersData = "watchSnapshot.prayersData"
        static let locationData = "watchSnapshot.locationData"
        static let prayerCalculation = "watchSnapshot.prayerCalculation"
        static let accentColor = "watchSnapshot.accentColor"
        static let appLanguageCode = "watchSnapshot.appLanguageCode"
        static let monthCacheData = "watchSnapshot.monthCacheData"
        static let monthCacheKey = "watchSnapshot.monthCacheKey"
        static let requestSync = "watchSnapshot.requestSync"
    }

    @Published private(set) var lastAppliedAt: Date?

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private let defaults = UserDefaults(suiteName: watchSharedAppGroupID)
    var onSnapshotApplied: (() -> Void)?

    override init() {
        super.init()
    }

    func activate() {
        guard let session else { return }
        guard session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }

    func requestSyncIfPossible() {
        guard let session else { return }
        guard session.isReachable else { return }
        session.sendMessage([Keys.requestSync: true], replyHandler: nil, errorHandler: nil)
    }

    private func applyContext(_ context: [String: Any]) {
        if let prayersData = context[Keys.prayersData] as? Data {
            defaults?.set(prayersData, forKey: "prayersData")
        }

        if let locationData = context[Keys.locationData] as? Data {
            defaults?.set(locationData, forKey: "currentLocation")
        }

        if let prayerCalculation = context[Keys.prayerCalculation] as? String {
            defaults?.set(prayerCalculation, forKey: "prayerCalculation")
        }

        if let accentColor = context[Keys.accentColor] as? String {
            defaults?.set(accentColor, forKey: "accentColor")
        }

        if let appLanguageCode = context[Keys.appLanguageCode] as? String {
            defaults?.set(appLanguageCode, forKey: "appLanguageCode")
        }

        if
            let monthCacheData = context[Keys.monthCacheData] as? Data,
            let monthCacheKey = context[Keys.monthCacheKey] as? String
        {
            defaults?.set(monthCacheData, forKey: monthCacheKey)
            defaults?.set(monthCacheData, forKey: "waktusolat.gps.month.cache.v1")
        }

        lastAppliedAt = Date()
        onSnapshotApplied?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }

        Task { @MainActor in
            if !session.receivedApplicationContext.isEmpty {
                self.applyContext(session.receivedApplicationContext)
            } else {
                self.requestSyncIfPossible()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in
            self.requestSyncIfPossible()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            self.applyContext(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            self.applyContext(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            self.applyContext(userInfo)
        }
    }
}
#endif

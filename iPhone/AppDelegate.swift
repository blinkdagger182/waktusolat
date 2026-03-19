import UIKit
import BackgroundTasks
import UserNotifications
import ActivityKit
import Combine

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let taskID  = "com.Quran.Elmallah.Prayer-Times.fetchPrayerTimes"
    private var cancellables = Set<AnyCancellable>()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }

        scheduleAppRefresh()
        UNUserNotificationCenter.current().delegate = self
        Settings.registerForRemoteNotificationsHandler = {
            UIApplication.shared.registerForRemoteNotifications()
        }
        requestPushPermissions()
        setupLiveActivityPushTokenHandler()
        observePushToStartToken()
        observeZoneChanges()
        syncPushToStartTokenIfCached()
        return true
    }

    private func observePushToStartToken() {
        guard #available(iOS 17.2, *) else { return }
        Task {
            for await tokenData in Activity<PrayerLiveActivityAttributes>.pushToStartTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                logger.debug("✅ Live Activity push-to-start token: \(token)")
                UserDefaults.standard.set(token, forKey: "pushToStartToken")
                let zone = UserDefaults.standard.string(forKey: "lastKnownMalaysiaZone")
                PushNotificationService.registerPushToStartToken(token, zone: zone)
                if let zone { UserDefaults.standard.set(zone, forKey: "pushToStartZone") }
            }
        }
    }

    /// Re-registers the cached push-to-start token whenever the user's zone changes.
    private func observeZoneChanges() {
        guard #available(iOS 17.2, *) else { return }
        Settings.shared.objectWillChange
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.reRegisterIfZoneChanged() }
            .store(in: &cancellables)
    }

    /// On launch, sync only if zone has drifted from what was last registered.
    private func syncPushToStartTokenIfCached() {
        guard #available(iOS 17.2, *),
              let token = UserDefaults.standard.string(forKey: "pushToStartToken") else { return }
        let zone     = UserDefaults.standard.string(forKey: "lastKnownMalaysiaZone")
        let lastZone = UserDefaults.standard.string(forKey: "pushToStartZone")
        guard zone != lastZone else { return }
        PushNotificationService.registerPushToStartToken(token, zone: zone)
        UserDefaults.standard.set(zone, forKey: "pushToStartZone")
    }

    private func reRegisterIfZoneChanged() {
        guard let token = UserDefaults.standard.string(forKey: "pushToStartToken"),
              let zone = UserDefaults.standard.string(forKey: "lastKnownMalaysiaZone") else { return }
        let lastZone = UserDefaults.standard.string(forKey: "pushToStartZone")
        guard zone != lastZone else { return }
        logger.debug("🔄 Zone changed (\(lastZone ?? "nil") → \(zone)), re-registering push-to-start token")
        PushNotificationService.registerPushToStartToken(token, zone: zone)
        UserDefaults.standard.set(zone, forKey: "pushToStartZone")
    }

    private func setupLiveActivityPushTokenHandler() {
        if #available(iOS 16.2, *) {
            PrayerLiveActivityCoordinator.shared.onPushToken = { pushToken, prayerName, city, prayerTime in
                let zone = UserDefaults.standard.string(forKey: "lastKnownMalaysiaZone")
                PushNotificationService.registerLiveActivityToken(
                    pushToken: pushToken,
                    activityId: "next-prayer",
                    deviceToken: nil,
                    prayerName: prayerName,
                    city: city,
                    prayerTime: prayerTime,
                    zone: zone
                )
            }
        }
    }
    
    // MARK: - Push Notifications
    
    private func requestPushPermissions() {
        // Only register for APNs if already authorized — the UI handles the first-time
        // permission prompt from AdhanView/SettingsAdhanView once the window is ready.
        // Calling requestAuthorization here (before the scene is visible) can silently
        // suppress the system dialog on some devices, leaving the auth status stuck at
        // .notDetermined and the Azan/Settings tabs appearing empty.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        logger.debug("✅ APNs device token: \(token)")

        PushNotificationService.registerDeviceToken(token)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("❌ APNs registration failed: \(error.localizedDescription)")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }

    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = nextRunDate()
        
        if let date = request.earliestBeginDate {
                logger.debug("🔧 Scheduling BGAppRefresh – earliestBeginDate: \(date.formatted())")
            }

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.debug("✅ BGAppRefresh submitted")
        } catch {
            logger.error("❌ BG submit failed: \(error.localizedDescription)")
        }
    }

    private func nextRunDate(offsetMins: Double = 35) -> Date {
        let now = Date()
        let minimum = now.addingTimeInterval(15 * 60)
        var candidates: [Date] = []

        // Keep Live Activity trigger fresh even if app was not foregrounded.
        if let liveTrigger = Settings.shared.nextLiveActivityTriggerDate(from: now) {
            // Ask system to wake slightly before threshold for better chance of on-time display.
            candidates.append(liveTrigger.addingTimeInterval(-2 * 60))
        }

        // Fallback existing cadence around Fajr next-day refresh.
        if let firstPrayer = Settings.shared.prayers?
            .prayers
            .sorted(by: { $0.time < $1.time })
            .first?.time {
            let timeParts = Calendar.current.dateComponents([.hour, .minute, .second], from: firstPrayer)
            if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
               let hour = timeParts.hour,
               let minute = timeParts.minute,
               let second = timeParts.second,
               let nextDayPrayer = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: tomorrow) {
                candidates.append(nextDayPrayer.addingTimeInterval(-offsetMins * 60))
            }
        }

        let selected = candidates.min() ?? now.addingTimeInterval(24 * 60 * 60)
        return max(selected, minimum)
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        logger.debug("🚀 BGAppRefresh fired")
        scheduleAppRefresh()

        // Guard against double-completion: URLSession default timeout (60s) exceeds the
        // typical BGAppRefreshTask window (~30s), so both the expiration handler and the
        // fetch completion can fire. Calling setTaskCompleted twice is undefined behaviour.
        var completed = false
        func finish(success: Bool) {
            guard !completed else { return }
            completed = true
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            logger.error("⏰ BG task expired before finishing")
            finish(success: false)
        }

        Settings.shared.fetchPrayerTimes {
            Settings.shared.updateCurrentAndNextPrayer()
            logger.debug("🎉 BG task completed – prayer times refreshed")
            finish(success: true)
        }
    }

    // Foreground Notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

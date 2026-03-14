import UIKit
import BackgroundTasks
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let taskID  = "com.Quran.Elmallah.Prayer-Times.fetchPrayerTimes"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]?) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }

        scheduleAppRefresh()
        UNUserNotificationCenter.current().delegate = self
        return true
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

        task.expirationHandler = {
            logger.error("⏰ BG task expired before finishing")
            task.setTaskCompleted(success: false)
        }

        Settings.shared.fetchPrayerTimes {
            Settings.shared.updateCurrentAndNextPrayer()
            logger.debug("🎉 BG task completed – prayer times refreshed")
            task.setTaskCompleted(success: true)
        }
    }

    // Foreground Notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

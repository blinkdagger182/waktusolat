import Foundation
import UIKit

struct PushNotificationService {
    private static let baseURL = "https://api-waktusolat.vercel.app"

    static func registerDeviceToken(_ token: String) {
        post(
            path: "/api/device-token",
            body: [
                "deviceToken": token,
                "platform": "ios",
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "deviceModel": UIDevice.current.model
            ],
            label: "device token"
        )
    }

    static func registerPushToStartToken(_ token: String, zone: String?, leadMinutes: Int = 5) {
        var body: [String: Any] = [
            "pushToStartToken": token,
            "leadMinutes": leadMinutes
        ]
        if let zone { body["zone"] = zone }
        post(path: "/api/live-activity/register-start-token", body: body, label: "push-to-start token")
    }

    static func registerLiveActivityToken(
        pushToken: String,
        activityId: String,
        deviceToken: String?,
        prayerName: String?,
        city: String?,
        prayerTime: Date?
    ) {
        var body: [String: Any] = [
            "pushToken": pushToken,
            "activityId": activityId
        ]
        if let deviceToken { body["deviceToken"] = deviceToken }
        if let prayerName { body["prayerName"] = prayerName }
        if let city { body["city"] = city }
        if let prayerTime { body["prayerTime"] = prayerTime.timeIntervalSince1970 }
        post(path: "/api/live-activity/register", body: body, label: "live activity token")
    }

    // MARK: - Private

    private static func post(path: String, body: [String: Any], label: String) {
        guard let url = URL(string: baseURL + path) else {
            logger.error("❌ Invalid URL for \(label) registration")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("❌ Failed to serialize \(label) payload: \(error.localizedDescription)")
            return
        }
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                logger.error("❌ \(label) registration failed: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    logger.debug("✅ \(label) registered successfully")
                } else {
                    logger.error("❌ \(label) registration failed with status: \(http.statusCode)")
                }
            }
        }.resume()
    }
}

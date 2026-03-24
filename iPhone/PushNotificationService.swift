import Foundation
import UIKit

struct PushNotificationService {
    private static let baseURL = "https://api-waktusolat.vercel.app"

    static func registerDeviceToken(_ token: String) {
        post(
            endpoint: "\(baseURL)/api/device-token",
            payload: [
                "deviceToken": token,
                "platform": "ios",
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "deviceModel": UIDevice.current.model,
            ],
            label: "device token"
        )
    }

    static func registerPushToStartToken(_ token: String, zone: String?, liveEnabled: Bool, leadMinutes: Int) {
        var payload: [String: Any] = [
            "pushToStartToken": token,
            "platform": "ios",
            "liveEnabled": liveEnabled,
            "leadMinutes": leadMinutes,
        ]
        if let zone, !zone.isEmpty { payload["zone"] = zone }
        post(
            endpoint: "\(baseURL)/api/live-activity/register-start-token",
            payload: payload,
            label: "push-to-start token"
        )
    }

    static func registerLiveActivityToken(
        pushToken: String,
        activityId: String,
        deviceToken: String?,
        prayerName: String,
        city: String,
        prayerTime: Date,
        zone: String?
    ) {
        var payload: [String: Any] = [
            "pushToken": pushToken,
            "activityId": activityId,
            "prayerName": prayerName,
            "city": city,
            "prayerTime": ISO8601DateFormatter().string(from: prayerTime),
        ]
        if let deviceToken { payload["deviceToken"] = deviceToken }
        if let zone, !zone.isEmpty { payload["zone"] = zone }

        post(
            endpoint: "\(baseURL)/api/live-activity/register",
            payload: payload,
            label: "live activity token"
        )
    }

    private static func post(endpoint: String, payload: [String: Any], label: String) {
        guard let url = URL(string: endpoint) else {
            logger.error("❌ Invalid URL for \(label) registration")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            logger.error("❌ Failed to serialize \(label) payload: \(error.localizedDescription)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                logger.error("❌ \(label) registration failed: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                if http.statusCode == 200 {
                    if let message = registrationMessage(from: body) {
                        logger.debug("✅ \(message)")
                    } else {
                        logger.debug("✅ \(label) registered successfully")
                    }
                } else {
                    logger.error("❌ \(label) registration failed (\(http.statusCode)): \(body)")
                }
            }
        }.resume()
    }

    private static func registrationMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String,
              !message.isEmpty else {
            return nil
        }
        return message
    }
}

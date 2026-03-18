import Foundation
import UIKit

struct PushNotificationService {
    private static let baseURL = "https://api.waktusolat.app"
    
    static func registerDeviceToken(_ token: String) {
        let endpoint = "\(baseURL)/api/push/register"
        
        guard let url = URL(string: endpoint) else {
            logger.error("❌ Invalid URL for push registration")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "deviceToken": token,
            "platform": "ios",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "deviceModel": UIDevice.current.model
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            logger.error("❌ Failed to serialize push token payload: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                logger.error("❌ Push token registration failed: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    logger.debug("✅ Push token registered successfully")
                } else {
                    logger.error("❌ Push token registration failed with status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}

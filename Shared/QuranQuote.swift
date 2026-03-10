import Foundation

struct DailyQuranQuote: Codable, Equatable {
    let text: String
    let surahName: String
    let surahNumber: Int
    let ayahNumber: Int
    let reference: String
    let displayReference: String
    let characterCountText: Int
    let characterCountReference: Int
    let characterCountCombined: Int
    let isLockScreenSafe: Bool
    let theme: String
    let dateKey: String
}

extension DailyQuranQuote {
    static func emergencyFallback(dateKey: String) -> DailyQuranQuote {
        let text = "For indeed, with hardship comes ease."
        let surahName = "Ash-Sharh"
        let reference = "94:5"
        let displayReference = "\(surahName) \(reference)"
        return DailyQuranQuote(
            text: text,
            surahName: surahName,
            surahNumber: 94,
            ayahNumber: 5,
            reference: reference,
            displayReference: displayReference,
            characterCountText: text.count,
            characterCountReference: displayReference.count,
            characterCountCombined: text.count + displayReference.count,
            isLockScreenSafe: true,
            theme: "hope",
            dateKey: dateKey
        )
    }
}

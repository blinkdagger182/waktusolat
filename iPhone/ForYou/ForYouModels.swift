import Foundation

enum ForYouMomentType: String, Codable, CaseIterable, Identifiable {
    case morning
    case dhuha
    case evening
    case night

    var id: String { rawValue }
}

enum ForYouCTAType: String, Codable {
    case none
    case markDone
}

enum ForYouConsistencyLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case building
    case steady

    var id: String { rawValue }
}

enum ForYouPrimaryGoal: String, Codable, CaseIterable, Identifiable {
    case preserveFajr
    case addDhuha
    case dailyQuran
    case consistentDhikr

    var id: String { rawValue }
}

enum ForYouReminderStyle: String, Codable, CaseIterable, Identifiable {
    case gentle
    case balanced
    case focused

    var id: String { rawValue }
}

struct ForYouUserProfile: Codable, Equatable {
    var wakeTimeMinutes: Int
    var sleepTimeMinutes: Int
    var workStartMinutes: Int?
    var workEndMinutes: Int?
    var consistencyLevel: ForYouConsistencyLevel?
    var primaryGoal: ForYouPrimaryGoal?
    var reminderStyle: ForYouReminderStyle?

    var isComplete: Bool {
        consistencyLevel != nil && primaryGoal != nil && reminderStyle != nil
    }

    static let `default` = ForYouUserProfile(
        wakeTimeMinutes: 360,
        sleepTimeMinutes: 1380,
        workStartMinutes: 540,
        workEndMinutes: 1020,
        consistencyLevel: nil,
        primaryGoal: nil,
        reminderStyle: nil
    )
}

struct ForYouDailyPlan: Identifiable, Codable {
    let id: String
    let date: Date
    let title: String
    let subtitle: String?
    let locationLine: String?
    let sourceLine: String?
    let segments: [ForYouDaySegment]
    let isPremiumPreview: Bool
    let personalizationReason: String?
}

struct ForYouDaySegment: Identifiable, Codable {
    let id: String
    let type: ForYouMomentType
    let startWindow: Date
    let endWindow: Date
    let priority: Int
    let durationMinutes: Int
    let title: String
    let arabicText: String?
    let contentReference: String?
    let shortDescription: String
    let ctaType: ForYouCTAType
    let personalizationReason: String?
}

struct ForYouPrayerTimeline {
    let fajr: Date?
    let sunrise: Date?
    let dhuha: Date?
    let asr: Date?
    let maghrib: Date?
    let isha: Date?
    let locationLine: String?
    let sourceLine: String?
}

struct ForYouContentTemplate: Identifiable {
    let id: String
    let type: ForYouMomentType
    let titleEn: String
    let titleMy: String
    let arabicText: String?
    let shortDescriptionEn: String
    let shortDescriptionMy: String
    let contentReference: String?
    let durationMinutes: Int
    let ctaType: ForYouCTAType
    let goals: [ForYouPrimaryGoal]
    let idealLevels: [ForYouConsistencyLevel]
}

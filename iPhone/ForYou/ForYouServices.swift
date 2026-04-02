import Foundation

enum ForYouUserProfileService {
    private static let storageKey = "forYou.userProfile.v1"
    private static let defaults = UserDefaults.standard

    static func load() -> ForYouUserProfile {
        guard
            let data = defaults.data(forKey: storageKey),
            let profile = try? JSONDecoder().decode(ForYouUserProfile.self, from: data)
        else {
            return .default
        }
        return profile
    }

    static func save(_ profile: ForYouUserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

enum ForYouCompletionStore {
    private static let storageKey = "forYou.completedSegmentIDs.v1"
    private static let defaults = UserDefaults.standard

    static func completedIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    static func setCompleted(_ completed: Bool, id: String) {
        var ids = completedIDs()
        if completed {
            ids.insert(id)
        } else {
            ids.remove(id)
        }
        defaults.set(Array(ids), forKey: storageKey)
    }
}

enum ForYouContentRepository {
    static let templates: [ForYouContentTemplate] = [
        ForYouContentTemplate(
            id: "morning-protection",
            type: .morning,
            titleEn: "Morning Protection",
            titleMy: "Perlindungan Pagi",
            arabicText: "قُلْ هُوَ ٱللَّهُ أَحَدٌ • قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ • قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ",
            shortDescriptionEn: "Begin after Fajr with the three Quls. A light anchor before the day opens fully.",
            shortDescriptionMy: "Mulakan selepas Subuh dengan tiga Qul. Sauh yang ringan sebelum hari benar-benar bermula.",
            contentReference: "Sunan al-Tirmidhi 3575",
            durationMinutes: 4,
            ctaType: .markDone,
            goals: [.preserveFajr, .consistentDhikr],
            idealLevels: [.beginner, .building, .steady]
        ),
        ForYouContentTemplate(
            id: "morning-kursi",
            type: .morning,
            titleEn: "Ayat al-Kursi",
            titleMy: "Ayat al-Kursi",
            arabicText: "ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ",
            shortDescriptionEn: "Keep one ayah close in the first quiet minutes. Protection with almost no friction.",
            shortDescriptionMy: "Dekatkan satu ayat pada minit-minit tenang pertama. Perlindungan tanpa banyak geseran.",
            contentReference: "Al-Hakim · Hisnul Muslim",
            durationMinutes: 3,
            ctaType: .markDone,
            goals: [.preserveFajr, .dailyQuran],
            idealLevels: [.building, .steady]
        ),
        ForYouContentTemplate(
            id: "dhuha-prayer",
            type: .dhuha,
            titleEn: "Dhuha Window",
            titleMy: "Jendela Dhuha",
            arabicText: "صَلَاةُ ٱلضُّحَىٰ",
            shortDescriptionEn: "A soft midday return: two rak'ahs when the day has settled and your heart can catch up.",
            shortDescriptionMy: "Kembalinya jiwa di tengah hari: dua rakaat ketika hari mula tenang dan hati dapat mengejar semula.",
            contentReference: "Sahih Muslim 720",
            durationMinutes: 8,
            ctaType: .markDone,
            goals: [.addDhuha, .consistentDhikr],
            idealLevels: [.beginner, .building, .steady]
        ),
        ForYouContentTemplate(
            id: "dhuha-reflection",
            type: .dhuha,
            titleEn: "Surah Ad-Duha",
            titleMy: "Surah Ad-Duha",
            arabicText: "مَا وَدَّعَكَ رَبُّكَ وَمَا قَلَىٰ",
            shortDescriptionEn: "A midday reassurance: your Lord has not left you. Read slowly, without urgency.",
            shortDescriptionMy: "Ketenangan tengah hari: Tuhanmu tidak meninggalkanmu. Baca dengan perlahan, tanpa tergesa-gesa.",
            contentReference: "Surah Ad-Duha 93:3",
            durationMinutes: 5,
            ctaType: .none,
            goals: [.dailyQuran, .addDhuha],
            idealLevels: [.beginner, .building, .steady]
        ),
        ForYouContentTemplate(
            id: "evening-asr",
            type: .evening,
            titleEn: "Before the Day Fades",
            titleMy: "Sebelum Hari Pudar",
            arabicText: "وَٱلْعَصْرِ ۝ إِنَّ ٱلْإِنسَٰنَ لَفِى خُسْرٍ",
            shortDescriptionEn: "Late afternoon asks for honesty. Keep it simple: a short surah and a pause before Maghrib.",
            shortDescriptionMy: "Petang meminta kejujuran. Kekalkan ringkas: surah pendek dan jeda sebelum Maghrib.",
            contentReference: "Surah Al-Asr",
            durationMinutes: 4,
            ctaType: .none,
            goals: [.dailyQuran, .consistentDhikr],
            idealLevels: [.beginner, .building, .steady]
        ),
        ForYouContentTemplate(
            id: "evening-adhkar",
            type: .evening,
            titleEn: "Evening Adhkar",
            titleMy: "Zikir Petang",
            arabicText: "سُبْحَانَ ٱللَّٰهِ 33 • ٱلْحَمْدُ لِلَّٰهِ 33 • ٱللَّٰهُ أَكْبَرُ 34",
            shortDescriptionEn: "Close the day with compact remembrance. Enough to reset the tone without feeling heavy.",
            shortDescriptionMy: "Tutup hari dengan zikir yang ringkas. Cukup untuk mengubah nada hari tanpa terasa berat.",
            contentReference: "Sahih al-Bukhari 843 · Sahih Muslim 597",
            durationMinutes: 5,
            ctaType: .markDone,
            goals: [.consistentDhikr, .preserveFajr],
            idealLevels: [.beginner, .building, .steady]
        ),
        ForYouContentTemplate(
            id: "night-kursi",
            type: .night,
            titleEn: "Before Sleep",
            titleMy: "Sebelum Tidur",
            arabicText: "ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ",
            shortDescriptionEn: "End with Ayat al-Kursi and leave the day in Allah's care instead of carrying it into sleep.",
            shortDescriptionMy: "Akhiri dengan Ayat al-Kursi dan serahkan hari ini kepada Allah, bukan membawanya ke dalam tidur.",
            contentReference: "Sahih al-Bukhari 2311",
            durationMinutes: 4,
            ctaType: .markDone,
            goals: [.preserveFajr, .dailyQuran],
            idealLevels: [.beginner, .building, .steady]
        ),
        ForYouContentTemplate(
            id: "night-baqarah",
            type: .night,
            titleEn: "Night Sufficiency",
            titleMy: "Kecukupan Malam",
            arabicText: "آمَنَ ٱلرَّسُولُ بِمَآ أُنزِلَ إِلَيْهِ مِن رَّبِّهِۦ",
            shortDescriptionEn: "The last two verses of Al-Baqarah are enough for the night. Calm, complete, and deeply rooted.",
            shortDescriptionMy: "Dua ayat terakhir Al-Baqarah mencukupi untuk malam. Tenang, lengkap, dan sangat berakar.",
            contentReference: "Sahih al-Bukhari 5009 · Sahih Muslim 808",
            durationMinutes: 6,
            ctaType: .markDone,
            goals: [.dailyQuran, .consistentDhikr],
            idealLevels: [.building, .steady]
        )
    ]

    static func templates(for type: ForYouMomentType) -> [ForYouContentTemplate] {
        templates.filter { $0.type == type }
    }
}

enum ForYouPrayerTimeService {
    static func timeline(for date: Date, settings: Settings) -> ForYouPrayerTimeline {
        let locationLine = resolvedLocationLine(settings: settings)
        let sourceLine = settings.prayerCountrySupportConfig?.autoMethodLabel ?? settings.prayerCalculation
        guard let prayers = settings.prayers?.prayers, !prayers.isEmpty else {
            return ForYouPrayerTimeline(
                fajr: fallbackDate(hour: 5, minute: 45, on: date),
                sunrise: fallbackDate(hour: 7, minute: 10, on: date),
                dhuha: fallbackDate(hour: 8, minute: 0, on: date),
                asr: fallbackDate(hour: 16, minute: 30, on: date),
                maghrib: fallbackDate(hour: 19, minute: 20, on: date),
                isha: fallbackDate(hour: 20, minute: 35, on: date),
                prayers: [],
                locationLine: locationLine,
                sourceLine: sourceLine
            )
        }

        let shifted = shift(prayers: prayers, onto: date)
        let fajr = firstPrayer(in: shifted, matching: ["fajr"])
        let sunrise = firstPrayer(in: shifted, matching: ["shurooq", "syuruk", "sunrise"])
        let asr = firstPrayer(in: shifted, matching: ["asr"])
        let maghrib = firstPrayer(in: shifted, matching: ["maghrib", "magrib"])
        let isha = firstPrayer(in: shifted, matching: ["isha", "isyak", "isya"])
        let dhuha = fallbackDhuha(fajr: fajr, sunrise: sunrise, date: date)

        return ForYouPrayerTimeline(
            fajr: fajr,
            sunrise: sunrise,
            dhuha: dhuha,
            asr: asr,
            maghrib: maghrib,
            isha: isha,
            prayers: shifted,
            locationLine: locationLine,
            sourceLine: sourceLine
        )
    }

    private static func shift(prayers: [Prayer], onto date: Date) -> [Prayer] {
        prayers.map { prayer in
            Prayer(
                id: prayer.id,
                nameArabic: prayer.nameArabic,
                nameTransliteration: prayer.nameTransliteration,
                nameEnglish: prayer.nameEnglish,
                time: shiftedTime(prayer.time, onto: date),
                image: prayer.image,
                rakah: prayer.rakah,
                sunnahBefore: prayer.sunnahBefore,
                sunnahAfter: prayer.sunnahAfter
            )
        }
    }

    private static func shiftedTime(_ source: Date, onto target: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: source)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            of: target
        ) ?? target
    }

    private static func firstPrayer(in prayers: [Prayer], matching candidates: [String]) -> Date? {
        prayers.first { prayer in
            let key = prayer.nameTransliteration.lowercased()
            return candidates.contains(where: { key.contains($0) })
        }?.time
    }

    private static func fallbackDhuha(fajr: Date?, sunrise: Date?, date: Date) -> Date? {
        if let fajr, let sunrise {
            let gap = sunrise.timeIntervalSince(fajr)
            if gap > 0 {
                return sunrise.addingTimeInterval(max(30 * 60, gap / 3))
            }
        }
        return fallbackDate(hour: 8, minute: 15, on: date)
    }

    private static func fallbackDate(hour: Int, minute: Int, on date: Date) -> Date? {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }

    private static func resolvedLocationLine(settings: Settings) -> String? {
        if let area = settings.resolvedPrayerArea?.displayName {
            return area
        }
        return settings.currentLocation?.city
    }
}

enum ForYouPlanScoringEngine {
    static func score(
        template: ForYouContentTemplate,
        profile: ForYouUserProfile,
        date: Date
    ) -> Double {
        var score = 0.0

        if profile.primaryGoal.map(template.goals.contains) == true {
            score += 3.0
        }

        if let level = profile.consistencyLevel, template.idealLevels.contains(level) {
            score += 2.0
        }

        if Calendar.current.isDateInToday(date), template.ctaType == .markDone {
            score += 0.6
        }

        if Calendar.current.component(.weekday, from: date) == 6, template.type == .dhuha {
            score += 0.4
        }

        if profile.consistencyLevel == .beginner, template.durationMinutes > 6 {
            score -= 1.2
        }

        return score
    }
}

@MainActor
final class ForYouPlanGeneratorService {
    func generatePlans(
        anchorDate: Date,
        settings: Settings,
        profile: ForYouUserProfile,
        hasPremiumAccess: Bool
    ) -> [ForYouDailyPlan] {
        let offsets = [-1, 0, 1, 2]
        return offsets.compactMap { dayOffset in
            guard let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: anchorDate) else {
                return nil
            }
            return generatePlan(
                for: date,
                settings: settings,
                profile: profile,
                hasPremiumAccess: hasPremiumAccess,
                isPremiumPreview: dayOffset > 0 && !hasPremiumAccess
            )
        }
    }

    func generatePlan(
        for date: Date,
        settings: Settings,
        profile: ForYouUserProfile,
        hasPremiumAccess: Bool,
        isPremiumPreview: Bool
    ) -> ForYouDailyPlan {
        let timeline = ForYouPrayerTimeService.timeline(for: date, settings: settings)
        let segments = buildSegments(for: date, profile: profile, timeline: timeline, includeNight: hasPremiumAccess || profile.consistencyLevel != .beginner)
        let timelineEntries = buildTimelineEntries(for: date, settings: settings, profile: profile, timeline: timeline)
        let weekday = Calendar.current.component(.weekday, from: date)
        let title = title(for: date)
        let subtitle = subtitle(for: date, weekday: weekday, profile: profile)
        let reason = isPremiumPreview ? personalizationReason(for: profile) : nil

        return ForYouDailyPlan(
            id: ISO8601DateFormatter().string(from: date),
            date: date,
            title: title,
            subtitle: subtitle,
            locationLine: timeline.locationLine,
            sourceLine: timeline.sourceLine,
            segments: segments,
            timelineEntries: timelineEntries,
            isPremiumPreview: isPremiumPreview,
            personalizationReason: reason
        )
    }

    private func buildSegments(
        for date: Date,
        profile: ForYouUserProfile,
        timeline: ForYouPrayerTimeline,
        includeNight: Bool
    ) -> [ForYouDaySegment] {
        var selectedTypes: [ForYouMomentType] = [.morning, .dhuha, .evening]
        if includeNight { selectedTypes.append(.night) }

        return selectedTypes.compactMap { type in
            let template = ForYouContentRepository.templates(for: type)
                .max { lhs, rhs in
                    ForYouPlanScoringEngine.score(template: lhs, profile: profile, date: date)
                    < ForYouPlanScoringEngine.score(template: rhs, profile: profile, date: date)
                }

            guard let template else { return nil }
            let window = window(for: type, timeline: timeline, date: date)
            return ForYouDaySegment(
                id: "\(ISO8601DateFormatter().string(from: date))-\(type.rawValue)",
                type: type,
                startWindow: window.start,
                endWindow: window.end,
                priority: max(1, Int(ForYouPlanScoringEngine.score(template: template, profile: profile, date: date) * 10)),
                durationMinutes: template.durationMinutes,
                title: isMalayAppLanguage() ? template.titleMy : template.titleEn,
                arabicText: template.arabicText,
                contentReference: template.contentReference,
                shortDescription: isMalayAppLanguage() ? template.shortDescriptionMy : template.shortDescriptionEn,
                ctaType: template.ctaType,
                personalizationReason: personalizationReason(for: profile)
            )
        }
    }

    private func buildTimelineEntries(
        for date: Date,
        settings: Settings,
        profile: ForYouUserProfile,
        timeline: ForYouPrayerTimeline
    ) -> [ForYouTimelineEntry] {
        let prayerEntries = buildPrayerNotificationEntries(for: date, settings: settings, profile: profile, prayers: timeline.prayers)
        let zikirEntries = buildZikirEntries(for: date, settings: settings, profile: profile, prayers: timeline.prayers)
        return (prayerEntries + zikirEntries)
            .sorted { lhs, rhs in
                if lhs.time == rhs.time {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return lhs.time < rhs.time
            }
    }

    private func buildPrayerNotificationEntries(
        for date: Date,
        settings: Settings,
        profile: ForYouUserProfile,
        prayers: [Prayer]
    ) -> [ForYouTimelineEntry] {
        prayers.flatMap { prayer -> [ForYouTimelineEntry] in
            let canonicalName = canonicalPrayerName(prayer.nameTransliteration)
            guard let rule = notificationRule(for: canonicalName, settings: settings), rule.enabled else {
                return []
            }

            var entries: [ForYouTimelineEntry] = []

            if rule.preMinutes > 0,
               let preTime = Calendar.current.date(byAdding: .minute, value: -rule.preMinutes, to: prayer.time) {
                entries.append(
                    makeTimelineEntry(
                        id: "\(ISO8601DateFormatter().string(from: date))-\(canonicalName)-pre",
                        kind: .prayer,
                        momentType: momentType(for: canonicalName),
                        time: preTime,
                        title: localizedPrayerName(prayer.nameTransliteration),
                        subtitle: preNotificationSubtitle(minutes: rule.preMinutes, prayerName: localizedPrayerName(prayer.nameTransliteration), location: settings.currentPrayerAreaName ?? settings.activePrayerLocationDisplayName ?? settings.currentLocation?.city),
                        icon: "bell.badge",
                        arabicText: prayer.nameArabic,
                        reference: nil,
                        recommendation: recommendation(for: momentType(for: canonicalName), profile: profile, date: date)
                    )
                )
            }

            entries.append(
                makeTimelineEntry(
                    id: "\(ISO8601DateFormatter().string(from: date))-\(canonicalName)-live",
                    kind: .prayer,
                    momentType: momentType(for: canonicalName),
                    time: prayer.time,
                    title: localizedPrayerName(prayer.nameTransliteration),
                    subtitle: livePrayerSubtitle(prayerName: localizedPrayerName(prayer.nameTransliteration), location: settings.currentPrayerAreaName ?? settings.activePrayerLocationDisplayName ?? settings.currentLocation?.city),
                    icon: icon(for: canonicalName),
                    arabicText: prayer.nameArabic,
                    reference: nil,
                    recommendation: recommendation(for: momentType(for: canonicalName), profile: profile, date: date)
                )
            )

            return entries
        }
    }

    private func buildZikirEntries(
        for date: Date,
        settings: Settings,
        profile: ForYouUserProfile,
        prayers: [Prayer]
    ) -> [ForYouTimelineEntry] {
        guard settings.zikirNotificationsEnabled, !prayers.isEmpty else { return [] }

        return zikirNotificationAnchorDates(for: prayers).map { anchor in
            let selection = ZikirSelector.select(
                for: .init(
                    date: anchor.date,
                    prayers: prayers,
                    surface: .app
                )
            )

            let location = settings.currentPrayerAreaName ?? settings.activePrayerLocationDisplayName ?? settings.currentLocation?.city
            let title = selection.helperTitle.isEmpty ? appLocalized(selection.bucket.titleKey) : selection.helperTitle
            let subtitle = location.map { "\(selection.phrase.localizedTranslation()) • \($0)" } ?? selection.phrase.localizedTranslation()
            let moment = momentType(for: anchor.bucket)

            return makeTimelineEntry(
                id: "\(ISO8601DateFormatter().string(from: date))-zikir-\(anchor.bucket.rawValue)",
                kind: .zikir,
                momentType: moment,
                time: anchor.date,
                title: title,
                subtitle: subtitle,
                icon: icon(for: moment),
                arabicText: selection.phrase.textArabic,
                reference: appLocalized(selection.bucket.titleKey),
                recommendation: recommendation(for: moment, profile: profile, date: date)
            )
        }
    }

    private func window(for type: ForYouMomentType, timeline: ForYouPrayerTimeline, date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let fallbackStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: date) ?? date

        switch type {
        case .morning:
            return (timeline.fajr ?? fallbackStart, timeline.sunrise ?? fallbackStart.addingTimeInterval(90 * 60))
        case .dhuha:
            let start = timeline.dhuha ?? fallbackStart.addingTimeInterval(2 * 60 * 60)
            return (start, start.addingTimeInterval(90 * 60))
        case .evening:
            let start = timeline.asr ?? fallbackStart.addingTimeInterval(9 * 60 * 60)
            return (start, timeline.maghrib ?? start.addingTimeInterval(2 * 60 * 60))
        case .night:
            let start = timeline.isha ?? fallbackStart.addingTimeInterval(14 * 60 * 60)
            let end = calendar.date(bySettingHour: 23, minute: 45, second: 0, of: date) ?? start.addingTimeInterval(2 * 60 * 60)
            return (start, end)
        }
    }

    private func title(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appLocale()
        formatter.dateFormat = "EEEE"
        let day = formatter.string(from: date)
        if Calendar.current.isDateInToday(date) {
            return "\(day) · \(isMalayAppLanguage() ? "Hari Ini" : "Today")"
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "\(day) · \(isMalayAppLanguage() ? "Esok" : "Tomorrow")"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "\(day) · \(isMalayAppLanguage() ? "Semalam" : "Yesterday")"
        }
        return day
    }

    private func subtitle(for date: Date, weekday: Int, profile: ForYouUserProfile) -> String {
        let gentleEn = [
            "A calm path, not a crowded one.",
            "Hold onto what is light enough to return to.",
            "Let the day feel prepared before it feels busy."
        ]
        let gentleMy = [
            "Laluan yang tenang, bukan yang sesak.",
            "Pegang apa yang cukup ringan untuk diulangi.",
            "Biarkan hari terasa tersusun sebelum terasa sibuk."
        ]
        let focusedEn = [
            "Small, rooted moments are enough for today.",
            "A little consistency can carry the whole day.",
            "Return at the right moments, not at every moment."
        ]
        let focusedMy = [
            "Saat kecil yang berakar sudah memadai untuk hari ini.",
            "Sedikit konsisten boleh membawa seluruh hari.",
            "Kembali pada saat yang tepat, bukan setiap saat."
        ]

        let lines = (profile.reminderStyle ?? .gentle) == .focused
            ? (isMalayAppLanguage() ? focusedMy : focusedEn)
            : (isMalayAppLanguage() ? gentleMy : gentleEn)

        let index = abs(weekday + Calendar.current.ordinality(of: .day, in: .year, for: date)!) % lines.count
        return lines[index]
    }

    private func personalizationReason(for profile: ForYouUserProfile) -> String {
        switch profile.primaryGoal {
        case .preserveFajr:
            return isMalayAppLanguage() ? "Dipilih untuk menjaga ritma selepas Subuh." : "Chosen to protect your post-Fajr rhythm."
        case .addDhuha:
            return isMalayAppLanguage() ? "Disusun untuk membantu Dhuha terasa mudah dicapai." : "Arranged to make Dhuha feel reachable."
        case .dailyQuran:
            return isMalayAppLanguage() ? "Ditekankan untuk mengekalkan sentuhan harian dengan al-Quran." : "Weighted toward daily Quran contact."
        case .consistentDhikr:
            return isMalayAppLanguage() ? "Dibentuk untuk mengekalkan zikir yang ringan tetapi konsisten." : "Built around light but consistent dhikr."
        case .none:
            return isMalayAppLanguage() ? "Disusun mengikut rentak harian semasa." : "Prepared around your current daily rhythm."
        }
    }

    private func makeTimelineEntry(
        id: String,
        kind: ForYouTimelineEntryKind,
        momentType: ForYouMomentType,
        time: Date,
        title: String,
        subtitle: String,
        icon: String,
        arabicText: String?,
        reference: String?,
        recommendation: ForYouTimelineRecommendation?
    ) -> ForYouTimelineEntry {
        ForYouTimelineEntry(
            id: id,
            kind: kind,
            momentType: momentType,
            time: time,
            hourBucket: Calendar.current.component(.hour, from: time),
            title: title,
            subtitle: subtitle,
            icon: icon,
            arabicText: arabicText,
            reference: reference,
            recommendation: recommendation
        )
    }

    private func recommendation(
        for type: ForYouMomentType,
        profile: ForYouUserProfile,
        date: Date
    ) -> ForYouTimelineRecommendation? {
        let template = ForYouContentRepository.templates(for: type)
            .max { lhs, rhs in
                ForYouPlanScoringEngine.score(template: lhs, profile: profile, date: date)
                < ForYouPlanScoringEngine.score(template: rhs, profile: profile, date: date)
            }

        guard let template else { return nil }
        return ForYouTimelineRecommendation(
            title: isMalayAppLanguage() ? template.titleMy : template.titleEn,
            arabicText: template.arabicText,
            reference: template.contentReference,
            shortDescription: isMalayAppLanguage() ? template.shortDescriptionMy : template.shortDescriptionEn
        )
    }

    private func preNotificationSubtitle(minutes: Int, prayerName: String, location: String?) -> String {
        let placeLine = location.map { " • \($0)" } ?? ""
        if isMalayAppLanguage() {
            return "\(minutes) min sebelum \(prayerName)\(placeLine)"
        }
        return "\(minutes)m before \(prayerName)\(placeLine)"
    }

    private func livePrayerSubtitle(prayerName: String, location: String?) -> String {
        let placeLine = location.map { " • \($0)" } ?? ""
        if isMalayAppLanguage() {
            return "Masuk waktu \(prayerName)\(placeLine)"
        }
        return "Time for \(prayerName)\(placeLine)"
    }

    private func icon(for canonicalPrayerName: String) -> String {
        switch canonicalPrayerName {
        case "fajr": return "sunrise"
        case "sunrise", "ishraq", "dhuha": return "sun.max"
        case "dhuhr": return "sun.max.fill"
        case "asr": return "sunset"
        case "maghrib": return "sunset.fill"
        case "isha": return "moon.stars"
        default: return "bell"
        }
    }

    private func icon(for momentType: ForYouMomentType) -> String {
        switch momentType {
        case .morning:
            return "sunrise"
        case .dhuha:
            return "sun.max"
        case .evening:
            return "sunset"
        case .night:
            return "moon.stars.fill"
        }
    }

    private func canonicalPrayerName(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "subuh":
            return "fajr"
        case "syuruk":
            return "sunrise"
        case "zuhur", "jumuah":
            return "dhuhr"
        case "asar":
            return "asr"
        case "magrib":
            return "maghrib"
        case "isya", "isyak":
            return "isha"
        default:
            return normalized
        }
    }

    private func momentType(for canonicalPrayerName: String) -> ForYouMomentType {
        switch canonicalPrayerName {
        case "fajr", "sunrise", "ishraq":
            return .morning
        case "dhuhr", "dhuha":
            return .dhuha
        case "asr", "maghrib":
            return .evening
        case "isha":
            return .night
        default:
            return .morning
        }
    }

    private func momentType(for bucket: ZikirTimeBucket) -> ForYouMomentType {
        switch bucket {
        case .morning:
            return .morning
        case .midday:
            return .dhuha
        case .evening:
            return .evening
        case .night:
            return .night
        }
    }

    private func zikirNotificationAnchorDates(for prayerList: [Prayer]) -> [(bucket: ZikirTimeBucket, date: Date)] {
        func prayerTime(_ names: Set<String>) -> Date? {
            prayerList.first {
                names.contains(canonicalPrayerName($0.nameTransliteration))
            }?.time
        }

        let fajr = prayerTime(["fajr"])
        let dhuhr = prayerTime(["dhuhr"])
        let asr = prayerTime(["asr"])
        let isha = prayerTime(["isha"])

        return [
            fajr.map { (.morning, $0.addingTimeInterval(20 * 60)) },
            dhuhr.map { (.midday, $0.addingTimeInterval(20 * 60)) },
            asr.map { (.evening, $0.addingTimeInterval(20 * 60)) },
            isha.map { (.night, $0.addingTimeInterval(20 * 60)) }
        ].compactMap { $0 }
    }

    private func notificationRule(for canonicalPrayerName: String, settings: Settings) -> (enabled: Bool, preMinutes: Int)? {
        switch canonicalPrayerName {
        case "fajr":
            return (settings.notificationFajr, settings.preNotificationFajr)
        case "sunrise":
            return (settings.notificationSunrise, settings.preNotificationSunrise)
        case "dhuhr":
            return (settings.notificationDhuhr, settings.preNotificationDhuhr)
        case "asr":
            return (settings.notificationAsr, settings.preNotificationAsr)
        case "maghrib":
            return (settings.notificationMaghrib, settings.preNotificationMaghrib)
        case "isha":
            return (settings.notificationIsha, settings.preNotificationIsha)
        default:
            return nil
        }
    }
}

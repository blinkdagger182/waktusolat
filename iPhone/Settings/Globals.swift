import SwiftUI

let sharedAppGroupID = "group.app.riskcreatives.waktu"

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguageCode"

    case system
    case english = "en"
    case bahasaMelayu = "ms"

    var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .bahasaMelayu:
            return "ms"
        }
    }

    var quranTranslationEdition: String {
        switch self {
        case .system:
            return resolvedSystemLanguage.quranTranslationEdition
        case .english:
            return "en.asad"
        case .bahasaMelayu:
            return "ms.basmeih"
        }
    }

    var quranTranslationEditionLabel: String {
        quranTranslationEdition
    }

    var displayName: String {
        switch self {
        case .system:
            return appLocalized("System")
        case .english:
            return appLocalized("English")
        case .bahasaMelayu:
            return appLocalized("Bahasa Melayu")
        }
    }
}

private var sharedLanguageDefaults: UserDefaults? {
    UserDefaults(suiteName: sharedAppGroupID)
}

private var resolvedSystemLanguage: AppLanguage {
    let preferredCode = Locale.preferredLanguages.first?
        .replacingOccurrences(of: "_", with: "-")
        .lowercased()

    if let preferredCode, preferredCode.hasPrefix("ms") {
        return .bahasaMelayu
    }

    return .english
}

func storedAppLanguageCode() -> String? {
    UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        ?? sharedLanguageDefaults?.string(forKey: AppLanguage.storageKey)
}

func effectiveAppLanguage(from storedCode: String? = storedAppLanguageCode()) -> AppLanguage {
    guard
        let storedCode,
        let language = AppLanguage(rawValue: storedCode),
        language != .system
    else {
        return resolvedSystemLanguage
    }

    return language
}

func effectiveAppLanguageCode(from storedCode: String? = storedAppLanguageCode()) -> String {
    effectiveAppLanguage(from: storedCode).rawValue
}

func isMalayAppLanguage(_ storedCode: String? = storedAppLanguageCode()) -> Bool {
    effectiveAppLanguageCode(from: storedCode).hasPrefix("ms")
}

func appLocale(for storedCode: String? = storedAppLanguageCode()) -> Locale {
    Locale(identifier: effectiveAppLanguage(from: storedCode).localeIdentifier ?? resolvedSystemLanguage.localeIdentifier ?? "en")
}

func syncSharedAppLanguagePreference(_ storedCode: String?) {
    guard let defaults = sharedLanguageDefaults else { return }
    if let storedCode {
        defaults.set(storedCode, forKey: AppLanguage.storageKey)
    } else {
        defaults.removeObject(forKey: AppLanguage.storageKey)
    }
}

func currentQuranTranslationEdition(for storedCode: String? = storedAppLanguageCode()) -> String {
    effectiveAppLanguage(from: storedCode).quranTranslationEdition
}

func currentQuranTranslationEditionLabel(for storedCode: String? = storedAppLanguageCode()) -> String {
    effectiveAppLanguage(from: storedCode).quranTranslationEditionLabel
}

enum WidgetZikirAlignment: String, CaseIterable, Identifiable {
    static let storageKey = "widgetZikirAlignment"

    case center
    case leading
    case trailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .center:
            return appLocalized("Centered")
        case .leading:
            return appLocalized("Left Aligned")
        case .trailing:
            return appLocalized("Right Aligned")
        }
    }

    var summary: String {
        switch self {
        case .center:
            return isMalayAppLanguage()
                ? "Gaya lalai yang seimbang di tengah."
                : "The balanced default centered style."
        case .leading:
            return isMalayAppLanguage()
                ? "Teks diratakan ke kiri untuk rupa yang lebih editorial."
                : "Aligns the content to the left for a more editorial look."
        case .trailing:
            return isMalayAppLanguage()
                ? "Teks diratakan ke kanan untuk rupa yang lebih kemas."
                : "Aligns the content to the right for a sharper layout."
        }
    }
}

enum NextPrayerCircleStyle: String, CaseIterable, Identifiable {
    static let storageKey = "nextPrayerCircleStyle"

    case classic
    case minimal
    case percentageRing
    case countdownRing
    case dualCountdownRing
    case dualCountdownRingNextPrayer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:
            return isMalayAppLanguage() ? "Featured" : "Classic"
        case .minimal:
            return isMalayAppLanguage() ? "Minimal" : "Minimal"
        case .percentageRing:
            return isMalayAppLanguage() ? "Bulatan Peratus" : "Percentage Ring"
        case .countdownRing:
            return isMalayAppLanguage() ? "Bulatan Kiraan Detik" : "Countdown Ring"
        case .dualCountdownRing:
            return isMalayAppLanguage() ? "Bulatan Kiraan Ganda" : "Dual Countdown Ring"
        case .dualCountdownRingNextPrayer:
            return isMalayAppLanguage() ? "Bulatan Ganda Solat Seterusnya" : "Dual Ring Next Prayer"
        }
    }

    var summary: String {
        switch self {
        case .classic:
            return isMalayAppLanguage()
                ? "Gaya bulatan asal untuk solat seterusnya."
                : "The original circular next-prayer style."
        case .minimal:
            return isMalayAppLanguage()
                ? "Susun atur yang lebih ringkas dengan masa lebih menonjol."
                : "A cleaner layout with more emphasis on the time."
        case .percentageRing:
            return isMalayAppLanguage()
                ? "Memaparkan peratus baki sebelum solat seterusnya dengan ikon solat semasa."
                : "Shows the percentage left until the next prayer with the current prayer icon."
        case .countdownRing:
            return isMalayAppLanguage()
                ? "Bulatan kemajuan yang mengira menuju solat seterusnya."
                : "A circular progress ring counting down to the next prayer."
        case .dualCountdownRing:
            return isMalayAppLanguage()
                ? "Bulatan dalam mengira ke solat seterusnya, dengan bulatan luar menunjukkan baki masa hari ini hingga tengah malam."
                : "An inner ring for the next prayer, with an outer ring showing the remaining day until midnight."
        case .dualCountdownRingNextPrayer:
            return isMalayAppLanguage()
                ? "Versi dua bulatan yang memaparkan nama dan waktu solat seterusnya di tengah."
                : "A dual-ring style that shows the next prayer name and time in the center."
        }
    }
}

enum PrayerListWidgetStyle: String, CaseIterable, Identifiable {
    static let storageKey = "prayerListWidgetStyle"

    case classic
    case focus
    case departuresBoard
    case iconBoard
    case iconBoardSix

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:
            return isMalayAppLanguage() ? "Featured" : "Classic"
        case .focus:
            return isMalayAppLanguage() ? "Fokus" : "Focus"
        case .departuresBoard:
            return isMalayAppLanguage() ? "Papan Berlepas" : "Departures Board"
        case .iconBoard:
            return isMalayAppLanguage() ? "3 Ikon / Waktu" : "3 Icons / Times"
        case .iconBoardSix:
            return isMalayAppLanguage() ? "6 Ikon / Waktu" : "6 Icons / Times"
        }
    }

    var summary: String {
        switch self {
        case .classic:
            return isMalayAppLanguage()
                ? "Paparan senarai asal dengan beberapa waktu solat."
                : "The original list style with several prayer times."
        case .focus:
            return isMalayAppLanguage()
                ? "Menyerlahkan waktu terdekat dengan sokongan dua waktu lain."
                : "Highlights the nearest prayer with two supporting rows."
        case .departuresBoard:
            return isMalayAppLanguage()
                ? "Setiap solat diletakkan dalam petak seperti papan maklumat penerbangan."
                : "Places each prayer inside a flight-information-style board."
        case .iconBoard:
            return isMalayAppLanguage()
                ? "Memaparkan tiga waktu solat sebagai lajur masa, ikon, dan huruf ringkas."
                : "Shows three prayers as compact columns with time, icon, and initial."
        case .iconBoardSix:
            return isMalayAppLanguage()
                ? "Memaparkan keenam-enam waktu solat dalam satu susun atur ikon penuh."
                : "Shows all six prayers in a complete icon-board layout."
        }
    }
}

enum DailyVerseWidgetStyle: String, CaseIterable, Identifiable {
    static let storageKey = "dailyVerseWidgetStyle"

    case classic
    case centered
    case classicBaskerville
    case centeredBaskerville

    var id: String { rawValue }

    var fontDisplayName: String {
        switch self {
        case .classic, .centered:
            return "Georgia"
        case .classicBaskerville, .centeredBaskerville:
            return "Baskerville"
        }
    }

    var verseFontName: String {
        switch self {
        case .classic, .centered:
            return "Georgia"
        case .classicBaskerville, .centeredBaskerville:
            return "Baskerville"
        }
    }

    var referenceFontName: String {
        switch self {
        case .classic, .centered:
            return "Georgia-Bold"
        case .classicBaskerville, .centeredBaskerville:
            return "Baskerville-Bold"
        }
    }

    var isCentered: Bool {
        switch self {
        case .centered, .centeredBaskerville:
            return true
        case .classic, .classicBaskerville:
            return false
        }
    }

    var title: String {
        switch self {
        case .classic:
            return isMalayAppLanguage() ? "Featured \(fontDisplayName)" : "Classic \(fontDisplayName)"
        case .centered:
            return isMalayAppLanguage() ? "Tengah \(fontDisplayName)" : "Centered \(fontDisplayName)"
        case .classicBaskerville:
            return isMalayAppLanguage() ? "Featured \(fontDisplayName)" : "Classic \(fontDisplayName)"
        case .centeredBaskerville:
            return isMalayAppLanguage() ? "Tengah \(fontDisplayName)" : "Centered \(fontDisplayName)"
        }
    }

    var summary: String {
        switch self {
        case .classic:
            return isMalayAppLanguage()
                ? "Ayat harian asal dengan teks berpenjuru kiri."
                : "The original daily verse style with leading text."
        case .centered:
            return isMalayAppLanguage()
                ? "Ayat diratakan ke tengah untuk rupa yang lebih tenang."
                : "Centers the verse for a calmer presentation."
        case .classicBaskerville:
            return isMalayAppLanguage()
                ? "Gaya asal dengan fon Baskerville berpenjuru kiri."
                : "The classic leading layout with Baskerville."
        case .centeredBaskerville:
            return isMalayAppLanguage()
                ? "Gaya tengah dengan fon Baskerville."
                : "The centered layout with Baskerville."
        }
    }
}

enum LockScreenPrayerTimesStyle: String, CaseIterable, Identifiable {
    static let storageKey = "lockScreenPrayerCountdownStyle"

    case prayerCountdownWithLocation
    case prayerCountdownWithoutLocation
    case prayerCountdownClassicWithLocation
    case prayerCountdownClassicWithoutLocation
    case prayerCountdownCenteredWithLocation
    case prayerCountdownCenteredWithoutLocation
    case prayerTimelineWithLocation
    case prayerTimelineWithoutLocation
    case prayerTimelinePlusWithLocation
    case prayerTimelinePlusWithoutLocation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prayerCountdownWithLocation:
            return isMalayAppLanguage() ? "Waktu Solat Berlabel + Lokasi" : "Prayer Dots + Location"
        case .prayerCountdownWithoutLocation:
            return isMalayAppLanguage() ? "Waktu Solat Berlabel" : "Prayer Dots"
        case .prayerCountdownClassicWithLocation:
            return isMalayAppLanguage() ? "Waktu Solat Featured + Lokasi" : "Featured Dots + Location"
        case .prayerCountdownClassicWithoutLocation:
            return isMalayAppLanguage() ? "Waktu Solat Featured" : "Featured Dots"
        case .prayerCountdownCenteredWithLocation:
            return isMalayAppLanguage() ? "Waktu Solat Tengah + Lokasi" : "Centered Dots + Location"
        case .prayerCountdownCenteredWithoutLocation:
            return isMalayAppLanguage() ? "Waktu Solat Tengah" : "Centered Dots"
        case .prayerTimelineWithLocation:
            return isMalayAppLanguage() ? "Garis Masa Solat + Lokasi" : "Prayer Timeline + Location"
        case .prayerTimelineWithoutLocation:
            return isMalayAppLanguage() ? "Garis Masa Solat" : "Prayer Timeline"
        case .prayerTimelinePlusWithLocation:
            return isMalayAppLanguage() ? "Garis Masa Solat+ + Lokasi" : "Prayer Timeline+ + Location"
        case .prayerTimelinePlusWithoutLocation:
            return isMalayAppLanguage() ? "Garis Masa Solat+" : "Prayer Timeline+"
        }
    }

    var summary: String {
        switch self {
        case .prayerCountdownWithLocation:
            return isMalayAppLanguage()
                ? "Gaya titik berlabel dengan lokasi aktif."
                : "Labeled dot style with the active location."
        case .prayerCountdownWithoutLocation:
            return isMalayAppLanguage()
                ? "Gaya titik berlabel tanpa lokasi."
                : "Labeled dot style without the location."
        case .prayerCountdownClassicWithLocation:
            return isMalayAppLanguage()
                ? "Gaya titik asal tanpa label dengan lokasi aktif."
                : "The original dot style without labels, with the active location."
        case .prayerCountdownClassicWithoutLocation:
            return isMalayAppLanguage()
                ? "Gaya titik asal tanpa label dan tanpa lokasi."
                : "The original dot style without labels or location."
        case .prayerCountdownCenteredWithLocation:
            return isMalayAppLanguage()
                ? "Gaya titik tengah dengan lokasi aktif."
                : "A centered dot style with the active location."
        case .prayerCountdownCenteredWithoutLocation:
            return isMalayAppLanguage()
                ? "Gaya titik tengah tanpa lokasi."
                : "A centered dot style without the location."
        case .prayerTimelineWithLocation:
            return isMalayAppLanguage()
                ? "Gaya graf garisan dengan lokasi aktif."
                : "Line-graph style with the active location."
        case .prayerTimelineWithoutLocation:
            return isMalayAppLanguage()
                ? "Gaya graf garisan tanpa lokasi."
                : "Line-graph style without the location."
        case .prayerTimelinePlusWithLocation:
            return isMalayAppLanguage()
                ? "Graf yang lebih lembut, tinggi, dan melengkung dengan lokasi aktif."
                : "A softer, taller, curvier graph with the active location."
        case .prayerTimelinePlusWithoutLocation:
            return isMalayAppLanguage()
                ? "Graf yang lebih lembut, tinggi, dan melengkung tanpa lokasi."
                : "A softer, taller, curvier graph without the location."
        }
    }
}

enum LockScreenPrayerCountdownBarStyle: String, CaseIterable, Identifiable {
    static let storageKey = "lockScreenPrayerCountdownBarStyle"

    case withLocation
    case withoutLocation
    case batteryWithLocation
    case batteryWithoutLocation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .withLocation, .withoutLocation:
            return isMalayAppLanguage()
                ? (self == .withLocation ? "Bar Kiraan Detik + Lokasi" : "Bar Kiraan Detik")
                : (self == .withLocation ? "Countdown Bar + Location" : "Countdown Bar")
        case .batteryWithLocation, .batteryWithoutLocation:
            return isMalayAppLanguage()
                ? (self == .batteryWithLocation ? "Bar Kiraan Bateri + Lokasi" : "Bar Kiraan Bateri")
                : (self == .batteryWithLocation ? "Battery Countdown + Location" : "Battery Countdown")
        }
    }

    var summary: String {
        switch self {
        case .withLocation:
            return isMalayAppLanguage()
                ? "Bar kiraan detik penuh dengan lokasi aktif."
                : "Full countdown bar with the active location."
        case .withoutLocation:
            return isMalayAppLanguage()
                ? "Bar kiraan detik penuh tanpa lokasi."
                : "Full countdown bar without the location."
        case .batteryWithLocation:
            return isMalayAppLanguage()
                ? "Gaya bar bateri yang lebih besar dengan lokasi aktif."
                : "A larger battery-like countdown style with the active location."
        case .batteryWithoutLocation:
            return isMalayAppLanguage()
                ? "Gaya bar bateri yang lebih besar tanpa lokasi."
                : "A larger battery-like countdown style without the location."
        }
    }
}

enum LockScreenWidgetPreviewStyle: String, CaseIterable, Identifiable {
    static let storageKey = "selectedLockScreenWidgetPreviewStyle"

    case nextPrayerCircular
    case prayerTimeline
    case prayerList
    case prayerCountdown
    case zikir
    case dailyVerse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nextPrayerCircular:
            return isMalayAppLanguage() ? "Bulatan Solat Seterusnya" : "Next Prayer Circle"
        case .prayerTimeline:
            return isMalayAppLanguage() ? "Garis Masa Solat" : "Prayer Timeline"
        case .prayerList:
            return isMalayAppLanguage() ? "Senarai Solat" : "Prayer List"
        case .prayerCountdown:
            return isMalayAppLanguage() ? "Kiraan Detik Solat" : "Prayer Countdown"
        case .zikir:
            return isMalayAppLanguage() ? "Zikir & Selawat" : "Zikir & Selawat"
        case .dailyVerse:
            return isMalayAppLanguage() ? "Ayat Harian" : "Daily Verse"
        }
    }

    var summary: String {
        switch self {
        case .nextPrayerCircular:
            return isMalayAppLanguage() ? "Paparan bulat yang ringkas untuk solat seterusnya." : "A compact circular style for the next prayer."
        case .prayerTimeline:
            return isMalayAppLanguage() ? "Fokus pada solat semasa, masa seterusnya, dan garis mini." : "Focuses on the current prayer, next time, and a mini graph."
        case .prayerList:
            return isMalayAppLanguage() ? "Paparan senarai yang menunjukkan beberapa waktu solat sekali gus." : "A list layout that shows several prayer times at once."
        case .prayerCountdown:
            return isMalayAppLanguage() ? "Kiraan detik yang jelas dengan bar kemajuan." : "A clearer countdown with a progress bar."
        case .zikir:
            return isMalayAppLanguage() ? "Zikir ringkas dalam susun atur yang tenang." : "A calm layout for short daily adhkar."
        case .dailyVerse:
            return isMalayAppLanguage() ? "Ayat harian ringkas untuk skrin kunci." : "A compact daily verse for the Lock Screen."
        }
    }

    var familyName: String {
        switch self {
        case .nextPrayerCircular:
            return isMalayAppLanguage() ? "Bulatan" : "Circular"
        default:
            return isMalayAppLanguage() ? "Segi empat" : "Rectangular"
        }
    }
}

private func appLocalizedBundle(for storedCode: String? = storedAppLanguageCode()) -> Bundle {
    let languageCode = effectiveAppLanguageCode(from: storedCode)
    guard
        let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
        let bundle = Bundle(path: path)
    else {
        return .main
    }

    return bundle
}

func appLocalized(_ key: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: appLocalizedBundle(), comment: "")
}

func appLocalized(_ key: String, _ args: CVarArg...) -> String {
    let format = appLocalized(key)
    return String(format: format, locale: appLocale(), arguments: args)
}

func localizedPrayerName(_ raw: String) -> String {
    switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "subuh", "fajr":
        return appLocalized("Fajr")
    case "syuruk", "shurooq", "sunrise":
        return appLocalized("Shurooq")
    case "zuhur", "dhuhr", "jumuah":
        return appLocalized("Dhuhr")
    case "asar", "asr":
        return appLocalized("Asr")
    case "isyak", "isya", "isha":
        return appLocalized("Isha")
    case "maghrib", "magrib":
        return appLocalized("Maghrib")
    default:
        return raw
    }
}

func localizedPrayerMeaning(_ raw: String) -> String {
    let isMalay = effectiveAppLanguageCode().hasPrefix("ms")

    switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "dawn":
        return isMalay ? "Fajar" : "Dawn"
    case "sunrise":
        return isMalay ? "Matahari terbit" : "Sunrise"
    case "midday":
        return isMalay ? "Tengah hari" : "Midday"
    case "afternoon":
        return isMalay ? "Petang" : "Afternoon"
    case "sunset":
        return isMalay ? "Matahari terbenam" : "Sunset"
    case "night":
        return isMalay ? "Malam" : "Night"
    default:
        return raw
    }
}

func localizedShurooqSummaryText() -> String {
    effectiveAppLanguageCode().hasPrefix("ms")
        ? "Syuruk bukan satu solat, tetapi menandakan berakhirnya waktu Subuh."
        : "Shurooq is not a prayer, but marks the end of Fajr."
}

func localizedHijriMonthName(_ month: Int) -> String {
    switch month {
    case 1: return appLocalized("Muharram")
    case 2: return appLocalized("Safar")
    case 3: return appLocalized("Rabi al-Awwal")
    case 4: return appLocalized("Rabi al-Thani")
    case 5: return appLocalized("Jumada al-Ula")
    case 6: return appLocalized("Jumada al-Thani")
    case 7: return appLocalized("Rajab")
    case 8: return appLocalized("Sha'ban")
    case 9: return appLocalized("Ramadan")
    case 10: return appLocalized("Shawwal")
    case 11: return appLocalized("Dhul Qi'dah")
    case 12: return appLocalized("Dhul Hijjah")
    default: return ""
    }
}

func localizedPrayerRakahInfo(_ rakah: String) -> String {
    effectiveAppLanguageCode().hasPrefix("ms")
        ? "Solat rakaat: \(rakah)"
        : appLocalized("Prayer Rakahs: %@", rakah)
}

func localizedSunnahBeforeInfo(_ rakah: String) -> String {
    effectiveAppLanguageCode().hasPrefix("ms")
        ? "Rakaat sebelum solat: \(rakah)"
        : appLocalized("Sunnah Rakahs Before: %@", rakah)
}

func localizedSunnahAfterInfo(_ rakah: String) -> String {
    effectiveAppLanguageCode().hasPrefix("ms")
        ? "Rakaat selepas solat: \(rakah)"
        : appLocalized("Sunnah Rakahs After: %@", rakah)
}

func localizedPrayerDetailNote(for prayerName: String) -> String? {
    let normalized = prayerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let isMalay = effectiveAppLanguageCode().hasPrefix("ms")

    switch normalized {
    case "shurooq", "syuruk", "sunrise":
        return isMalay
            ? "Berdasarkan Sahih Muslim 612a, Syuruk menandakan berakhirnya waktu Subuh. Syuruk bukan solat fardu yang tersendiri."
            : "Based on Sahih Muslim 612a, Shurooq marks the end of Fajr time. It is not a prayer itself."
    case "fajr", "subuh":
        return isMalay
            ? "Dalam Sahih Muslim 612a, Rasulullah SAW menjelaskan bahawa waktu Subuh berterusan sehingga mula terbit matahari."
            : "In Sahih Muslim 612a, the Prophet ﷺ described Fajr as lasting until the first part of the sun appears."
    case "dhuhr", "dhuhr/asr", "zuhur":
        return isMalay
            ? "Dalam Sahih Muslim 612a, Rasulullah SAW menjelaskan bahawa waktu Zuhur berterusan sehingga masuk waktu Asar."
            : "In Sahih Muslim 612a, the Prophet ﷺ described Dhuhr as lasting until Asr begins."
    case "asr", "asar":
        return isMalay
            ? "Dalam Sahih Muslim 612a, Rasulullah SAW menjelaskan bahawa waktu Asar berterusan sehingga matahari menjadi kekuningan."
            : "In Sahih Muslim 612a, the Prophet ﷺ described Asr as lasting until the sun turns yellow."
    case "maghrib", "maghrib/isha", "magrib":
        return isMalay
            ? "Dalam Sahih Muslim 612a, Rasulullah SAW menjelaskan bahawa waktu Maghrib berterusan sehingga hilang cahaya senja."
            : "In Sahih Muslim 612a, the Prophet ﷺ described Maghrib as lasting until the twilight disappears."
    case "isha", "isyak", "isya":
        return isMalay
            ? "Dalam Sahih Muslim 612a, Rasulullah SAW menjelaskan bahawa waktu Isyak berterusan sehingga pertengahan malam."
            : "In Sahih Muslim 612a, the Prophet ﷺ described Isha as lasting until half of the night has passed."
    case "jumuah":
        return isMalay
            ? "Dalam Sunan Abi Dawud 1067, Rasulullah SAW bersabda bahawa solat Jumaat berjemaah ialah kewajipan bagi setiap Muslim kecuali hamba, wanita, kanak-kanak, dan orang yang sakit."
            : "In Sunan Abi Dawud 1067, the Prophet ﷺ said that Friday prayer in congregation is obligatory for every Muslim except a slave, a woman, a child, and a sick person."
    default:
        return nil
    }
}

enum AccentColor: String, CaseIterable, Identifiable {
    var id: String { self.rawValue }

    case adaptive, red, orange, yellow, green, blue, indigo, cyan, teal, mint, purple, brown, lightPink, hotPink, emerald, coral

    var color: Color {
        switch self {
        case .adaptive: return .primary
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .indigo: return .indigo
        case .cyan: return .cyan
        case .teal: return .teal
        case .mint: return .mint
        case .purple: return .purple
        case .brown: return .brown
        case .lightPink: return Color(red: 1.0, green: 182.0 / 255.0, blue: 193.0 / 255.0) // #ffb6c1
        case .hotPink: return Color(red: 1.0, green: 105.0 / 255.0, blue: 180.0 / 255.0)   // #ff69b4
        case .emerald: return Color(red: 0.0, green: 168.0 / 255.0, blue: 107.0 / 255.0)   // #00a86b
        case .coral: return Color(red: 1.0, green: 127.0 / 255.0, blue: 80.0 / 255.0)      // #ff7f50
        }
    }

    var toggleTint: Color {
        switch self {
        case .adaptive: return Color(UIColor.systemGray)
        default: return color
        }
    }

    static func fromStoredValue(_ raw: String?) -> AccentColor {
        guard let raw else { return .adaptive }
        switch raw {
        case "pink":
            return .hotPink
        case "white", "default":
            return .adaptive
        default:
            return AccentColor(rawValue: raw) ?? .adaptive
        }
    }
}

let accentColors: [AccentColor] = AccentColor.allCases

struct CustomColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme? = nil
}

extension EnvironmentValues {
    var customColorScheme: ColorScheme? {
        get { self[CustomColorSchemeKey.self] }
        set { self[CustomColorSchemeKey.self] = newValue }
    }
}

func arabicNumberString(from number: Int) -> String {
    let arabicNumbers = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
    return String(number).map { arabicNumbers[Int(String($0))!] }.joined()
}

private let quranStripScalars: Set<UnicodeScalar> = {
    var s = Set<UnicodeScalar>()

    // Tashkeel  U+064B…U+065F
    for v in 0x064B...0x065F { if let u = UnicodeScalar(v) { s.insert(u) } }

    // Quranic annotation signs  U+06D6…U+06ED
    for v in 0x06D6...0x06ED { if let u = UnicodeScalar(v) { s.insert(u) } }

    // Extras: short alif, madda, open ta-marbuta, dagger alif
    [0x0670, 0x0657, 0x0674, 0x0656].forEach { v in
        if let u = UnicodeScalar(v) { s.insert(u) }
    }

    return s
}()

extension String {
    var removingArabicDiacriticsAndSigns: String {
        var out = String.UnicodeScalarView()
        out.reserveCapacity(unicodeScalars.count)

        for scalar in unicodeScalars {
            switch scalar.value {
            case 0x0671: // ٱ  hamzatul-wasl
                out.append(UnicodeScalar(0x0627)!)
            default:
                if !quranStripScalars.contains(scalar) { out.append(scalar) }
            }
        }
        return String(out)
    }
    
    func removeDiacriticsFromLastLetter() -> String {
        guard let last = last else { return self }
        let cleaned = String(last).removingArabicDiacriticsAndSigns
        return cleaned == String(last) ? self : dropLast() + cleaned
    }

    subscript(_ r: Range<Int>) -> Substring {
        let start = index(startIndex, offsetBy: r.lowerBound)
        let end = index(startIndex, offsetBy: r.upperBound)
        return self[start..<end]
    }
}

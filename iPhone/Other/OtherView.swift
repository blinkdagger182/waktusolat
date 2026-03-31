import SwiftUI

struct LibraryDailyQuranQuote: Codable {
    let dayKey: String
    let reference: String
    let text: String
    let surahName: String
}

private struct LibraryQuranAyahAPIResponse: Decodable {
    let translationText: String
    let surahNameEnglish: String
}

private struct LibraryInspiringVerseReference: Hashable {
    let reference: String
    let theme: String
    let fallbackText: String?
}

private struct LibraryInspiringVerseReferencePayload: Decodable {
    let reference: String
    let theme: String
}

private struct LibraryQuotesJSONPayload: Decodable {
    let reference: String
    let ayat: String
}

private enum LibraryDailyInspirationPool {
    static let seedKey = "dailyInspirationUserSeed"

    static let fallbackBaseReferences: [LibraryInspiringVerseReference] = [
        .init(reference: "94:5", theme: "hope", fallbackText: nil),
        .init(reference: "94:6", theme: "hope", fallbackText: nil),
        .init(reference: "2:286", theme: "trust", fallbackText: nil),
        .init(reference: "65:3", theme: "trust", fallbackText: nil),
        .init(reference: "2:152", theme: "remembrance", fallbackText: nil),
        .init(reference: "6:54", theme: "mercy", fallbackText: nil),
        .init(reference: "7:156", theme: "mercy", fallbackText: nil),
        .init(reference: "30:60", theme: "patience", fallbackText: nil),
        .init(reference: "2:153", theme: "patience", fallbackText: nil),
        .init(reference: "2:45", theme: "patience", fallbackText: nil),
        .init(reference: "3:159", theme: "trust", fallbackText: nil),
        .init(reference: "3:139", theme: "hope", fallbackText: nil),
        .init(reference: "4:96", theme: "mercy", fallbackText: nil),
        .init(reference: "3:150", theme: "trust", fallbackText: nil),
        .init(reference: "16:128", theme: "perseverance", fallbackText: nil),
        .init(reference: "50:16", theme: "remembrance", fallbackText: nil),
        .init(reference: "13:28", theme: "peace", fallbackText: nil),
        .init(reference: "11:88", theme: "trust", fallbackText: nil),
        .init(reference: "93:5", theme: "hope", fallbackText: nil),
        .init(reference: "93:6", theme: "mercy", fallbackText: nil),
        .init(reference: "17:70", theme: "gratitude", fallbackText: nil),
        .init(reference: "2:257", theme: "trust", fallbackText: nil),
        .init(reference: "14:7", theme: "gratitude", fallbackText: nil),
        .init(reference: "40:60", theme: "remembrance", fallbackText: nil),
        .init(reference: "5:93", theme: "mercy", fallbackText: nil),
        .init(reference: "7:56", theme: "mercy", fallbackText: nil),
        .init(reference: "2:185", theme: "hope", fallbackText: nil),
        .init(reference: "42:19", theme: "trust", fallbackText: nil),
        .init(reference: "93:3", theme: "hope", fallbackText: nil),
        .init(reference: "29:69", theme: "perseverance", fallbackText: nil),
        .init(reference: "50:39", theme: "patience", fallbackText: nil),
        .init(reference: "11:61", theme: "trust", fallbackText: nil),
        .init(reference: "65:2", theme: "trust", fallbackText: nil),
        .init(reference: "10:64", theme: "hope", fallbackText: nil),
        .init(reference: "10:58", theme: "gratitude", fallbackText: nil),
        .init(reference: "57:4", theme: "peace", fallbackText: nil),
        .init(reference: "7:180", theme: "remembrance", fallbackText: nil),
        .init(reference: "10:62", theme: "peace", fallbackText: nil),
        .init(reference: "99:7", theme: "perseverance", fallbackText: nil),
        .init(reference: "93:7", theme: "hope", fallbackText: nil)
    ]

    static let baseReferences: [LibraryInspiringVerseReference] = {
        if let loaded = loadFromQuotesJSON(), !loaded.isEmpty {
            return loaded
        }
        if let loaded = loadFromJSON(), !loaded.isEmpty {
            return loaded
        }
        return fallbackBaseReferences
    }()

    static let references: [LibraryInspiringVerseReference] = {
        let source = baseReferences
        guard !source.isEmpty else { return [] }

        if source.count >= 365 {
            return Array(source.prefix(365))
        }

        return (0..<365).map { idx in
            let mixed = (idx * 37 + idx / 7 + 11) % source.count
            return source[mixed]
        }
    }()

    static func reference(for date: Date, defaults: UserDefaults?) -> LibraryInspiringVerseReference {
        let pool = references
        guard !pool.isEmpty else {
            return LibraryInspiringVerseReference(
                reference: "94:5",
                theme: "hope",
                fallbackText: "Sesungguhnya bersama kesukaran ada kemudahan."
            )
        }

        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let userSeed = loadUserSeed(defaults: defaults)
        let cycleIndex = (userSeed &+ UInt64(dayOfYear * 48271)) % 365
        return pool[Int(cycleIndex % UInt64(pool.count))]
    }

    private static func loadUserSeed(defaults: UserDefaults?) -> UInt64 {
        if let number = defaults?.object(forKey: seedKey) as? NSNumber {
            return number.uint64Value
        }
        if let existingInt = defaults?.object(forKey: seedKey) as? Int {
            return UInt64(max(existingInt, 1))
        }
        if let existingString = defaults?.string(forKey: seedKey), let parsed = UInt64(existingString) {
            return parsed
        }
        if let existingData = defaults?.data(forKey: seedKey),
           let parsed = try? JSONDecoder().decode(UInt64.self, from: existingData) {
            return parsed
        }

        let newSeed = UInt64.random(in: 1...UInt64.max / 2)
        defaults?.set(NSNumber(value: newSeed), forKey: seedKey)
        return newSeed
    }

    private static func loadFromJSON() -> [LibraryInspiringVerseReference]? {
        let possibleURLs: [URL?] = [
            Bundle.main.url(forResource: "QuranInspirationReferences", withExtension: "json"),
            Bundle.main.url(forResource: "QuranInspirationReferences", withExtension: "json", subdirectory: "Shared"),
            Bundle.main.url(forResource: "QuranInspirationReferences", withExtension: "json", subdirectory: "Resources/JSONs")
        ]

        guard let fileURL = possibleURLs.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode([LibraryInspiringVerseReferencePayload].self, from: data)
        else {
            return nil
        }

        let filtered = payload
            .filter { isSingleAyahReference($0.reference) }
            .map { LibraryInspiringVerseReference(reference: $0.reference, theme: $0.theme, fallbackText: nil) }

        return filtered.isEmpty ? nil : filtered
    }

    private static func loadFromQuotesJSON() -> [LibraryInspiringVerseReference]? {
        let possibleURLs: [URL?] = [
            Bundle.main.url(forResource: "quotes", withExtension: "json"),
            Bundle.main.url(forResource: "quotes", withExtension: "json", subdirectory: "Resources"),
            Bundle.main.url(forResource: "quotes", withExtension: "json", subdirectory: "Resources/JSONs")
        ]

        guard let fileURL = possibleURLs.compactMap({ $0 }).first,
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode([LibraryQuotesJSONPayload].self, from: data)
        else {
            return nil
        }

        var seen = Set<String>()
        var parsed: [LibraryInspiringVerseReference] = []
        for row in payload {
            guard isSingleAyahReference(row.reference) else { continue }
            if seen.insert(row.reference).inserted {
                parsed.append(.init(reference: row.reference, theme: "inspiration", fallbackText: row.ayat))
            }
        }

        return parsed.isEmpty ? nil : parsed
    }

    private static func isSingleAyahReference(_ reference: String) -> Bool {
        let comps = reference.split(separator: ":")
        guard comps.count == 2 else { return false }
        guard !comps[0].contains("-"), !comps[1].contains("-") else { return false }
        return Int(comps[0]) != nil && Int(comps[1]) != nil
    }
}

struct FullSurahSelection: Identifiable, Equatable {
    let surahNumber: Int
    let initialAyahNumber: Int?
    let dailyAyahNumber: Int?
    var id: String { "\(surahNumber):\(initialAyahNumber ?? 0):\(dailyAyahNumber ?? 0)" }
}

enum FullQuranResumeStorage {
    static let lastSurahKey = "fullQuranLastViewedSurahV1"
    static let lastAyahKey = "fullQuranLastViewedAyahV1"
    static let lastPlayedSurahKey = "fullQuranLastPlayedSurahV1"
    static let lastPlayedAyahKey = "fullQuranLastPlayedAyahV1"
}

private struct DailyQuranReferenceParts {
    let surahNumber: Int
    let ayahNumber: Int?
}

private enum PrayerTimeSlot: String, CaseIterable, Hashable {
    case morning
    case midday
    case afternoon
    case evening
    case night

    var systemIcon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .afternoon: return "sun.horizon.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var color: Color {
        switch self {
        case .morning: return Color(red: 0.96, green: 0.66, blue: 0.21)
        case .midday: return Color(red: 0.98, green: 0.53, blue: 0.12)
        case .afternoon: return Color(red: 0.91, green: 0.41, blue: 0.21)
        case .evening: return Color(red: 0.62, green: 0.32, blue: 0.76)
        case .night: return Color(red: 0.27, green: 0.35, blue: 0.70)
        }
    }

    var title: String {
        switch self {
        case .morning: return isMalayAppLanguage() ? "Pagi" : "Morning"
        case .midday: return isMalayAppLanguage() ? "Tengah Hari" : "Midday"
        case .afternoon: return isMalayAppLanguage() ? "Petang" : "Afternoon"
        case .evening: return isMalayAppLanguage() ? "Senja" : "Evening"
        case .night: return isMalayAppLanguage() ? "Malam" : "Night"
        }
    }

    var subtitle: String {
        switch self {
        case .morning:
            return isMalayAppLanguage()
                ? "Amalan perlindungan selepas Subuh."
                : "Protective recitations after Fajr."
        case .midday:
            return isMalayAppLanguage()
                ? "Amalan Dhuha dan renungan ketika hari meninggi."
                : "Dhuha practices and reflections as the day rises."
        case .afternoon:
            return isMalayAppLanguage()
                ? "Peringatan untuk waktu Asar dan lewat petang."
                : "Reminders for Asr and the late afternoon."
        case .evening:
            return isMalayAppLanguage()
                ? "Zikir petang untuk menutup siang."
                : "Evening adhkar to close the day."
        case .night:
            return isMalayAppLanguage()
                ? "Bacaan sebelum tidur dan Witir."
                : "Before-sleep recitations and Witr."
        }
    }
}

private struct TodayPractice: Identifiable, Hashable {
    enum Badge: Hashable {
        case authenticSunnah
        case reflection

        var label: String {
            switch self {
            case .authenticSunnah:
                return isMalayAppLanguage() ? "✓ Sunnah Sahih" : "✓ Authentic Sunnah"
            case .reflection:
                return isMalayAppLanguage() ? "✨ Cadangan Renungan" : "✨ Reflection Suggestion"
            }
        }

        var color: Color {
            switch self {
            case .authenticSunnah:
                return Color(red: 0.20, green: 0.63, blue: 0.37)
            case .reflection:
                return Color(red: 0.55, green: 0.31, blue: 0.73)
            }
        }
    }

    let id: String
    let arabicText: String
    let titleEn: String
    let titleMy: String
    let descriptionEn: String
    let descriptionMy: String
    let badge: Badge
    let sourceTextEn: String?
    let sourceTextMy: String?
    let sourceReference: String?
    let noteEn: String?
    let noteMy: String?
    let surahNumber: Int?
    let ayahNumber: Int?
    let slots: Set<PrayerTimeSlot>
}

private enum TodayPracticeLibrary {
    static let all: [TodayPractice] = [
        .init(
            id: "morning-three-quls",
            arabicText: "قُلْ هُوَ ٱللَّهُ أَحَدٌ • قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ • قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ",
            titleEn: "Three Quls (3x)",
            titleMy: "Tiga Qul (3x)",
            descriptionEn: "Recite Al-Ikhlas, Al-Falaq, and An-Nas three times each for protection through the day.",
            descriptionMy: "Baca Al-Ikhlas, Al-Falaq, dan An-Nas tiga kali setiap satu untuk perlindungan sepanjang hari.",
            badge: .authenticSunnah,
            sourceTextEn: "Recite them three times in the morning and evening; they will suffice you from everything.",
            sourceTextMy: "Bacalah tiga kali pada waktu pagi dan petang; ia akan mencukupimu daripada segala sesuatu.",
            sourceReference: "Sunan al-Tirmidhi 3575",
            noteEn: nil,
            noteMy: nil,
            surahNumber: 112,
            ayahNumber: nil,
            slots: [.morning, .evening]
        ),
        .init(
            id: "morning-ayat-kursi",
            arabicText: "ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ",
            titleEn: "Ayat Kursi",
            titleMy: "Ayat Kursi",
            descriptionEn: "A widely taught morning protection recitation carried in daily adhkar compilations.",
            descriptionMy: "Bacaan perlindungan pagi yang masyhur dalam himpunan zikir harian.",
            badge: .authenticSunnah,
            sourceTextEn: "Whoever recites Ayat al-Kursi in the morning will be protected until evening.",
            sourceTextMy: "Sesiapa membaca Ayat al-Kursi pada waktu pagi akan dilindungi hingga petang.",
            sourceReference: "Al-Hakim · Hisnul Muslim",
            noteEn: "The strongest chain is for night, but morning use is widely accepted in adhkar works.",
            noteMy: "Riwayat paling kuat ialah untuk malam, tetapi amalan pagi diterima luas dalam karya zikir.",
            surahNumber: 2,
            ayahNumber: 255,
            slots: [.morning]
        ),
        .init(
            id: "midday-dhuha-prayer",
            arabicText: "صَلَاةُ ٱلضُّحَىٰ",
            titleEn: "Dhuha Prayer",
            titleMy: "Solat Dhuha",
            descriptionEn: "Two rak'ahs of Dhuha fulfill the charity due from every joint each morning.",
            descriptionMy: "Dua rakaat Dhuha mencukupi sedekah bagi setiap sendi pada setiap pagi.",
            badge: .authenticSunnah,
            sourceTextEn: "Two rak'ahs of Dhuha suffice for that.",
            sourceTextMy: "Dua rakaat Dhuha mencukupi untuk itu.",
            sourceReference: "Sahih Muslim 720",
            noteEn: "This is a prayer recommendation, not a surah-specific recitation.",
            noteMy: "Ini saranan solat, bukan bacaan surah khusus.",
            surahNumber: nil,
            ayahNumber: nil,
            slots: [.midday]
        ),
        .init(
            id: "midday-ad-duha",
            arabicText: "وَٱلضُّحَىٰ ۝ وَٱلَّيْلِ إِذَا سَجَىٰ",
            titleEn: "Surah Ad-Duha",
            titleMy: "Surah Ad-Duha",
            descriptionEn: "A fitting midday reflection on reassurance and divine care.",
            descriptionMy: "Renungan tengah hari yang sesuai tentang ketenangan dan penjagaan Allah.",
            badge: .reflection,
            sourceTextEn: nil,
            sourceTextMy: nil,
            sourceReference: nil,
            noteEn: "Thematically aligned with Dhuha time, but not prescribed for this time in sahih hadith.",
            noteMy: "Selari dari segi tema dengan waktu Dhuha, tetapi tidak ditetapkan khusus pada waktu ini dalam hadis sahih.",
            surahNumber: 93,
            ayahNumber: nil,
            slots: [.midday]
        ),
        .init(
            id: "midday-ash-sharh",
            arabicText: "أَلَمْ نَشْرَحْ لَكَ صَدْرَكَ",
            titleEn: "Surah Ash-Sharh",
            titleMy: "Surah Ash-Sharh",
            descriptionEn: "A midday reminder that hardship and ease arrive together.",
            descriptionMy: "Peringatan tengah hari bahawa kesukaran dan kemudahan datang bersama.",
            badge: .reflection,
            sourceTextEn: nil,
            sourceTextMy: nil,
            sourceReference: nil,
            noteEn: "A reflection suggestion only, not a time-specific Sunnah recitation.",
            noteMy: "Cadangan renungan sahaja, bukan bacaan Sunnah yang khusus pada waktu ini.",
            surahNumber: 94,
            ayahNumber: nil,
            slots: [.midday]
        ),
        .init(
            id: "afternoon-dhikr",
            arabicText: "سُبْحَانَ ٱللَّٰهِ 33 • ٱلْحَمْدُ لِلَّٰهِ 33 • ٱللَّٰهُ أَكْبَرُ 34",
            titleEn: "Tasbih, Tahmid, Takbir",
            titleMy: "Tasbih, Tahmid, Takbir",
            descriptionEn: "A compact dhikr set to renew remembrance as the day begins to close.",
            descriptionMy: "Zikir ringkas untuk menyegarkan ingatan kepada Allah ketika hari mula menutup.",
            badge: .authenticSunnah,
            sourceTextEn: "Say SubhanAllah 33 times, Alhamdulillah 33 times, and Allahu Akbar 34 times.",
            sourceTextMy: "Ucapkan SubhanAllah 33 kali, Alhamdulillah 33 kali, dan Allahu Akbar 34 kali.",
            sourceReference: "Sahih al-Bukhari 843 · Sahih Muslim 597",
            noteEn: "Authentic dhikr, though not limited to only the Asr window.",
            noteMy: "Zikir yang sahih, walaupun tidak terhad khusus pada jendela waktu Asar sahaja.",
            surahNumber: nil,
            ayahNumber: nil,
            slots: [.afternoon]
        ),
        .init(
            id: "afternoon-al-asr",
            arabicText: "وَٱلْعَصْرِ ۝ إِنَّ ٱلْإِنسَٰنَ لَفِى خُسْرٍ",
            titleEn: "Surah Al-Asr",
            titleMy: "Surah Al-Asr",
            descriptionEn: "A short but sharp reminder that time is the real measure of loss and success.",
            descriptionMy: "Peringatan yang ringkas tetapi tajam bahawa masa ialah ukuran sebenar rugi dan untung.",
            badge: .reflection,
            sourceTextEn: "The companions were reported to recite it to each other when parting.",
            sourceTextMy: "Para sahabat dilaporkan membacanya sesama mereka ketika berpisah.",
            sourceReference: "Reported in tafsir works",
            noteEn: "Not established as a specific Asr-time recitation in sahih hadith.",
            noteMy: "Tidak sabit sebagai bacaan khusus waktu Asar dalam hadis sahih.",
            surahNumber: 103,
            ayahNumber: nil,
            slots: [.afternoon]
        ),
        .init(
            id: "evening-three-quls",
            arabicText: "قُلْ هُوَ ٱللَّهُ أَحَدٌ • قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ • قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ",
            titleEn: "Three Quls (3x)",
            titleMy: "Tiga Qul (3x)",
            descriptionEn: "The same protective recitations return in the evening adhkar.",
            descriptionMy: "Bacaan perlindungan yang sama kembali dalam zikir petang.",
            badge: .authenticSunnah,
            sourceTextEn: "Recite them three times in the morning and evening; they will suffice you from everything.",
            sourceTextMy: "Bacalah tiga kali pada waktu pagi dan petang; ia akan mencukupimu daripada segala sesuatu.",
            sourceReference: "Sunan al-Tirmidhi 3575",
            noteEn: nil,
            noteMy: nil,
            surahNumber: 112,
            ayahNumber: nil,
            slots: [.evening]
        ),
        .init(
            id: "evening-ayat-kursi",
            arabicText: "ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ",
            titleEn: "Ayat Kursi",
            titleMy: "Ayat Kursi",
            descriptionEn: "A strong evening protection recitation commonly taught in adhkar collections.",
            descriptionMy: "Bacaan perlindungan petang yang kuat dan masyhur dalam himpunan zikir.",
            badge: .authenticSunnah,
            sourceTextEn: "Included broadly in evening adhkar collections for protection.",
            sourceTextMy: "Dimasukkan secara meluas dalam himpunan zikir petang untuk perlindungan.",
            sourceReference: "Hisnul Muslim",
            noteEn: "Night evidence is strongest, with evening use carried by established adhkar practice.",
            noteMy: "Dalil malam lebih kuat, manakala amalan petang dibawa oleh tradisi zikir yang mantap.",
            surahNumber: 2,
            ayahNumber: 255,
            slots: [.evening]
        ),
        .init(
            id: "night-ayat-kursi",
            arabicText: "ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ",
            titleEn: "Ayat Kursi Before Sleep",
            titleMy: "Ayat Kursi Sebelum Tidur",
            descriptionEn: "A protector from Allah remains with you until morning.",
            descriptionMy: "Penjaga daripada Allah kekal bersamamu hingga pagi.",
            badge: .authenticSunnah,
            sourceTextEn: "A protector from Allah will remain with him, and no devil will approach him until morning.",
            sourceTextMy: "Seorang penjaga daripada Allah akan terus bersamanya, dan syaitan tidak akan mendekatinya hingga pagi.",
            sourceReference: "Sahih al-Bukhari 2311",
            noteEn: nil,
            noteMy: nil,
            surahNumber: 2,
            ayahNumber: 255,
            slots: [.night]
        ),
        .init(
            id: "night-baqarah-last-two",
            arabicText: "آمَنَ ٱلرَّسُولُ بِمَآ أُنزِلَ إِلَيْهِ مِن رَّبِّهِۦ",
            titleEn: "Last Two Verses of Al-Baqarah",
            titleMy: "Dua Ayat Terakhir Al-Baqarah",
            descriptionEn: "Recite Al-Baqarah 285-286 at night; they will suffice you.",
            descriptionMy: "Baca Al-Baqarah 285-286 pada waktu malam; ia akan mencukupimu.",
            badge: .authenticSunnah,
            sourceTextEn: "Whoever recites the last two verses of Surah Al-Baqarah at night, they will suffice him.",
            sourceTextMy: "Sesiapa membaca dua ayat terakhir Surah Al-Baqarah pada waktu malam, ia akan mencukupinya.",
            sourceReference: "Sahih al-Bukhari 5009 · Sahih Muslim 808",
            noteEn: nil,
            noteMy: nil,
            surahNumber: 2,
            ayahNumber: 285,
            slots: [.night]
        ),
        .init(
            id: "night-three-quls-sleep",
            arabicText: "قُلْ هُوَ ٱللَّهُ أَحَدٌ • قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ • قُلْ أَعُوذُ بِرَبِّ ٱلنَّاسِ",
            titleEn: "Three Quls Before Sleep",
            titleMy: "Tiga Qul Sebelum Tidur",
            descriptionEn: "Recite, blow into your hands, then wipe over your body three times.",
            descriptionMy: "Baca, tiup ke dalam tapak tangan, kemudian sapu ke seluruh badan tiga kali.",
            badge: .authenticSunnah,
            sourceTextEn: "The Prophet ﷺ would recite them, blow into his hands, and wipe over his body before sleep.",
            sourceTextMy: "Nabi ﷺ membaca surah-surah ini, meniup ke tapak tangannya, lalu menyapu ke seluruh tubuh sebelum tidur.",
            sourceReference: "Sahih al-Bukhari 5017",
            noteEn: nil,
            noteMy: nil,
            surahNumber: 112,
            ayahNumber: nil,
            slots: [.night]
        ),
        .init(
            id: "night-al-mulk",
            arabicText: "تَبَارَكَ ٱلَّذِى بِيَدِهِ ٱلْمُلْكُ",
            titleEn: "Surah Al-Mulk",
            titleMy: "Surah Al-Mulk",
            descriptionEn: "A thirty-verse surah that intercedes until forgiveness is granted.",
            descriptionMy: "Surah tiga puluh ayat yang memberi syafaat sehingga keampunan dikurniakan.",
            badge: .authenticSunnah,
            sourceTextEn: "A surah of 30 verses intercedes for a man until he is forgiven.",
            sourceTextMy: "Ada satu surah yang terdiri daripada 30 ayat memberi syafaat kepada seseorang hingga dia diampunkan.",
            sourceReference: "Sunan al-Tirmidhi 2891",
            noteEn: "Widely read at night, though the hadith text does not explicitly restrict it to bedtime.",
            noteMy: "Diamalkan secara meluas pada waktu malam, walaupun lafaz hadis tidak menghadkannya secara khusus kepada waktu tidur.",
            surahNumber: 67,
            ayahNumber: nil,
            slots: [.night]
        ),
        .init(
            id: "night-witr-surahs",
            arabicText: "سَبِّحِ ٱسْمَ رَبِّكَ ٱلْأَعْلَىٰ • قُلْ يَٰٓأَيُّهَا ٱلْكَٰفِرُونَ • قُلْ هُوَ ٱللَّهُ أَحَدٌ",
            titleEn: "Witr Surahs",
            titleMy: "Surah Dalam Witir",
            descriptionEn: "The Prophet ﷺ was reported to recite Al-A'la, Al-Kafirun, and Al-Ikhlas in Witr.",
            descriptionMy: "Nabi ﷺ diriwayatkan membaca Al-A'la, Al-Kafirun, dan Al-Ikhlas dalam Witir.",
            badge: .authenticSunnah,
            sourceTextEn: "He used to recite Al-A'la, Al-Kafirun, and Al-Ikhlas in Witr.",
            sourceTextMy: "Baginda membaca Al-A'la, Al-Kafirun, dan Al-Ikhlas dalam solat Witir.",
            sourceReference: "Sunan Abi Dawud 1423 · Sunan al-Tirmidhi 463",
            noteEn: "A Sunnah option for Witr, not an exclusive requirement.",
            noteMy: "Pilihan Sunnah untuk Witir, bukan satu-satunya ketetapan.",
            surahNumber: 87,
            ayahNumber: nil,
            slots: [.night]
        ),
        .init(
            id: "night-qunut",
            arabicText: "ٱللَّهُمَّ ٱهْدِنِي فِيمَنْ هَدَيْتَ",
            titleEn: "Qunut in Witr",
            titleMy: "Qunut Dalam Witir",
            descriptionEn: "A concise supplication taught for Witr: Allahumma ihdini feeman hadayt...",
            descriptionMy: "Doa ringkas yang diajar untuk Witir: Allahumma ihdini feeman hadayt...",
            badge: .authenticSunnah,
            sourceTextEn: "Allahumma ihdini feeman hadayt...",
            sourceTextMy: "Allahumma ihdini feeman hadayt...",
            sourceReference: "Sunan Abi Dawud 1425",
            noteEn: "Shown here as a Witr reminder rather than a Quran reading item.",
            noteMy: "Dipaparkan di sini sebagai peringatan Witir, bukan item bacaan Al-Quran.",
            surahNumber: nil,
            ayahNumber: nil,
            slots: [.night]
        )
    ]

    static func practices(for slot: PrayerTimeSlot) -> [TodayPractice] {
        all.filter { $0.slots.contains(slot) }
    }

    static func slot(currentPrayer: Prayer?, nextPrayer: Prayer?) -> PrayerTimeSlot {
        let currentKey = normalize(currentPrayer?.nameTransliteration ?? "")
        let nextKey = normalize(nextPrayer?.nameTransliteration ?? "")

        if nextKey == "fajr" || currentKey == "isha" {
            return .night
        }
        if currentKey == "fajr" || nextKey == "shurooq" {
            return .morning
        }
        if currentKey == "shurooq" || currentKey == "dhuhr" || currentKey == "jumuah" || nextKey == "asr" {
            return .midday
        }
        if currentKey == "asr" || nextKey == "maghrib" {
            return .afternoon
        }
        if currentKey == "maghrib" || nextKey == "isha" {
            return .evening
        }
        return .night
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}

private struct TodaySlotBanner: View {
    let slot: PrayerTimeSlot

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(slot.color.opacity(0.13))
                    .frame(width: 50, height: 50)

                Image(systemName: slot.systemIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(slot.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(slot.title)
                    .font(.headline.weight(.bold))

                Text(slot.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(slot.color.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(slot.color.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

private struct TodayPracticeCard: View {
    let practice: TodayPractice
    let accentColor: Color
    let onOpenSurah: (Int, Int?) -> Void

    @EnvironmentObject private var settings: Settings

    private var sourceText: String? {
        isMalayAppLanguage() ? practice.sourceTextMy : practice.sourceTextEn
    }

    private var noteText: String? {
        isMalayAppLanguage() ? practice.noteMy : practice.noteEn
    }

    private var titleText: String {
        isMalayAppLanguage() ? practice.titleMy : practice.titleEn
    }

    private var descriptionText: String {
        isMalayAppLanguage() ? practice.descriptionMy : practice.descriptionEn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(practice.badge.label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(practice.badge.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(practice.badge.color.opacity(0.12))
                )

            Text(practice.arabicText)
                .font(.custom(preferredQuranArabicFontName(settings: settings, size: 24), size: 24))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 5) {
                Text(titleText)
                    .font(.subheadline.weight(.semibold))

                Text(descriptionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let sourceText, let sourceReference = practice.sourceReference {
                VStack(alignment: .leading, spacing: 5) {
                    Text("“\(sourceText)”")
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("— \(sourceReference)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accentColor)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
            }

            if let noteText {
                Text(noteText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let surahNumber = practice.surahNumber {
                Button {
                    onOpenSurah(surahNumber, practice.ayahNumber)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "book.pages")
                            .font(.caption.weight(.semibold))
                        Text(isMalayAppLanguage() ? "Buka dalam Quran" : "Open in Quran")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accentColor.opacity(0.10))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

private enum LibrarySegment: String, CaseIterable {
    case today, quran

    func label() -> String {
        switch self {
        case .today: return isMalayAppLanguage() ? "Hari Ini" : "Today"
        case .quran: return isMalayAppLanguage() ? "Al-Quran" : "Quran"
        }
    }
}

struct OtherView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.openURL) private var openURL
    @State private var selectedSegment: LibrarySegment = .today
    @State private var dailyQuranQuote: LibraryDailyQuranQuote?
    @State private var selectedFullSurah: FullSurahSelection?
    @State private var resumeSelection: FullSurahSelection?
    @State private var surahs: [QuranSurahIndexItem] = []
    @State private var isLoadingSurahs = true
    @State private var surahListErrorMessage: String?
    @State private var searchText = ""
    @State private var expandedSurahNumber: Int?
    @State private var dailyQuranArabicText: String?
    @State private var pinnedSurahNumbers: [Int] = []

    private static let pinnedSurahsKey = "pinnedSurahNumbersV1"
    private static let maxPinnedSurahs = 3

    private var isSearchingSurahs: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredSurahs: [QuranSurahIndexItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return surahs }
        return surahs.filter {
            "\($0.number)".contains(query)
            || $0.englishName.lowercased().contains(query)
            || localizedSurahName(number: $0.number, englishName: $0.englishName).lowercased().contains(query)
            || $0.arabicName.contains(query)
        }
    }

    private func currentDayKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func loadDailyQuranQuoteFromCache() -> Bool {
        let defaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
        let languageAwareKey = "dailyInspirationCachedQuoteV3.\(quranContentLanguageCode())"
        guard
            let data = defaults?.data(forKey: languageAwareKey)
                ?? (!isMalayAppLanguage() ? defaults?.data(forKey: "dailyInspirationCachedQuoteV2") : nil)
                ?? (!isMalayAppLanguage() ? defaults?.data(forKey: "dailyInspirationCachedQuoteV1") : nil),
            let cached = try? JSONDecoder().decode(LibraryDailyQuranQuote.self, from: data),
            cached.dayKey == currentDayKey()
        else {
            dailyQuranQuote = nil
            return false
        }
        dailyQuranQuote = cached
        return true
    }

    @MainActor
    private func loadDailyQuranQuote() async {
        let loadedFromCache = loadDailyQuranQuoteFromCache()
        if loadedFromCache {
            await loadDailyQuranArabicIfNeeded()
            return
        }

        do {
            let fetched = try await fetchDailyQuranQuoteFromAPI()
            dailyQuranQuote = fetched
            saveDailyQuranQuoteToCache(fetched)
            await loadDailyQuranArabicIfNeeded()
        } catch {
            dailyQuranQuote = nil
            dailyQuranArabicText = nil
        }
    }

    private func saveDailyQuranQuoteToCache(_ quote: LibraryDailyQuranQuote) {
        guard let data = try? JSONEncoder().encode(quote) else { return }
        let defaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
        let languageAwareKey = "dailyInspirationCachedQuoteV3.\(quranContentLanguageCode())"
        defaults?.set(data, forKey: languageAwareKey)
    }

    private func fetchDailyQuranQuoteFromAPI(for date: Date = Date()) async throws -> LibraryDailyQuranQuote {
        let defaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
        let selectedReference = LibraryDailyInspirationPool.reference(for: date, defaults: defaults)
        let dayKey = currentDayKey(for: date)

        guard var components = URLComponents(url: quranProxyBaseURL(bundle: .main), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path += "/ayah/\(selectedReference.reference)"
        components.queryItems = [URLQueryItem(name: "lang", value: quranContentLanguageCode())]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(LibraryQuranAyahAPIResponse.self, from: data)
        let normalizedText = decoded.translationText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return LibraryDailyQuranQuote(
            dayKey: dayKey,
            reference: selectedReference.reference,
            text: normalizedText.isEmpty ? (selectedReference.fallbackText ?? decoded.translationText) : normalizedText,
            surahName: decoded.surahNameEnglish
        )
    }

    @MainActor
    private func loadDailyQuranArabicIfNeeded() async {
        guard let quote = dailyQuranQuote else {
            dailyQuranArabicText = nil
            return
        }

        do {
            dailyQuranArabicText = try await DailyQuranArabicAPI.fetchArabicText(reference: quote.reference)
        } catch {
            dailyQuranArabicText = nil
        }
    }

    private func openDailyQuranModal() {
        guard let reference = dailyQuranQuote?.reference else { return }
        var components = URLComponents()
        components.scheme = "waktu"
        components.host = "quran"
        components.queryItems = [URLQueryItem(name: "reference", value: reference)]
        guard let url = components.url else { return }
        openURL(url)
    }

    private func parseReference(_ reference: String) -> DailyQuranReferenceParts? {
        let parts = reference.split(separator: ":")
        guard let first = parts.first,
              let surah = Int(first),
              (1...114).contains(surah) else {
            return nil
        }
        let ayah: Int?
        if parts.count > 1, let parsedAyah = Int(parts[1]), parsedAyah > 0 {
            ayah = parsedAyah
        } else {
            ayah = nil
        }
        return DailyQuranReferenceParts(surahNumber: surah, ayahNumber: ayah)
    }

    private func openDailyQuranFullSurah() {
        guard let reference = dailyQuranQuote?.reference,
              let parsed = parseReference(reference) else { return }
        selectedFullSurah = FullSurahSelection(
            surahNumber: parsed.surahNumber,
            initialAyahNumber: parsed.ayahNumber,
            dailyAyahNumber: parsed.ayahNumber
        )
    }

    private func loadResumeSelection() {
        let defaults = UserDefaults.standard
        let playedSurah = defaults.integer(forKey: FullQuranResumeStorage.lastPlayedSurahKey)
        let playedAyah = defaults.integer(forKey: FullQuranResumeStorage.lastPlayedAyahKey)
        let viewedSurah = defaults.integer(forKey: FullQuranResumeStorage.lastSurahKey)
        let viewedAyah = defaults.integer(forKey: FullQuranResumeStorage.lastAyahKey)
        let surah = (1...114).contains(playedSurah) ? playedSurah : viewedSurah
        let ayah = (1...114).contains(playedSurah) ? playedAyah : viewedAyah
        guard (1...114).contains(surah) else {
            resumeSelection = nil
            return
        }
        resumeSelection = FullSurahSelection(
            surahNumber: surah,
            initialAyahNumber: ayah > 0 ? ayah : nil,
            dailyAyahNumber: nil
        )
    }

    @MainActor
    private func loadSurahsIfNeeded() async {
        guard surahs.isEmpty else { return }
        isLoadingSurahs = true
        surahListErrorMessage = nil
        defer { isLoadingSurahs = false }

        do {
            surahs = try await QuranSurahIndexAPI.fetchAll()
        } catch {
            let reason = error.localizedDescription
            if reason.isEmpty || reason == "The operation couldn’t be completed." {
                surahListErrorMessage = isMalayAppLanguage()
                    ? "Tidak dapat memuatkan senarai surah sekarang. Sila cuba lagi."
                    : "Unable to load the surah list right now. Please try again."
            } else {
                surahListErrorMessage = reason
            }
        }
    }

    @ViewBuilder
    private var quranIntroSection: some View {
        if !isSearchingSurahs {
            Section {
                LibraryIntroHeader()
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)

                if let quote = dailyQuranQuote {
                    DailyQuranHeroCard(
                        quote: quote,
                        arabicText: dailyQuranArabicText,
                        accentColor: settings.accentColor.color,
                        arabicFontName: preferredQuranArabicFontName(settings: settings, size: 29),
                        onOpenVerse: openDailyQuranModal,
                        onOpenSurah: openDailyQuranFullSurah
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparator(.hidden)
                } else {
                    Text(isMalayAppLanguage()
                         ? "Buka widget Al-Quran Harian sekali untuk memuatkan ayat hari ini di sini."
                         : "Open the Daily Quran widget once to load today’s verse here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
                        .listRowSeparator(.hidden)
                }

                if let resumeSelection {
                    QuranResumeCard(
                        surahTitle: surahTitle(for: resumeSelection.surahNumber),
                        surahNumber: resumeSelection.surahNumber,
                        ayahNumber: resumeSelection.initialAyahNumber,
                        totalAyahCount: QuranSurahVerseCounts.count(for: resumeSelection.surahNumber),
                        accentColor: settings.accentColor.color,
                        onResume: {
                            selectedFullSurah = resumeSelection
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 14, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    @ViewBuilder
    private var pinnedSurahsSection: some View {
        let pinnedSurahs = surahs.filter { pinnedSurahNumbers.contains($0.number) }
            .sorted { pinnedSurahNumbers.firstIndex(of: $0.number)! < pinnedSurahNumbers.firstIndex(of: $1.number)! }

        if !isSearchingSurahs && !pinnedSurahs.isEmpty {
            Section(header: HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(45))
                Text(isMalayAppLanguage() ? "SURAH DISEMATKAN" : "PINNED SURAHS")
            }) {
                ForEach(pinnedSurahs) { surah in
                    QuranSurahExpandableCard(
                        surah: surah,
                        isExpanded: expandedSurahNumber == surah.number,
                        accentColor: settings.accentColor.color,
                        progressAyah: loadLastReadAyah(for: surah.number),
                        totalAyahCount: QuranSurahVerseCounts.count(for: surah.number),
                        isPinned: true,
                        onToggle: {
                            withAnimation(.spring(response: 0.46, dampingFraction: 0.9)) {
                                expandedSurahNumber = expandedSurahNumber == surah.number ? nil : surah.number
                            }
                        },
                        onOpen: {
                            selectedFullSurah = FullSurahSelection(
                                surahNumber: surah.number,
                                initialAyahNumber: nil,
                                dailyAyahNumber: nil
                            )
                        },
                        onResume: {
                            selectedFullSurah = FullSurahSelection(
                                surahNumber: surah.number,
                                initialAyahNumber: loadLastReadAyah(for: surah.number),
                                dailyAyahNumber: nil
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation { togglePin(surahNumber: surah.number) }
                        } label: {
                            Label(isMalayAppLanguage() ? "Tanggalkan Pin" : "Unpin Surah", systemImage: "pin.slash")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var surahListSection: some View {
        Section(header: Text(isSearchingSurahs
                             ? (isMalayAppLanguage() ? "HASIL CARIAN SURAH" : "SURAH SEARCH RESULTS")
                             : (isMalayAppLanguage() ? "SENARAI SURAH" : "SURAH LIST"))) {
            if isLoadingSurahs {
                HStack {
                    Spacer()
                    ProgressView(isMalayAppLanguage() ? "Memuatkan senarai surah..." : "Loading surah list...")
                    Spacer()
                }
            } else if let surahListErrorMessage {
                Text(surahListErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredSurahs) { surah in
                    let isPinned = pinnedSurahNumbers.contains(surah.number)
                    let canPin = !isPinned && pinnedSurahNumbers.count < Self.maxPinnedSurahs
                    QuranSurahExpandableCard(
                        surah: surah,
                        isExpanded: expandedSurahNumber == surah.number,
                        accentColor: settings.accentColor.color,
                        progressAyah: loadLastReadAyah(for: surah.number),
                        totalAyahCount: QuranSurahVerseCounts.count(for: surah.number),
                        isPinned: isPinned,
                        onToggle: {
                            withAnimation(.spring(response: 0.46, dampingFraction: 0.9)) {
                                expandedSurahNumber = expandedSurahNumber == surah.number ? nil : surah.number
                            }
                        },
                        onOpen: {
                            selectedFullSurah = FullSurahSelection(
                                surahNumber: surah.number,
                                initialAyahNumber: nil,
                                dailyAyahNumber: nil
                            )
                        },
                        onResume: {
                            selectedFullSurah = FullSurahSelection(
                                surahNumber: surah.number,
                                initialAyahNumber: loadLastReadAyah(for: surah.number),
                                dailyAyahNumber: nil
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        if isPinned {
                            Button(role: .destructive) {
                                withAnimation { togglePin(surahNumber: surah.number) }
                            } label: {
                                Label(isMalayAppLanguage() ? "Tanggalkan Pin" : "Unpin Surah", systemImage: "pin.slash")
                            }
                        } else {
                            Button {
                                withAnimation { togglePin(surahNumber: surah.number) }
                            } label: {
                                Label(isMalayAppLanguage() ? "Semat Surah" : "Pin Surah", systemImage: "pin")
                            }
                            .disabled(!canPin)
                        }
                        if !canPin && !isPinned {
                            Text(isMalayAppLanguage()
                                 ? "Maksimum 3 surah disematkan"
                                 : "Maximum 3 surahs can be pinned")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private var activeTodaySlot: TodayPrayerTimeSlot {
        TodayPracticeLibrary.slot(
            currentPrayer: settings.currentPrayer,
            nextPrayer: settings.nextPrayer
        )
    }

    private var activeTodayPractices: [TodayPractice] {
        TodayPracticeLibrary.practices(for: activeTodaySlot)
    }

    private var todaySection: some View {
        Section {
            LibraryIntroHeader()
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)

            TodaySlotBanner(slot: activeTodaySlot)
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.hidden)

            ForEach(activeTodayPractices) { practice in
                TodayPracticeCard(
                    practice: practice,
                    accentColor: settings.accentColor.color,
                    onOpenSurah: { surahNumber, ayahNumber in
                        selectedFullSurah = FullSurahSelection(
                            surahNumber: surahNumber,
                            initialAyahNumber: ayahNumber,
                            dailyAyahNumber: ayahNumber
                        )
                    }
                )
                .environmentObject(settings)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                if selectedSegment == .today {
                    todaySection
                } else {
                    quranIntroSection
                    pinnedSurahsSection
                    surahListSection
                }

                #if false
                Section(header: Text("ISLAMIC RESOURCES")) {
                    NavigationLink(destination: ArabicView()) {
                        Label(
                            title: { Text("Arabic Alphabet") },
                            icon: {
                                Image(systemName: "textformat.size.ar")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }
                    
                    NavigationLink(destination: AdhkarView()) {
                        Label(
                            title: { Text("Common Adhkar") },
                            icon: {
                                Image(systemName: "book.closed")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }

                    NavigationLink(destination: DuaView()) {
                        Label(
                            title: { Text("Common Duas") },
                            icon: {
                                Image(systemName: "text.book.closed")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }

                    NavigationLink(destination: TasbihView()) {
                        Label(
                            title: { Text("Tasbih Counter") },
                            icon: {
                                Image(systemName: "circles.hexagonpath.fill")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }

                    NavigationLink(destination: NamesView()) {
                        Label(
                            title: { Text("99 Names of Allah") },
                            icon: {
                                Image(systemName: "signature")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }
                    
                    #if !os(watchOS)
                    NavigationLink(destination: DateView()) {
                        Label(
                            title: { Text("Hijri Calendar Converter") },
                            icon: {
                                Image(systemName: "calendar")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }
                    #endif

                    NavigationLink(destination: WallpaperView()) {
                        Label(
                            title: { Text("Islamic Wallpapers") },
                            icon: {
                                Image(systemName: "photo.on.rectangle")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        )
                        .padding(.vertical, 4)
                        .accentColor(settings.accentColor.color)
                    }
                }
                #endif
                
                #if false
                ProphetQuote()
                #endif
                
                #if false
                AlIslamAppsSection()
                #endif
            }
            .applyConditionalListStyle(defaultView: settings.defaultView)
            .navigationTitle(isMalayAppLanguage() ? "Pustaka" : "Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $selectedSegment) {
                        ForEach(LibrarySegment.allCases, id: \.self) { segment in
                            Text(segment.label()).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
            }
            .onAppear {
                loadResumeSelection()
                loadPinnedSurahs()
                Task { await loadSurahsIfNeeded() }
                Task { await loadDailyQuranQuote() }
            }
            .task(id: effectiveAppLanguageCode()) {
                await loadDailyQuranQuote()
            }
            .onChange(of: selectedFullSurah) { selection in
                if selection == nil {
                    loadResumeSelection()
                }
            }
            .sheet(item: $selectedFullSurah) { selection in
                NavigationView {
                    QuranSurahDetailsView(
                        surahNumber: selection.surahNumber,
                        initialAyahNumber: selection.initialAyahNumber,
                        dailyAyahNumber: selection.dailyAyahNumber
                    )
                        .environmentObject(settings)
                        .navigationTitle(surahTitle(for: selection.surahNumber))
                        .navigationBarTitleDisplayMode(.inline)
                        .interactiveDismissDisabled()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(isMalayAppLanguage() ? "Selesai" : "Done") {
                                    selectedFullSurah = nil
                                }
                            }
                        }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: selectedSegment == .quran ? .always : .never),
                prompt: isMalayAppLanguage() ? "Cari surah" : "Search surah"
            )
        }
    }

    private func loadPinnedSurahs() {
        let stored = UserDefaults.standard.array(forKey: Self.pinnedSurahsKey) as? [Int] ?? []
        pinnedSurahNumbers = stored
    }

    private func savePinnedSurahs() {
        UserDefaults.standard.set(pinnedSurahNumbers, forKey: Self.pinnedSurahsKey)
    }

    private func togglePin(surahNumber: Int) {
        if let index = pinnedSurahNumbers.firstIndex(of: surahNumber) {
            pinnedSurahNumbers.remove(at: index)
        } else if pinnedSurahNumbers.count < Self.maxPinnedSurahs {
            pinnedSurahNumbers.append(surahNumber)
        }
        savePinnedSurahs()
    }

    private func loadLastReadAyah(for surahNumber: Int) -> Int? {
        let ayah = UserDefaults.standard.integer(forKey: "fullSurahLastReadAyahV1.\(surahNumber)")
        return ayah > 0 ? ayah : nil
    }

    private func surahTitle(for surahNumber: Int) -> String {
        if let surah = surahs.first(where: { $0.number == surahNumber }) {
            return localizedSurahName(number: surah.number, englishName: surah.englishName)
        }
        return isMalayAppLanguage() ? "Surah \(surahNumber)" : "Surah \(surahNumber)"
    }
}

#Preview {
    OtherView()
        .environmentObject(Settings.shared)
}

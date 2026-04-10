import Foundation

enum ZikirCategory: String, Codable, CaseIterable {
    case morning
    case midday
    case evening
    case night
    case friday
}

enum ZikirTimeBucket: String, Codable, CaseIterable {
    case morning
    case midday
    case evening
    case night

    var titleKey: String {
        switch self {
        case .morning:
            return "Morning Zikir"
        case .midday:
            return "Midday Zikir"
        case .evening:
            return "Evening Zikir"
        case .night:
            return "Night Zikir"
        }
    }
}

struct ZikirPhrase: Identifiable, Codable, Hashable {
    let id: String
    let helperTitles: [String]
    let helperTitlesMS: [String]
    let textArabic: String
    let translation: String
    let translationMS: String
    let category: ZikirCategory
    let weight: Int
    let isFridayBoost: Bool
    let maxRecommendedLength: Int

    var isWidgetSafeByDefault: Bool {
        maxRecommendedLength <= 24
    }

    func localizedHelperTitles() -> [String] {
        isMalayAppLanguage() ? helperTitlesMS : helperTitles
    }

    func localizedTranslation() -> String {
        isMalayAppLanguage() ? translationMS : translation
    }
}

enum ZikirLibrary {
    static let all: [ZikirPhrase] = [
        .init(id: "morning-subhanallah", helperTitles: ["Morning remembrance", "A simple start for today", "Read once with presence"], helperTitlesMS: ["Zikir pagi", "Permulaan ringan untuk hari ini", "Baca sekali dengan hadir hati"], textArabic: "سُبْحَانَ اللَّهِ", translation: "Glory be to Allah.", translationMS: "Maha Suci Allah.", category: .morning, weight: 4, isFridayBoost: false, maxRecommendedLength: 18),
        .init(id: "morning-alhamdulillah", helperTitles: ["For a grateful heart", "Morning remembrance", "Begin with gratitude"], helperTitlesMS: ["Untuk hati yang bersyukur", "Zikir pagi", "Mulakan dengan syukur"], textArabic: "الْحَمْدُ لِلَّهِ", translation: "All praise belongs to Allah.", translationMS: "Segala puji bagi Allah.", category: .morning, weight: 4, isFridayBoost: false, maxRecommendedLength: 18),
        .init(id: "morning-allahu-akbar", helperTitles: ["A simple remembrance for this moment", "Morning remembrance", "Read with presence"], helperTitlesMS: ["Zikir ringkas untuk saat ini", "Zikir pagi", "Baca dengan hadir hati"], textArabic: "اللَّهُ أَكْبَرُ", translation: "Allah is the Greatest.", translationMS: "Allah Maha Besar.", category: .morning, weight: 4, isFridayBoost: false, maxRecommendedLength: 18),
        .init(id: "morning-la-ilaha", helperTitles: ["Morning remembrance", "For clarity and tawhid", "Read slowly with presence"], helperTitlesMS: ["Zikir pagi", "Untuk tauhid yang jelas", "Baca perlahan dengan hadir hati"], textArabic: "لَا إِلٰهَ إِلَّا اللَّهُ", translation: "There is no god but Allah.", translationMS: "Tiada tuhan melainkan Allah.", category: .morning, weight: 5, isFridayBoost: false, maxRecommendedLength: 22),
        .init(id: "morning-istighfar", helperTitles: ["A gentle return to Allah", "Morning repentance", "Read once with presence"], helperTitlesMS: ["Kembali lembut kepada Allah", "Istighfar pagi", "Baca sekali dengan hadir hati"], textArabic: "أَسْتَغْفِرُ اللَّهَ", translation: "I seek Allah's forgiveness.", translationMS: "Aku memohon keampunan Allah.", category: .morning, weight: 4, isFridayBoost: false, maxRecommendedLength: 22),
        .init(id: "morning-hasbunallah", helperTitles: ["For a calm heart", "When you need trust", "Morning remembrance"], helperTitlesMS: ["Untuk hati yang tenang", "Saat memerlukan tawakal", "Zikir pagi"], textArabic: "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ", translation: "Allah is enough for us, the best Trustee.", translationMS: "Cukuplah Allah bagi kami, sebaik-baik Pelindung.", category: .morning, weight: 3, isFridayBoost: false, maxRecommendedLength: 24),
        .init(id: "morning-raditu", helperTitles: ["Read with contentment", "A light dhikr for the heart", "Morning remembrance"], helperTitlesMS: ["Baca dengan reda", "Zikir ringan untuk hati", "Zikir pagi"], textArabic: "رَضِيتُ بِاللَّهِ رَبًّا", translation: "I am pleased with Allah as my Lord.", translationMS: "Aku reda Allah sebagai Tuhanku.", category: .morning, weight: 3, isFridayBoost: false, maxRecommendedLength: 24),

        .init(id: "midday-subhanallah", helperTitles: ["A pause between tasks", "Midday remembrance", "Read once with presence"], helperTitlesMS: ["Jeda seketika antara urusan", "Zikir tengah hari", "Baca sekali dengan hadir hati"], textArabic: "سُبْحَانَ اللَّهِ", translation: "Glory be to Allah.", translationMS: "Maha Suci Allah.", category: .midday, weight: 3, isFridayBoost: false, maxRecommendedLength: 18),
        .init(id: "midday-alhamdulillah", helperTitles: ["Midday remembrance", "Pause with gratitude", "For a thankful heart"], helperTitlesMS: ["Zikir tengah hari", "Berhenti seketika dengan syukur", "Untuk hati yang bersyukur"], textArabic: "الْحَمْدُ لِلَّهِ", translation: "All praise belongs to Allah.", translationMS: "Segala puji bagi Allah.", category: .midday, weight: 3, isFridayBoost: false, maxRecommendedLength: 18),
        .init(id: "midday-la-hawla", helperTitles: ["When you feel weak", "A reminder of reliance", "Midday remembrance"], helperTitlesMS: ["Saat terasa lemah", "Peringatan tentang pergantungan kepada Allah", "Zikir tengah hari"], textArabic: "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ", translation: "There is no power except through Allah.", translationMS: "Tiada daya dan tiada kekuatan melainkan dengan Allah.", category: .midday, weight: 5, isFridayBoost: false, maxRecommendedLength: 24),
        .init(id: "midday-istighfar-azim", helperTitles: ["A brief moment of istighfar", "Midday repentance", "Read with presence"], helperTitlesMS: ["Saat ringkas untuk istighfar", "Istighfar tengah hari", "Baca dengan hadir hati"], textArabic: "أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ", translation: "I seek forgiveness from Allah the Mighty.", translationMS: "Aku memohon keampunan Allah Yang Maha Agung.", category: .midday, weight: 4, isFridayBoost: false, maxRecommendedLength: 24),
        .init(id: "midday-salawat-short", helperTitles: ["A light selawat for today", "Friday remembrance", "Send blessings with love"], helperTitlesMS: ["Selawat ringan untuk hari ini", "Zikir hari Jumaat", "Berselawat dengan kasih"], textArabic: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ", translation: "O Allah, send blessings upon Muhammad.", translationMS: "Ya Allah, limpahkanlah selawat ke atas Muhammad.", category: .midday, weight: 3, isFridayBoost: true, maxRecommendedLength: 24),
        .init(id: "midday-a-inni", helperTitles: ["Ask for help in worship", "A simple midday dua", "Read with presence"], helperTitlesMS: ["Mohon bantuan dalam ibadah", "Doa ringkas tengah hari", "Baca dengan hadir hati"], textArabic: "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ", translation: "O Allah, help me to remember You.", translationMS: "Ya Allah, bantulah aku untuk mengingati-Mu.", category: .midday, weight: 3, isFridayBoost: false, maxRecommendedLength: 24),

        .init(id: "evening-subhanallahi-wa-bihamdih", helperTitles: ["Evening remembrance", "Repeat with presence", "A light dhikr for the heart"], helperTitlesMS: ["Zikir petang", "Ulang dengan hadir hati", "Zikir ringan untuk hati"], textArabic: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", translation: "Glory be to Allah and praise be to Him.", translationMS: "Maha Suci Allah dan segala puji bagi-Nya.", category: .evening, weight: 4, isFridayBoost: false, maxRecommendedLength: 24),
        .init(id: "evening-subhanallah-azim", helperTitles: ["For a heart at rest", "Evening remembrance", "Read slowly with presence"], helperTitlesMS: ["Untuk hati yang tenteram", "Zikir petang", "Baca perlahan dengan hadir hati"], textArabic: "سُبْحَانَ اللَّهِ الْعَظِيمِ", translation: "Glory be to Allah the Magnificent.", translationMS: "Maha Suci Allah Yang Maha Agung.", category: .evening, weight: 4, isFridayBoost: false, maxRecommendedLength: 24),
        .init(id: "evening-istighfar", helperTitles: ["As the day softens", "Evening repentance", "A return to Allah"], helperTitlesMS: ["Saat hari mulai reda", "Istighfar petang", "Kembali kepada Allah"], textArabic: "أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ", translation: "I seek Allah's forgiveness and turn to Him.", translationMS: "Aku memohon keampunan Allah dan bertaubat kepada-Nya.", category: .evening, weight: 4, isFridayBoost: false, maxRecommendedLength: 24),
        .init(id: "evening-hasbiyallahu", helperTitles: ["For peace and reliance", "Evening remembrance", "When the heart needs trust"], helperTitlesMS: ["Untuk ketenangan dan tawakal", "Zikir petang", "Saat hati memerlukan pergantungan"], textArabic: "حَسْبِيَ اللَّهُ لَا إِلٰهَ إِلَّا هُوَ", translation: "Allah is sufficient for me. There is no god but Him.", translationMS: "Allah mencukupi bagiku. Tiada tuhan melainkan Dia.", category: .evening, weight: 3, isFridayBoost: false, maxRecommendedLength: 24),
        .init(id: "evening-la-ilaha", helperTitles: ["A simple remembrance for tonight", "Evening remembrance", "Read once with presence"], helperTitlesMS: ["Zikir ringkas untuk malam ini", "Zikir petang", "Baca sekali dengan hadir hati"], textArabic: "لَا إِلٰهَ إِلَّا اللَّهُ", translation: "There is no god but Allah.", translationMS: "Tiada tuhan melainkan Allah.", category: .evening, weight: 4, isFridayBoost: false, maxRecommendedLength: 22),
        .init(id: "evening-salawat", helperTitles: ["A gentle selawat", "Friday remembrance", "Send blessings tonight"], helperTitlesMS: ["Selawat yang lembut", "Zikir hari Jumaat", "Berselawat malam ini"], textArabic: "اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ", translation: "O Allah, bless and grant peace to our Prophet Muhammad.", translationMS: "Ya Allah, limpahkanlah selawat dan salam ke atas Nabi kami Muhammad.", category: .evening, weight: 3, isFridayBoost: true, maxRecommendedLength: 24),

        .init(id: "night-bismika", helperTitles: ["Before rest", "Night remembrance", "Read with trust"], helperTitlesMS: ["Sebelum berehat", "Zikir malam", "Baca dengan tawakal"], textArabic: "بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا", translation: "In Your name, O Allah, I die and I live.", translationMS: "Dengan nama-Mu ya Allah, aku mati dan aku hidup.", category: .night, weight: 5, isFridayBoost: false, maxRecommendedLength: 24),
        .init(id: "night-subhanalmalik", helperTitles: ["A quiet remembrance", "Night remembrance", "Read before sleep"], helperTitlesMS: ["Zikir yang tenang", "Zikir malam", "Baca sebelum tidur"], textArabic: "سُبْحَانَ الْمَلِكِ الْقُدُّوسِ", translation: "Glory be to the Sovereign, the Most Holy.", translationMS: "Maha Suci Raja Yang Maha Suci.", category: .night, weight: 4, isFridayBoost: false, maxRecommendedLength: 24),
        .init(id: "night-allahumma-ighfirli", helperTitles: ["Before sleep", "A short dua for mercy", "Read once with presence"], helperTitlesMS: ["Sebelum tidur", "Doa ringkas memohon rahmat", "Baca sekali dengan hadir hati"], textArabic: "اللَّهُمَّ اغْفِرْ لِي", translation: "O Allah, forgive me.", translationMS: "Ya Allah, ampunilah aku.", category: .night, weight: 4, isFridayBoost: false, maxRecommendedLength: 20),
        .init(id: "night-allahumma-afuw", helperTitles: ["A gentle night dua", "Seek Allah's pardon", "Night remembrance"], helperTitlesMS: ["Doa malam yang lembut", "Mohon kemaafan Allah", "Zikir malam"], textArabic: "اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ", translation: "O Allah, You are Pardoning and love pardon.", translationMS: "Ya Allah, sesungguhnya Engkau Maha Pemaaf dan menyukai kemaafan.", category: .night, weight: 3, isFridayBoost: false, maxRecommendedLength: 24),
        .init(id: "night-amantu-billah", helperTitles: ["Rest with certainty", "Night remembrance", "A light dhikr for the heart"], helperTitlesMS: ["Berehat dengan yakin", "Zikir malam", "Zikir ringan untuk hati"], textArabic: "آمَنْتُ بِاللَّهِ وَحْدَهُ", translation: "I believe in Allah alone.", translationMS: "Aku beriman kepada Allah semata-mata.", category: .night, weight: 3, isFridayBoost: false, maxRecommendedLength: 22),
        .init(id: "night-salawat-short", helperTitles: ["A final selawat for tonight", "Friday remembrance", "Send blessings with love"], helperTitlesMS: ["Selawat penutup untuk malam ini", "Zikir hari Jumaat", "Berselawat dengan kasih"], textArabic: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ", translation: "O Allah, send blessings upon Muhammad.", translationMS: "Ya Allah, limpahkanlah selawat ke atas Muhammad.", category: .night, weight: 3, isFridayBoost: true, maxRecommendedLength: 24),

        .init(id: "friday-salawat-short", helperTitles: ["Friday remembrance", "A light selawat for today", "A quick blessing for this hour"], helperTitlesMS: ["Zikir hari Jumaat", "Selawat ringan untuk hari ini", "Selawat ringkas untuk jam ini"], textArabic: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ", translation: "O Allah, send blessings upon Muhammad.", translationMS: "Ya Allah, limpahkanlah selawat ke atas Muhammad.", category: .friday, weight: 5, isFridayBoost: true, maxRecommendedLength: 24),
        .init(id: "friday-salawat-complete", helperTitles: ["Friday remembrance", "A fuller selawat for Friday", "Bless your tongue with selawat"], helperTitlesMS: ["Zikir hari Jumaat", "Selawat yang lebih lengkap untuk Jumaat", "Basahi lidah dengan selawat"], textArabic: "اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ", translation: "O Allah, bless and grant peace to our Prophet Muhammad.", translationMS: "Ya Allah, limpahkanlah selawat dan salam ke atas Nabi kami Muhammad.", category: .friday, weight: 4, isFridayBoost: true, maxRecommendedLength: 24),
        .init(id: "friday-sallallahu", helperTitles: ["Friday remembrance", "A short selawat for this moment", "A brief salutation for today"], helperTitlesMS: ["Zikir hari Jumaat", "Selawat ringkas untuk saat ini", "Salam ringkas untuk hari ini"], textArabic: "صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ", translation: "Peace and blessings be upon him.", translationMS: "Selawat dan salam ke atas Baginda.", category: .friday, weight: 3, isFridayBoost: true, maxRecommendedLength: 22),
    ]

    static func phrases(for bucket: ZikirTimeBucket, includeFridayBoosts: Bool) -> [ZikirPhrase] {
        let bucketItems = all.filter {
            $0.category.rawValue == bucket.rawValue && (includeFridayBoosts || !$0.isFridayBoost)
        }
        guard includeFridayBoosts else { return bucketItems }
        return bucketItems + all.filter { $0.category == .friday }
    }
}

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

    static func reset() {
        defaults.removeObject(forKey: storageKey)
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

    static func reset() {
        defaults.removeObject(forKey: storageKey)
    }
}

enum ForYouDhikrProgressStore {
    private static let storageKey = "forYou.dhikrProgressByEntry.v1"
    private static let defaults = UserDefaults.standard

    static func count(for id: String) -> Int {
        progressMap()[id] ?? 0
    }

    static func setCount(_ count: Int, for id: String) {
        var map = progressMap()
        map[id] = max(0, count)
        defaults.set(map, forKey: storageKey)
    }

    static func reset() {
        defaults.removeObject(forKey: storageKey)
    }

    private static func progressMap() -> [String: Int] {
        defaults.dictionary(forKey: storageKey) as? [String: Int] ?? [:]
    }
}

enum ForYouSessionStore {
    private static var hasVisitedTodayTab = false

    static func shouldAutoScrollOnTodayAppear() -> Bool {
        let shouldAutoScroll = hasVisitedTodayTab
        hasVisitedTodayTab = true
        return shouldAutoScroll
    }

    static func reset() {
        hasVisitedTodayTab = false
    }
}

enum ForYouDebugStore {
    private static let defaults = UserDefaults.standard
    private static let swipeHintKey = "forYou.didSeeSwipeHint.v1"

    static func resetAll() {
        ForYouUserProfileService.reset()
        ForYouCompletionStore.reset()
        ForYouSessionStore.reset()
        defaults.removeObject(forKey: swipeHintKey)
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

// MARK: - Wirid Content

enum WiridContentRepository {

    // Canonical prayer names that receive the full wirid (all 26 items)
    static let fullWiridPrayers: Set<String> = ["fajr", "maghrib"]

    // Curated items from the post-prayer wirid sequence.
    // isShort = true  → displayed for all 5 prayers (🔰 in the source) — 12 items
    // isShort = false → Fajr & Maghrib only (full sequence)           — 14 items
    static let items: [WiridItem] = [

        // ── 🔰 Short sequence (all prayers) ──────────────────────────────

        WiridItem(
            id: "wirid-01-istighfar",
            titleEn: "Istighfar",
            titleMy: "Istighfar",
            arabicText: "أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ وَأَتُوبُ إِلَيْهِ",
            transliteration: "Astaghfirullāhal-'aẓīm, allażī lā ilāha illā huwal-ḥayyul-qayyūm, wa atūbu ilaih",
            translationMy: "Aku memohon ampun kepada Allah yang Maha Besar, tiada tuhan selain Dia yang Hidup lagi sentiasa berkuasa, dan aku bertaubat kepadaNya.",
            reference: nil,
            count: "3×",
            isShort: true,
            orderIndex: 1
        ),
        WiridItem(
            id: "wirid-02-tauhid",
            titleEn: "Affirmation of Oneness",
            titleMy: "Pengakuan Tauhid",
            arabicText: "لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ يُحْيِي وَيُمِيتُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ",
            transliteration: "Lā ilāha illallāhu waḥdahu lā sharīka lah, lahul-mulku wa lahul-ḥamdu yuḥyī wa yumītu wa huwa 'alā kulli shay'in qadīr",
            translationMy: "Tiada tuhan yang disembah melainkan Allah, tiada sekutu bagiNya, bagiNya kerajaan dan segala puji. Dia menghidupkan dan mematikan, Dia Maha Berkuasa atas segala sesuatu.",
            reference: nil,
            count: "3×",
            isShort: true,
            orderIndex: 2
        ),
        WiridItem(
            id: "wirid-03-ajirna",
            titleEn: "Protection from Hellfire",
            titleMy: "Mohon Dijauhkan Neraka",
            arabicText: "اللَّهُمَّ أَجِرْنَا مِنَ النَّارِ",
            transliteration: "Allāhumma ajirnā minan-nār",
            translationMy: "Ya Allah jauhkanlah kami daripada azab api neraka.",
            reference: nil,
            count: "3× (7× Subuh & Maghrib)",
            isShort: true,
            orderIndex: 3
        ),
        WiridItem(
            id: "wirid-04-salam",
            titleEn: "Supplication for Peace",
            titleMy: "Memohon Keselamatan",
            arabicText: "اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ وَإِلَيْكَ يَعُودُ السَّلَامُ فَحَيِّنَا رَبَّنَا بِالسَّلَامِ وَأَدْخِلْنَا الْجَنَّةَ دَارَ السَّلَامِ تَبَارَكْتَ رَبَّنَا وَتَعَالَيْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ",
            transliteration: "Allāhumma antas-salām, wa minkas-salām, wa ilaika ya'ūdus-salām, faḥayyinā rabbanā bis-salām, wa adkhilnal-jannata dāras-salām, tabārakta rabbanā wa ta'ālayta yā żal-jalāli wal-ikrām",
            translationMy: "Ya Allah Engkaulah penyelamat sejahtera, daripada Engkaulah datangnya kesejahteraan, kepada Engkaulah kembalinya sejahtera. Maka hidupkanlah kami dengan sejahtera dan masukkan kami ke syurga negara yang aman. Bertambah berkat-Mu ya Tuhan kami, Maha Tinggi Engkau wahai Tuhan yang memiliki kebesaran dan kemuliaan.",
            reference: nil,
            count: nil,
            isShort: true,
            orderIndex: 4
        ),
        WiridItem(
            id: "wirid-05-taawuz",
            titleEn: "Seeking Refuge",
            titleMy: "Ta'awuz",
            arabicText: "أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ",
            transliteration: "A'ūdzu billāhi minash-shayṭānir-rajīm",
            translationMy: "Aku berlindung dengan Allah daripada syaitan yang direjam.",
            reference: nil,
            count: nil,
            isShort: true,
            orderIndex: 5
        ),
        WiridItem(
            id: "wirid-06-fatihah-1",
            titleEn: "Al-Fatihah",
            titleMy: "Al-Fatihah",
            arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ ۝ الرَّحْمَٰنِ الرَّحِيمِ ۝ مَالِكِ يَوْمِ الدِّينِ ۝ إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ ۝ اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ ۝ صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ",
            transliteration: "Bismillāhir-raḥmānir-raḥīm. Al-ḥamdu lillāhi rabbil-'ālamīn. Ar-raḥmānir-raḥīm. Māliki yawmid-dīn. Iyyāka na'budu wa iyyāka nasta'īn. Ihdinaṣ-ṣirāṭal-mustaqīm. Ṣirāṭallażīna an'amta 'alaihim, ghairil-maghḍūbi 'alaihim wa laḍ-ḍāllīn.",
            translationMy: "Dengan nama Allah Yang Maha Pemurah lagi Maha Mengasihani. Segala puji bagi Allah Tuhan sekalian alam. Yang Maha Pemurah lagi Maha Mengasihani. Yang Menguasai hari Pembalasan. Hanya Engkaulah yang kami sembah dan hanya kepada Engkaulah kami memohon pertolongan. Tunjukilah kami jalan yang lurus. Iaitu jalan orang yang Engkau kurniakan nikmat, bukan jalan orang yang Engkau murkai dan bukan pula jalan orang yang sesat.",
            reference: "Al-Fatihah 1:1–7",
            count: nil,
            isShort: true,
            orderIndex: 6
        ),
        WiridItem(
            id: "wirid-08-ayatul-kursi",
            titleEn: "Ayat al-Kursi",
            titleMy: "Ayat al-Kursi",
            arabicText: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ",
            transliteration: "Allāhu lā ilāha illā huwal-ḥayyul-qayyūm, lā ta'khużuhū sinatuw wa lā nawm, lahū mā fis-samāwāti wa mā fil-arḍ, man żallażī yashfa'u 'indahū illā bi'iżnih, ya'lamu mā baina aydīhim wa mā khalfahum, wa lā yuḥīṭūna bishai'im min 'ilmihī illā bimā shā', wasi'a kursiyyuhus-samāwāti wal-arḍ, wa lā ya'ūduhū ḥifẓuhumā wa huwal-'aliyyul-'aẓīm",
            translationMy: "Allah, tiada Tuhan melainkan Dia yang Hidup, yang sentiasa mentadbir. Tidak mengantuk dan tidak tidur. Milik-Nya segala yang di langit dan di bumi. Tiada yang dapat memberi syafaat di sisi-Nya melainkan dengan izin-Nya. Dia mengetahui apa yang di hadapan dan di belakang mereka. Mereka tidak meliputi ilmu-Nya kecuali apa yang Dia kehendaki. Kursi-Nya meliputi langit dan bumi dan tidak memberatkan-Nya menjaga keduanya. Dia Maha Tinggi lagi Maha Agung.",
            reference: "Al-Baqarah 2:255",
            count: nil,
            isShort: true,
            orderIndex: 8
        ),
        WiridItem(
            id: "wirid-16-ikhlas",
            titleEn: "Surah Al-Ikhlas",
            titleMy: "Surah Al-Ikhlas",
            arabicText: "قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ",
            transliteration: "Qul huwallāhu aḥad. Allāhuṣ-ṣamad. Lam yalid wa lam yūlad. Wa lam yakul lahū kufuwan aḥad.",
            translationMy: "Katakanlah: Dialah Allah Yang Maha Esa. Allah tempat bergantung segala sesuatu. Dia tidak beranak dan tidak pula diperanakkan. Dan tidak ada seorang pun yang setara dengan-Nya.",
            reference: "Al-Ikhlas 112",
            count: nil,
            isShort: true,
            orderIndex: 16
        ),
        WiridItem(
            id: "wirid-20-tasbih-intro",
            titleEn: "Opening of Tasbih",
            titleMy: "Pembukaan Tasbih",
            arabicText: "إِلَٰهِي يَا رَبِّ — سُبْحَانَ اللَّهِ",
            transliteration: "Ilāhī yā rabbi — subḥānallāh",
            translationMy: "Ya Allah Ya Tuhanku — Maha Suci Allah.",
            reference: nil,
            count: nil,
            isShort: true,
            orderIndex: 20
        ),
        WiridItem(
            id: "wirid-21-subhanallah",
            titleEn: "Tasbih",
            titleMy: "Tasbih",
            arabicText: "سُبْحَانَ اللَّهِ",
            transliteration: "SubḥānAllāh",
            translationMy: "Maha Suci Allah.",
            reference: "Sahih al-Bukhari 843 · Sahih Muslim 597",
            count: "33×",
            isShort: true,
            orderIndex: 21
        ),
        WiridItem(
            id: "wirid-23-alhamdulillah",
            titleEn: "Tahmid",
            titleMy: "Tahmid",
            arabicText: "الْحَمْدُ لِلَّهِ",
            transliteration: "Alḥamdulillāh",
            translationMy: "Segala pujian hanya bagi Allah.",
            reference: "Sahih al-Bukhari 843 · Sahih Muslim 597",
            count: "33×",
            isShort: true,
            orderIndex: 23
        ),
        WiridItem(
            id: "wirid-26-completion",
            titleEn: "Closing Formula",
            titleMy: "Penutup Wirid",
            arabicText: "لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ",
            transliteration: "Lā ilāha illallāhu waḥdahu lā sharīka lah, lahul-mulku wa lahul-ḥamd, wa huwa 'alā kulli shay'in qadīr, wa lā ḥawla wa lā quwwata illā billāhil-'aliyyil-'aẓīm, astaghfirullāhal-'aẓīm",
            translationMy: "Tiada tuhan melainkan Allah Yang Maha Esa, tiada sekutu bagi-Nya, bagi-Nya kerajaan dan segala pujian, Dia Maha Berkuasa atas segala sesuatu. Tiada daya dan kekuatan kecuali dengan izin Allah Yang Maha Tinggi lagi Maha Agung. Aku memohon ampun kepada Allah Yang Maha Agung.",
            reference: nil,
            count: nil,
            isShort: true,
            orderIndex: 26
        ),

        // ── Full sequence only (Fajr & Maghrib) ──────────────────────────

        WiridItem(
            id: "wirid-07-baqarah-163",
            titleEn: "Al-Baqarah 2:163",
            titleMy: "Al-Baqarah 2:163",
            arabicText: "وَإِلَٰهُكُمْ إِلَٰهٌ وَاحِدٌ ۖ لَّا إِلَٰهَ إِلَّا هُوَ الرَّحْمَٰنُ الرَّحِيمُ",
            transliteration: "Wa ilāhukum ilāhuw wāḥid, lā ilāha illā huwar-raḥmānur-raḥīm",
            translationMy: "Dan Tuhan kamu ialah Tuhan Yang Maha Esa, tiada Tuhan melainkan Dia, Yang Maha Pemurah lagi Maha Mengasihani.",
            reference: "Al-Baqarah 2:163",
            count: nil,
            isShort: false,
            orderIndex: 7
        ),
        WiridItem(
            id: "wirid-09-baqarah-284",
            titleEn: "Al-Baqarah 2:284",
            titleMy: "Al-Baqarah 2:284",
            arabicText: "لِلَّهِ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ وَإِن تُبْدُوا مَا فِي أَنفُسِكُمْ أَوْ تُخْفُوهُ يُحَاسِبْكُم بِهِ اللَّهُ ۖ فَيَغْفِرُ لِمَن يَشَاءُ وَيُعَذِّبُ مَن يَشَاءُ ۗ وَاللَّهُ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ",
            transliteration: "Lillāhi mā fis-samāwāti wa mā fil-arḍ, wa in tubdū mā fī anfusikum aw tukhfūhu yuḥāsibkum bihillāh, fa yaghfiru liman yashā'u wa yu'aẓżibu man yashā', wallāhu 'alā kulli shay'in qadīr",
            translationMy: "Segala yang ada di langit dan bumi adalah kepunyaan Allah. Jika kamu melahirkan atau menyembunyikan apa yang ada dalam hati kamu, Allah akan menghitungnya. Lalu Dia mengampunkan sesiapa yang dikehendaki-Nya dan menyeksa sesiapa yang dikehendaki-Nya. Allah Maha Berkuasa atas tiap-tiap sesuatu.",
            reference: "Al-Baqarah 2:284",
            count: nil,
            isShort: false,
            orderIndex: 9
        ),
        WiridItem(
            id: "wirid-10-baqarah-285",
            titleEn: "Al-Baqarah 2:285",
            titleMy: "Al-Baqarah 2:285",
            arabicText: "آمَنَ الرَّسُولُ بِمَا أُنزِلَ إِلَيْهِ مِن رَّبِّهِ وَالْمُؤْمِنُونَ ۚ كُلٌّ آمَنَ بِاللَّهِ وَمَلَائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ لَا نُفَرِّقُ بَيْنَ أَحَدٍ مِّن رُّسُلِهِ ۚ وَقَالُوا سَمِعْنَا وَأَطَعْنَا ۖ غُفْرَانَكَ رَبَّنَا وَإِلَيْكَ الْمَصِيرُ",
            transliteration: "Āmanar-rasūlu bimā unzila ilayhi mir-rabbihī wal-mu'minūn, kullun āmana billāhi wa malā'ikatihī wa kutubihī wa rusulih, lā nufarriqu baina aḥadim mir-rusulih, wa qālū sami'nā wa aṭa'nā, gufrānaka rabbanā wa ilaikal-maṣīr",
            translationMy: "Rasulullah beriman kepada apa yang diturunkan kepadanya dari Tuhannya, dan orang-orang yang beriman juga semuanya beriman kepada Allah, malaikat-malaikat-Nya, kitab-kitab-Nya dan rasul-rasul-Nya. Mereka berkata: Kami dengar dan kami taat. Kami pohon keampunan-Mu ya Tuhan kami dan kepada-Mu tempat kembali.",
            reference: "Al-Baqarah 2:285",
            count: nil,
            isShort: false,
            orderIndex: 10
        ),
        WiridItem(
            id: "wirid-11-baqarah-286",
            titleEn: "Al-Baqarah 2:286",
            titleMy: "Al-Baqarah 2:286",
            arabicText: "لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا ۚ لَهَا مَا كَسَبَتْ وَعَلَيْهَا مَا اكْتَسَبَتْ ۗ رَبَّنَا لَا تُؤَاخِذْنَا إِن نَّسِينَا أَوْ أَخْطَأْنَا ۚ رَبَّنَا وَلَا تَحْمِلْ عَلَيْنَا إِصْرًا كَمَا حَمَلْتَهُ عَلَى الَّذِينَ مِن قَبْلِنَا ۚ رَبَّنَا وَلَا تُحَمِّلْنَا مَا لَا طَاقَةَ لَنَا بِهِ ۖ وَاعْفُ عَنَّا وَاغْفِرْ لَنَا وَارْحَمْنَا ۚ أَنتَ مَوْلَانَا فَانصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ",
            transliteration: "Lā yukallifullāhu nafsan illā wus'ahā, lahā mā kasabat wa 'alaihā maktasabat, rabbanā lā tu'ākhiżnā in nasīnā aw akhṭa'nā, rabbanā wa lā taḥmil 'alainā iṣran kamā ḥamaltahū 'alallażīna min qablinā, rabbanā wa lā tuḥammilnā mā lā ṭāqata lanā bih, wa'fu 'annā wagfir lanā warḥamnā, anta mawlānā fanṣurnā 'alal-qawmil-kāfirīn",
            translationMy: "Allah tidak memberati seseorang melainkan apa yang terdaya olehnya. Wahai Tuhan kami, janganlah Engkau mengirakan kami salah jika kami lupa atau tersalah. Janganlah Engkau bebankan kepada kami bebanan yang berat sebagaimana yang telah Engkau bebankan kepada orang-orang terdahulu. Janganlah Engkau pikulkan apa yang kami tidak terdaya. Maafkanlah, ampunkanlah dan rahmatilah kami. Engkaulah Penolong kami, tolonglah kami menghadapi orang-orang kafir.",
            reference: "Al-Baqarah 2:286",
            count: nil,
            isShort: false,
            orderIndex: 11
        ),
        WiridItem(
            id: "wirid-12-ali-imran-18",
            titleEn: "Ali Imran 3:18",
            titleMy: "Ali Imran 3:18",
            arabicText: "شَهِدَ اللَّهُ أَنَّهُ لَا إِلَٰهَ إِلَّا هُوَ وَالْمَلَائِكَةُ وَأُولُو الْعِلْمِ قَائِمًا بِالْقِسْطِ ۚ لَا إِلَٰهَ إِلَّا هُوَ الْعَزِيزُ الْحَكِيمُ",
            transliteration: "Shahidallāhu annahū lā ilāha illā huwa wal-malā'ikatu wa ulul-'ilmi qā'imam bil-qisṭ, lā ilāha illā huwal-'azīzul-ḥakīm",
            translationMy: "Allah menerangkan bahawa tiada Tuhan yang berhak disembah melainkan Dia, dan para malaikat serta orang-orang yang berilmu juga menyaksikan demikian. Dia sentiasa mentadbir dengan keadilan. Tiada Tuhan melainkan Dia, Yang Maha Kuasa lagi Maha Bijaksana.",
            reference: "Ali Imran 3:18",
            count: nil,
            isShort: false,
            orderIndex: 12
        ),
        WiridItem(
            id: "wirid-13-ali-imran-19",
            titleEn: "Ali Imran 3:19",
            titleMy: "Ali Imran 3:19",
            arabicText: "إِنَّ الدِّينَ عِندَ اللَّهِ الْإِسْلَامُ",
            transliteration: "Innad-dīna 'indallāhil-islām",
            translationMy: "Sesungguhnya agama yang benar dan diredai di sisi Allah ialah Islam.",
            reference: "Ali Imran 3:19",
            count: nil,
            isShort: false,
            orderIndex: 13
        ),
        WiridItem(
            id: "wirid-14-ali-imran-26",
            titleEn: "Ali Imran 3:26",
            titleMy: "Ali Imran 3:26",
            arabicText: "قُلِ اللَّهُمَّ مَالِكَ الْمُلْكِ تُؤْتِي الْمُلْكَ مَن تَشَاءُ وَتَنزِعُ الْمُلْكَ مِمَّن تَشَاءُ وَتُعِزُّ مَن تَشَاءُ وَتُذِلُّ مَن تَشَاءُ ۖ بِيَدِكَ الْخَيْرُ ۖ إِنَّكَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ",
            transliteration: "Qulillāhumma mālikal-mulki tu'til-mulka man tashā'u wa tanzi'ul-mulka mimman tashā'u wa tu'izzu man tashā'u wa tużillu man tashā', biyadikal-khair, innaka 'alā kulli shay'in qadīr",
            translationMy: "Katakanlah: Wahai Tuhan yang memiliki kerajaan, Engkau memberi kerajaan kepada sesiapa yang Engkau kehendaki dan Engkau mencabut kerajaan dari sesiapa yang Engkau kehendaki. Engkau memuliakan sesiapa yang Engkau kehendaki dan menghinakan sesiapa yang Engkau kehendaki. Dalam kekuasaan Engkaulah segala kebaikan. Sesungguhnya Engkau Maha Berkuasa.",
            reference: "Ali Imran 3:26",
            count: nil,
            isShort: false,
            orderIndex: 14
        ),
        WiridItem(
            id: "wirid-15-ali-imran-27",
            titleEn: "Ali Imran 3:27",
            titleMy: "Ali Imran 3:27",
            arabicText: "تُولِجُ اللَّيْلَ فِي النَّهَارِ وَتُولِجُ النَّهَارَ فِي اللَّيْلِ ۖ وَتُخْرِجُ الْحَيَّ مِنَ الْمَيِّتِ وَتُخْرِجُ الْمَيِّتَ مِنَ الْحَيِّ ۖ وَتَرْزُقُ مَن تَشَاءُ بِغَيْرِ حِسَابٍ",
            transliteration: "Tūlijul-laila fin-nahāri wa tūlijun-nahāra fil-laili wa tukhrijul-ḥayya minal-mayyiti wa tukhrijul-mayyita minal-ḥayyi wa tarzuqu man tashā'u bighayri ḥisāb",
            translationMy: "Engkau memasukkan malam ke dalam siang dan memasukkan siang ke dalam malam. Engkau mengeluarkan yang hidup dari yang mati dan yang mati dari yang hidup. Engkau memberi rezeki kepada sesiapa yang Engkau kehendaki tanpa hisab.",
            reference: "Ali Imran 3:27",
            count: nil,
            isShort: false,
            orderIndex: 15
        ),
        WiridItem(
            id: "wirid-17-falaq",
            titleEn: "Surah Al-Falaq",
            titleMy: "Surah Al-Falaq",
            arabicText: "قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِن شَرِّ مَا خَلَقَ ۝ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ",
            transliteration: "Qul a'ūdzu birabbil-falaq. Min sharri mā khalaq. Wa min sharri ghāsiqin iżā waqab. Wa min sharrin-naffāthāti fil-'uqad. Wa min sharri ḥāsidin iżā ḥasad.",
            translationMy: "Katakanlah: Aku berlindung kepada Tuhan yang menciptakan fajar. Dari kejahatan makhluk-makhluk yang Dia ciptakan. Dari kejahatan malam apabila gelap pekat. Dari kejahatan makhluk-makhluk yang menghembus pada simpulan-simpulan. Dari kejahatan orang yang dengki apabila dia mendengki.",
            reference: "Al-Falaq 113",
            count: nil,
            isShort: false,
            orderIndex: 17
        ),
        WiridItem(
            id: "wirid-18-nas",
            titleEn: "Surah An-Nas",
            titleMy: "Surah An-Nas",
            arabicText: "قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ",
            transliteration: "Qul a'ūdzu birabbin-nās. Malikin-nās. Ilāhin-nās. Min sharril-waswāsil-khannās. Allażī yuwaswisu fī ṣudūrin-nās. Minal-jinnati wan-nās.",
            translationMy: "Katakanlah: Aku berlindung kepada Tuhan manusia. Raja manusia. Tuhan yang disembah manusia. Dari kejahatan pembisik yang bersembunyi. Yang membisikkan ke dalam dada manusia. Dari golongan jin dan manusia.",
            reference: "An-Nas 114",
            count: nil,
            isShort: false,
            orderIndex: 18
        ),
        WiridItem(
            id: "wirid-19-fatihah-2",
            titleEn: "Al-Fatihah (closing)",
            titleMy: "Al-Fatihah (penutup)",
            arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ ۝ الرَّحْمَٰنِ الرَّحِيمِ ۝ مَالِكِ يَوْمِ الدِّينِ ۝ إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ ۝ اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ ۝ صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ",
            transliteration: "Bismillāhir-raḥmānir-raḥīm. Al-ḥamdu lillāhi rabbil-'ālamīn. Ar-raḥmānir-raḥīm. Māliki yawmid-dīn. Iyyāka na'budu wa iyyāka nasta'īn. Ihdinaṣ-ṣirāṭal-mustaqīm. Ṣirāṭallażīna an'amta 'alaihim, ghairil-maghḍūbi 'alaihim wa laḍ-ḍāllīn.",
            translationMy: "Dengan nama Allah Yang Maha Pemurah lagi Maha Mengasihani. Segala puji bagi Allah Tuhan sekalian alam. Yang Maha Pemurah lagi Maha Mengasihani. Yang Menguasai hari Pembalasan. Hanya Engkaulah yang kami sembah dan hanya kepada Engkaulah kami memohon pertolongan. Tunjukilah kami jalan yang lurus. Iaitu jalan orang yang Engkau kurniakan nikmat, bukan jalan orang yang Engkau murkai dan bukan pula jalan orang yang sesat.",
            reference: "Al-Fatihah 1:1–7",
            count: nil,
            isShort: false,
            orderIndex: 19
        ),
        WiridItem(
            id: "wirid-22-tahmid-formula",
            titleEn: "Opening of Tahmid",
            titleMy: "Pembukaan Tahmid",
            arabicText: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ دَائِمًا قَائِمًا أَبَدًا — الْحَمْدُ لِلَّهِ",
            transliteration: "Subḥānallāhi wa biḥamdihī dā'iman qā'iman abadā — alḥamdulillāh",
            translationMy: "Maha Suci Allah, aku bertasbih sambil memuji-Nya kekal sentiasa selama-lamanya — segala pujian hanya bagi Allah.",
            reference: nil,
            count: nil,
            isShort: false,
            orderIndex: 22
        ),
        WiridItem(
            id: "wirid-24-takbir-intro",
            titleEn: "Opening of Takbir",
            titleMy: "Pembukaan Takbir",
            arabicText: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ عَلَى كُلِّ حَالٍ وَنِعْمَةٍ — اللَّهُ أَكْبَرُ",
            transliteration: "Alḥamdu lillāhi rabbil-'ālamīna 'alā kulli ḥālin wa ni'matin — Allāhu akbar",
            translationMy: "Segala pujian bagi Allah Tuhan sekalian alam, dalam setiap keadaan dan nikmat — Allah Maha Besar.",
            reference: nil,
            count: nil,
            isShort: false,
            orderIndex: 24
        ),
        WiridItem(
            id: "wirid-25-allahuakbar",
            titleEn: "Takbir",
            titleMy: "Takbir",
            arabicText: "اللَّهُ أَكْبَرُ",
            transliteration: "Allāhu akbar",
            translationMy: "Allah Maha Besar.",
            reference: "Sahih al-Bukhari 843 · Sahih Muslim 597",
            count: "33×",
            isShort: false,
            orderIndex: 25
        )
    ]

    static func items(forPrayer canonicalName: String) -> [WiridItem] {
        let isFull = fullWiridPrayers.contains(canonicalName)
        return items
            .filter { isFull || $0.isShort }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Returns the single best item to feature in the timeline card for a prayer.
    static func featuredItem(forPrayer canonicalName: String) -> WiridItem? {
        items.first { $0.id == "wirid-08-ayatul-kursi" }
    }

    static func shortSubtitle(forPrayer canonicalName: String) -> (en: String, my: String) {
        let isFull = fullWiridPrayers.contains(canonicalName)
        let shortCount = items.filter { $0.isShort }.count
        let fullCount = items.count
        let count = isFull ? fullCount : shortCount
        if isFull {
            return (
                en: "Full wirid sequence · \(count) steps · Tasbih 33× each",
                my: "Wirid penuh · \(count) langkah · Tasbih 33× setiap satu"
            )
        } else {
            return (
                en: "Short wirid · \(count) steps · Tasbih 33× each",
                my: "Wirid ringkas · \(count) langkah · Tasbih 33× setiap satu"
            )
        }
    }
}

// MARK: - Doa Content

enum DoaContentRepository {

    static let all: [DoaItem] = [
        DoaItem(
            id: "doa-01-qabul",
            titleEn: "Prayer Acceptance",
            titleMy: "Doa Penerimaan Solat",
            arabicText: "اللَّهُمَّ تَقَبَّلْ مِنَّا صَلَاتَنَا وَدُعَاءَنَا إِنَّكَ أَنْتَ السَّمِيعُ الْعَلِيمُ وَتُبْ عَلَيْنَا إِنَّكَ أَنْتَ التَّوَّابُ الرَّحِيمُ ۝ اللَّهُمَّ اجْعَلْ دِينَنَا دِينَ النَّبِيِّ مُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ وَإِسْلَامَنَا إِسْلَامَ الْمُسْلِمِينَ وَإِيمَانَنَا إِيمَانَ الْمُؤْمِنِينَ وَصَلَاتَنَا صَلَاةَ الْخَاشِعِينَ ۝ رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
            transliteration: "Allāhumma taqabbal minnā ṣalātanā wa du'ā'anā innaka antas-samī'ul-'alīm, wa tub 'alainā innaka antat-tawwābur-raḥīm. Allāhumma ij'al dīnanā dīnan-nabiyyi Muḥammadin ṣallallāhu 'alaihi wa sallam, wa islāmanā islāmal-muslimīn, wa īmānanā īmānal-mu'minīn, wa ṣalātanā ṣalātal-khāshi'īn. Rabbanā ātinā fid-dunyā ḥasanatan wa fil-ākhirati ḥasanatan wa qinā 'adhāban-nār.",
            translationMy: "Ya Allah, terimalah solat dan doa kami, sesungguhnya Engkau Maha Mendengar lagi Maha Mengetahui. Ampunilah kami, sesungguhnya Engkau Maha Pengampun lagi Maha Penyayang. Ya Allah, jadikanlah agama kami agama Nabi Muhammad, keislaman kami Islam yang sebenar, keimanan kami iman yang sempurna, dan solat kami solat yang khusyuk. Ya Tuhan kami, kurniakanlah kami kebaikan di dunia dan di akhirat, dan peliharalah kami dari azab neraka.",
            note: nil
        ),
        DoaItem(
            id: "doa-02-umum",
            titleEn: "General Supplication",
            titleMy: "Doa Umum",
            arabicText: "اللَّهُمَّ أَحْيِنَا بِالْإِيمَانِ وَاحْشُرْنَا بِالْإِيمَانِ وَأَدْخِلْنَا الْجَنَّةَ مَعَ الْإِيمَانِ بِرَحْمَتِكَ يَا أَرْحَمَ الرَّاحِمِينَ ۝ اللَّهُمَّ أَعِنَّا عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ ۝ اللَّهُمَّ إِنَّا نَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى",
            transliteration: "Allāhumma aḥyinā bil-īmān, waḥshurnā bil-īmān, wa adkhilnal-jannata ma'al-īmān, biraḥmatika yā arḥamar-rāḥimīn. Allāhumma a'innā 'alā żikrika wa shukrika wa ḥusni 'ibādatik. Allāhumma innā nas'alukal-hudā wat-tuqā wal-'afāfa wal-ghinā.",
            translationMy: "Ya Allah, hidupkanlah kami dengan iman, kumpulkanlah kami dengan iman dan masukkanlah kami ke dalam syurga bersama iman dengan rahmat-Mu, wahai Yang Paling Pengasih. Ya Allah, tolonglah kami untuk mengingati-Mu, bersyukur kepada-Mu dan melakukan ibadah yang sebaik-baiknya. Ya Allah, kami memohon kepada-Mu petunjuk, ketakwaan, kehormatan diri dan kecukupan.",
            note: nil
        ),
        DoaItem(
            id: "doa-03-sihat",
            titleEn: "Health, Knowledge & Good End",
            titleMy: "Doa Kesihatan, Ilmu & Kematian Baik",
            arabicText: "اللَّهُمَّ إِنَّا نَسْأَلُكَ سَلَامَةً فِي الدِّينِ وَعَافِيَةً فِي الْجَسَدِ وَزِيَادَةً فِي الْعِلْمِ وَبَرَكَةً فِي الرِّزْقِ وَتَوْبَةً قَبْلَ الْمَوْتِ وَرَحْمَةً عِنْدَ الْمَوْتِ وَمَغْفِرَةً بَعْدَ الْمَوْتِ ۝ اللَّهُمَّ هَوِّنْ عَلَيْنَا فِي سَكَرَاتِ الْمَوْتِ وَالنَّجَاةَ مِنَ النَّارِ وَالْعَفْوَ عِنْدَ الْحِسَابِ ۝ اللَّهُمَّ اخْتِمْ لَنَا بِحُسْنِ الْخَاتِمَةِ وَلَا تَخْتِمْ عَلَيْنَا بِسُوءِ الْخَاتِمَةِ",
            transliteration: "Allāhumma innā nas'aluka salāmatan fīd-dīn, wa 'āfiyatan fil-jasad, wa ziyādatan fil-'ilm, wa barakatan fir-rizq, wa tawbatan qablal-mawt, wa raḥmatan 'indal-mawt, wa maghfiratan ba'dal-mawt. Allāhumma hawwin 'alainā fī sakarātil-mawt, wan-najāta minan-nār, wal-'afwa 'indal-ḥisāb. Allāhummakhtim lanā biḥusnil-khātimah, wa lā takhtim 'alainā bisū'il-khātimah.",
            translationMy: "Ya Allah, kami memohon keselamatan agama, kesihatan jasad, tambahan ilmu, keberkatan rezeki, taubat sebelum mati, rahmat ketika mati dan keampunan selepas mati. Ya Allah, ringankanlah ke atas kami semasa sakaratul maut, selamatkan kami dari neraka dan kurniakan kemaafan semasa hisab. Ya Allah, akhirilah umur kami dengan kesudahan yang baik dan janganlah Engkau akhirkan dengan kesudahan yang buruk.",
            note: nil
        ),
        DoaItem(
            id: "doa-04-iman",
            titleEn: "Faith & Forgiveness",
            titleMy: "Doa Iman & Keampunan",
            arabicText: "اللَّهُمَّ أَحْيِنَا بِالْإِيمَانِ وَأَمِتْنَا بِالْإِيمَانِ وَأَدْخِلْنَا الْجَنَّةَ مَعَ الْإِيمَانِ ۝ اللَّهُمَّ اغْفِرْ لَنَا ذُنُوبَنَا وَلِوَالِدَيْنَا وَارْحَمْهُمَا كَمَا رَبَّيَانَا صَغِيرًا ۝ رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِن لَّدُنكَ رَحْمَةً إِنَّكَ أَنتَ الْوَهَّابُ ۝ رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
            transliteration: "Allāhumma aḥyinā bil-īmān, wa amitnā bil-īmān, wa adkhilnal-jannata ma'al-īmān. Allāhummaghfir lanā dhunūbanā wa liwālidainā warḥamhumā kamā rabbayānā ṣaghīrā. Rabbanā lā tuzigh qulūbanā ba'da idh hadaytanā wa hab lanā min ladunka raḥmatan innaka antal-wahhāb. Rabbanā ātinā fid-dunyā ḥasanatan wa fil-ākhirati ḥasanatan wa qinā 'adhāban-nār.",
            translationMy: "Ya Allah, hidupkanlah kami dengan iman, matikanlah kami dengan iman dan masukkanlah kami ke dalam syurga bersama iman. Ya Allah, ampunilah dosa-dosa kami dan dosa kedua ibu bapa kami, serta rahmatilah mereka sebagaimana mereka mendidik kami semasa kecil. Ya Tuhan kami, janganlah Engkau pesongkan hati kami setelah Engkau beri petunjuk, dan kurniakanlah kami rahmat dari sisi-Mu, sesungguhnya Engkau Maha Pemberi. Ya Tuhan kami, kurniakanlah kami kebaikan di dunia dan di akhirat, dan peliharalah kami dari azab neraka.",
            note: nil
        ),
        DoaItem(
            id: "doa-05-perlindungan-keluarga",
            titleEn: "Family & Household Protection",
            titleMy: "Doa Perlindungan Keluarga",
            arabicText: "اللَّهُمَّ إِنَّا نَسْتَحْفِظُكَ وَنَسْتَوْدِعُكَ دِينَنَا وَأَهْلَنَا وَكُلَّ شَيْءٍ أَعْطَيْتَنَا ۝ اللَّهُمَّ اجْعَلْنَا وَإِيَّاهُمْ فِي كَنَفِكَ وَأَمَانِكَ وَجِوَارِكَ مِنْ كُلِّ شَيْطَانٍ مَرِيدٍ وَجَبَّارٍ عَنِيدٍ وَمِنْ كُلِّ شَرٍّ ۝ اللَّهُمَّ أَصْلِحْ ذَاتَ بَيْنِنَا وَأَلِّفْ بَيْنَ قُلُوبِنَا وَاهْدِنَا سُبُلَ السَّلَامِ وَنَجِّنَا مِنَ الظُّلُمَاتِ إِلَى النُّورِ",
            transliteration: "Allāhumma innā nastaḥfiẓuka wa nastawdi'uka dīnanā wa ahlanā wa kulla shay'in a'ṭaytanā. Allāhumma ij'alnā wa iyyāhum fī kanafika wa amānika wa jawārika min kulli shayṭānin marīdin wa jabbārin 'anīdin wa min kulli sharr. Allāhumma aṣliḥ dhāta bainanā wa allif baina qulūbinā waihdinā subulas-salāmi wa najjinā minaẓ-ẓulumāti ilan-nūr.",
            translationMy: "Ya Allah, kami memohon perlindungan-Mu dan menitipkan kepada-Mu agama kami, keluarga kami dan segala yang Engkau kurniakan kepada kami. Ya Allah, jadikanlah kami dan mereka dalam pemeliharaan, perlindungan dan jaminan-Mu dari setiap syaitan yang derhaka, setiap yang zalim dan dari segala kejahatan. Ya Allah, perbaikilah hubungan antara kami, lembutkanlah hati-hati kami, tunjukkanlah kami jalan keselamatan dan selamatkanlah kami dari kegelapan kepada cahaya.",
            note: nil
        ),
        DoaItem(
            id: "doa-06-abu-darda",
            titleEn: "Doa of Abu Darda",
            titleMy: "Doa Abu Darda",
            arabicText: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ عَلَيْكَ تَوَكَّلْتُ وَأَنْتَ رَبُّ الْعَرْشِ الْعَظِيمِ ۝ مَا شَاءَ اللَّهُ كَانَ وَمَا لَمْ يَشَأْ لَمْ يَكُنْ لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ ۝ أَعْلَمُ أَنَّ اللَّهَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ وَأَنَّ اللَّهَ قَدْ أَحَاطَ بِكُلِّ شَيْءٍ عِلْمًا ۝ اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي وَمِنْ شَرِّ كُلِّ دَابَّةٍ أَنْتَ آخِذٌ بِنَاصِيَتِهَا إِنَّ رَبِّي عَلَى صِرَاطٍ مُسْتَقِيمٍ",
            transliteration: "Allāhumma anta rabbī lā ilāha illā ant, 'alaika tawakkaltu wa anta rabbul-'arshil-'aẓīm. Mā shā'allāhu kāna wa mā lam yasha' lam yakun, lā ḥawla wa lā quwwata illā billāhil-'aliyyil-'aẓīm. A'lamu annallāha 'alā kulli shay'in qadīr wa annallāha qad aḥāṭa bikulli shay'in 'ilmā. Allāhumma innī a'ūdhu bika min sharri nafsī wa min sharri kulli dābbatin anta ākhidhun bināṣiyatihā, inna rabbī 'alā ṣirāṭin mustaqīm.",
            translationMy: "Ya Allah, Engkaulah Tuhanku, tiada tuhan selain Engkau, kepada-Mu aku bertawakkal dan Engkau adalah Tuhan Arasy yang Maha Agung. Apa yang Allah kehendaki itulah yang terjadi dan apa yang tidak Dia kehendaki tidak akan terjadi. Tiada daya dan kekuatan kecuali dengan Allah Yang Maha Tinggi lagi Maha Agung. Aku tahu bahawa Allah Maha Berkuasa atas segala sesuatu dan ilmu-Nya meliputi segala sesuatu. Ya Allah, aku berlindung dengan-Mu dari kejahatan diriku dan dari kejahatan setiap makhluk yang Engkau pegang ubun-ubunnya. Sesungguhnya Tuhanku berada di atas jalan yang lurus.",
            note: "Doa Abu Darda r.a. — diriwayatkan bahawa beliau mengamalkan doa ini yang diperoleh daripada Rasulullah ﷺ"
        ),
        DoaItem(
            id: "doa-07-wabak",
            titleEn: "Protection from Illness & Calamity",
            titleMy: "Doa Wabak & Bala",
            arabicText: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْبَرَصِ وَالْجُنُونِ وَالْجُذَامِ وَمِنْ سَيِّئِ الْأَسْقَامِ ۝ اللَّهُمَّ ادْفَعْ عَنَّا الْبَلَاءَ وَالْغَلَاءَ وَالْوَبَاءَ وَالطَّاعُونَ وَالْفَحْشَاءَ وَالْمُنْكَرَ وَالْبَغْيَ وَالسُّوءَ الْمُخْتَلِفَ وَالشَّدَائِدَ وَالْمِحَنَ مَا ظَهَرَ مِنْهَا وَمَا بَطَنَ مِنْ بَلَدِنَا وَمِنْ بُلْدَانِ الْمُسْلِمِينَ كَافَّةً ۝ إِنَّكَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ وَبِالْإِجَابَةِ جَدِيرٌ",
            transliteration: "Allāhumma innī a'ūdhu bika minal-barasi, wal-junūni, wal-judhāmi, wa min sayyi'il-asqām. Allāhumma idfa' 'annal-balā'a, wal-ghalā'a, wal-wabā'a, waṭ-ṭā'ūna, wal-faḥshā'a, wal-munkara, wal-baghya, was-sū'al-mukhtalif, wash-shadā'ida, wal-miḥana, mā ẓahara minhā wa mā baṭana min baladinā wa min buldānil-muslimīna kāffah. Innaka 'alā kulli shay'in qadīr wa bil-ijābati jadīr.",
            translationMy: "Ya Allah, aku berlindung dengan-Mu dari penyakit sopak, gila, kusta dan penyakit-penyakit yang buruk. Ya Allah, jauhkanlah dari kami bencana, kenaikan harga, wabak, taun, perlakuan keji, mungkar, kezaliman, pelbagai keburukan, kepayahan dan dugaan, yang zahir mahupun yang tersembunyi, dari negeri kami dan dari seluruh negara umat Islam. Sesungguhnya Engkau Maha Berkuasa atas segala-galanya dan selayaknya memberi perkenan.",
            note: nil
        ),
        DoaItem(
            id: "doa-08-islam-ummah",
            titleEn: "Strength of Islam & the Ummah",
            titleMy: "Doa Kekuatan Islam & Ummah",
            arabicText: "اللَّهُمَّ أَعِزَّ الْإِسْلَامَ وَالْمُسْلِمِينَ وَأَذِلَّ الشِّرْكَ وَالْمُشْرِكِينَ وَالنِّفَاقَ وَالْمُنَافِقِينَ وَالظُّلْمَ وَالظَّالِمِينَ وَدَمِّرْ أَعْدَاءَ الدِّينِ ۝ اللَّهُمَّ انْصُرْ إِخْوَانَنَا الْمُجَاهِدِينَ وَالْمُسْتَضْعَفِينَ فِي فِلَسْطِينَ وَفِي غَزَّةَ وَفِي الْعِرَاقِ وَفِي سُورِيَا وَفِي كَشْمِيرَ وَفِي كُلِّ مَكَانٍ ۝ اللَّهُمَّ قَوِّ عَزَائِمَهُمْ وَاجْمَعْ كَلِمَتَهُمْ وَثَبِّتْ أَقْدَامَهُمْ وَانْصُرْهُمْ عَلَى أَعْدَائِهِمْ ۝ رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
            transliteration: "Allāhumma a'izzal-islāma wal-muslimīn, wa adhillash-shirka wal-mushrikīn, wan-nifāqa wal-munāfiqīn, waẓ-ẓulma waẓ-ẓālimīn, wa dammir a'dā'ad-dīn. Allāhumma anṣur ikhwānanal-mujāhidīn wal-mustaḍ'afīn fī filasṭīn, wa fī ghazzah, wa fil-'irāq, wa fī sūriyā, wa fī kashmīr, wa fī kulli makān. Allāhumma qawwi 'azā'imahum, wajma' kalimatahum, wa thabbit aqdāmahum, wanṣurhum 'alā a'dā'ihim. Rabbanā ātinā fid-dunyā ḥasanatan wa fil-ākhirati ḥasanatan wa qinā 'adhāban-nār.",
            translationMy: "Ya Allah, muliakanlah Islam dan kaum Muslimin, hinakanlah syirik dan kaum musyrikin, kemunafikan dan munafiqin, kezaliman dan orang-orang zalim, serta hancurkanlah musuh-musuh agama. Ya Allah, tolonglah saudara-saudara kami yang berjuang dan yang tertindas di Palestin, Gaza, Iraq, Syria, Kashmir dan di setiap tempat. Ya Allah, kuatkanlah azam mereka, satukanlah kata-kata mereka, teguhkanlah pendirian mereka dan menangkanlah mereka ke atas musuh-musuh mereka. Ya Tuhan kami, kurniakanlah kami kebaikan di dunia dan di akhirat, dan peliharalah kami dari azab neraka.",
            note: nil
        )
    ]

    /// Returns the recommended doa for a given prayer. Rotates through the 8 duas
    /// based on canonical prayer name so each prayer has a consistent pairing.
    static func recommended(forPrayer canonicalName: String) -> DoaItem {
        let index: Int
        switch canonicalName {
        case "fajr":    index = 0   // Doa 1 — acceptance, fresh start
        case "dhuhr":   index = 3   // Doa 4 — short iman doa, midday
        case "asr":     index = 4   // Doa 5 — family protection, end of work
        case "maghrib": index = 6   // Doa 7 — wabak/protection, communal
        case "isha":    index = 5   // Doa 6 — Abu Darda, night reflection
        default:        index = 1
        }
        return all[index]
    }

    /// Returns a secondary doa for the full-sequence prayers (Fajr & Maghrib).
    static func secondary(forPrayer canonicalName: String) -> DoaItem? {
        switch canonicalName {
        case "fajr":    return all[7]   // Doa 8 — ummah, powerful morning close
        case "maghrib": return all[1]   // Doa 2 — general, evening wrap
        default:        return nil
        }
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
        // Temporarily hide Wirid Ringkas / Wirid & Doa timeline cards.
        // Keep the dedicated blue Wirid and Doa surfaces unchanged.
        let wiridEntries: [ForYouTimelineEntry] = []
        let sunEntries = buildSunEntries(for: date, timeline: timeline)
        return (prayerEntries + zikirEntries + wiridEntries + sunEntries)
            .sorted { lhs, rhs in
                if lhs.time == rhs.time {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return lhs.time < rhs.time
            }
    }

    private func buildSunEntries(for date: Date, timeline: ForYouPrayerTimeline) -> [ForYouTimelineEntry] {
        var entries: [ForYouTimelineEntry] = []
        let iso = ISO8601DateFormatter().string(from: date)
//        let featured = WiridContentRepository.featuredItem(forPrayer: "fajr")
//        let sub = WiridContentRepository.shortSubtitle(forPrayer: "fajr") // short wirid

        // Syuruk / Shurooq — prayer entry only, no wirid (it's a forbidden prayer time)
        if let sunrise = timeline.sunrise {
            entries.append(makeTimelineEntry(
                id: "\(iso)-syuruk",
                kind: .prayer,
                momentType: .morning,
                time: sunrise,
                title: isMalayAppLanguage() ? "Syuruk" : "Shurooq",
                subtitle: isMalayAppLanguage() ? "Matahari terbit" : "Sunrise",
                icon: "sunrise.fill",
                arabicText: "الشُّرُوق",
                reference: nil,
                recommendation: nil
            ))

            // Ishraq — 18 min after sunrise, with wirid card 5 min later
            let ishraqTime = sunrise.addingTimeInterval(18 * 60)
            entries.append(makeTimelineEntry(
                id: "\(iso)-ishraq",
                kind: .prayer,
                momentType: .morning,
                time: ishraqTime,
                title: isMalayAppLanguage() ? "Solat Ishraq" : "Ishraq Prayer",
                subtitle: isMalayAppLanguage() ? "2 rakaat selepas matahari terbit sepenuhnya" : "2 rak'ahs after sunrise is complete",
                icon: "sun.horizon.fill",
                arabicText: "صَلَاةُ الْإِشْرَاق",
                reference: nil,
                recommendation: nil
            ))
//            if let wiridTime = Calendar.current.date(byAdding: .minute, value: 5, to: ishraqTime) {
//                entries.append(makeTimelineEntry(
//                    id: "\(iso)-wirid-ishraq",
//                    kind: .zikir,
//                    momentType: .morning,
//                    time: wiridTime,
//                    title: isMalayAppLanguage() ? "Wirid Ringkas" : "Wirid Ringkas",
//                    subtitle: isMalayAppLanguage() ? sub.my : sub.en,
//                    icon: "text.book.closed",
//                    arabicText: featured?.arabicText,
//                    reference: featured?.reference,
//                    recommendation: nil
//                ))
//            }
        }

        // Dhuha — with wirid card 5 min later
        if let dhuha = timeline.dhuha {
            entries.append(makeTimelineEntry(
                id: "\(iso)-dhuha",
                kind: .prayer,
                momentType: .dhuha,
                time: dhuha,
                title: isMalayAppLanguage() ? "Solat Dhuha" : "Dhuha Prayer",
                subtitle: isMalayAppLanguage() ? "2–8 rakaat, amalan sunnah pagi" : "2–8 rak'ahs, a sunnah of the morning",
                icon: "sun.max.fill",
                arabicText: "صَلَاةُ الضُّحَى",
                reference: "Sahih Muslim 720",
                recommendation: nil
            ))
//            if let wiridTime = Calendar.current.date(byAdding: .minute, value: 5, to: dhuha) {
//                entries.append(makeTimelineEntry(
//                    id: "\(iso)-wirid-dhuha",
//                    kind: .zikir,
//                    momentType: .dhuha,
//                    time: wiridTime,
//                    title: isMalayAppLanguage() ? "Wirid Ringkas" : "Wirid Ringkas",
//                    subtitle: isMalayAppLanguage() ? sub.my : sub.en,
//                    icon: "text.book.closed",
//                    arabicText: featured?.arabicText,
//                    reference: featured?.reference,
//                    recommendation: nil
//                ))
//            }
        }

        return entries
    }

    private func buildWiridEntries(for date: Date, prayers: [Prayer]) -> [ForYouTimelineEntry] {
        let targetPrayers = ["fajr", "dhuhr", "asr", "maghrib", "isha"]

        return prayers.compactMap { prayer in
            let canonical = canonicalPrayerName(prayer.nameTransliteration)
            guard targetPrayers.contains(canonical) else { return nil }

            // Place the wirid card 5 minutes after the prayer begins
            guard let entryTime = Calendar.current.date(byAdding: .minute, value: 5, to: prayer.time) else {
                return nil
            }

            let isFull = WiridContentRepository.fullWiridPrayers.contains(canonical)
            let featured = WiridContentRepository.featuredItem(forPrayer: canonical)
            let sub = WiridContentRepository.shortSubtitle(forPrayer: canonical)
            let titleEn = isFull ? "Wirid & Doa" : "Wirid Ringkas"
            let titleMy = isFull ? "Wirid & Doa" : "Wirid Ringkas"

            return makeTimelineEntry(
                id: "\(ISO8601DateFormatter().string(from: date))-wirid-\(canonical)",
                kind: .zikir,
                momentType: momentType(for: canonical),
                time: entryTime,
                title: isMalayAppLanguage() ? titleMy : titleEn,
                subtitle: isMalayAppLanguage() ? sub.my : sub.en,
                icon: "text.book.closed",
                arabicText: featured?.arabicText,
                reference: featured?.reference,
                recommendation: nil
            )
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

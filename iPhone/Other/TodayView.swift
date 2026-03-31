import SwiftUI

// MARK: - Segment

private enum TodaySegment: String, CaseIterable {
    case today, forYou

    func label() -> String {
        switch self {
        case .today:  return isMalayAppLanguage() ? "Hari Ini" : "Today"
        case .forYou: return isMalayAppLanguage() ? "Untuk Kamu" : "For You"
        }
    }
}

// MARK: - For You content

private struct ForYouItem: Identifiable {
    let id: String
    let arabicText: String
    let titleEn: String
    let titleMy: String
    let bodyEn: String
    let bodyMy: String
    let sourceEn: String?
    let sourceRef: String?
}

private let forYouItems: [ForYouItem] = [
    .init(
        id: "foryou-istighfar",
        arabicText: "أَسْتَغْفِرُ ٱللَّٰهَ",
        titleEn: "Seek Forgiveness Often",
        titleMy: "Sering Mohon Keampunan",
        bodyEn: "The Prophet ﷺ would seek forgiveness more than 70 times a day. Istighfar opens closed doors and lifts burdens you didn't know you were carrying.",
        bodyMy: "Nabi ﷺ memohon keampunan lebih dari 70 kali sehari. Istighfar membuka pintu yang tertutup dan meringankan beban yang tidak kamu sedar sedang dipikul.",
        sourceEn: "\"By Allah, I seek forgiveness from Allah and repent to Him more than seventy times a day.\"",
        sourceRef: "Sahih al-Bukhari 6307"
    ),
    .init(
        id: "foryou-gratitude",
        arabicText: "وَإِذْ تَأَذَّنَ رَبُّكُمْ لَئِن شَكَرْتُمْ لَأَزِيدَنَّكُمْ",
        titleEn: "Gratitude Multiplies Blessings",
        titleMy: "Syukur Melipatgandakan Nikmat",
        bodyEn: "When you feel stuck, name three things you're grateful for. Gratitude is not just a feeling — it's a practice that invites more.",
        bodyMy: "Apabila kamu rasa tersekat, sebutkan tiga perkara yang kamu syukuri. Syukur bukan sekadar perasaan — ia amalan yang mendatangkan lebih banyak nikmat.",
        sourceEn: "\"If you are grateful, I will certainly give you more.\"",
        sourceRef: "Surah Ibrahim 14:7"
    ),
    .init(
        id: "foryou-salawat",
        arabicText: "اللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ",
        titleEn: "Send Salawat on the Prophet ﷺ",
        titleMy: "Hantar Selawat ke atas Nabi ﷺ",
        bodyEn: "One salawat brings ten blessings from Allah, erases ten sins, and raises you ten degrees. It costs nothing and returns everything.",
        bodyMy: "Satu selawat membawa sepuluh rahmat dari Allah, menghapus sepuluh dosa, dan meninggikan darjat sepuluh tingkat. Tidak memerlukan apa pun, tetapi memberi segalanya.",
        sourceEn: "\"Whoever sends one blessing upon me, Allah will send ten upon him.\"",
        sourceRef: "Sahih Muslim 408"
    ),
    .init(
        id: "foryou-duha",
        arabicText: "مَا وَدَّعَكَ رَبُّكَ وَمَا قَلَىٰ",
        titleEn: "You Are Not Forgotten",
        titleMy: "Kamu Tidak Dilupakan",
        bodyEn: "\"Your Lord has not forsaken you, nor does He hate you.\" Revealed in the darkest moment of the Prophet's life — and it speaks to yours too.",
        bodyMy: "\"Tuhanmu tidak meninggalkanmu, dan Dia tidak membencimu.\" Diturunkan pada saat paling gelap dalam kehidupan Nabi — dan ia juga berbicara kepada hidupmu.",
        sourceEn: nil,
        sourceRef: "Surah Ad-Duha 93:3"
    ),
    .init(
        id: "foryou-consistency",
        arabicText: "أَحَبُّ الأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا",
        titleEn: "Small & Consistent Wins",
        titleMy: "Kecil tapi Konsisten",
        bodyEn: "The most beloved deeds to Allah are the most consistent, even if they are small. You don't have to do everything — just don't stop.",
        bodyMy: "Amalan yang paling disukai Allah adalah yang paling konsisten, walaupun kecil. Kamu tidak perlu lakukan semuanya — cuma jangan berhenti.",
        sourceEn: "\"The most beloved deeds to Allah are the most consistent, even if little.\"",
        sourceRef: "Sahih al-Bukhari 6464"
    ),
    .init(
        id: "foryou-quran-heart",
        arabicText: "وَنُنَزِّلُ مِنَ ٱلْقُرْءَانِ مَا هُوَ شِفَآءٌ وَرَحْمَةٌ",
        titleEn: "The Quran Heals",
        titleMy: "Al-Quran Menyembuhkan",
        bodyEn: "\"We send down the Quran as a healing and mercy.\" Even one ayah a day reconnects you to a source that heals what medicine cannot.",
        bodyMy: "\"Kami menurunkan Al-Quran sebagai penawar dan rahmat.\" Walaupun satu ayat sehari, ia menghubungkan kamu semula kepada sumber yang menyembuhkan apa yang ubat tidak mampu.",
        sourceEn: nil,
        sourceRef: "Surah Al-Isra 17:82"
    ),
]

private struct ForYouCard: View {
    let item: ForYouItem
    let accentColor: Color

    @EnvironmentObject private var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.arabicText)
                .font(.custom(preferredQuranArabicFontName(settings: settings, size: 24), size: 24))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

            VStack(alignment: .leading, spacing: 5) {
                Text(isMalayAppLanguage() ? item.titleMy : item.titleEn)
                    .font(.subheadline.weight(.semibold))

                Text(isMalayAppLanguage() ? item.bodyMy : item.bodyEn)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let src = item.sourceEn, let ref = item.sourceRef {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\"\(src)\"")
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("— \(ref)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accentColor)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
            } else if let ref = item.sourceRef {
                Text("— \(ref)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accentColor)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

// MARK: - Prayer Time Slot

enum TodayPrayerTimeSlot: String, CaseIterable, Hashable {
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

struct TodayPractice: Identifiable, Hashable {
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
    let slots: Set<TodayPrayerTimeSlot>
}

enum TodayPracticeLibrary {
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

    static func practices(for slot: TodayPrayerTimeSlot) -> [TodayPractice] {
        all.filter { $0.slots.contains(slot) }
    }

    static func slot(currentPrayer: Prayer?, nextPrayer: Prayer?) -> TodayPrayerTimeSlot {
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

struct TodaySlotBanner: View {
    let slot: TodayPrayerTimeSlot

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

struct TodayPracticeCard: View {
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
                    Text(“\”\(sourceText)\””)
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

struct TodayView: View {
    @EnvironmentObject private var settings: Settings
    @State private var selectedSegment: TodaySegment = .today
    @State private var selectedFullSurah: FullSurahSelection?

    private func surahTitle(for surahNumber: Int) -> String {
        let fallbackEnglish = "Surah \(surahNumber)"
        return localizedSurahName(number: surahNumber, englishName: fallbackEnglish)
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

    private func openTodayPracticeSurah(_ surahNumber: Int, _ ayahNumber: Int?) {
        selectedFullSurah = FullSurahSelection(
            surahNumber: surahNumber,
            initialAyahNumber: ayahNumber,
            dailyAyahNumber: ayahNumber
        )
    }

    var body: some View {
        NavigationView {
            List {
                if selectedSegment == .today {
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
                                onOpenSurah: openTodayPracticeSurah
                            )
                            .environmentObject(settings)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                } else {
                    Section {
                        ForEach(forYouItems) { item in
                            ForYouCard(item: item, accentColor: settings.accentColor.color)
                                .environmentObject(settings)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .applyConditionalListStyle(defaultView: settings.defaultView)
            .navigationTitle(isMalayAppLanguage() ? "Hari Ini" : "Today")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $selectedSegment) {
                        ForEach(TodaySegment.allCases, id: \.self) { seg in
                            Text(seg.label()).tag(seg)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
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
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(Settings.shared)
}

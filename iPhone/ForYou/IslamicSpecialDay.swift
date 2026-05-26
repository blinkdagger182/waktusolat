import Foundation

struct IslamicSpecialDay {
    let hijriMonth: Int
    let hijriDay: Int
    let greetingEN: String
    let greetingBM: String
    let subtitleEN: String
    let subtitleBM: String
}

enum IslamicCalendarGreetings {
    private static let hijriCalendar: Calendar = {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    // All special days in the Islamic calendar (month, day)
    private static let specialDays: [IslamicSpecialDay] = [
        // Muharram
        IslamicSpecialDay(
            hijriMonth: 1, hijriDay: 1,
            greetingEN: "Islamic New Year",
            greetingBM: "Maal Hijrah",
            subtitleEN: "1 Muharram — a new beginning",
            subtitleBM: "1 Muharram — permulaan baru"
        ),
        IslamicSpecialDay(
            hijriMonth: 1, hijriDay: 10,
            greetingEN: "Day of Ashura",
            greetingBM: "Hari Asyura",
            subtitleEN: "Fast today for two years of forgiveness",
            subtitleBM: "Puasa hari ini untuk dua tahun keampunan"
        ),
        // Rabi' Al-Awwal
        IslamicSpecialDay(
            hijriMonth: 3, hijriDay: 12,
            greetingEN: "Mawlid Al-Nabi ﷺ",
            greetingBM: "Maulidur Rasul ﷺ",
            subtitleEN: "Celebrating the Prophet's birth ﷺ",
            subtitleBM: "Sambutan kelahiran Nabi ﷺ"
        ),
        // Rajab
        IslamicSpecialDay(
            hijriMonth: 7, hijriDay: 27,
            greetingEN: "Isra' Wal Mi'raj",
            greetingBM: "Isra' Wal Mi'raj",
            subtitleEN: "The Night Journey and Ascension",
            subtitleBM: "Perjalanan Malam dan Mikraj"
        ),
        // Sha'ban
        IslamicSpecialDay(
            hijriMonth: 8, hijriDay: 15,
            greetingEN: "Nisfu Sha'ban",
            greetingBM: "Nisfu Sha'ban",
            subtitleEN: "Seek forgiveness this blessed night",
            subtitleBM: "Pohon keampunan pada malam yang mulia ini"
        ),
        // Ramadan
        IslamicSpecialDay(
            hijriMonth: 9, hijriDay: 1,
            greetingEN: "Ramadan Mubarak",
            greetingBM: "Selamat Menyambut Ramadan",
            subtitleEN: "The blessed month begins today",
            subtitleBM: "Bulan yang penuh keberkatan bermula hari ini"
        ),
        IslamicSpecialDay(
            hijriMonth: 9, hijriDay: 21,
            greetingEN: "Laylat Al-Qadr begins",
            greetingBM: "Malam Lailatul Qadar",
            subtitleEN: "The last ten nights — seek Laylat Al-Qadr",
            subtitleBM: "Sepuluh malam terakhir — cari Lailatul Qadar"
        ),
        IslamicSpecialDay(
            hijriMonth: 9, hijriDay: 27,
            greetingEN: "Laylat Al-Qadr",
            greetingBM: "Malam Lailatul Qadar",
            subtitleEN: "Better than a thousand months",
            subtitleBM: "Lebih baik dari seribu bulan"
        ),
        // Shawwal
        IslamicSpecialDay(
            hijriMonth: 10, hijriDay: 1,
            greetingEN: "Eid Al-Fitr Mubarak",
            greetingBM: "Selamat Hari Raya Aidilfitri",
            subtitleEN: "Taqabbalallahu minna wa minkum",
            subtitleBM: "Taqabbalallahu minna wa minkum"
        ),
        IslamicSpecialDay(
            hijriMonth: 10, hijriDay: 2,
            greetingEN: "Eid Mubarak",
            greetingBM: "Selamat Hari Raya",
            subtitleEN: "May Allah accept from us and from you",
            subtitleBM: "Semoga Allah menerima amalan kita"
        ),
        IslamicSpecialDay(
            hijriMonth: 10, hijriDay: 3,
            greetingEN: "Eid Mubarak",
            greetingBM: "Selamat Hari Raya",
            subtitleEN: "May Allah accept from us and from you",
            subtitleBM: "Semoga Allah menerima amalan kita"
        ),
        // Dhul Hijja
        IslamicSpecialDay(
            hijriMonth: 12, hijriDay: 1,
            greetingEN: "First days of Dhul Hijja",
            greetingBM: "Awal Dhul Hijja",
            subtitleEN: "The most beloved days to Allah",
            subtitleBM: "Hari-hari paling disukai Allah"
        ),
        IslamicSpecialDay(
            hijriMonth: 12, hijriDay: 8,
            greetingEN: "Eve of Arafah",
            greetingBM: "Malam sebelum Arafah",
            subtitleEN: "Tomorrow is the Day of Arafah",
            subtitleBM: "Esok adalah Hari Arafah"
        ),
        IslamicSpecialDay(
            hijriMonth: 12, hijriDay: 9,
            greetingEN: "Day of Arafah",
            greetingBM: "Hari Arafah",
            subtitleEN: "Fasting today expiates two years of sins",
            subtitleBM: "Puasa hari ini menghapus dosa dua tahun"
        ),
        IslamicSpecialDay(
            hijriMonth: 12, hijriDay: 10,
            greetingEN: "Eid Al-Adha Mubarak",
            greetingBM: "Selamat Hari Raya Aidiladha",
            subtitleEN: "Taqabbalallahu minna wa minkum",
            subtitleBM: "Taqabbalallahu minna wa minkum"
        ),
        IslamicSpecialDay(
            hijriMonth: 12, hijriDay: 11,
            greetingEN: "Eid Al-Adha Mubarak",
            greetingBM: "Selamat Hari Raya Aidiladha",
            subtitleEN: "Ayyam Al-Tashreeq — days of celebration",
            subtitleBM: "Hari Tasyrik — hari-hari perayaan"
        ),
        IslamicSpecialDay(
            hijriMonth: 12, hijriDay: 12,
            greetingEN: "Eid Al-Adha Mubarak",
            greetingBM: "Selamat Hari Raya Aidiladha",
            subtitleEN: "Ayyam Al-Tashreeq — days of celebration",
            subtitleBM: "Hari Tasyrik — hari-hari perayaan"
        ),
        IslamicSpecialDay(
            hijriMonth: 12, hijriDay: 13,
            greetingEN: "Ayyam Al-Tashreeq",
            greetingBM: "Hari Tasyrik",
            subtitleEN: "The last of the blessed days",
            subtitleBM: "Penghujung hari-hari yang penuh berkah"
        ),
    ]

    /// Returns the special day for a given Gregorian date, adjusted by the app's hijri offset.
    static func specialDay(for date: Date, hijriOffset: Int) -> IslamicSpecialDay? {
        let adjusted = hijriOffset != 0
            ? (Calendar(identifier: .islamicUmmAlQura).date(byAdding: .day, value: hijriOffset, to: date) ?? date)
            : date
        let comps = hijriCalendar.dateComponents([.month, .day], from: adjusted)
        guard let month = comps.month, let day = comps.day else { return nil }
        return specialDays.first { $0.hijriMonth == month && $0.hijriDay == day }
    }
}

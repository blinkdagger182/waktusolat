import SwiftUI
#if os(iOS)
import UIKit
#endif

struct DailyQuranArabicPayload: Decodable {
    let arabicText: String?
}

struct QuranSurahDetails {
    struct Ayah: Identifiable {
        let numberInSurah: Int
        let arabicText: String
        let translationText: String?
        let audioURL: String?
        let words: [Word]
        let wordTimings: [WordTiming]

        var id: Int { numberInSurah }
    }

    struct Word: Decodable, Hashable {
        let position: Int
        let textArabic: String
    }

    struct WordTiming: Decodable, Hashable {
        let wordPosition: Int
        let startMs: Int
        let endMs: Int
    }

    let number: Int
    let englishName: String
    let arabicName: String
    let ayahs: [Ayah]
}

enum QuranSurahAPI {
    static func fetchSurahDetails(surahNumber: Int) async throws -> QuranSurahDetails {
        guard (1...114).contains(surahNumber) else {
            throw QuranSurahAPIError.invalidURL
        }

        let decoded = try await fetchSurah(surahNumber: surahNumber)

        return QuranSurahDetails(
            number: decoded.number,
            englishName: decoded.englishName,
            arabicName: decoded.arabicName,
            ayahs: decoded.ayahs.map {
                QuranSurahDetails.Ayah(
                    numberInSurah: $0.numberInSurah,
                    arabicText: $0.arabicText,
                    translationText: $0.translationText,
                    audioURL: $0.audioURL,
                    words: $0.words ?? [],
                    wordTimings: $0.wordTimings ?? []
                )
            }
        )
    }

    private static func fetchSurah(surahNumber: Int) async throws -> QuranSurahProxyResponse {
        guard var components = URLComponents(url: quranProxyBaseURL(), resolvingAgainstBaseURL: false) else {
            throw QuranSurahAPIError.invalidURL
        }
        components.path += "/surah/\(surahNumber)"
        components.queryItems = [
            URLQueryItem(name: "lang", value: quranContentLanguageCode())
        ]
        guard let url = components.url else {
            throw QuranSurahAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw QuranSurahAPIError.badResponse
        }

        return try JSONDecoder().decode(QuranSurahProxyResponse.self, from: data)
    }
}

enum QuranSurahAPIError: Error {
    case invalidURL
    case badResponse
}

struct QuranSurahProxyResponse: Decodable {
    let number: Int
    let englishName: String
    let arabicName: String
    let ayahs: [QuranSurahProxyAyah]
}

struct QuranSurahIndexItem: Decodable, Identifiable {
    let number: Int
    let englishName: String
    let arabicName: String

    var id: Int { number }
}

struct QuranSurahIndexResponse: Decodable {
    let chapters: [QuranSurahIndexItem]

    var data: [QuranSurahIndexItem] { chapters }
}

enum QuranSurahLocalizedNames {
    static let bahasaMelayu: [String] = [
        "Al-Fatihah", "Al-Baqarah", "Ali 'Imran", "An-Nisa'", "Al-Ma'idah", "Al-An'am", "Al-A'raf", "Al-Anfal", "At-Taubah", "Yunus", "Hud", "Yusuf",
        "Ar-Ra'd", "Ibrahim", "Al-Hijr", "An-Nahl", "Al-Isra'", "Al-Kahfi", "Maryam", "Taha", "Al-Anbiya'", "Al-Hajj", "Al-Mu'minun", "An-Nur",
        "Al-Furqan", "Asy-Syu'ara'", "An-Naml", "Al-Qasas", "Al-'Ankabut", "Ar-Rum", "Luqman", "As-Sajdah", "Al-Ahzab", "Saba'", "Fatir", "Ya Sin",
        "As-Saffat", "Sad", "Az-Zumar", "Ghafir", "Fussilat", "Asy-Syura", "Az-Zukhruf", "Ad-Dukhan", "Al-Jasiyah", "Al-Ahqaf", "Muhammad", "Al-Fath",
        "Al-Hujurat", "Qaf", "Az-Zariyat", "At-Tur", "An-Najm", "Al-Qamar", "Ar-Rahman", "Al-Waqi'ah", "Al-Hadid", "Al-Mujadalah", "Al-Hasyr", "Al-Mumtahanah",
        "As-Saff", "Al-Jumu'ah", "Al-Munafiqun", "At-Taghabun", "At-Talaq", "At-Tahrim", "Al-Mulk", "Al-Qalam", "Al-Haqqah", "Al-Ma'arij", "Nuh", "Al-Jinn",
        "Al-Muzzammil", "Al-Muddassir", "Al-Qiyamah", "Al-Insan", "Al-Mursalat", "An-Naba'", "An-Nazi'at", "'Abasa", "At-Takwir", "Al-Infitar", "Al-Mutaffifin", "Al-Insyiqaq",
        "Al-Buruj", "At-Tariq", "Al-A'la", "Al-Ghasyiyah", "Al-Fajr", "Al-Balad", "Asy-Syams", "Al-Lail", "Ad-Duha", "Asy-Syarh", "At-Tin", "Al-'Alaq",
        "Al-Qadr", "Al-Bayyinah", "Az-Zalzalah", "Al-'Adiyat", "Al-Qari'ah", "At-Takathur", "Al-'Asr", "Al-Humazah", "Al-Fil", "Quraisy", "Al-Ma'un", "Al-Kausar",
        "Al-Kafirun", "An-Nasr", "Al-Masad", "Al-Ikhlas", "Al-Falaq", "An-Nas"
    ]
}

enum QuranSurahIndexAPI {
    static func fetchAll() async throws -> [QuranSurahIndexItem] {
        guard let url = URL(string: "\(quranProxyBaseURL().absoluteString)/chapters") else {
            throw QuranSurahAPIError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw QuranSurahAPIError.badResponse
        }
        let decoded = try JSONDecoder().decode(QuranSurahIndexResponse.self, from: data)
        return decoded.data
    }
}

struct QuranSurahProxyAyah: Decodable {
    let numberInSurah: Int
    let arabicText: String
    let translationText: String?
    let audioURL: String?
    let words: [QuranSurahDetails.Word]?
    let wordTimings: [QuranSurahDetails.WordTiming]?
}

enum QuranSurahVerseCounts {
    private static let counts: [Int] = [
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111,
        43, 52, 99, 128, 111, 110, 98, 135, 112, 78, 118, 64,
        77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83,
        182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29,
        18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
        14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28,
        20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25,
        22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19,
        5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3,
        6, 3, 5, 4, 5, 6
    ]

    static func count(for surahNumber: Int) -> Int? {
        guard (1...counts.count).contains(surahNumber) else { return nil }
        return counts[surahNumber - 1]
    }
}

func preferredQuranArabicFontName(settings: Settings, size: CGFloat) -> String {
    #if os(iOS)
    let candidates = [
        settings.fontArabic,
        "KFGQPCUthmanicScriptHAFS",
        "Uthmani",
        "KFGQPC Uthmanic Script HAFS",
        "UthmanicHafs1 Ver09",
        "AmiriQuran-Regular",
        "Amiri Quran"
    ]
    for name in candidates where !name.isEmpty {
        if UIFont(name: name, size: size) != nil {
            return name
        }
    }
    #endif
    return settings.fontArabic
}

func localizedSurahName(number: Int, englishName: String) -> String {
    guard effectiveQuranContentLanguage() == .bahasaMelayu else { return englishName }
    guard (1...QuranSurahLocalizedNames.bahasaMelayu.count).contains(number) else { return englishName }
    return QuranSurahLocalizedNames.bahasaMelayu[number - 1]
}

enum DailyQuranArabicAPI {
    static func fetchArabicText(reference: String) async throws -> String? {
        guard var components = URLComponents(url: quranProxyBaseURL(), resolvingAgainstBaseURL: false) else {
            throw QuranSurahAPIError.invalidURL
        }
        components.path += "/ayah/\(reference)"
        components.queryItems = [
            URLQueryItem(name: "lang", value: quranContentLanguageCode())
        ]
        guard let url = components.url else {
            throw QuranSurahAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw QuranSurahAPIError.badResponse
        }
        let decoded = try JSONDecoder().decode(DailyQuranArabicPayload.self, from: data)
        return decoded.arabicText?
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

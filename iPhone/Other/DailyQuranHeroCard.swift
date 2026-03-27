import SwiftUI

struct DailyQuranHeroCard: View {
    let quote: LibraryDailyQuranQuote
    let arabicText: String?
    let accentColor: Color
    let arabicFontName: String
    let onOpenVerse: () -> Void
    let onOpenSurah: () -> Void

    private var reflectionSourceLabel: String {
        if isMalayAppLanguage() {
            return "Sumber: Abdullah Basmeih"
        }
        return "Source: Muhammad Asad"
    }

    private var localizedSurahTitle: String {
        let surahNumber = Int(quote.reference.split(separator: ":").first ?? "")
        guard let surahNumber else { return quote.surahName }
        return localizedSurahName(number: surahNumber, englishName: quote.surahName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("بِسْمِ ٱللَّٰهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
                .font(.custom(arabicFontName, size: 18))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(isMalayAppLanguage() ? "Refleksi Harian" : "Daily Reflection")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                SurahReferenceBadge(
                    title: localizedSurahTitle,
                    reference: quote.reference
                )
            }

            VStack(alignment: .center, spacing: 10) {
                if let arabicText, !arabicText.isEmpty {
                    Text(arabicText)
                        .font(.custom(arabicFontName, size: 24))
                        .lineSpacing(6)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(quote.text)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary.opacity(0.82))
                    .frame(maxWidth: 430)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)

                Text(reflectionSourceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 12) {
                Button(action: onOpenVerse) {
                    HStack(spacing: 6) {
                        Text(isMalayAppLanguage() ? "Lihat ayat penuh" : "View full verse")
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onOpenSurah) {
                    HStack(spacing: 6) {
                        Text(isMalayAppLanguage() ? "Teruskan Bacaan" : "Continue Reading")
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(accentColor)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            accentColor.opacity(0.06),
                            Color(.systemGray6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.32), lineWidth: 1)
        }
        .shadow(color: accentColor.opacity(0.12), radius: 22, x: 0, y: 12)
    }
}

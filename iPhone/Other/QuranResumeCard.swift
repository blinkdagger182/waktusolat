import SwiftUI

struct QuranResumeCard: View {
    let surahTitle: String
    let surahNumber: Int
    let ayahNumber: Int?
    let totalAyahCount: Int?
    let accentColor: Color
    let onResume: () -> Void

    private var progressFraction: CGFloat {
        guard let ayahNumber, let totalAyahCount, totalAyahCount > 0 else { return 0 }
        return CGFloat(min(max(ayahNumber, 0), totalAyahCount)) / CGFloat(totalAyahCount)
    }

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 5)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: progressFraction)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 56, height: 56)

                    Text(ayahNumber.map(String.init) ?? "\(surahNumber)")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(isMalayAppLanguage() ? "Sambung Bacaan" : "Continue Reading")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(surahTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let ayahNumber, let totalAyahCount {
                        Text(isMalayAppLanguage() ? "Ayat \(ayahNumber) / \(totalAyahCount)" : "Ayah \(ayahNumber) / \(totalAyahCount)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(accentColor)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(isMalayAppLanguage() ? "Resume" : "Resume")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor)

                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.primary.opacity(0.03), accentColor.opacity(0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

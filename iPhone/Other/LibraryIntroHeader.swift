import SwiftUI

struct LibraryIntroHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isMalayAppLanguage() ? "Pustaka" : "Library")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Image(systemName: "book.pages.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary.opacity(0.85))

                Text(isMalayAppLanguage() ? "Refleksi harian, bacaan Al-Quran, dan sambungan terakhir anda." : "Daily reflection, full Quran reading, and your last progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }
}

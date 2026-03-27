import SwiftUI

struct QuranSurahBrowserView: View {
    @EnvironmentObject private var settings: Settings
    @Binding var selectedSurah: FullSurahSelection?
    @Environment(\.dismiss) private var dismiss
    @State private var surahs: [QuranSurahIndexItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var filteredSurahs: [QuranSurahIndexItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return surahs }
        return surahs.filter {
            "\($0.number)".contains(query)
            || $0.englishName.lowercased().contains(query)
            || $0.arabicName.contains(query)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(isMalayAppLanguage() ? "Memuatkan senarai surah..." : "Loading surah list...")
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                List(filteredSurahs) { surah in
                    Button {
                        selectedSurah = FullSurahSelection(surahNumber: surah.number, ayahNumber: nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(surah.number)")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(surah.englishName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(surah.arabicName)
                                    .font(.custom(preferredQuranArabicFontName(settings: settings, size: 18), size: 18))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .searchable(text: $searchText, prompt: isMalayAppLanguage() ? "Cari surah" : "Search surah")
            }
        }
        .task {
            await loadSurahs()
        }
    }

    @MainActor
    private func loadSurahs() async {
        guard surahs.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            surahs = try await QuranSurahIndexAPI.fetchAll()
        } catch {
            let reason = error.localizedDescription
            if reason.isEmpty || reason == "The operation couldn’t be completed." {
                errorMessage = isMalayAppLanguage()
                    ? "Tidak dapat memuatkan senarai surah sekarang. Sila cuba lagi."
                    : "Unable to load the surah list right now. Please try again."
            } else {
                errorMessage = reason
            }
        }
    }
}

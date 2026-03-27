import SwiftUI

struct QuranSurahExpandableCard: View {
    let surah: QuranSurahIndexItem
    let isExpanded: Bool
    let accentColor: Color
    let progressAyah: Int?
    let totalAyahCount: Int?
    let onToggle: () -> Void
    let onOpen: () -> Void
    let onResume: () -> Void

    private var progressFraction: CGFloat? {
        guard let progressAyah, let totalAyahCount, totalAyahCount > 0 else { return nil }
        let clamped = min(max(progressAyah, 0), totalAyahCount)
        return CGFloat(clamped) / CGFloat(totalAyahCount)
    }

    private var progressText: String? {
        guard let progressAyah else { return nil }
        return isMalayAppLanguage()
            ? "Ayat terakhir: \(progressAyah)"
            : "Last focused ayah: \(progressAyah)"
    }

    private var metadataText: String {
        isMalayAppLanguage()
            ? "Surah \(surah.number)"
            : "Surah \(surah.number)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: 48, height: 48)
                        if let progressFraction {
                            Circle()
                                .trim(from: 0, to: progressFraction)
                                .stroke(
                                    accentColor,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 48, height: 48)
                        }
                        Text("\(surah.number)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizedSurahName(number: surah.number, englishName: surah.englishName))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(surah.arabicName)
                            .font(.custom(preferredQuranArabicFontName(settings: .shared, size: 22), size: 22))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(metadataText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            if let progressText {
                                Text(progressText)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(accentColor)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.trailing, 12)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 10)
                .padding(.vertical, 18)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Text(
                        isMalayAppLanguage()
                            ? "Buka surah penuh, atau sambung dari ayat terakhir yang anda tumpukan."
                            : "Open the full surah, or continue from the last ayah you focused on."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button(action: onOpen) {
                            Text(isMalayAppLanguage() ? "Buka Surah" : "Open Surah")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)

                        if progressAyah != nil {
                            Button(action: onResume) {
                                Text(isMalayAppLanguage() ? "Sambung" : "Resume")
                                    .font(.footnote.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(accentColor.opacity(0.16))
                                    )
                                    .foregroundStyle(accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.leading, 70)
                .padding(.trailing, 12)
                .padding(.bottom, 16)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)).combined(with: .opacity)
                    )
                )
            }

            Divider()
                .padding(.leading, 70)
                .padding(.trailing, 10)
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.46, dampingFraction: 0.9), value: isExpanded)
    }
}

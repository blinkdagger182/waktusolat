import SwiftUI

private enum DailyQuranHeroAnimationStore {
    private static var animatedKeys: Set<String> = []

    static func hasAnimated(_ key: String) -> Bool {
        animatedKeys.contains(key)
    }

    static func markAnimated(_ key: String) {
        animatedKeys.insert(key)
    }
}

struct DailyQuranHeroCard: View {
    let quote: LibraryDailyQuranQuote
    let arabicText: String?
    let shouldAnimateArabic: Bool
    let accentColor: Color
    let arabicFontName: String
    let onOpenVerse: () -> Void
    let onOpenSurah: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var animateThisPresentation = false
    @State private var revealedArabicWordCount = 0
    @State private var highlightedArabicWordIndex: Int?

    init(
        quote: LibraryDailyQuranQuote,
        arabicText: String?,
        shouldAnimateArabic: Bool,
        accentColor: Color,
        arabicFontName: String,
        onOpenVerse: @escaping () -> Void,
        onOpenSurah: @escaping () -> Void
    ) {
        self.quote = quote
        self.arabicText = arabicText
        self.shouldAnimateArabic = shouldAnimateArabic
        self.accentColor = accentColor
        self.arabicFontName = arabicFontName
        self.onOpenVerse = onOpenVerse
        self.onOpenSurah = onOpenSurah

        let initialWords = arabicText?.split(separator: " ").count ?? 0
        let alreadyAnimated = DailyQuranHeroAnimationStore.hasAnimated(quote.reference)
        let shouldStartRevealed = !shouldAnimateArabic || alreadyAnimated
        _animateThisPresentation = State(initialValue: shouldAnimateArabic && !alreadyAnimated)
        _revealedArabicWordCount = State(initialValue: shouldStartRevealed ? initialWords : 0)
        _highlightedArabicWordIndex = State(initialValue: nil)
    }

    private let arabicRevealStepDuration: UInt64 = 230_000_000
    private let arabicHighlightHoldDuration: UInt64 = 160_000_000
    private let arabicRevealAnimationDuration: Double = 0.72

    /// Picks white or black text to contrast against `accentColor` fill,
    /// regardless of color scheme (handles white accent in dark mode, etc.)
    private var buttonTextColor: Color {
        let ui = UIColor(accentColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.55 ? Color.black.opacity(0.82) : Color.white
    }

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

    private var arabicWords: [String] {
        arabicText?.split(separator: " ").map(String.init) ?? []
    }

    private var shouldRenderAnimatedArabic: Bool {
        animateThisPresentation && !DailyQuranHeroAnimationStore.hasAnimated(quote.reference)
    }

    private var revealedArabicView: Text {
        guard !arabicWords.isEmpty else {
            return Text(arabicText ?? "")
        }

        return arabicWords.enumerated().reduce(Text("")) { partial, item in
            let (index, word) = item
            let isRevealed = index < revealedArabicWordCount
            let isHighlighted = highlightedArabicWordIndex == index
            let segment = styledArabicSegment(
                word: word + (index < arabicWords.count - 1 ? " " : ""),
                isRevealed: isRevealed,
                isHighlighted: isHighlighted
            )

            return partial + segment
        }
    }

    private func styledArabicSegment(word: String, isRevealed: Bool, isHighlighted: Bool) -> Text {
        let color: Color
        if !isRevealed {
            color = .primary.opacity(0)
        } else if isHighlighted {
            color = .primary.opacity(0.98)
        } else {
            color = .primary.opacity(0.92)
        }

        if isHighlighted {
            return Text(word)
                .bold()
                .foregroundColor(color)
        }

        return Text(word)
            .foregroundColor(color)
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
                    if shouldRenderAnimatedArabic {
                        ZStack {
                            Text(arabicText)
                                .font(.custom(arabicFontName, size: 24))
                                .lineSpacing(6)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.clear)
                                .frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityHidden(true)

                            revealedArabicView
                                .font(.custom(arabicFontName, size: 24))
                                .lineSpacing(6)
                                .multilineTextAlignment(.center)
                                .shadow(
                                    color: highlightedArabicWordIndex == nil ? .clear : .white.opacity(0.55),
                                    radius: highlightedArabicWordIndex == nil ? 0 : 14
                                )
                                .frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)
                                .animation(.easeOut(duration: arabicRevealAnimationDuration), value: revealedArabicWordCount)
                                .animation(.easeOut(duration: arabicRevealAnimationDuration * 0.75), value: highlightedArabicWordIndex)
                        }
                    } else {
                        Text(arabicText)
                            .font(.custom(arabicFontName, size: 24))
                            .lineSpacing(6)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary.opacity(0.92))
                            .frame(maxWidth: .infinity)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
                    .foregroundStyle(buttonTextColor)
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
        .task(id: "\(quote.reference)|\(arabicText == nil ? "missing-arabic" : "ready")|\(shouldAnimateArabic)") {
            let animationKey = quote.reference
            guard !arabicWords.isEmpty else {
                revealedArabicWordCount = 0
                highlightedArabicWordIndex = nil
                return
            }

            guard shouldRenderAnimatedArabic else {
                revealedArabicWordCount = arabicWords.count
                highlightedArabicWordIndex = nil
                return
            }

            revealedArabicWordCount = 0
            highlightedArabicWordIndex = nil
            for index in 1...arabicWords.count {
                if Task.isCancelled { break }
                highlightedArabicWordIndex = index - 1
                revealedArabicWordCount = index
                try? await Task.sleep(nanoseconds: arabicRevealStepDuration)
            }
            try? await Task.sleep(nanoseconds: arabicHighlightHoldDuration)
            highlightedArabicWordIndex = nil
            DailyQuranHeroAnimationStore.markAnimated(animationKey)
        }
    }
}

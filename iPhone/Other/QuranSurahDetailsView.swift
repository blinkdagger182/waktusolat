import SwiftUI
import AVFoundation
#if os(iOS)
import UIKit
#endif

struct QuranSurahDetailsView: View {
    let surahNumber: Int
    let initialAyahNumber: Int?
    let dailyAyahNumber: Int?

    @EnvironmentObject private var settings: Settings
    @State private var details: QuranSurahDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pendingRestoreAyah: Int?
    @State private var didRestorePosition = false
    @State private var lastSavedAyah: Int?
    @State private var recitationPlayer: AVQueuePlayer?
    @State private var isRecitationLoading = false
    @State private var isReciting = false
    @State private var recitationErrorMessage: String?
    @State private var recitationEndObserver: NSObjectProtocol?
    @State private var currentPlaybackAyah: Int?
    @State private var currentPlaybackWordPosition: Int?
    @State private var playbackAyahSequence: [Int] = []
    @State private var playbackSequenceIndex = 0
    @State private var playbackTimeObserver: Any?

    private var quranArabicFontName: String {
        let candidates = [
            settings.fontArabic,
            "KFGQPCUthmanicScriptHAFS",
            "Uthmani",
            "KFGQPC Uthmanic Script HAFS",
            "UthmanicHafs1 Ver09",
            "AmiriQuran-Regular",
            "Amiri Quran"
        ]
        #if os(iOS)
        for name in candidates where !name.isEmpty {
            if UIFont(name: name, size: 28) != nil {
                return name
            }
        }
        #endif
        return settings.fontArabic
    }

    private var dailyAyahTagTextColor: Color {
        #if os(iOS)
        let ui = UIColor(settings.accentColor.color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .white
        }
        let luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
        return luminance > 0.62 ? .black : .white
        #else
        return .white
        #endif
    }

    var body: some View {
        content(surahNumber: surahNumber)
            .task(id: surahNumber) {
                await loadSurah(surahNumber: surahNumber)
            }
            .onDisappear {
                stopRecitation()
            }
            .safeAreaInset(edge: .bottom) {
                if let details, currentPlaybackAyah != nil || recitationPlayer != nil || isRecitationLoading {
                    QuranRecitationControlBar(
                        surahTitle: localizedSurahName(number: details.number, englishName: details.englishName),
                        ayahNumber: currentPlaybackAyah,
                        isReciting: isReciting,
                        isLoading: isRecitationLoading,
                        accentColor: settings.accentColor.color,
                        canGoBackward: canGoBackward,
                        canGoForward: canGoForward,
                        onPrevious: playPreviousAyah,
                        onPlayPause: toggleRecitation,
                        onNext: playNextAyah
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .background(.thinMaterial)
                }
            }
    }

    private var canGoBackward: Bool {
        guard let currentPlaybackAyah else { return false }
        return currentPlaybackAyah > 1
    }

    private var canGoForward: Bool {
        guard let details, let currentPlaybackAyah else { return false }
        return currentPlaybackAyah < details.ayahs.count
    }

    private func content(surahNumber: Int) -> some View {
        Group {
            if isLoading {
                ProgressView(isMalayAppLanguage()
                             ? "Memuatkan Surah \(surahNumber)..."
                             : "Loading Surah \(surahNumber)...")
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
            } else if let details {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            Text("\(localizedSurahName(number: details.number, englishName: details.englishName)) (\(details.arabicName))")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(isMalayAppLanguage()
                                 ? "Surah \(details.number) • \(details.ayahs.count) ayat"
                                 : "Surah \(details.number) • \(details.ayahs.count) ayahs")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Button(action: toggleRecitation) {
                                    HStack(spacing: 8) {
                                        Image(systemName: isRecitationLoading ? "hourglass" : (isReciting ? "pause.fill" : "play.fill"))
                                        Text(isRecitationLoading
                                             ? (isMalayAppLanguage() ? "Memuatkan bacaan..." : "Loading recitation...")
                                             : (isReciting
                                                ? (isMalayAppLanguage() ? "Jeda Bacaan" : "Pause Recitation")
                                                : (isMalayAppLanguage() ? "Mainkan Bacaan" : "Play Recitation")))
                                    }
                                    .font(.footnote.weight(.semibold))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.primary.opacity(0.08))
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isRecitationLoading || details.ayahs.allSatisfy { $0.audioURL == nil })

                                if let recitationErrorMessage {
                                    Text(recitationErrorMessage)
                                        .font(.caption2)
                                        .foregroundStyle(.red.opacity(0.9))
                                        .lineLimit(2)
                                }
                            }

                            Divider()

                            ForEach(details.ayahs) { ayah in
                                let isDailyAyah = dailyAyahNumber == ayah.numberInSurah
                                let isActiveAyah = currentPlaybackAyah == ayah.numberInSurah
                                let isPlayingAyah = isActiveAyah && isReciting
                                let isCompletedAyah = currentPlaybackAyah.map { ayah.numberInSurah < $0 } ?? false
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text("\(ayah.numberInSurah)")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle((isActiveAyah || isCompletedAyah) ? settings.accentColor.color : .secondary)

                                        if isPlayingAyah {
                                            Text(isMalayAppLanguage() ? "Sedang dimainkan" : "Now playing")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(settings.accentColor.color)
                                        } else if isActiveAyah {
                                            Text(isMalayAppLanguage() ? "Dijeda" : "Paused")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(settings.accentColor.color)
                                        }
                                    }

                                    InteractiveArabicAyahTextView(
                                        words: ayah.words,
                                        fallbackText: ayah.arabicText,
                                        highlightedWordPosition: isActiveAyah
                                            ? currentPlaybackWordPosition
                                            : (isCompletedAyah ? (ayah.words.last?.position ?? Int.max) : nil),
                                        fontName: quranArabicFontName,
                                        fontSize: 30,
                                        accentColor: settings.accentColor.color,
                                        fullyHighlighted: isCompletedAyah,
                                        onTapWord: { wordPosition in
                                            playRecitation(fromAyah: ayah.numberInSurah, startingWordPosition: wordPosition)
                                        }
                                    )
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                    if let translation = ayah.translationText, !translation.isEmpty {
                                        Text(translation)
                                            .font(.subheadline)
                                            .foregroundStyle((isActiveAyah || isCompletedAyah) ? settings.accentColor.color : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            isActiveAyah
                                                ? settings.accentColor.color.opacity(0.12)
                                                : (isCompletedAyah
                                                    ? settings.accentColor.color.opacity(0.06)
                                                    : Color.primary.opacity(0.04))
                                        )
                                )
                                .overlay {
                                    if isActiveAyah {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(settings.accentColor.color, lineWidth: 2)
                                    } else if isCompletedAyah {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(settings.accentColor.color.opacity(0.35), lineWidth: 1)
                                    } else if isDailyAyah {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(settings.accentColor.color, lineWidth: 2)
                                    }
                                }
                                .overlay(alignment: .topLeading) {
                                    if isDailyAyah {
                                        Text(isMalayAppLanguage() ? "Ayat Harian" : "Daily Ayat")
                                            .font(.caption2.weight(.bold))
                                            .foregroundColor(dailyAyahTagTextColor)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(settings.accentColor.color)
                                            )
                                            .padding(.leading, 10)
                                            .offset(y: -10)
                                    }
                                }
                                .id(ayah.numberInSurah)
                                .onTapGesture {
                                    playRecitation(fromAyah: ayah.numberInSurah)
                                }
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: AyahMinYPreferenceKey.self,
                                            value: [ayah.numberInSurah: geo.frame(in: .named("surahScrollView")).minY]
                                        )
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    .coordinateSpace(name: "surahScrollView")
                    .onAppear {
                        guard !didRestorePosition else { return }
                        let target = pendingRestoreAyah ?? initialAyahNumber ?? dailyAyahNumber
                        guard let target else {
                            didRestorePosition = true
                            return
                        }
                        DispatchQueue.main.async {
                            proxy.scrollTo(target, anchor: .top)
                            didRestorePosition = true
                        }
                    }
                    .onChange(of: currentPlaybackAyah) { ayah in
                        guard let ayah else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(ayah, anchor: .center)
                        }
                    }
                    .onPreferenceChange(AyahMinYPreferenceKey.self) { positions in
                        guard didRestorePosition, !positions.isEmpty else { return }
                        let topBoundary: CGFloat = 0
                        let atOrAboveTop = positions.filter { $0.value <= topBoundary + 1 }
                        let trackedAyah: Int?
                        if let crossingTop = atOrAboveTop.max(by: { $0.value < $1.value }) {
                            trackedAyah = crossingTop.key
                        } else {
                            trackedAyah = positions.min(by: { $0.value < $1.value })?.key
                        }
                        guard let trackedAyah else { return }
                        guard trackedAyah != lastSavedAyah else { return }
                        lastSavedAyah = trackedAyah
                        saveLastReadAyah(trackedAyah, for: surahNumber)
                        saveViewedResumeSelection(surahNumber: surahNumber, ayahNumber: trackedAyah)
                    }
                }
            } else {
                Text(isMalayAppLanguage()
                     ? "Memuatkan Surah \(surahNumber)..."
                     : "Loading Surah \(surahNumber)...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    @MainActor
    private func loadSurah(surahNumber: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        pendingRestoreAyah = initialAyahNumber ?? loadLastReadAyah(for: surahNumber)
        didRestorePosition = false
        lastSavedAyah = pendingRestoreAyah
        saveViewedResumeSelection(surahNumber: surahNumber, ayahNumber: pendingRestoreAyah ?? dailyAyahNumber)

        do {
            details = try await QuranSurahAPI.fetchSurahDetails(surahNumber: surahNumber)
            let focusedAyah = pendingRestoreAyah ?? initialAyahNumber ?? dailyAyahNumber
            currentPlaybackAyah = focusedAyah
            if let focusedAyah,
               let focusedAyahDetails = details?.ayahs.first(where: { $0.numberInSurah == focusedAyah }) {
                currentPlaybackWordPosition = focusedAyahDetails.words.first?.position
            } else {
                currentPlaybackWordPosition = nil
            }
        } catch {
            details = nil
            let reason = error.localizedDescription
            if reason.isEmpty || reason == "The operation couldn’t be completed." {
                errorMessage = isMalayAppLanguage()
                    ? "Tidak dapat memuatkan surah ini sekarang. Sila cuba lagi."
                    : "Unable to load this surah right now. Please try again."
            } else {
                errorMessage = isMalayAppLanguage()
                    ? "Tidak dapat memuatkan surah ini sekarang. \(reason)"
                    : "Unable to load this surah right now. \(reason)"
            }
        }
    }

    @MainActor
    private func toggleRecitation() {
        recitationErrorMessage = nil

        if let player = recitationPlayer {
            if isReciting {
                player.pause()
                isReciting = false
            } else {
                player.play()
                isReciting = true
            }
            return
        }

        let startingAyah = currentPlaybackAyah ?? pendingRestoreAyah ?? initialAyahNumber ?? dailyAyahNumber ?? 1
        playRecitation(fromAyah: startingAyah)
    }

    @MainActor
    private func playRecitation(fromAyah ayahNumber: Int, startingWordPosition: Int? = nil) {
        recitationErrorMessage = nil
        guard let details else { return }
        let validAyah = min(max(ayahNumber, 1), details.ayahs.count)
        let startingAyahDetails = details.ayahs.first(where: { $0.numberInSurah == validAyah })
        let slice = details.ayahs.filter { $0.numberInSurah >= validAyah }
        let itemsWithAyah = slice.compactMap { ayah -> (Int, AVPlayerItem)? in
            guard let audioURL = ayah.audioURL, let url = URL(string: audioURL) else { return nil }
            return (ayah.numberInSurah, AVPlayerItem(url: url))
        }

        guard itemsWithAyah.isEmpty == false else {
            recitationErrorMessage = isMalayAppLanguage()
                ? "Bacaan belum tersedia untuk ayat ini."
                : "Recitation is not available for this ayah yet."
            return
        }

        isRecitationLoading = true
        stopRecitation()

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            recitationErrorMessage = isMalayAppLanguage() ? "Sesi audio gagal." : "Audio session failed."
        }
        #endif

        let resolvedStartingWordPosition = resolvedWordPosition(
            requested: startingWordPosition,
            in: startingAyahDetails
        )

        playbackAyahSequence = itemsWithAyah.map(\.0)
        playbackSequenceIndex = 0
        currentPlaybackAyah = playbackAyahSequence.first
        currentPlaybackWordPosition = resolvedStartingWordPosition ?? startingAyahDetails?.words.first?.position
        saveViewedResumeSelection(surahNumber: surahNumber, ayahNumber: validAyah)
        savePlayedResumeSelection(surahNumber: surahNumber, ayahNumber: validAyah)

        let player = AVQueuePlayer(items: itemsWithAyah.map(\.1))
        recitationPlayer = player
        playbackTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { time in
            updateCurrentPlaybackWord(for: time)
        }
        recitationEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { _ in
            if playbackSequenceIndex + 1 < playbackAyahSequence.count {
                playbackSequenceIndex += 1
                let nextAyah = playbackAyahSequence[playbackSequenceIndex]
                currentPlaybackAyah = nextAyah
                let nextAyahDetails = details.ayahs.first(where: { $0.numberInSurah == nextAyah })
                currentPlaybackWordPosition = nextAyahDetails?.words.first?.position
                saveViewedResumeSelection(surahNumber: surahNumber, ayahNumber: nextAyah)
                savePlayedResumeSelection(surahNumber: surahNumber, ayahNumber: nextAyah)
            } else {
                isReciting = false
            }
        }
        player.play()
        if let startMs = wordStartMs(for: startingAyahDetails, wordPosition: resolvedStartingWordPosition) {
            player.seek(to: CMTime(value: CMTimeValue(startMs), timescale: 1000))
        }
        isRecitationLoading = false
        isReciting = true
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    @MainActor
    private func stopRecitation() {
        if let playbackTimeObserver, let recitationPlayer {
            recitationPlayer.removeTimeObserver(playbackTimeObserver)
            self.playbackTimeObserver = nil
        }
        recitationPlayer?.pause()
        recitationPlayer?.removeAllItems()
        recitationPlayer = nil
        isReciting = false
        isRecitationLoading = false
        playbackAyahSequence = []
        playbackSequenceIndex = 0
        currentPlaybackAyah = nil
        currentPlaybackWordPosition = nil
        if let recitationEndObserver {
            NotificationCenter.default.removeObserver(recitationEndObserver)
            self.recitationEndObserver = nil
        }
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
    }

    @MainActor
    private func playPreviousAyah() {
        guard let currentPlaybackAyah else { return }
        playRecitation(fromAyah: max(currentPlaybackAyah - 1, 1))
    }

    @MainActor
    private func playNextAyah() {
        guard let details else { return }
        let current = currentPlaybackAyah ?? 1
        playRecitation(fromAyah: min(current + 1, details.ayahs.count))
    }

    private func storageKey(for surahNumber: Int) -> String {
        "fullSurahLastReadAyahV1.\(surahNumber)"
    }

    private func loadLastReadAyah(for surahNumber: Int) -> Int? {
        let ayah = UserDefaults.standard.integer(forKey: storageKey(for: surahNumber))
        return ayah > 0 ? ayah : nil
    }

    private func saveLastReadAyah(_ ayahNumber: Int, for surahNumber: Int) {
        guard ayahNumber > 0 else { return }
        UserDefaults.standard.set(ayahNumber, forKey: storageKey(for: surahNumber))
    }

    private func saveViewedResumeSelection(surahNumber: Int, ayahNumber: Int?) {
        let defaults = UserDefaults.standard
        defaults.set(surahNumber, forKey: FullQuranResumeStorage.lastSurahKey)
        if let ayahNumber, ayahNumber > 0 {
            defaults.set(ayahNumber, forKey: FullQuranResumeStorage.lastAyahKey)
        }
    }

    private func savePlayedResumeSelection(surahNumber: Int, ayahNumber: Int?) {
        let defaults = UserDefaults.standard
        defaults.set(surahNumber, forKey: FullQuranResumeStorage.lastPlayedSurahKey)
        if let ayahNumber, ayahNumber > 0 {
            defaults.set(ayahNumber, forKey: FullQuranResumeStorage.lastPlayedAyahKey)
        }
    }

    private func wordStartMs(for ayah: QuranSurahDetails.Ayah?, wordPosition: Int?) -> Int? {
        guard let ayah, let wordPosition else { return nil }
        return ayah.wordTimings.first(where: { $0.wordPosition == wordPosition })?.startMs
    }

    private func resolvedWordPosition(requested: Int?, in ayah: QuranSurahDetails.Ayah?) -> Int? {
        guard let requested, let ayah else { return requested }
        if ayah.wordTimings.contains(where: { $0.wordPosition == requested }) {
            return requested
        }
        if let nextAvailable = ayah.wordTimings.first(where: { $0.wordPosition >= requested }) {
            return nextAvailable.wordPosition
        }
        return ayah.wordTimings.last?.wordPosition ?? requested
    }

    private func updateCurrentPlaybackWord(for time: CMTime) {
        guard
            let details,
            let currentPlaybackAyah,
            let ayah = details.ayahs.first(where: { $0.numberInSurah == currentPlaybackAyah }),
            !ayah.wordTimings.isEmpty
        else {
            return
        }

        let currentMs = max(0, Int((time.seconds * 1000).rounded()))
        if let activeTiming = ayah.wordTimings.first(where: { currentMs >= $0.startMs && currentMs <= $0.endMs }) {
            currentPlaybackWordPosition = activeTiming.wordPosition
            return
        }

        if let upcomingTiming = ayah.wordTimings.first(where: { currentMs < $0.startMs }) {
            currentPlaybackWordPosition = upcomingTiming.wordPosition
            return
        }

        currentPlaybackWordPosition = ayah.wordTimings.last?.wordPosition
    }
}

private struct AyahMinYPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

#if os(iOS)
private struct InteractiveArabicAyahTextView: UIViewRepresentable {
    let words: [QuranSurahDetails.Word]
    let fallbackText: String
    let highlightedWordPosition: Int?
    let fontName: String
    let fontSize: CGFloat
    let accentColor: Color
    let fullyHighlighted: Bool
    let onTapWord: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapWord: onTapWord)
    }

    func makeUIView(context: Context) -> InteractiveArabicTextView {
        let view = InteractiveArabicTextView()
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = false
        view.isScrollEnabled = false
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.maximumNumberOfLines = 0
        view.textContainer.lineBreakMode = .byWordWrapping
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.delegateProxy = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.textView = view
        return view
    }

    func updateUIView(_ uiView: InteractiveArabicTextView, context: Context) {
        context.coordinator.onTapWord = onTapWord
        context.coordinator.textView = uiView
        uiView.configure(
            words: words,
            fallbackText: fallbackText,
            highlightedWordPosition: highlightedWordPosition,
            fontName: fontName,
            fontSize: fontSize,
            accentColor: UIColor(accentColor),
            fullyHighlighted: fullyHighlighted
        )
    }

    final class Coordinator: NSObject {
        var onTapWord: (Int) -> Void
        weak var textView: InteractiveArabicTextView?

        init(onTapWord: @escaping (Int) -> Void) {
            self.onTapWord = onTapWord
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView else { return }
            let point = gesture.location(in: textView)
            if let wordPosition = textView.wordPosition(at: point) {
                onTapWord(wordPosition)
            }
        }
    }
}

private final class InteractiveArabicTextView: UITextView {
    weak var delegateProxy: InteractiveArabicAyahTextView.Coordinator?
    private let wordPositionAttribute = NSAttributedString.Key("waktuWordPosition")

    override var intrinsicContentSize: CGSize {
        let fitting = sizeThatFits(CGSize(width: bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 64, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: fitting.height)
    }

    func configure(
        words: [QuranSurahDetails.Word],
        fallbackText: String,
        highlightedWordPosition: Int?,
        fontName: String,
        fontSize: CGFloat,
        accentColor: UIColor,
        fullyHighlighted: Bool
    ) {
        let attributed = NSMutableAttributedString()
        let textColor = UIColor.label
        let baseFont = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)

        if words.isEmpty {
            attributed.append(NSAttributedString(string: fallbackText, attributes: [
                .font: baseFont,
                .foregroundColor: fullyHighlighted ? accentColor : textColor,
            ]))
        } else {
            for (index, word) in words.enumerated() {
                if index > 0 {
                    attributed.append(NSAttributedString(string: " ", attributes: [
                        .font: baseFont,
                        .foregroundColor: textColor,
                    ]))
                }

                var attrs: [NSAttributedString.Key: Any] = [
                    .font: baseFont,
                    .foregroundColor: textColor,
                    wordPositionAttribute: word.position,
                ]

                if let highlightedWordPosition, word.position <= highlightedWordPosition {
                    attrs[.foregroundColor] = accentColor
                }

                attributed.append(NSAttributedString(string: word.textArabic, attributes: attrs))
            }
        }

        attributedText = attributed
        textAlignment = .right
        semanticContentAttribute = .forceRightToLeft
        typingAttributes = [
            .font: baseFont,
            .foregroundColor: textColor,
        ]

        DispatchQueue.main.async {
            self.invalidateIntrinsicContentSize()
            self.superview?.invalidateIntrinsicContentSize()
        }
    }

    func wordPosition(at point: CGPoint) -> Int? {
        let adjustedPoint = CGPoint(
            x: point.x - textContainerInset.left,
            y: point.y - textContainerInset.top
        )

        let directIndex = layoutManager.characterIndex(
            for: adjustedPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        if directIndex < textStorage.length,
           let directHit = textStorage.attribute(wordPositionAttribute, at: directIndex, effectiveRange: nil) as? Int {
            return directHit
        }

        var bestMatch: (position: Int, distance: CGFloat)?

        textStorage.enumerateAttribute(wordPositionAttribute, in: NSRange(location: 0, length: textStorage.length)) { value, range, _ in
            guard let position = value as? Int else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            layoutManager.enumerateEnclosingRects(
                forGlyphRange: glyphRange,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: textContainer
            ) { rect, _ in
                let expanded = rect.insetBy(dx: -8, dy: -6)
                if expanded.contains(adjustedPoint) {
                    bestMatch = (position, 0)
                    return
                }

                let clampedX = min(max(adjustedPoint.x, expanded.minX), expanded.maxX)
                let clampedY = min(max(adjustedPoint.y, expanded.minY), expanded.maxY)
                let dx = adjustedPoint.x - clampedX
                let dy = adjustedPoint.y - clampedY
                let distance = sqrt((dx * dx) + (dy * dy))

                guard bestMatch == nil || distance < bestMatch!.distance else { return }
                bestMatch = (position, distance)
            }
        }

        guard let bestMatch else { return nil }
        return bestMatch.position
    }
}
#else
private struct InteractiveArabicAyahTextView: View {
    let words: [QuranSurahDetails.Word]
    let fallbackText: String
    let highlightedWordPosition: Int?
    let fontName: String
    let fontSize: CGFloat
    let accentColor: Color
    let fullyHighlighted: Bool
    let onTapWord: (Int) -> Void

    var body: some View {
        Text(fallbackText)
            .font(.custom(fontName, size: fontSize))
            .foregroundStyle(fullyHighlighted ? accentColor : .primary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
    }
}
#endif

private struct QuranRecitationControlBar: View {
    let surahTitle: String
    let ayahNumber: Int?
    let isReciting: Bool
    let isLoading: Bool
    let accentColor: Color
    let canGoBackward: Bool
    let canGoForward: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    private var subtitleText: String {
        if isLoading {
            return isMalayAppLanguage() ? "Memuatkan bacaan..." : "Loading recitation..."
        }
        if let ayahNumber {
            return isMalayAppLanguage() ? "Ayat \(ayahNumber)" : "Ayah \(ayahNumber)"
        }
        return isMalayAppLanguage() ? "Sedia untuk dimainkan" : "Ready to play"
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(surahTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(subtitleText)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isLoading || !canGoBackward)
                .foregroundStyle(canGoBackward ? Color.primary : Color.secondary.opacity(0.45))

                Button(action: onPlayPause) {
                    ZStack {
                        Circle()
                            .fill(accentColor)
                        Image(systemName: isLoading ? "hourglass" : (isReciting ? "pause.fill" : "play.fill"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .accessibilityLabel(isReciting
                    ? (isMalayAppLanguage() ? "Jeda bacaan" : "Pause recitation")
                    : (isMalayAppLanguage() ? "Mainkan bacaan" : "Play recitation"))

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isLoading || !canGoForward)
                .foregroundStyle(canGoForward ? Color.primary : Color.secondary.opacity(0.45))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

import SwiftUI
import AVFoundation
import UIKit
import WidgetKit

private enum ForYouPalette {
    static let canvas    = Color(uiColor: .systemGroupedBackground)
    static let card      = Color(uiColor: .secondarySystemBackground).opacity(0.82)
    static let softCard  = Color(uiColor: .secondarySystemGroupedBackground)
    static let stroke    = Color.primary.opacity(0.08)
    static let ink       = Color.primary
    static let secondaryInk = Color.secondary
    static let timePillFill = Color(uiColor: .systemBackground)
    static let recommendationFill = Color(uiColor: .tertiarySystemBackground)
    static let accentSky = Color(red: 0.61, green: 0.83, blue: 0.93)
    static let darkTile  = Color(red: 0.23, green: 0.26, blue: 0.30)
    // Prayer tab strip colors
    static let tabWirid = Color(red: 0x91/255, green: 0xcd/255, blue: 0xe1/255)
    static let tabDoa   = Color(red: 0x00/255, green: 0x35/255, blue: 0x66/255)
    static let tabExtra = Color(red: 0xf7/255, green: 0x45/255, blue: 0x4d/255)
}

private enum ForYouFormatters {
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = appLocale()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let year: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = appLocale()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = appLocale()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = appLocale()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private enum ForYouTypography {
    static func playfairHeadline(size: CGFloat) -> Font {
        if UIFont(name: "PlayfairDisplay-Regular", size: size) != nil {
            return .custom("PlayfairDisplay-Regular", size: size)
        }
        if UIFont(name: "Playfair Display", size: size) != nil {
            return .custom("Playfair Display", size: size)
        }
        return .system(size: size, weight: .medium, design: .serif)
    }
}

private extension ForYouMomentType {
    var displayTitle: String {
        switch self {
        case .morning: return isMalayAppLanguage() ? "Pagi" : "Morning"
        case .dhuha: return "Dhuha"
        case .evening: return isMalayAppLanguage() ? "Petang" : "Evening"
        case .night: return isMalayAppLanguage() ? "Malam" : "Night"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise"
        case .dhuha: return "sun.max"
        case .evening: return "sunset"
        case .night: return "moon.stars.fill"
        }
    }

    var tint: Color {
        switch self {
        case .morning:
            return Color(red: 0.92, green: 0.82, blue: 0.61)
        case .dhuha:
            return Color(red: 0.99, green: 0.80, blue: 0.52)
        case .evening:
            return Color(red: 0.88, green: 0.74, blue: 0.62)
        case .night:
            return Color(red: 0.70, green: 0.73, blue: 0.84)
        }
    }
}

private extension ForYouTimelineEntryKind {
    var displayTitle: String {
        switch self {
        case .prayer:
            return isMalayAppLanguage() ? "Peringatan" : "Reminder"
        case .zikir:
            return "Zikir"
        }
    }
}

private struct ForYouOnboardingView: View {
    let initialProfile: ForYouUserProfile
    let onSave: (ForYouUserProfile) -> Void

    @EnvironmentObject private var settings: Settings
    @Environment(\.dismiss) private var dismiss

    @State private var consistencyLevel: ForYouConsistencyLevel
    @State private var primaryGoal: ForYouPrimaryGoal
    @State private var reminderStyle: ForYouReminderStyle

    init(initialProfile: ForYouUserProfile, onSave: @escaping (ForYouUserProfile) -> Void) {
        self.initialProfile = initialProfile
        self.onSave = onSave
        _consistencyLevel = State(initialValue: initialProfile.consistencyLevel ?? .beginner)
        _primaryGoal = State(initialValue: initialProfile.primaryGoal ?? .preserveFajr)
        _reminderStyle = State(initialValue: initialProfile.reminderStyle ?? .gentle)
    }

    var body: some View {
        NavigationView {
            ZStack {
                ForYouPalette.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isMalayAppLanguage() ? "Bina rentak harian kamu" : "Shape your daily rhythm")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(ForYouPalette.ink)
                            Text(isMalayAppLanguage() ? "Tiga pilihan ringkas supaya For You terasa lembut, bukan berat." : "Three quick choices so For You feels guided, not crowded.")
                                .font(.subheadline)
                                .foregroundStyle(ForYouPalette.secondaryInk)
                        }

                        onboardingSection(
                            title: isMalayAppLanguage() ? "Tahap semasa" : "Current pace",
                            options: ForYouConsistencyLevel.allCases,
                            selection: $consistencyLevel
                        ) { option in
                            switch option {
                            case .beginner: return isMalayAppLanguage() ? "Baru membina ritma" : "Just building rhythm"
                            case .building: return isMalayAppLanguage() ? "Sudah ada asas" : "Some consistency already"
                            case .steady: return isMalayAppLanguage() ? "Mahukan struktur yang lebih dalam" : "Ready for deeper structure"
                            }
                        }

                        onboardingSection(
                            title: isMalayAppLanguage() ? "Fokus utama" : "Main focus",
                            options: ForYouPrimaryGoal.allCases,
                            selection: $primaryGoal
                        ) { option in
                            switch option {
                            case .preserveFajr: return isMalayAppLanguage() ? "Jaga ritma selepas Subuh" : "Protect the post-Fajr rhythm"
                            case .addDhuha: return isMalayAppLanguage() ? "Mulakan Dhuha dengan lembut" : "Gently add Dhuha"
                            case .dailyQuran: return isMalayAppLanguage() ? "Sentuh al-Quran setiap hari" : "Touch the Quran daily"
                            case .consistentDhikr: return isMalayAppLanguage() ? "Kekalkan zikir yang ringan" : "Keep light daily dhikr"
                            }
                        }

                        onboardingSection(
                            title: isMalayAppLanguage() ? "Nada peringatan" : "Reminder tone",
                            options: ForYouReminderStyle.allCases,
                            selection: $reminderStyle
                        ) { option in
                            switch option {
                            case .gentle: return isMalayAppLanguage() ? "Lembut dan menenangkan" : "Soft and reassuring"
                            case .balanced: return isMalayAppLanguage() ? "Seimbang dan jelas" : "Balanced and clear"
                            case .focused: return isMalayAppLanguage() ? "Terus dan terarah" : "More focused"
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isMalayAppLanguage() ? "Simpan" : "Save") {
                        var profile = initialProfile
                        profile.consistencyLevel = consistencyLevel
                        profile.primaryGoal = primaryGoal
                        profile.reminderStyle = reminderStyle
                        onSave(profile)
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .preferredColorScheme(.light)
        .environmentObject(settings)
    }

    private func onboardingSection<Option: Hashable & Identifiable>(
        title: String,
        options: [Option],
        selection: Binding<Option>,
        description: @escaping (Option) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(ForYouPalette.ink)

            ForEach(options, id: \.id) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .strokeBorder(ForYouPalette.stroke.opacity(selection.wrappedValue.id == option.id ? 0 : 1), lineWidth: 1)
                            .background(
                                Circle()
                                    .fill(selection.wrappedValue.id == option.id ? settings.accentColor.color : .clear)
                            )
                            .frame(width: 18, height: 18)

                        Text(description(option))
                            .font(.subheadline)
                            .foregroundStyle(ForYouPalette.ink)

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(ForYouPalette.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(selection.wrappedValue.id == option.id ? settings.accentColor.color.opacity(0.55) : ForYouPalette.stroke, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ForYouDaySegmentView: View {
    let segment: ForYouDaySegment
    let isCompleted: Bool
    let onToggleCompletion: () -> Void

    @EnvironmentObject private var settings: Settings

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(startTimeText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(ForYouPalette.stroke, lineWidth: 1)
                            )
                    )

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(ForYouPalette.stroke)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 8)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(segment.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(ForYouPalette.ink)

                    Spacer(minLength: 8)

                    Text(segment.type.displayTitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)
                }

                Text(segment.shortDescription)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)
                    .lineLimit(2)

                if let arabicText = segment.arabicText {
                    Text(arabicText)
                        .font(.custom(preferredQuranArabicFontName(settings: settings, size: 20), size: 20))
                        .foregroundStyle(ForYouPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineSpacing(4)
                        .minimumScaleFactor(0.8)
                }

                HStack(alignment: .center, spacing: 8) {
                    if let contentReference = segment.contentReference {
                        Text(contentReference)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(ForYouPalette.secondaryInk)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    if segment.ctaType == .markDone {
                        Button {
                            onToggleCompletion()
                        } label: {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(isCompleted ? settings.accentColor.color : ForYouPalette.secondaryInk)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ForYouPalette.softCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ForYouPalette.stroke, lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var startTimeText: String {
        ForYouFormatters.shortTime.string(from: segment.startWindow)
    }
}

private struct ForYouMiniProgressTracker: View {
    struct Descriptor {
        let title: String
        let compactLabel: String?
        let maximumCount: Int
        let requiresLongPress: Bool
        let rowLabels: [String]
        let rowTargets: [Int]
        let holdDuration: Double
    }

    let descriptor: Descriptor
    let rowCounts: [Int]
    let activeHoldIndex: Int?
    let holdProgress: CGFloat
    let burstIndex: Int?
    let onTapStep: ((Int) -> Void)?
    let onPressingChanged: (Bool, Int) -> Void
    let onTriggered: (Int) -> Void

    private let tint = Color(red: 0.24, green: 0.67, blue: 0.45)
    private let track = Color(red: 0.24, green: 0.67, blue: 0.45).opacity(0.14)

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<descriptor.maximumCount, id: \.self) { index in
                trackerCell(index: index)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    private func trackerCell(index: Int) -> some View {
        let rowTarget = descriptor.rowTargets.indices.contains(index) ? descriptor.rowTargets[index] : 1
        let currentCount = rowCounts.indices.contains(index) ? rowCounts[index] : 0
        let isCompleted = currentCount >= rowTarget
        let isHolding = activeHoldIndex == index && !isCompleted
        let symbol = descriptor.maximumCount == 1 ? "moon.zzz.fill" : "sparkles"
        let rowLabel = descriptor.rowLabels.indices.contains(index) ? descriptor.rowLabels[index] : descriptor.title

        VStack(alignment: .leading, spacing: descriptor.requiresLongPress ? 0 : 6) {
            if descriptor.requiresLongPress {
                HStack(spacing: 8) {
                    Text(rowLabel)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(trackerRowTextColor(isCompleted: isCompleted, isHolding: isHolding))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isCompleted ? tint : .white)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(isCompleted ? tint.opacity(0.18) : tint)
                        )
                        .overlay(
                            ZStack {
                                if burstIndex == index {
                                    Circle()
                                        .stroke(tint.opacity(0.35), lineWidth: 1.5)
                                        .scaleEffect(1.6)
                                        .opacity(0)
                                        .animation(.easeOut(duration: 0.35), value: burstIndex)
                                    Circle()
                                        .fill(tint.opacity(0.16))
                                        .scaleEffect(1.9)
                                        .opacity(0)
                                        .animation(.easeOut(duration: 0.35), value: burstIndex)
                                }
                            }
                        )
                        .scaleEffect(isHolding ? 1.08 : 1)
                }
            } else {
                Text(rowLabel)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(trackerRowTextColor(isCompleted: isCompleted, isHolding: isHolding))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(track)

                        Capsule(style: .continuous)
                            .fill(tint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .mask(
                                GeometryReader { geometry in
                                    Rectangle()
                                        .frame(width: geometry.size.width * fillFraction(for: index), alignment: .leading)
                                }
                            )
                    }
                    .frame(height: 8)

                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isCompleted ? tint : .white)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(isCompleted ? tint.opacity(0.18) : tint)
                        )
                        .overlay(
                            ZStack {
                                if burstIndex == index {
                                    Circle()
                                        .stroke(tint.opacity(0.35), lineWidth: 1.5)
                                        .scaleEffect(1.6)
                                        .opacity(0)
                                        .animation(.easeOut(duration: 0.35), value: burstIndex)
                                    Circle()
                                        .fill(tint.opacity(0.16))
                                        .scaleEffect(1.9)
                                        .opacity(0)
                                        .animation(.easeOut(duration: 0.35), value: burstIndex)
                                }
                            }
                        )
                        .scaleEffect(isHolding ? 1.08 : 1)

                    Text("\(min(currentCount, rowTarget))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isCompleted ? tint : ForYouPalette.ink)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isCompleted ? tint.opacity(0.12) : Color.white.opacity(0.88))

                if descriptor.requiresLongPress {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(isCompleted ? 0.18 : 0.14))
                        .mask(
                            GeometryReader { geometry in
                                Rectangle()
                                    .frame(width: geometry.size.width * fillFraction(for: index), alignment: .leading)
                            }
                        )
                }

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isCompleted ? tint.opacity(0.28) : ForYouPalette.stroke, lineWidth: 1)
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .modifier(
            ForYouTrackerInteractionModifier(
                requiresLongPress: descriptor.requiresLongPress,
                holdDuration: descriptor.holdDuration,
                isCompleted: isCompleted,
                index: index,
                onTapStep: onTapStep,
                onPressingChanged: onPressingChanged,
                onTriggered: onTriggered
            )
        )
    }

    private func fillFraction(for index: Int) -> CGFloat {
        let rowTarget = descriptor.rowTargets.indices.contains(index) ? descriptor.rowTargets[index] : 1
        let currentCount = rowCounts.indices.contains(index) ? rowCounts[index] : 0
        if currentCount >= rowTarget {
            return 1
        }
        if rowTarget > 1 {
            return CGFloat(currentCount) / CGFloat(rowTarget)
        }
        if activeHoldIndex == index {
            return holdProgress
        }
        return 0
    }

    private func trackerRowTextColor(isCompleted: Bool, isHolding: Bool) -> Color {
        if descriptor.requiresLongPress && (isCompleted || isHolding) {
            return Color.black.opacity(0.82)
        }
        return ForYouPalette.ink
    }
}

private struct ForYouTrackerInteractionModifier: ViewModifier {
    let requiresLongPress: Bool
    let holdDuration: Double
    let isCompleted: Bool
    let index: Int
    let onTapStep: ((Int) -> Void)?
    let onPressingChanged: (Bool, Int) -> Void
    let onTriggered: (Int) -> Void

    func body(content: Content) -> some View {
        if requiresLongPress {
            content.onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 24, pressing: { pressing in
                guard !isCompleted else { return }
                onPressingChanged(pressing, index)
            }, perform: {
                guard !isCompleted else { return }
                onTriggered(index)
            })
        } else {
            Button {
                guard !isCompleted else { return }
                onTapStep?(index)
            } label: {
                content
            }
            .buttonStyle(.plain)
        }
    }
}

private func forYouRecommendationTrackerDescriptor(
    recommendation: ForYouTimelineRecommendation
) -> ForYouMiniProgressTracker.Descriptor? {
    let title = recommendation.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let rowLabels = recommendation.arabicText
        .map(forYouTrackerRowLabels(from:))
        ?? []

    switch title {
    case "morning protection", "perlindungan pagi":
        return .init(title: recommendation.title, compactLabel: nil, maximumCount: 3, requiresLongPress: true, rowLabels: Array(rowLabels.prefix(3)), rowTargets: [1, 1, 1], holdDuration: 10)
    case "evening adhkar", "evening zikir", "zikir petang":
        return .init(title: recommendation.title, compactLabel: nil, maximumCount: 3, requiresLongPress: false, rowLabels: Array(rowLabels.prefix(3)), rowTargets: [33, 33, 34], holdDuration: 0)
    case "surah ad-duha", "surah ad-dhuha":
        return .init(title: recommendation.title, compactLabel: nil, maximumCount: 1, requiresLongPress: true, rowLabels: [rowLabels.first ?? recommendation.title], rowTargets: [1], holdDuration: 20)
    case "before sleep", "sebelum tidur", "night sufficiency", "kecukupan malam":
        return .init(title: recommendation.title, compactLabel: nil, maximumCount: 1, requiresLongPress: true, rowLabels: [rowLabels.first ?? recommendation.title], rowTargets: [1], holdDuration: 10)
    default:
        return nil
    }
}

private func forYouTrackerRowLabels(from arabicText: String) -> [String] {
    let separators = CharacterSet(charactersIn: "•\n")
    let parts = arabicText
        .components(separatedBy: separators)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    return parts
}

private func forYouRecommendationTrackerStorageKey(
    entryID: String,
    recommendation: ForYouTimelineRecommendation,
    rowIndex: Int
) -> String {
    "for-you-recommendation-progress|\(entryID)|\(recommendation.title.lowercased())|\(rowIndex)"
}

private struct ForYouPremiumPreviewView: View {
    let plan: ForYouDailyPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isMalayAppLanguage() ? "Hari seterusnya sudah disediakan" : "Your next day is prepared")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))

            Text(isMalayAppLanguage() ? "Buka perjalanan kamu" : "Unlock your journey")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if let plan {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.title)
                        .font(.subheadline.weight(.semibold))
                    Text(plan.subtitle ?? "")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
                .blur(radius: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.black.opacity(0.20))
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct ForYouTimelineEntryView: View {
    let entry: ForYouTimelineEntry
    let isFocused: Bool
    var isCompact: Bool = false
    var extendsToNext: Bool = true

    @EnvironmentObject private var settings: Settings
    @State private var progressCount: Int
    @State private var activeHoldIndex: Int?
    @State private var holdProgress: CGFloat = 0
    @State private var burstIndex: Int?

    init(
        entry: ForYouTimelineEntry,
        isFocused: Bool,
        isCompact: Bool = false,
        extendsToNext: Bool = true
    ) {
        self.entry = entry
        self.isFocused = isFocused
        self.isCompact = isCompact
        self.extendsToNext = extendsToNext
        _progressCount = State(initialValue: ForYouDhikrProgressStore.count(for: entry.id))
    }

    var body: some View {
        HStack(alignment: .top, spacing: isCompact ? 8 : 10) {
            ForYouTimelineRailView(
                entry: entry,
                isFocused: isFocused,
                isCompact: isCompact,
                extendsToNext: extendsToNext
            )

            VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
                HStack(alignment: .top, spacing: 10) {
                    Label {
                        Text(entry.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(ForYouPalette.ink)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: entry.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(entry.momentType.tint)
                    }

                    Spacer(minLength: 8)

                    Text(entry.kind.displayTitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)
                }

                Text(entry.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)
                    .lineLimit(isCompact ? 2 : nil)
                    .fixedSize(horizontal: false, vertical: true)

                if let arabicText = entry.arabicText {
                    Text(arabicText)
                        .font(.custom(preferredQuranArabicFontName(settings: settings, size: isCompact ? 16 : 18), size: isCompact ? 16 : 18))
                        .foregroundStyle(ForYouPalette.ink)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineSpacing(3)
                }

                if let recommendation = entry.recommendation {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(isMalayAppLanguage() ? "Sesuai untuk waktu ini" : "Fits this time")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(ForYouPalette.secondaryInk)

                        Text(recommendation.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(ForYouPalette.ink)
                            .lineLimit(1)

                        if let arabicText = recommendation.arabicText {
                            ZStack(alignment: .topLeading) {
                                Text(arabicText)
                                    .font(.custom(preferredQuranArabicFontName(settings: settings, size: 16), size: 16))
                                    .foregroundStyle(ForYouPalette.ink)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                if let trackerDescriptor {
                                    ForYouMiniProgressTracker(
                                        descriptor: trackerDescriptor,
                                        rowCounts: Array(repeating: progressCount > 0 ? 1 : 0, count: trackerDescriptor.maximumCount),
                                        activeHoldIndex: activeHoldIndex,
                                        holdProgress: holdProgress,
                                        burstIndex: burstIndex,
                                        onTapStep: nil,
                                        onPressingChanged: handleTrackerPressing,
                                        onTriggered: completeCurrentTrackerStep
                                    )
                                }
                            }
                        }

                        Text(recommendation.shortDescription)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(ForYouPalette.secondaryInk)
                            .lineLimit(isCompact ? 2 : 3)
                            .fixedSize(horizontal: false, vertical: true)

                        if !isCompact, let reference = recommendation.reference {
                            Text(reference)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(ForYouPalette.secondaryInk)
                        }
                    }
                    .padding(isCompact ? 7 : 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ForYouPalette.recommendationFill)
                    )
                }

                if !isCompact, let reference = entry.reference {
                    Text(reference)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)
                        .lineLimit(1)
                }
            }
            .padding(isCompact ? 8 : 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ForYouPalette.softCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isFocused ? settings.accentColor.color.opacity(0.35) : ForYouPalette.stroke, lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeText: String {
        ForYouFormatters.shortTime.string(from: entry.time)
    }

    private var trackerDescriptor: ForYouMiniProgressTracker.Descriptor? {
        guard entry.kind == .zikir else { return nil }
        guard entry.progressTarget != nil || entry.progressRequiresLongPress else { return nil }
        return .init(
            title: entry.title,
            compactLabel: entry.progressRequiresLongPress ? (isMalayAppLanguage() ? "Tahan" : "Hold") : nil,
            maximumCount: max(entry.progressTarget ?? 1, 1),
            requiresLongPress: true,
            rowLabels: Array(repeating: entry.title, count: max(entry.progressTarget ?? 1, 1)),
            rowTargets: Array(repeating: 1, count: max(entry.progressTarget ?? 1, 1)),
            holdDuration: 10
        )
    }

    private func handleTrackerPressing(_ pressing: Bool, index: Int) {
        if pressing {
            activeHoldIndex = index
            holdProgress = 0
            withAnimation(.linear(duration: 10)) {
                holdProgress = 1
            }
        } else if activeHoldIndex == index {
            withAnimation(.easeOut(duration: 0.16)) {
                holdProgress = 0
            }
            activeHoldIndex = nil
        }
    }

    private func completeCurrentTrackerStep(_ index: Int) {
        guard let trackerDescriptor else { return }
        guard progressCount == index else { return }

        let nextCount = min(trackerDescriptor.maximumCount, progressCount + 1)
        progressCount = nextCount
        ForYouDhikrProgressStore.setCount(nextCount, for: entry.id)
        settings.hapticFeedback()
        burstIndex = index
        holdProgress = 0
        activeHoldIndex = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if burstIndex == index {
                burstIndex = nil
            }
        }
    }
}

private struct ForYouTimelineRailView: View {
    let entry: ForYouTimelineEntry
    let isFocused: Bool
    let isCompact: Bool
    let extendsToNext: Bool
    var trackerStatus: PrayerTrackerStatus? = nil
    var onTrackerTap: (() -> Void)? = nil

    @EnvironmentObject private var settings: Settings

    private var connectorGapBridge: CGFloat { extendsToNext ? 12 : 0 }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let onTrackerTap {
                    Button(action: onTrackerTap) {
                        timePill
                    }
                    .buttonStyle(.plain)
                } else {
                    timePill
                }
            }

            if let weather = entry.weather {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: weather.symbolName)
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(weather.temperatureCelsius)°C")
                            .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    }
                    .foregroundStyle(ForYouPalette.secondaryInk)

                    HStack(spacing: 4) {
                        Image(systemName: "cloud.rain")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(weather.precipitationProbability)% \(isMalayAppLanguage() ? "hujan" : "rain")")
                            .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                            .lineLimit(1)
                    }
                    .foregroundStyle(ForYouPalette.secondaryInk.opacity(0.85))
                }
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(connectorColor)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .padding(.top, isCompact ? 4 : 6)
                .padding(.bottom, connectorGapBridge)
        }
    }

    private var timePill: some View {
        Text(ForYouFormatters.shortTime.string(from: entry.time))
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(ForYouPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, isCompact ? 6 : 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(timePillFillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(timePillStrokeColor, lineWidth: 1)
                    )
            )
    }

    private var timePillFillColor: Color {
        switch trackerStatus {
        case .prayed:
            return Color.green.opacity(0.15)
        case .missed:
            return Color.red.opacity(0.12)
        case .pending, .none:
            return ForYouPalette.timePillFill
        }
    }

    private var timePillStrokeColor: Color {
        switch trackerStatus {
        case .prayed:
            return Color.green.opacity(0.35)
        case .missed:
            return Color.red.opacity(0.30)
        case .pending, .none:
            return isFocused ? settings.accentColor.color.opacity(0.45) : ForYouPalette.stroke
        }
    }

    private var connectorColor: Color {
        switch trackerStatus {
        case .prayed:
            return Color.green.opacity(0.30)
        case .missed:
            return Color.red.opacity(0.22)
        case .pending, .none:
            return isFocused ? settings.accentColor.color.opacity(0.28) : ForYouPalette.stroke
        }
    }
}

private struct ForYouPrayerTimelineEntryView: View {
    let entry: ForYouTimelineEntry
    let date: Date
    let isFocused: Bool
    let extendsToNext: Bool
    let selection: ForYouPrayerCardSelection
    let onSelectionChange: (ForYouPrayerCardSelection) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForYouTimelineRailView(
                entry: entry,
                isFocused: isFocused,
                isCompact: false,
                extendsToNext: extendsToNext,
                trackerStatus: trackerStatus,
                onTrackerTap: trackerPrayer.map { prayer in
                    {
                        settings.hapticFeedback()
                        let next = nextPrayerTrackerStatus(after: trackerStatus ?? .pending)
                        PrayerTrackerStore.setStatus(next, for: prayer, on: date)
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            )

            ForYouPrayerStackedCards(
                entry: entry,
                trackerStatus: trackerStatus,
                selection: selection,
                onSelectionChange: onSelectionChange
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @EnvironmentObject private var settings: Settings

    private var trackerPrayer: PrayerTrackerPrayer? {
        guard !isSunWindowEntry else { return nil }
        return PrayerTrackerPrayer.resolve(from: entry.title)
    }

    private var trackerStatus: PrayerTrackerStatus? {
        guard let trackerPrayer else { return nil }
        return PrayerTrackerStore.status(for: trackerPrayer, on: date)
    }

    private var isSunWindowEntry: Bool {
        let normalizedID = entry.id.lowercased()
        return normalizedID.hasSuffix("-syuruk")
            || normalizedID.contains("-syuruk-")
            || normalizedID.hasSuffix("-shurooq")
            || normalizedID.contains("-shurooq-")
            || normalizedID.hasSuffix("-sunrise")
            || normalizedID.contains("-sunrise-")
            || normalizedID.hasSuffix("-ishraq")
            || normalizedID.contains("-ishraq-")
            || normalizedID.hasSuffix("-dhuha")
            || normalizedID.contains("-dhuha-")
    }
}

// MARK: - Prayer expandable tabs

private enum ForYouPrayerTab: String, CaseIterable, Identifiable {
    case wirid = "Wirid"
    case doa   = "Doa"
    case weather = "Weather"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .wirid: return ForYouPalette.tabWirid
        case .doa:   return ForYouPalette.tabDoa
        case .weather: return ForYouPalette.darkTile
        }
    }

    var textColor: Color {
        switch self {
        case .wirid: return Color.black.opacity(0.85)
        case .doa:   return Color.white
        case .weather: return Color.white
        }
    }
}

private enum ForYouPrayerCardSelection: Equatable {
    case main(String)
    case tab(String, ForYouPrayerTab)

    var entryID: String {
        switch self {
        case .main(let entryID), .tab(let entryID, _):
            return entryID
        }
    }

    /// Unique scroll anchor for this exact card/tab combination.
    /// `.main` scrolls to the prayer row; `.tab` scrolls to that tab's strip.
    var scrollID: String {
        switch self {
        case .main(let entryID):
            return entryID
        case .tab(let entryID, let tab):
            return "\(entryID)-\(tab.rawValue)"
        }
    }

    var expandedTab: ForYouPrayerTab? {
        switch self {
        case .main:
            return nil
        case .tab(_, let tab):
            return tab
        }
    }
}

private func forYouPrayerTabs(for entry: ForYouTimelineEntry) -> [ForYouPrayerTab] {
    let normalizedID = entry.id.lowercased()
    let normalizedTitle = entry.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    let isShurooqEntry =
        normalizedID.hasSuffix("-syuruk") ||
        normalizedID.contains("-syuruk-") ||
        normalizedID.hasSuffix("-shurooq") ||
        normalizedID.contains("-shurooq-") ||
        normalizedID.hasSuffix("-sunrise") ||
        normalizedID.contains("-sunrise-") ||
        normalizedTitle == "syuruk" ||
        normalizedTitle == "shurooq" ||
        normalizedTitle == "sunrise"

    return isShurooqEntry ? [] : [.wirid, .doa]
}

private func nextPrayerTrackerStatus(after status: PrayerTrackerStatus) -> PrayerTrackerStatus {
    switch status {
    case .pending: return .prayed
    case .prayed: return .missed
    case .missed: return .pending
    }
}

// Each tab card slides up behind the card above it by this amount,
// so only the label strip peeks out at the bottom.
private let tabCardOverlap: CGFloat = 22
private let tabPeekHeight: CGFloat = 28

private struct ForYouPrayerStackedCards: View {
    let entry: ForYouTimelineEntry
    let trackerStatus: PrayerTrackerStatus?
    let selection: ForYouPrayerCardSelection
    let onSelectionChange: (ForYouPrayerCardSelection) -> Void
    @State private var presentedTab: ForYouPrayerTab?

    private var isActiveEntry: Bool {
        selection.entryID == entry.id
    }

    private var expandedTab: ForYouPrayerTab? {
        isActiveEntry ? selection.expandedTab : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ForYouTimelineEntryContentCard(
                entry: entry,
                trackerStatus: trackerStatus,
                collapsed: expandedTab != nil
            )
            .zIndex(10)
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))

            ForEach(Array(forYouPrayerTabs(for: entry).enumerated()), id: \.element) { index, tab in
                tabCard(tab: tab, index: index)
                    .padding(.top, topPadding(for: index))
                    .zIndex(zIndex(for: tab, index: index))
            }
        }
        .sheet(item: $presentedTab) { tab in
            NavigationView {
                ForYouPrayerTabModalView(entry: entry, tab: tab)
                    .navigationTitle(navigationTitle(for: tab))
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationViewStyle(.stack)
        }
    }

    @ViewBuilder
    private func tabCard(tab: ForYouPrayerTab, index: Int) -> some View {
        let isExpanded = expandedTab == tab
        let hiddenHeight = tabCardOverlap

        VStack(spacing: 0) {
            Color.clear.frame(height: hiddenHeight)

            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.80)) {
                    onSelectionChange(isExpanded ? .main(entry.id) : .tab(entry.id, tab))
                }
            } label: {
                HStack(spacing: 0) {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(tab.textColor)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: tabPeekHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(tab.color)
            // ID on the stable peek strip — never changes height, so scrollTo
            // always lands cleanly regardless of whether the card is expanded.
            .id("\(entry.id)-\(tab.rawValue)")

            if isExpanded {
                ForYouPrayerTabPanel(
                    entry: entry,
                    tab: tab,
                    mode: .preview,
                    onOpenFullContent: { presentedTab = tab }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(tab.color)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func topPadding(for index: Int) -> CGFloat {
        return -tabCardOverlap
    }

    private func zIndex(for tab: ForYouPrayerTab, index: Int) -> Double {
        return Double(forYouPrayerTabs(for: entry).count - index)
    }

    private func navigationTitle(for tab: ForYouPrayerTab) -> String {
        switch tab {
        case .wirid:
            return isMalayAppLanguage() ? "Wirid" : "Wirid"
        case .doa:
            return isMalayAppLanguage() ? "Doa" : "Dua"
        case .weather:
            return isMalayAppLanguage() ? "Cuaca" : "Weather"
        }
    }
}

// The card-only portion of ForYouTimelineEntryView (right column content)
// used by ForYouPrayerStackedCards so the time pill / connector stays separate
private struct ForYouTimelineEntryContentCard: View {
    let entry: ForYouTimelineEntry
    var trackerStatus: PrayerTrackerStatus? = nil
    var collapsed: Bool = false
    @EnvironmentObject private var settings: Settings
    @State private var recommendationRowCounts: [Int]
    @State private var recommendationActiveHoldIndex: Int?
    @State private var recommendationHoldProgress: CGFloat = 0
    @State private var recommendationBurstIndex: Int?

    init(
        entry: ForYouTimelineEntry,
        trackerStatus: PrayerTrackerStatus? = nil,
        collapsed: Bool = false
    ) {
        self.entry = entry
        self.trackerStatus = trackerStatus
        self.collapsed = collapsed
        if let recommendation = entry.recommendation,
           let descriptor = forYouRecommendationTrackerDescriptor(recommendation: recommendation) {
            let counts = descriptor.rowTargets.indices.map { rowIndex in
                ForYouDhikrProgressStore.count(
                    for: forYouRecommendationTrackerStorageKey(
                        entryID: entry.id,
                        recommendation: recommendation,
                        rowIndex: rowIndex
                    )
                )
            }
            _recommendationRowCounts = State(initialValue: counts)
        } else {
            _recommendationRowCounts = State(initialValue: [])
        }
    }

    private var prayerDetailLines: [String] {
        guard entry.kind == .prayer else { return [] }

        var lines: [String] = []
        if let rakah = cleanedPrayerDetail(entry.rakah) {
            lines.append(localizedPrayerRakahInfo(rakah))
        }
        if let sunnahBefore = cleanedPrayerDetail(entry.sunnahBefore) {
            lines.append(localizedSunnahBeforeInfo(sunnahBefore))
        }
        if let sunnahAfter = cleanedPrayerDetail(entry.sunnahAfter) {
            lines.append(localizedSunnahAfterInfo(sunnahAfter))
        }
        return lines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: collapsed ? 6 : 8) {
            HStack(alignment: .top, spacing: 10) {
                Label {
                    Text(entry.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(ForYouPalette.ink)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: entry.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(entry.momentType.tint)
                }
                Spacer(minLength: 8)
                Text(entry.kind.displayTitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)
            }

            if let trackerStatus {
                Text(prayerTrackerLabel(for: trackerStatus))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(prayerTrackerTextColor(for: trackerStatus))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(prayerTrackerFillColor(for: trackerStatus))
                    )
            }

            Text(entry.subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ForYouPalette.secondaryInk)
                .lineLimit(collapsed ? 1 : nil)
                .fixedSize(horizontal: false, vertical: true)

            if !collapsed, !prayerDetailLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(prayerDetailLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(ForYouPalette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ForYouPalette.recommendationFill)
                )
            }

            if !collapsed, let arabicText = entry.arabicText {
                Text(arabicText)
                    .font(.custom(preferredQuranArabicFontName(settings: settings, size: 18), size: 18))
                    .foregroundStyle(ForYouPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(3)
                    .minimumScaleFactor(0.8)
            }

            if !collapsed, let recommendation = entry.recommendation {
                VStack(alignment: .leading, spacing: 5) {
                    Text(isMalayAppLanguage() ? "Sesuai untuk waktu ini" : "Fits this time")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)
                    Text(recommendation.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(ForYouPalette.ink)
                        .lineLimit(1)
                    if let arabicText = recommendation.arabicText {
                        ZStack(alignment: .topLeading) {
                            Text(arabicText)
                                .font(.custom(preferredQuranArabicFontName(settings: settings, size: 16), size: 16))
                                .foregroundStyle(ForYouPalette.ink)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            if let recommendationTrackerDescriptor {
                                ForYouMiniProgressTracker(
                                    descriptor: recommendationTrackerDescriptor,
                                    rowCounts: recommendationRowCounts,
                                    activeHoldIndex: recommendationActiveHoldIndex,
                                    holdProgress: recommendationHoldProgress,
                                    burstIndex: recommendationBurstIndex,
                                    onTapStep: incrementRecommendationTrackerStep,
                                    onPressingChanged: handleRecommendationTrackerPressing,
                                    onTriggered: completeRecommendationTrackerStep
                                )
                            }
                        }
                    }
                    Text(recommendation.shortDescription)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if let reference = recommendation.reference {
                        Text(reference)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(ForYouPalette.secondaryInk)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ForYouPalette.recommendationFill)
                )
            }

            if !collapsed, let reference = entry.reference {
                Text(reference)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)
                    .lineLimit(1)
            }
        }
        .padding(collapsed ? 9 : 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private var recommendationTrackerDescriptor: ForYouMiniProgressTracker.Descriptor? {
        guard let recommendation = entry.recommendation else { return nil }
        return forYouRecommendationTrackerDescriptor(recommendation: recommendation)
    }

    private func handleRecommendationTrackerPressing(_ pressing: Bool, index: Int) {
        guard recommendationTrackerDescriptor != nil else { return }
        if pressing {
            recommendationActiveHoldIndex = index
            recommendationHoldProgress = 0
            withAnimation(.linear(duration: 10)) {
                recommendationHoldProgress = 1
            }
        } else if recommendationActiveHoldIndex == index {
            withAnimation(.easeOut(duration: 0.16)) {
                recommendationHoldProgress = 0
            }
            recommendationActiveHoldIndex = nil
        }
    }

    private func completeRecommendationTrackerStep(_ index: Int) {
        guard let recommendation = entry.recommendation,
              let descriptor = recommendationTrackerDescriptor else { return }
        guard recommendationRowCounts.indices.contains(index) else { return }

        var nextCounts = recommendationRowCounts
        nextCounts[index] = descriptor.rowTargets[index]
        recommendationRowCounts = nextCounts
        ForYouDhikrProgressStore.setCount(
            descriptor.rowTargets[index],
            for: forYouRecommendationTrackerStorageKey(entryID: entry.id, recommendation: recommendation, rowIndex: index)
        )
        settings.hapticFeedback()
        recommendationBurstIndex = index
        recommendationHoldProgress = 0
        recommendationActiveHoldIndex = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if recommendationBurstIndex == index {
                recommendationBurstIndex = nil
            }
        }
    }

    private func incrementRecommendationTrackerStep(_ index: Int) {
        guard let recommendation = entry.recommendation,
              let descriptor = recommendationTrackerDescriptor else { return }
        guard recommendationRowCounts.indices.contains(index) else { return }
        guard recommendationRowCounts[index] < descriptor.rowTargets[index] else { return }

        var nextCounts = recommendationRowCounts
        nextCounts[index] += 1
        recommendationRowCounts = nextCounts
        ForYouDhikrProgressStore.setCount(
            nextCounts[index],
            for: forYouRecommendationTrackerStorageKey(entryID: entry.id, recommendation: recommendation, rowIndex: index)
        )
        settings.hapticFeedback()
    }

    private var cardFillColor: Color {
        switch trackerStatus {
        case .prayed:
            return Color(red: 0.90, green: 0.97, blue: 0.92)
        case .missed:
            return Color(red: 0.99, green: 0.93, blue: 0.93)
        case .pending, .none:
            return Color(uiColor: .secondarySystemBackground)
        }
    }

    private func cleanedPrayerDetail(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let normalized = raw
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        if normalized == "0" || normalized == "-" || normalized == "nil" {
            return nil
        }

        return raw
    }

    private var cardStrokeColor: Color {
        switch trackerStatus {
        case .prayed:
            return Color.green.opacity(0.26)
        case .missed:
            return Color.red.opacity(0.20)
        case .pending, .none:
            return ForYouPalette.stroke
        }
    }

    private func prayerTrackerLabel(for status: PrayerTrackerStatus) -> String {
        switch status {
        case .pending:
            return isMalayAppLanguage() ? "Belum" : "Pending"
        case .prayed:
            return isMalayAppLanguage() ? "Selesai" : "Done"
        case .missed:
            return isMalayAppLanguage() ? "Tertinggal" : "Missed"
        }
    }

    private func prayerTrackerFillColor(for status: PrayerTrackerStatus) -> Color {
        switch status {
        case .pending:
            return Color.secondary.opacity(0.12)
        case .prayed:
            return Color.green.opacity(0.16)
        case .missed:
            return Color.red.opacity(0.12)
        }
    }

    private func prayerTrackerTextColor(for status: PrayerTrackerStatus) -> Color {
        switch status {
        case .pending:
            return ForYouPalette.secondaryInk
        case .prayed:
            return .green
        case .missed:
            return .red
        }
    }
}

private struct ForYouPrayerTabModalView: View {
    let entry: ForYouTimelineEntry
    let tab: ForYouPrayerTab

    var body: some View {
        ForYouPrayerTabPanel(entry: entry, tab: tab, mode: .full)
            .padding(.top, 8)
            .padding(.bottom, 20)
        .background(ForYouPalette.canvas.ignoresSafeArea())
    }
}

private struct ForYouPrayerTabPanel: View {
    enum DisplayMode {
        case preview
        case full
    }

    let entry: ForYouTimelineEntry
    let tab: ForYouPrayerTab
    var mode: DisplayMode = .full
    var onOpenFullContent: (() -> Void)? = nil

    @StateObject private var player = ForYouAudioPlayer()
    @State private var expandedSectionIDs: Set<String> = []
    @State private var focusedSectionID: String?
    @State private var weatherSnapshot: ForYouWeatherSnapshot?
    @State private var prayerWeatherRows: [WeatherPrayerRow] = []
    @EnvironmentObject private var settings: Settings

    private struct PanelSection: Identifiable {
        let id: String
        let title: String
        let arabic: String
        let transliteration: String
        let meaning: String
        let metadata: String?
        let progress: DhikrProgressDescriptor?
    }

    private struct PanelContent {
        let title: String
        let sections: [PanelSection]
    }

    private struct WeatherPrayerRow: Identifiable {
        let id: String
        let title: String
        let time: Date
        let weather: ForYouPrayerWeather
    }

    struct DhikrProgressDescriptor {
        let storageID: String
        let target: Int
    }

    private var content: PanelContent {
        switch tab {
        case .wirid:
            return wiridContent(for: canonicalPrayerName(from: entry.id))
        case .doa:
            return doaContent(for: canonicalPrayerName(from: entry.id))
        case .weather:
            return PanelContent(
                title: isMalayAppLanguage()
                    ? "Cuaca semasa dan ramalan mengikut waktu solat"
                    : "Current weather and prayer-by-prayer forecast",
                sections: []
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(isMalayAppLanguage() ? "Sesuai untuk waktu ini" : "Fits this time")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)

                Text(content.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(tab == .weather ? Color.white : ForYouPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if tab == .weather {
                        weatherContent
                    } else if mode == .preview {
                        previewContent
                    } else {
                        fullModeContent
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onTapGesture {
                    guard mode == .preview else { return }
                    onOpenFullContent?()
                }

            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tab == .weather ? ForYouPalette.darkTile : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .onDisappear { player.stop() }
        .task(id: weatherTaskKey) {
            await loadWeatherIfNeeded()
        }
    }

    private func audioFileName(tab: ForYouPrayerTab, prayer: String) -> String {
        let base = prayer.lowercased().replacingOccurrences(of: " ", with: "_")
        return "\(base)_\(tab.rawValue.lowercased())"
    }

    @ViewBuilder
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(previewSections.enumerated()), id: \.element.id) { index, section in
                    Text(section.arabic)
                        .font(.custom(preferredQuranArabicFontName(settings: settings, size: 18), size: 18))
                        .foregroundStyle(ForYouPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)

                    if index < previewSections.count - 1 {
                        Divider()
                            .opacity(0.35)
                    }
                }

                if remainingPreviewCount > 0 {
                    Text(previewSummaryLine)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(tab.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 6) {
                Text(isMalayAppLanguage() ? "Ketik teks untuk buka penuh" : "Tap the text to open full view")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(tab.color)
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var weatherContent: some View {
        if mode == .preview {
            weatherPreviewContent
        } else {
            weatherFullContent
        }
    }

    @ViewBuilder
    private var weatherPreviewContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let snapshot = weatherSnapshot {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: snapshot.symbolName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.temperatureText)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text(snapshot.conditionText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.84))
                    }

                    Spacer(minLength: 0)
                }

                if let currentPrayerWeather = entry.weather {
                    HStack(spacing: 8) {
                        Label {
                            Text("\(currentPrayerWeather.precipitationProbability)% \(isMalayAppLanguage() ? "hujan" : "rain")")
                        } icon: {
                            Image(systemName: "cloud.rain")
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.84))

                        Spacer(minLength: 0)

                        Text(locationLine)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.68))
                            .lineLimit(1)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text(isMalayAppLanguage() ? "Memuatkan cuaca semasa..." : "Loading current weather...")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.78))
                }
            }

            HStack(spacing: 6) {
                Text(isMalayAppLanguage() ? "Ketik teks untuk buka ramalan penuh" : "Tap the text to open full forecast")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.white.opacity(0.82))
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var weatherFullContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let snapshot = weatherSnapshot {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: snapshot.symbolName)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(snapshot.temperatureText)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text(snapshot.conditionText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.82))
                    }

                    Spacer(minLength: 0)
                }
            }

            if !prayerWeatherRows.isEmpty {
                VStack(spacing: 10) {
                    ForEach(prayerWeatherRows) { row in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: row.weather.symbolName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.88))
                                    Text(row.title)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.white)
                                    Text(ForYouFormatters.shortTime.string(from: row.time))
                                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                                        .foregroundStyle(Color.white.opacity(0.74))
                                }

                                Text("\(row.weather.conditionText) • \(row.weather.precipitationProbability)% \(isMalayAppLanguage() ? "hujan" : "rain")")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.76))
                            }

                            Spacer(minLength: 0)

                            Text("\(row.weather.temperatureCelsius)°C")
                                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text(isMalayAppLanguage() ? "Memuatkan ramalan waktu solat..." : "Loading prayer-time forecast...")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.78))
                }
                .padding(.vertical, 12)
            }
        }
    }

    private var previewSections: [PanelSection] {
        Array(content.sections.prefix(tab == .wirid ? 2 : 1))
    }

    private var remainingPreviewCount: Int {
        max(content.sections.count - previewSections.count, 0)
    }

    private var previewSummaryLine: String {
        if isMalayAppLanguage() {
            return "Dan \(remainingPreviewCount) lagi dalam paparan penuh"
        }

        return "And \(remainingPreviewCount) more in full view"
    }

    @ViewBuilder
    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(content.sections.enumerated()), id: \.element.id) { index, section in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(index + 1). \(section.title)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(modalAccentTextColor)
                        .fixedSize(horizontal: false, vertical: true)

                    if let progress = section.progress {
                        ForYouDhikrProgressBar(
                            title: section.title,
                            descriptor: progress,
                            tint: tab.color
                        )
                    }

                    Text(section.arabic)
                        .font(.custom(preferredQuranArabicFontName(settings: settings, size: 20), size: 20))
                        .foregroundStyle(ForYouPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    if usesTranslationAccordion {
                        Button {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                                toggleSection(section.id)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(isSectionExpanded(section.id)
                                     ? (isMalayAppLanguage() ? "Sembunyikan terjemahan" : "Hide translation")
                                     : (isMalayAppLanguage() ? "Lihat terjemahan" : "Show translation"))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                Spacer()
                                Image(systemName: isSectionExpanded(section.id) ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(modalAccentTextColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(modalAccentFill)
                            )
                        }
                        .buttonStyle(.plain)

                        if isSectionExpanded(section.id) {
                            translationContent(for: section)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    } else {
                        translationContent(for: section)
                    }
                }
                .id(section.id)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    focusedSectionID == section.id
                                        ? modalAccentTextColor.opacity(0.35)
                                        : ForYouPalette.stroke,
                                    lineWidth: 1
                                )
                        )
                )

                if index < content.sections.count - 1 {
                    Divider().opacity(0.35)
                }
            }
        }
    }

    @ViewBuilder
    private var fullModeContent: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    fullContent
                        .padding(.top, 2)
                        .padding(.bottom, tab == .wirid && !content.sections.isEmpty ? 112 : 0)
                }

                if tab == .wirid, !content.sections.isEmpty {
                    HStack(spacing: 12) {
                        modalFloatingControlButton(systemName: "chevron.left", disabled: focusedSectionIndex == 0) {
                            handleWiridBackward(proxy: proxy)
                        }
                        modalFloatingControlButton(systemName: "chevron.right", disabled: false) {
                            handleWiridForward(proxy: proxy)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(ForYouPalette.stroke, lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 10)
                }
            }
            .task {
                guard mode == .full, focusedSectionID == nil else { return }
                focusSection(at: 0, proxy: proxy)
            }
        }
    }

    private var usesTranslationAccordion: Bool {
        mode == .full
    }

    private func isSectionExpanded(_ id: String) -> Bool {
        expandedSectionIDs.contains(id)
    }

    private func toggleSection(_ id: String) {
        if expandedSectionIDs.contains(id) {
            expandedSectionIDs.remove(id)
        } else {
            expandedSectionIDs = [id]
        }
    }

    private var modalAccentTextColor: Color {
        switch tab {
        case .doa:
            return Color.blue.opacity(0.88)
        case .weather:
            return Color.white
        case .wirid:
            return tab.color
        }
    }

    private var modalAccentFill: Color {
        switch tab {
        case .doa:
            return Color.blue.opacity(0.14)
        case .weather:
            return Color.white.opacity(0.10)
        case .wirid:
            return tab.color.opacity(0.10)
        }
    }

    @ViewBuilder
    private func modalFloatingControlButton(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ForYouPalette.ink)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(
                            Circle()
                                .stroke(ForYouPalette.stroke, lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func handleWiridForward(proxy: ScrollViewProxy) {
        guard !content.sections.isEmpty else { return }

        let currentIndex = focusedSectionIndex ?? 0
        if let progress = content.sections[currentIndex].progress {
            let currentCount = ForYouDhikrProgressStore.count(for: progress.storageID)
            if currentCount < progress.target {
                triggerDhikrProgress(for: progress)
                return
            }
        }

        let nextIndex = min(currentIndex + 1, content.sections.count - 1)
        focusSection(at: nextIndex, proxy: proxy)
    }

    private func handleWiridBackward(proxy: ScrollViewProxy) {
        guard !content.sections.isEmpty else { return }
        let currentIndex = focusedSectionIndex ?? 0
        let previousIndex = max(currentIndex - 1, 0)
        focusSection(at: previousIndex, proxy: proxy)
    }

    private var focusedSectionIndex: Int? {
        guard let focusedSectionID else { return nil }
        return content.sections.firstIndex(where: { $0.id == focusedSectionID })
    }

    private func focusSection(at index: Int, proxy: ScrollViewProxy) {
        guard content.sections.indices.contains(index) else { return }
        let section = content.sections[index]
        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            focusedSectionID = section.id
            expandedSectionIDs = [section.id]
            proxy.scrollTo(section.id, anchor: .center)
        }
    }

    private func triggerDhikrProgress(for descriptor: DhikrProgressDescriptor) {
        NotificationCenter.default.post(
            name: .forYouDhikrProgressTrigger,
            object: nil,
            userInfo: ["storageID": descriptor.storageID]
        )
    }

    @ViewBuilder
    private func translationContent(for section: PanelSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.transliteration)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(ForYouPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(section.meaning)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ForYouPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            if let metadata = section.metadata {
                Text(metadata)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func wiridContent(for canonicalPrayer: String) -> PanelContent {
        let items = WiridContentRepository.items(forPrayer: canonicalPrayer)
        let isFull = WiridContentRepository.fullWiridPrayers.contains(canonicalPrayer)
        let title = isMalayAppLanguage()
            ? (isFull ? "Wirid penuh selepas solat" : "Wirid ringkas selepas solat")
            : (isFull ? "Full post-prayer wirid" : "Short post-prayer wirid")

        return PanelContent(
            title: title,
            sections: items.map { item in
                let itemTitle = isMalayAppLanguage() ? item.titleMy : item.titleEn
                var metadata: [String] = []
                if let count = item.count {
                    metadata.append(isMalayAppLanguage() ? "Ulangan: \(count)" : "Repeat: \(count)")
                }
                if let reference = item.reference {
                    metadata.append(reference)
                }

                return PanelSection(
                    id: item.id,
                    title: itemTitle,
                    arabic: item.arabicText,
                    transliteration: item.transliteration,
                    meaning: item.translationMy,
                    metadata: metadata.isEmpty ? nil : metadata.joined(separator: "\n"),
                    progress: dhikrProgressDescriptor(for: item.id, prayer: canonicalPrayer)
                )
            }
        )
    }

    private func doaContent(for canonicalPrayer: String) -> PanelContent {
        let items = [DoaContentRepository.recommended(forPrayer: canonicalPrayer)]
            + (DoaContentRepository.secondary(forPrayer: canonicalPrayer).map { [$0] } ?? [])

        return PanelContent(
            title: isMalayAppLanguage() ? "Doa selepas solat" : "Post-prayer dua",
            sections: items.map { item in
                let itemTitle = isMalayAppLanguage() ? item.titleMy : item.titleEn
                return PanelSection(
                    id: item.id,
                    title: itemTitle,
                    arabic: item.arabicText,
                    transliteration: item.transliteration,
                    meaning: item.translationMy,
                    metadata: item.note,
                    progress: nil
                )
            }
        )
    }

    private func dhikrProgressDescriptor(for sectionID: String, prayer: String) -> DhikrProgressDescriptor? {
        let target: Int?
        switch sectionID {
        case "wirid-03-ajirna":
            target = (prayer == "fajr" || prayer == "maghrib") ? 7 : 3
        case "wirid-21-subhanallah", "wirid-23-alhamdulillah", "wirid-25-allahuakbar":
            target = 33
        default:
            target = nil
        }

        guard let target else { return nil }
        return DhikrProgressDescriptor(storageID: "\(entry.id)::\(sectionID)", target: target)
    }

    private func canonicalPrayerName(from entryID: String) -> String {
        let normalized = entryID.lowercased()

        if normalized.contains("-fajr-") {
            return "fajr"
        }
        if normalized.contains("-dhuhr-") {
            return "dhuhr"
        }
        if normalized.contains("-asr-") {
            return "asr"
        }
        if normalized.contains("-maghrib-") {
            return "maghrib"
        }
        if normalized.contains("-isha-") {
            return "isha"
        }
        if normalized.hasSuffix("-ishraq") || normalized.contains("-ishraq-") {
            return "ishraq"
        }
        if normalized.hasSuffix("-dhuha") || normalized.contains("-dhuha-") {
            return "dhuha"
        }

        let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch title {
        case "subuh":
            return "fajr"
        case "zuhur", "jumuah":
            return "dhuhr"
        case "asar":
            return "asr"
        case "magrib":
            return "maghrib"
        case "isya", "isyak":
            return "isha"
        default:
            return title
        }
    }

    private var weatherTaskKey: String {
        guard tab == .weather else { return "non-weather" }
        guard let location = settings.currentLocation else { return "weather-no-location" }
        return "\(location.latitude)|\(location.longitude)|\(Calendar.current.startOfDay(for: entry.time).timeIntervalSince1970)"
    }

    private var locationLine: String {
        settings.currentPrayerAreaName
            ?? settings.activePrayerLocationDisplayName
            ?? settings.currentLocation?.city
            ?? ""
    }

    @MainActor
    private func loadWeatherIfNeeded() async {
        guard tab == .weather else { return }
        guard let location = settings.currentLocation, location.latitude != 1000, location.longitude != 1000 else {
            weatherSnapshot = nil
            prayerWeatherRows = []
            return
        }

        do {
            async let snapshot = ForYouWeatherService.shared.fetchCurrentWeather(for: location)
            async let weatherByHour = ForYouWeatherService.shared.weatherByHour(for: location, on: entry.time)
            let (resolvedSnapshot, resolvedByHour) = try await (snapshot, weatherByHour)
            weatherSnapshot = resolvedSnapshot
            prayerWeatherRows = makePrayerWeatherRows(using: resolvedByHour)
        } catch {
            weatherSnapshot = nil
            prayerWeatherRows = []
        }
    }

    private func makePrayerWeatherRows(using weatherByHour: [Int: ForYouPrayerWeather]) -> [WeatherPrayerRow] {
        let timeline = ForYouPrayerTimeService.timeline(for: entry.time, settings: settings)
        let rowCandidates: [(id: String, title: String, time: Date?)] = [
            ("fajr", localizedWeatherPrayerTitle("fajr"), timeline.fajr),
            ("sunrise", localizedWeatherPrayerTitle("sunrise"), timeline.sunrise),
            ("dhuha", localizedWeatherPrayerTitle("dhuha"), timeline.dhuha),
            ("dhuhr", localizedWeatherPrayerTitle("dhuhr"), timeline.prayers.first(where: { normalizedPrayerKey($0.nameTransliteration) == "dhuhr" })?.time),
            ("asr", localizedWeatherPrayerTitle("asr"), timeline.asr),
            ("maghrib", localizedWeatherPrayerTitle("maghrib"), timeline.maghrib),
            ("isha", localizedWeatherPrayerTitle("isha"), timeline.isha)
        ]

        return rowCandidates.compactMap { candidate in
            guard let time = candidate.time else { return nil }
            let hour = Calendar.current.component(.hour, from: time)
            guard let weather = weatherByHour[hour] else { return nil }
            return WeatherPrayerRow(
                id: "\(ISO8601DateFormatter().string(from: entry.time))-\(candidate.id)",
                title: candidate.title,
                time: time,
                weather: weather
            )
        }
    }

    private func localizedWeatherPrayerTitle(_ key: String) -> String {
        switch key {
        case "fajr":
            return isMalayAppLanguage() ? "Subuh" : "Fajr"
        case "sunrise":
            return isMalayAppLanguage() ? "Syuruk" : "Shurooq"
        case "dhuha":
            return "Dhuha"
        case "dhuhr":
            return isMalayAppLanguage() ? "Zuhur" : "Dhuhr"
        case "asr":
            return isMalayAppLanguage() ? "Asar" : "Asr"
        case "maghrib":
            return isMalayAppLanguage() ? "Magrib" : "Maghrib"
        case "isha":
            return isMalayAppLanguage() ? "Isyak" : "Isha"
        default:
            return key
        }
    }

    private func normalizedPrayerKey(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "subuh":
            return "fajr"
        case "zuhur", "jumuah":
            return "dhuhr"
        case "asar":
            return "asr"
        case "magrib":
            return "maghrib"
        case "isya", "isyak":
            return "isha"
        default:
            return value
        }
    }
}

private struct ForYouDhikrProgressBar: View {
    let title: String
    let descriptor: ForYouPrayerTabPanel.DhikrProgressDescriptor
    let tint: Color

    @EnvironmentObject private var settings: Settings
    @State private var count: Int = 0
    @State private var shakeTrigger: CGFloat = 0
    @State private var burstVisible = false

    private let progressGreen = Color(red: 0.20, green: 0.69, blue: 0.39)
    private let progressGreenSoft = Color(red: 0.20, green: 0.69, blue: 0.39).opacity(0.14)

    var body: some View {
        Button(action: increment) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(min(count, descriptor.target))/\(descriptor.target)")
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(progressGreen)
                }

                GeometryReader { geometry in
                    let fraction = CGFloat(min(count, descriptor.target)) / CGFloat(max(descriptor.target, 1))
                    let fillWidth = max(geometry.size.width * fraction, count > 0 ? 16 : 0)
                    let burstX = min(max(fillWidth - 10, 0), max(geometry.size.width - 20, 0))

                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(progressGreenSoft)

                        Capsule(style: .continuous)
                            .fill(progressGreen)
                            .frame(width: fillWidth)

                        if burstVisible || count > 0 {
                            ZStack {
                                Circle()
                                    .fill(progressGreen.opacity(0.18))
                                    .frame(width: 18, height: 18)

                                ForEach(0..<6, id: \.self) { index in
                                    Circle()
                                        .fill(progressGreen.opacity(0.85))
                                        .frame(width: 4, height: 4)
                                        .offset(
                                            x: burstVisible ? cos(Double(index) * .pi / 3) * 11 : 0,
                                            y: burstVisible ? sin(Double(index) * .pi / 3) * 11 : 0
                                        )
                                        .opacity(burstVisible ? 0 : 1)
                                }
                            }
                            .frame(width: 20, height: 20)
                            .offset(x: burstX, y: -4)
                        }
                    }
                    .frame(height: 12)
                }
                .frame(height: 12)
                .modifier(ForYouShakeEffect(animatableData: shakeTrigger))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(progressGreenSoft)
            )
        }
        .buttonStyle(.plain)
        .disabled(count >= descriptor.target)
        .onAppear {
            count = ForYouDhikrProgressStore.count(for: descriptor.storageID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .forYouDhikrProgressTrigger)) { notification in
            guard
                let storageID = notification.userInfo?["storageID"] as? String,
                storageID == descriptor.storageID
            else { return }
            increment()
        }
    }

    private func increment() {
        guard count < descriptor.target else { return }

        settings.hapticFeedback()

        withAnimation(.linear(duration: 0.28)) {
            shakeTrigger += 1
            burstVisible = true
        }

        let nextCount = min(count + 1, descriptor.target)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                count = nextCount
            }
            ForYouDhikrProgressStore.setCount(nextCount, for: descriptor.storageID)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeOut(duration: 0.18)) {
                burstVisible = false
            }
        }
    }
}

private extension Notification.Name {
    static let forYouDhikrProgressTrigger = Notification.Name("forYouDhikrProgressTrigger")
}

private struct ForYouShakeEffect: GeometryEffect {
    var amount: CGFloat = 5
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

@MainActor
private final class ForYouAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    var progressText: String {
        let elapsed = Int(progress * duration)
        let total   = Int(duration)
        return "\(format(elapsed)) / \(format(total))"
    }

    func togglePlayback(for fileName: String) {
        if isPlaying { stop(); return }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            // No audio file bundled yet — placeholder
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            duration = player?.duration ?? 0
            isPlaying = true
            startTimer()
        } catch {}
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let p = self.player else { return }
            self.progress = p.duration > 0 ? p.currentTime / p.duration : 0
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in stop() }
    }

    private func format(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct ForYouCompactTimelineEntryView: View {
    let entry: ForYouTimelineEntry

    @EnvironmentObject private var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Label {
                    Text(entry.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(ForYouPalette.ink)
                } icon: {
                    Image(systemName: entry.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(entry.momentType.tint)
                }

                Spacer(minLength: 8)

                Text(entry.kind.displayTitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)
            }

            Text(entry.subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ForYouPalette.secondaryInk)
                .lineLimit(2)

            if let arabicText = entry.arabicText {
                Text(arabicText)
                    .font(.custom(preferredQuranArabicFontName(settings: settings, size: 18), size: 18))
                    .foregroundStyle(ForYouPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if let recommendation = entry.recommendation {
                VStack(alignment: .leading, spacing: 5) {
                    Text(isMalayAppLanguage() ? "Sesuai untuk waktu ini" : "Fits this time")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)

                    Text(recommendation.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(ForYouPalette.ink)
                        .lineLimit(1)

                    if let arabicText = recommendation.arabicText {
                        Text(arabicText)
                            .font(.custom(preferredQuranArabicFontName(settings: settings, size: 15), size: 15))
                            .foregroundStyle(ForYouPalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Text(recommendation.shortDescription)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)
                        .lineLimit(2)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ForYouPalette.recommendationFill)
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ForYouPalette.softCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ForYouPalette.stroke, lineWidth: 1)
                )
        )
    }
}

private struct ForYouLockedLayer: View {
    let reason: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(ForYouPalette.ink)

            Text(isMalayAppLanguage() ? "Hari ini sudah kamu rasa. Hari-hari seterusnya menunggu." : "You have today. The days ahead are waiting.")
                .font(.headline.weight(.semibold))
                .foregroundStyle(ForYouPalette.ink)
                .multilineTextAlignment(.center)

            Text(reason ?? (isMalayAppLanguage() ? "Buka pelan yang diperibadikan, disediakan lebih awal untuk rentak ibadah kamu." : "Unlock the prepared days ahead with a more personal daily rhythm."))
                .font(.subheadline)
                .foregroundStyle(ForYouPalette.secondaryInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)

            Text(isMalayAppLanguage() ? "Pengalaman hari ini kekal penuh. Esok hanya dipratonton dengan lembut." : "Today stays fully open. Tomorrow is only softly previewed.")
                .font(.caption)
                .foregroundStyle(ForYouPalette.secondaryInk)
        }
        .padding(26)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct ForYouSummaryHeader: View {
    let plan: ForYouDailyPlan
    let currentPrayerEntry: ForYouTimelineEntry?
    let nextPrayerEntry: ForYouTimelineEntry?

    var body: some View {
        GeometryReader { geometry in
            let shellInsetHorizontal: CGFloat = 5
            let shellInsetTop: CGFloat = 5
            let shellInsetBottom: CGFloat = 9
            let panelSpacing: CGFloat = 5
            let panelHeight = geometry.size.height - shellInsetTop - shellInsetBottom
            let availableWidth = geometry.size.width - (shellInsetHorizontal * 2)
            let rightWidth = floor((availableWidth - panelSpacing) * 0.43)
            let leftWidth = availableWidth - panelSpacing - rightWidth
            let smallPanelHeight = floor((panelHeight - panelSpacing) / 2)

            HStack(spacing: panelSpacing) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        Image(systemName: currentPrayerIcon)
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(ForYouPalette.ink)

                        Text(currentPrayerEntry?.title ?? (isMalayAppLanguage() ? "Subuh" : "Fajr"))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(ForYouPalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 6)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(shortWeekday)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(ForYouPalette.ink)

                        Text(plan.locationLine ?? "")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(ForYouPalette.secondaryInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(width: leftWidth, height: panelHeight, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 2)
                        )
                )

                VStack(spacing: panelSpacing) {
                    HStack(spacing: 6) {
                        Image(systemName: nextPrayerIcon)
                            .font(.system(size: 18, weight: .medium))
                        Text(nextPrayerEntry?.title ?? "—")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                    .foregroundStyle(ForYouPalette.ink)
                    .frame(width: rightWidth, height: smallPanelHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(ForYouPalette.accentSky)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 2)
                            )
                    )

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 15, weight: .medium))
                        Text(nextPrayerTime)
                            .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(.white)
                    .frame(width: rightWidth, height: smallPanelHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(ForYouPalette.darkTile)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 2)
                            )
                    )
                }
            }
            .padding(.horizontal, shellInsetHorizontal)
            .padding(.top, shellInsetTop)
            .padding(.bottom, shellInsetBottom)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110)
        .background(
            ForYouTopRoundedShape(radius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var shortWeekday: String {
        ForYouFormatters.weekday.string(from: plan.date).prefix(3).capitalized
    }

    private var nextPrayerTime: String {
        guard let nextPrayerEntry else { return "--:--" }
        return ForYouFormatters.shortTime.string(from: nextPrayerEntry.time)
    }

    private var currentPrayerIcon: String {
        guard let currentPrayerEntry else { return "sunrise" }
        return prayerIcon(for: currentPrayerEntry.title)
    }

    private var nextPrayerIcon: String {
        guard let nextPrayerEntry else { return "arrow.right.circle" }
        return prayerIcon(for: nextPrayerEntry.title)
    }

    private func prayerIcon(for prayerTitle: String) -> String {
        switch prayerTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "fajr", "subuh":
            return "sunrise"
        case "dhuhr", "zuhur", "jumuah":
            return "sun.max.fill"
        case "asr", "asar":
            return "sunset"
        case "maghrib", "magrib":
            return "sunset.fill"
        case "isha", "isyak":
            return "moon.stars"
        default:
            return nextPrayerEntry?.icon ?? "arrow.right.circle"
        }
    }
}

private struct ForYouCollapsedHeaderBar: View {
    let plan: ForYouDailyPlan
    let currentPrayerEntry: ForYouTimelineEntry?
    let nextPrayerEntry: ForYouTimelineEntry?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: currentPrayerEntry?.icon ?? "sunrise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ForYouPalette.ink)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentPrayerEntry?.title ?? (isMalayAppLanguage() ? "Subuh" : "Fajr"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(ForYouPalette.ink)
                            .lineLimit(1)

                        Text(plan.locationLine ?? shortDate)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(ForYouPalette.secondaryInk)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(nextPrayerEntry?.title ?? (isMalayAppLanguage() ? "Seterusnya" : "Next"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)
                        .lineLimit(1)

                    Text(nextPrayerTime)
                        .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(ForYouPalette.ink)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(ForYouPalette.stroke, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMalayAppLanguage() ? "Lompat ke bahagian waktu solat" : "Jump to prayer times section")
    }

    private var shortDate: String {
        ForYouFormatters.monthDay.string(from: plan.date)
    }

    private var nextPrayerTime: String {
        guard let nextPrayerEntry else { return "--:--" }
        return ForYouFormatters.shortTime.string(from: nextPrayerEntry.time)
    }
}

private struct ForYouExpandableWeatherCard: View {
    let plan: ForYouDailyPlan
    let isExpanded: Bool
    let onToggle: () -> Void

    @EnvironmentObject private var settings: Settings
    @State private var weatherSnapshot: ForYouWeatherSnapshot?
    @State private var appleWeatherDetails: ForYouAppleWeatherDetails?

    private struct PrayerWeatherRow: Identifiable {
        let id: String
        let title: String
        let time: Date
        let weather: ForYouPrayerWeather
    }

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 0) {
                weatherStrip

                if isExpanded {
                    expandedContent
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ForYouPalette.darkTile)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .clipShape(ForYouBottomRoundedShape(radius: 18))
            .overlay(
                ForYouBottomRoundedShape(radius: 18)
                    .stroke(isExpanded ? Color.white.opacity(0.06) : ForYouPalette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .task(id: weatherRequestKey) {
            await loadWeather()
        }
    }

    private var weatherStrip: some View {
        HStack(spacing: 0) {
            Text(isMalayAppLanguage() ? "Cuaca" : "Weather")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)

            Spacer()

            if isExpanded {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.88))
            } else if let weatherSnapshot {
                Text((isMalayAppLanguage() ? "Kini: " : "Now: ") + weatherSnapshot.temperatureText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(ForYouPalette.darkTile)
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let details = appleWeatherDetails {
                HStack(alignment: .top, spacing: 14) {
                    Text(details.temperatureText)
                        .font(.system(size: 34, weight: .light, design: .rounded))
                        .foregroundStyle(Color.white)

                    Image(systemName: details.symbolName)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.86))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(details.conditionText)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text("H:\(details.highTemperatureText)  L:\(details.lowTemperatureText)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.64))
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    appleWeatherMetric(title: isMalayAppLanguage() ? "Kelembapan" : "Humidity", value: "\(details.humidityPercent)%", icon: "humidity.fill")
                    appleWeatherMetric(title: "UV Index", value: details.uvIndexText, icon: "sun.max")
                    appleWeatherMetric(title: isMalayAppLanguage() ? "Terasa" : "Feels like", value: details.feelsLikeText, icon: "thermometer")
                }
            } else if let snapshot = weatherSnapshot {
                HStack(alignment: .center, spacing: 14) {
                    Text(snapshot.temperatureText)
                        .font(.system(size: 34, weight: .light, design: .rounded))
                        .foregroundStyle(Color.white)

                    Image(systemName: snapshot.symbolName)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.86))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.conditionText)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text(locationLine)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.64))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text(isMalayAppLanguage() ? "Memuatkan cuaca semasa..." : "Loading current weather...")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.78))
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.12))

            VStack(spacing: 10) {
                ForEach(expandedPrayerWeatherRows) { row in
                    HStack(spacing: 10) {
                        Image(systemName: row.weather.symbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.84))
                            .frame(width: 16)

                        Text(row.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)

                        Text(ForYouFormatters.shortTime.string(from: row.time))
                            .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.92))

                        Text("◔ \(row.weather.precipitationProbability)% \(isMalayAppLanguage() ? "hujan" : "rain")")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.68))

                        Spacer(minLength: 0)

                        Text("\(row.weather.temperatureCelsius)°C")
                            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color.white)
                    }
                }
            }
        }
    }

    private func appleWeatherMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.8))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.66))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var expandedPrayerWeatherRows: [PrayerWeatherRow] {
        if let appleWeatherDetails {
            return prayerWeatherRows(from: appleWeatherDetails.hourlyByHour)
        }
        return prayerWeatherRows(from: nil)
    }

    private func prayerWeatherRows(from hourlyByHour: [Int: ForYouPrayerWeather]?) -> [PrayerWeatherRow] {
        let rows = plan.timelineEntries.compactMap { entry -> PrayerWeatherRow? in
            guard let key = prayerWeatherKey(for: entry) else { return nil }
            let hour = Calendar.current.component(.hour, from: entry.time)
            guard let weather = hourlyByHour?[hour] ?? entry.weather else { return nil }
            return PrayerWeatherRow(
                id: key,
                title: weatherTitle(for: key),
                time: entry.time,
                weather: weather
            )
        }

        var deduped: [String: PrayerWeatherRow] = [:]
        for row in rows where deduped[row.id] == nil {
            deduped[row.id] = row
        }

        let orderedKeys = ["fajr", "sunrise", "dhuha", "dhuhr", "asr", "maghrib", "isha"]
        return orderedKeys.compactMap { deduped[$0] }
    }

    private func prayerWeatherKey(for entry: ForYouTimelineEntry) -> String? {
        let normalizedID = entry.id.lowercased()
        let normalizedTitle = entry.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedID.contains("-fajr-") || normalizedTitle == "subuh" || normalizedTitle == "fajr" {
            return "fajr"
        }
        if normalizedID.hasSuffix("-syuruk") || normalizedID.contains("-syuruk-") || normalizedID.hasSuffix("-shurooq") || normalizedTitle == "syuruk" || normalizedTitle == "shurooq" {
            return "sunrise"
        }
        if normalizedID.hasSuffix("-dhuha") || normalizedID.contains("-dhuha-") || normalizedTitle == "dhuha" {
            return "dhuha"
        }
        if normalizedID.contains("-dhuhr-") || normalizedTitle == "zuhur" || normalizedTitle == "dhuhr" || normalizedTitle == "jumuah" {
            return "dhuhr"
        }
        if normalizedID.contains("-asr-") || normalizedTitle == "asar" || normalizedTitle == "asr" {
            return "asr"
        }
        if normalizedID.contains("-maghrib-") || normalizedTitle == "magrib" || normalizedTitle == "maghrib" {
            return "maghrib"
        }
        if normalizedID.contains("-isha-") || normalizedTitle == "isya" || normalizedTitle == "isyak" || normalizedTitle == "isha" {
            return "isha"
        }
        return nil
    }

    private func weatherTitle(for key: String) -> String {
        switch key {
        case "fajr":
            return isMalayAppLanguage() ? "Subuh" : "Fajr"
        case "sunrise":
            return isMalayAppLanguage() ? "Syuruk" : "Shurooq"
        case "dhuha":
            return "Dhuha"
        case "dhuhr":
            return isMalayAppLanguage() ? "Zohor" : "Dhuhr"
        case "asr":
            return isMalayAppLanguage() ? "Asar" : "Asr"
        case "maghrib":
            return isMalayAppLanguage() ? "Maghrib" : "Maghrib"
        case "isha":
            return isMalayAppLanguage() ? "Isyak" : "Isha"
        default:
            return key
        }
    }

    private var locationLine: String {
        plan.locationLine ?? settings.currentPrayerAreaName ?? settings.currentLocation?.city ?? ""
    }

    private var weatherRequestKey: String {
        guard let location = settings.currentLocation else { return "weather-card-no-location" }
        return "\(location.latitude)|\(location.longitude)|\(Calendar.current.startOfDay(for: plan.date).timeIntervalSince1970)"
    }

    @MainActor
    private func loadWeather() async {
        guard let location = settings.currentLocation, location.latitude != 1000, location.longitude != 1000 else {
            weatherSnapshot = nil
            appleWeatherDetails = nil
            return
        }

        async let currentSnapshot = try? ForYouWeatherService.shared.fetchCurrentWeather(for: location)
        async let appleDetails = try? ForYouWeatherService.shared.appleWeatherDetails(for: location, on: plan.date)

        weatherSnapshot = await currentSnapshot
        appleWeatherDetails = await appleDetails
    }
}

private struct ForYouBottomRoundedShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(self.radius, min(rect.width, rect.height) / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()

        return path
    }
}

private struct ForYouTopRoundedShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(self.radius, min(rect.width, rect.height) / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

private enum ForYouDisplayedTimelineItem: Identifiable {
    case entry(ForYouTimelineEntry)
    case sunToggle(Date)

    var id: String {
        switch self {
        case .entry(let entry):
            return entry.id
        case .sunToggle(let time):
            return "sun-toggle-\(time.timeIntervalSince1970)"
        }
    }
}

private struct ForYouSunTimelineToggleRow: View {
    let time: Date
    let isExpanded: Bool
    let extendsToNext: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Text(ForYouFormatters.shortTime.string(from: time))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ForYouPalette.timePillFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(ForYouPalette.stroke, lineWidth: 1)
                            )
                    )

                Button(action: action) {
                    Image(systemName: isExpanded ? "minus" : "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ForYouPalette.ink)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .overlay(
                                    Circle()
                                        .stroke(ForYouPalette.stroke, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(ForYouPalette.stroke)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, extendsToNext ? 12 : 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(isMalayAppLanguage() ? "Jendela pagi" : "Morning window")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(ForYouPalette.ink)

                Text(
                    isExpanded
                        ? (isMalayAppLanguage() ? "Sembunyikan Syuruk, Ishraq dan Dhuha" : "Hide Syuruk, Ishraq and Dhuha")
                        : (isMalayAppLanguage() ? "Tunjuk Syuruk, Ishraq dan Dhuha" : "Show Syuruk, Ishraq and Dhuha")
                )
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ForYouPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ForYouPalette.softCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(ForYouPalette.stroke, lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ForYouDayView: View {
    static let prayerTimelineSectionID = "for-you-prayer-timeline-section"

    let viewModel: ForYouDayViewModel
    let greetingName: String?
    let completedIDs: Set<String>
    let onToggleCompletion: (String) -> Void
    let selection: ForYouPrayerCardSelection?
    let onSelectionChange: (ForYouPrayerCardSelection) -> Void
    let onScrollToPrayerTimeline: () -> Void

    @State private var selectedPageIndex: Int?
    @State private var showsExpandedSunEntries = false
    @State private var showsExpandedWeatherCard = false

    init(
        viewModel: ForYouDayViewModel,
        greetingName: String?,
        completedIDs: Set<String>,
        onToggleCompletion: @escaping (String) -> Void,
        selection: ForYouPrayerCardSelection?,
        onSelectionChange: @escaping (ForYouPrayerCardSelection) -> Void,
        onScrollToPrayerTimeline: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.greetingName = greetingName
        self.completedIDs = completedIDs
        self.onToggleCompletion = onToggleCompletion
        self.selection = selection
        self.onSelectionChange = onSelectionChange
        self.onScrollToPrayerTimeline = onScrollToPrayerTimeline
        _selectedPageIndex = State(initialValue: Self.resolveInitialPageIndex(for: viewModel.plan))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {

                VStack(spacing: 0) {
                    ForEach(Array(timelinePages.enumerated()), id: \.offset) { index, page in
                        pageContent(index: index, page: page)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .id(index)
                    }
                }

            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .clipped()
            .background(background)

            if viewModel.isLocked {
                Rectangle()
                    .fill(.black.opacity(usesSoftPreviewLock ? 0.04 : 0.14))
                    .blur(radius: usesSoftPreviewLock ? 0 : 16)

                VStack {
                    Spacer()
                    ForYouLockedLayer(reason: viewModel.plan.personalizationReason)
                    Spacer()
                }
                .padding(.horizontal, 24)
            }

        }
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .clipped()
        .scaleEffect(shouldBlurLockedContent ? 0.982 : 1)
        .opacity(shouldBlurLockedContent ? 0.92 : 1)
        .offset(y: -10)
        .blur(radius: shouldBlurLockedContent ? 7 : 0)
        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: viewModel.isLocked)
    }

    private var usesSoftPreviewLock: Bool {
        viewModel.isLocked && Calendar.current.isDateInTomorrow(viewModel.plan.date)
    }

    private var shouldBlurLockedContent: Bool {
        viewModel.isLocked && !usesSoftPreviewLock
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
            .fill(ForYouPalette.canvas)
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var footer: some View {
        EmptyView()
    }

    private var highlightedEntry: ForYouTimelineEntry? {
        guard let selectedPageIndex else {
            return viewModel.plan.timelineEntries.first
        }
        let page = timelinePages.indices.contains(selectedPageIndex) ? timelinePages[selectedPageIndex] : nil
        if let focused = page?.compactMap(entry(from:)).first(where: { $0.id == focusedEntryID }) {
            return focused
        }
        return page?.compactMap(entry(from:)).first ?? viewModel.plan.timelineEntries.first
    }

    private func highlightedEntry(for pageIndex: Int) -> ForYouTimelineEntry? {
        let page = timelinePages.indices.contains(pageIndex) ? timelinePages[pageIndex] : nil
        if let focused = page?.compactMap(entry(from:)).first(where: { $0.id == focusedEntryID }) {
            return focused
        }
        return page?.compactMap(entry(from:)).first ?? viewModel.plan.timelineEntries.first
    }

    private var initialSegmentIndex: Int {
        guard !viewModel.plan.timelineEntries.isEmpty else { return 0 }
        guard Calendar.current.isDateInToday(viewModel.plan.date) else {
            return 0
        }
        let now = Date()
        return viewModel.plan.timelineEntries.lastIndex(where: { $0.time <= now }) ?? 0
    }

    private var focusedEntryID: String? {
        guard !displayedPrayerEntries.isEmpty else { return nil }
        if Calendar.current.isDateInToday(viewModel.plan.date) {
            let now = Date()
            return (displayedPrayerEntries.last(where: { $0.time <= now }) ?? displayedPrayerEntries.first)?.id
        }
        return displayedPrayerEntries.first?.id
    }

    private var firstPageEntryCount: Int { 1 }
    private var subsequentPageEntryCount: Int { 2 }

    private var displayedTimelineItems: [ForYouDisplayedTimelineItem] {
        let entries = viewModel.plan.timelineEntries
        guard !entries.isEmpty else { return [] }

        var items: [ForYouDisplayedTimelineItem] = []
        var insertedToggle = false
        for entry in entries {
            if isCollapsibleSunEntry(entry) {
                if !insertedToggle {
                    items.append(.sunToggle(entry.time))
                    insertedToggle = true
                }
                if showsExpandedSunEntries {
                    items.append(.entry(entry))
                }
                continue
            }
            items.append(.entry(entry))
        }
        return items
    }

    private var displayedPrayerEntries: [ForYouTimelineEntry] {
        displayedTimelineItems.compactMap(entry(from:)).filter { $0.kind == .prayer }
    }

    private var timelinePages: [[ForYouDisplayedTimelineItem]] {
        let entries = displayedTimelineItems
        guard !entries.isEmpty else { return [] }

        var pages: [[ForYouDisplayedTimelineItem]] = []
        var start = 0

        let firstCount = min(firstPageEntryCount, entries.count)
        pages.append(Array(entries[start..<start + firstCount]))
        start += firstCount

        while start < entries.count {
            let end = min(start + subsequentPageEntryCount, entries.count)
            pages.append(Array(entries[start..<end]))
            start = end
        }

        return pages
    }

    private var dateLine: String {
        ForYouFormatters.monthDay.string(from: viewModel.plan.date)
    }

    private var yearLine: String {
        ForYouFormatters.year.string(from: viewModel.plan.date)
    }

    private var weekdayLine: String {
        ForYouFormatters.weekday.string(from: viewModel.plan.date)
    }

    private var greetingLine: String {
        let trimmedName = greetingName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedName.isEmpty else { return "Hello!" }
        return "Hello, \(trimmedName)!"
    }

    private var currentPrayerEntry: ForYouTimelineEntry? {
        let prayerEntries = viewModel.plan.timelineEntries.filter { $0.kind == .prayer }
        guard !prayerEntries.isEmpty else { return nil }

        if Calendar.current.isDateInToday(viewModel.plan.date) {
            let now = Date()
            return prayerEntries.last(where: { $0.time <= now }) ?? prayerEntries.first
        }

        return prayerEntries.first
    }

    private var nextPrayerEntry: ForYouTimelineEntry? {
        let prayerEntries = viewModel.plan.timelineEntries.filter { $0.kind == .prayer }
        guard !prayerEntries.isEmpty else { return nil }

        if Calendar.current.isDateInToday(viewModel.plan.date) {
            let now = Date()
            return prayerEntries.first(where: { $0.time > now })
        }

        return prayerEntries.dropFirst().first
    }

    private var prayerEntries: [ForYouTimelineEntry] {
        displayedPrayerEntries
    }

    private var defaultPrayerSelection: ForYouPrayerCardSelection? {
        guard !prayerEntries.isEmpty else { return nil }

        if let focusedEntryID, prayerEntries.contains(where: { $0.id == focusedEntryID }) {
            return .main(focusedEntryID)
        }

        return prayerEntries.first.map { .main($0.id) }
    }

    private var prayerSelection: ForYouPrayerCardSelection? {
        if let selection,
           prayerCardSequence.contains(selection) {
            return selection
        }

        return defaultPrayerSelection
    }

    private var prayerCardSequence: [ForYouPrayerCardSelection] {
        prayerEntries.flatMap { entry in
            [ForYouPrayerCardSelection.main(entry.id)] + forYouPrayerTabs(for: entry).map { .tab(entry.id, $0) }
        }
    }

    private func setPrayerSelection(_ selection: ForYouPrayerCardSelection) {
        onSelectionChange(selection)
    }

    @ViewBuilder
    private func pageContent(index: Int, page: [ForYouDisplayedTimelineItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if index == 0 {
                VStack(alignment: .leading, spacing: 0) {
                    Text(greetingLine)
                        .font(ForYouTypography.playfairHeadline(size: 31))
                        .foregroundStyle(ForYouPalette.ink)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 10)
                        .padding(.bottom, 10)

                    Button(action: onScrollToPrayerTimeline) {
                        ForYouSummaryHeader(
                            plan: viewModel.plan,
                            currentPrayerEntry: currentPrayerEntry,
                            nextPrayerEntry: nextPrayerEntry
                        )
                    }
                    .buttonStyle(ForYouHeroJumpButtonStyle())
                    .accessibilityLabel(isMalayAppLanguage() ? "Lompat ke bahagian waktu solat" : "Jump to prayer times section")

                    ForYouExpandableWeatherCard(
                        plan: viewModel.plan,
                        isExpanded: showsExpandedWeatherCard,
                        onToggle: {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                showsExpandedWeatherCard.toggle()
                            }
                        }
                    )
                    .padding(.top, -6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekdayLine)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(ForYouPalette.ink)
                            .padding(.top, 10)
                        if let location = viewModel.plan.locationLine {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(ForYouPalette.secondaryInk)
                                .lineLimit(1)
                        }
                    }

                    Text(isMalayAppLanguage() ? "Hari penuh" : "Full day")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)
                        .padding(.top, 10)
                        .id(Self.prayerTimelineSectionID)
                }
            }

            ForEach(Array(page.enumerated()), id: \.element.id) { itemIndex, item in
                VStack(alignment: .leading, spacing: 0) {
                    if let entry = entry(from: item) {
                        if entry.kind == .prayer {
                            ForYouPrayerTimelineEntryView(
                                entry: entry,
                                date: viewModel.plan.date,
                                isFocused: entry.id == focusedEntryID,
                                extendsToNext: itemIndex != page.count - 1,
                                selection: prayerSelection ?? .main(entry.id),
                                onSelectionChange: { selection in
                                    setPrayerSelection(selection)
                                }
                            )
                        } else {
                            ForYouTimelineEntryView(
                                entry: entry,
                                isFocused: entry.id == focusedEntryID,
                                extendsToNext: itemIndex != page.count - 1
                            )
                        }
                    } else if case .sunToggle(let time) = item {
                        ForYouSunTimelineToggleRow(
                            time: time,
                            isExpanded: showsExpandedSunEntries,
                            extendsToNext: itemIndex != page.count - 1,
                            action: {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                    showsExpandedSunEntries.toggle()
                                }
                            }
                        )
                    }
                }
                .id(item.id)
                .transition(
                    itemIsAnimatedSunEntry(item)
                        ? .move(edge: .top).combined(with: .opacity)
                        : .identity
                )
            }
        }
        .padding(.bottom, 16)
    }

    private func entry(from item: ForYouDisplayedTimelineItem) -> ForYouTimelineEntry? {
        if case .entry(let entry) = item { return entry }
        return nil
    }

    private func isCollapsibleSunEntry(_ entry: ForYouTimelineEntry) -> Bool {
        let normalizedID = entry.id.lowercased()
        return normalizedID.hasSuffix("-syuruk")
            || normalizedID.contains("-syuruk-")
            || normalizedID.hasSuffix("-ishraq")
            || normalizedID.contains("-ishraq-")
            || normalizedID.hasSuffix("-dhuha")
            || normalizedID.contains("-dhuha-")
    }

    private func itemIsAnimatedSunEntry(_ item: ForYouDisplayedTimelineItem) -> Bool {
        guard let entry = entry(from: item) else { return false }
        return isCollapsibleSunEntry(entry)
    }

    private static func resolveInitialPageIndex(for plan: ForYouDailyPlan) -> Int {
        let entries = plan.timelineEntries
        guard !entries.isEmpty else { return 0 }

        let initialSegmentIndex: Int
        if Calendar.current.isDateInToday(plan.date) {
            let now = Date()
            initialSegmentIndex = entries.lastIndex(where: { $0.time <= now }) ?? 0
        } else {
            initialSegmentIndex = 0
        }

        let firstPageEntryCount = 1
        let subsequentPageEntryCount = 2

        if initialSegmentIndex < firstPageEntryCount {
            return 0
        }

        let remainingIndex = initialSegmentIndex - firstPageEntryCount
        return 1 + (remainingIndex / subsequentPageEntryCount)
    }
}

private struct ForYouHeroJumpButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.982 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -0.35 : 0))
            .offset(y: configuration.isPressed ? -1 : 0)
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.14 : 0.08),
                radius: configuration.isPressed ? 18 : 10,
                x: 0,
                y: configuration.isPressed ? 10 : 5
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.24 : 0), lineWidth: 1)
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct ForYouVerticalPager<Content: View>: View {
    let count: Int
    @Binding var selectedIndex: Int
    let content: (Int) -> Content

    @GestureState private var dragOffset: CGFloat = 0

    init(
        count: Int,
        selectedIndex: Binding<Int>,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.count = count
        self._selectedIndex = selectedIndex
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let pageHeight = geometry.size.height

            ZStack(alignment: .top) {
                ForEach(0..<count, id: \.self) { index in
                    content(index)
                        .frame(width: geometry.size.width, height: pageHeight, alignment: .top)
                        .offset(y: CGFloat(index - selectedIndex) * pageHeight + dragOffset)
                        .opacity(abs(index - selectedIndex) <= 1 ? 1 : 0)
                        .allowsHitTesting(index == selectedIndex)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        let threshold = pageHeight * 0.16
                        var nextIndex = selectedIndex

                        if value.translation.height <= -threshold {
                            nextIndex = min(selectedIndex + 1, count - 1)
                        } else if value.translation.height >= threshold {
                            nextIndex = max(selectedIndex - 1, 0)
                        }

                        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                            selectedIndex = nextIndex
                        }
                    }
            )
        }
    }
}

private struct ForYouPrayerTrackerCard: View {
    let date: Date
    let refreshToken: UUID
    let onStatusChange: (PrayerTrackerPrayer, PrayerTrackerStatus) -> Void

    @EnvironmentObject private var settings: Settings
    @State private var weatherSnapshot: ForYouWeatherSnapshot?

    private struct TimelineItem: Identifiable {
        let prayer: PrayerTrackerPrayer
        let time: Date?
        let status: PrayerTrackerStatus
        let isCurrent: Bool

        var id: PrayerTrackerPrayer { prayer }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isMalayAppLanguage() ? "Penjejak Solat" : "Prayer Tracker")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ForYouPalette.ink)

                    if let weatherSnapshot {
                        HStack(spacing: 8) {
                            Image(systemName: weatherSnapshot.symbolName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.teal)
                            Text("\(weatherSnapshot.temperatureText) • \(weatherSnapshot.conditionText)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(ForYouPalette.secondaryInk)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(ForYouFormatters.monthDay.string(from: date))
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundStyle(ForYouPalette.ink)

                        Text(ForYouFormatters.year.string(from: date))
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(ForYouPalette.secondaryInk.opacity(0.6))
                    }

                    Text(ForYouFormatters.weekday.string(from: date))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    Text("\(PrayerTrackerStore.completedCount(on: date))/\(PrayerTrackerPrayer.allCases.count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.green)

                    ProgressView(
                        value: Double(PrayerTrackerStore.completedCount(on: date)),
                        total: Double(PrayerTrackerPrayer.allCases.count)
                    )
                    .tint(.green)
                    .frame(width: 92)
                }
            }

            Text(isMalayAppLanguage() ? "Ikut garis masa solat hari ini. Ketik satu baris untuk pusing status: belum, selesai, atau tertinggal." : "Follow today’s prayer timeline. Tap any row to cycle between pending, done, and missed.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ForYouPalette.secondaryInk)

            VStack(spacing: 10) {
                ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                    Button {
                        settings.hapticFeedback()
                        onStatusChange(item.prayer, nextStatus(after: item.status))
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(color(for: item.status))
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(item.isCurrent ? .green : color(for: item.status).opacity(0.22), lineWidth: item.isCurrent ? 5 : 1)
                                            .frame(width: item.isCurrent ? 20 : 12, height: item.isCurrent ? 20 : 12)
                                    )
                                    .padding(.top, 4)

                                if index < timelineItems.count - 1 {
                                    Rectangle()
                                        .fill(color(for: item.status).opacity(item.status == .pending ? 0.20 : 0.32))
                                        .frame(width: 2)
                                        .frame(maxHeight: .infinity)
                                        .padding(.top, 6)
                                }
                            }
                            .frame(width: 20)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(item.prayer.localizedTitle)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(ForYouPalette.ink)

                                    if item.isCurrent {
                                        Text(isMalayAppLanguage() ? "Sekarang" : "Now")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(.green)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(Color.green.opacity(0.12))
                                            )
                                    }

                                    Spacer(minLength: 0)

                                    Text(timeLabel(for: item.time))
                                        .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                                        .foregroundStyle(ForYouPalette.secondaryInk)
                                }

                                Text(label(for: item.status))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(color(for: item.status))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(color(for: item.status).opacity(item.isCurrent ? 0.14 : 0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(color(for: item.status).opacity(item.isCurrent ? 0.32 : 0.18), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .id(refreshToken)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(ForYouPalette.stroke, lineWidth: 1)
                )
        )
        .task(id: weatherRequestKey) {
            await loadWeather()
        }
    }

    private func nextStatus(after status: PrayerTrackerStatus) -> PrayerTrackerStatus {
        switch status {
        case .pending: return .prayed
        case .prayed: return .missed
        case .missed: return .pending
        }
    }

    private func label(for status: PrayerTrackerStatus) -> String {
        switch status {
        case .pending:
            return isMalayAppLanguage() ? "Belum dikemas kini" : "Not updated"
        case .prayed:
            return isMalayAppLanguage() ? "Selesai" : "Done"
        case .missed:
            return isMalayAppLanguage() ? "Tertinggal" : "Missed"
        }
    }

    private func color(for status: PrayerTrackerStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .prayed: return .green
        case .missed: return .red
        }
    }

    private var timelineItems: [TimelineItem] {
        let prayers = prayerLookup
        let now = Date()

        return PrayerTrackerPrayer.allCases.enumerated().map { index, trackerPrayer in
            let time = prayers[trackerPrayer]
            let nextTime = PrayerTrackerPrayer.allCases.dropFirst(index + 1).compactMap { prayers[$0] }.first
            let isCurrent = isSameDayAsToday && {
                guard let time else { return false }
                if let nextTime {
                    return now >= time && now < nextTime
                }
                return now >= time
            }()

            return TimelineItem(
                prayer: trackerPrayer,
                time: time,
                status: PrayerTrackerStore.status(for: trackerPrayer, on: date),
                isCurrent: isCurrent
            )
        }
    }

    private var prayerLookup: [PrayerTrackerPrayer: Date] {
        let prayers = settings.getPrayerTimes(for: date, fullPrayers: true)
            ?? settings.getPrayerTimes(for: date)
            ?? []

        return Dictionary(uniqueKeysWithValues: PrayerTrackerPrayer.allCases.compactMap { trackerPrayer in
            guard let prayer = prayers.first(where: { trackerPrayer.matches($0.nameTransliteration) }) else {
                return nil
            }
            return (trackerPrayer, prayer.time)
        })
    }

    private var weatherRequestKey: String {
        guard let location = settings.currentLocation else { return "no-location" }
        return "\(location.latitude)|\(location.longitude)|\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)"
    }

    private var isSameDayAsToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private func timeLabel(for time: Date?) -> String {
        guard let time else { return "--:--" }
        return ForYouFormatters.shortTime.string(from: time)
    }

    @MainActor
    private func loadWeather() async {
        guard let location = settings.currentLocation, location.latitude != 1000, location.longitude != 1000 else {
            weatherSnapshot = nil
            return
        }

        do {
            weatherSnapshot = try await ForYouWeatherService.shared.fetchCurrentWeather(for: location)
        } catch {
            weatherSnapshot = nil
        }
    }
}

private extension PrayerTrackerPrayer {
    func matches(_ rawPrayerName: String) -> Bool {
        Self.resolve(from: rawPrayerName) == self
    }
}

struct ForYouRootView: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var revenueCat: RevenueCatManager
    @EnvironmentObject private var bottomBarVisibility: BottomBarVisibilityController
    @AppStorage("forYou.prayerTrackerPromptVisible") private var prayerTrackerPromptVisible = false
    @StateObject private var viewModel = ForYouFeedViewModel()
    @State private var selectedPrayerCard: ForYouPrayerCardSelection?
    @State private var scrollTarget: (scrollID: String, token: UUID?)?
    @State private var scrollOffset: CGFloat = 0
    @State private var shouldAutoScrollOnAppear = ForYouSessionStore.shouldAutoScrollOnTodayAppear()
    private let onScrollOffsetChange: ((CGFloat) -> Void)?

    private let focusScrollAnchor = UnitPoint(x: 0.5, y: 0.18)

    init(onScrollOffsetChange: ((CGFloat) -> Void)? = nil) {
        self.onScrollOffsetChange = onScrollOffsetChange
    }

    var body: some View {
        ZStack {
            ForYouPalette.canvas.ignoresSafeArea()

            if viewModel.dayViewModels.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(ForYouPalette.ink)
                    Text(isMalayAppLanguage() ? "Menyusun hari kamu..." : "Preparing your day...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        if let todayItem = currentDayViewModel {
                            VStack(spacing: 0) {
                                ForYouDayView(
                                    viewModel: todayItem,
                                    greetingName: viewModel.profile.firstName,
                                    completedIDs: viewModel.completedIDs,
                                    onToggleCompletion: viewModel.toggleCompletion(for:),
                                    selection: prayerSelection,
                                    onSelectionChange: { selectedPrayerCard = $0 },
                                    onScrollToPrayerTimeline: {
                                        settings.hapticFeedback()
                                        if let currentPrayerSelection {
                                            selectedPrayerCard = currentPrayerSelection
                                        }
                                        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                                            proxy.scrollTo(
                                                currentPrayerSelection?.entryID ?? ForYouDayView.prayerTimelineSectionID,
                                                anchor: focusScrollAnchor
                                            )
                                        }
                                    }
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .background(
                        ScrollOffsetObserver { offset in
                            scrollOffset = offset
                            onScrollOffsetChange?(offset)
                        }
                    )
                    .onAppear {
                        onScrollOffsetChange?(0)
                        if shouldAutoScrollOnAppear,
                           !viewModel.showOnboarding,
                           let id = currentPrayerSelection?.entryID ?? currentDayViewModel?.focusedEntryID {
                            selectedPrayerCard = .main(id)
                            bottomBarVisibility.suppressNextHide()
                            // Seed scrollTarget.scrollID so the first button press
                            // cycles relative to the auto-scrolled card, not index 0.
                            // token is nil so the onChange observer does NOT fire.
                            scrollTarget = (scrollID: id, token: nil)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo(id, anchor: focusScrollAnchor)
                                }
                            }
                        }
                    }
                    .onChange(of: scrollTarget?.token) { _ in
                        guard let scrollID = scrollTarget?.scrollID else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                            proxy.scrollTo(scrollID, anchor: focusScrollAnchor)
                        }
                    }
                }
            }

            if dimmedOverlayVisible {
                Color.black
                    .opacity(viewModel.showOnboarding ? 0.60 : 0.48)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(15)
            }
        }
        .allowsHitTesting(!viewModel.showOnboarding && !prayerTrackerPromptVisible)
        .overlay(alignment: .top) {
            if let todayItem = currentDayViewModel, !viewModel.showOnboarding {
                ForYouCollapsedHeaderBar(
                    plan: todayItem.plan,
                    currentPrayerEntry: currentPrayerEntry,
                    nextPrayerEntry: nextPrayerEntry,
                    onTap: scrollToPrayerTimeline
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .offset(y: collapsedHeaderVisible ? 0 : -18)
                .opacity(collapsedHeaderVisible ? 1 : 0)
                .allowsHitTesting(collapsedHeaderVisible)
                .animation(.easeOut(duration: 0.2), value: collapsedHeaderVisible)
                .zIndex(20)
            }
        }
//        .overlay(alignment: .bottom) {
//            if !prayerCardSequence.isEmpty, !viewModel.showOnboarding {
//                HStack(spacing: 10) {
//                    pageCycleControlButton(systemName: "chevron.left") {
//                        bottomBarVisibility.suppressNextShow()
//                        cyclePrayerSelection(direction: -1)
//                    }
//
//                    pageCycleControlButton(systemName: "chevron.right") {
//                        bottomBarVisibility.suppressNextShow()
//                        cyclePrayerSelection(direction: 1)
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.vertical, 10)
//                .background(
//                    Capsule(style: .continuous)
//                        .fill(Color(uiColor: .secondarySystemBackground))
//                        .overlay(
//                            Capsule(style: .continuous)
//                                .stroke(ForYouPalette.stroke, lineWidth: 1)
//                        )
//                )
//                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 4)
//                .padding(.bottom, bottomBarVisibility.isHidden ? 18 : 104)
//                .zIndex(10)
//                .animation(.easeOut(duration: 0.18), value: bottomBarVisibility.isHidden)
//            }
//        }
        .overlay {
            if viewModel.showOnboarding {
                ForYouSwipeOnboardingView(
                    initialProfile: viewModel.profile,
                    currentPrayerTitle: currentPrayerEntry?.title ?? (isMalayAppLanguage() ? "Solat" : "Prayer"),
                    currentPrayerIcon: currentPrayerEntry?.icon ?? "sparkles",
                    onComplete: { profile in
                        viewModel.saveProfile(profile, settings: settings, hasPremiumAccess: hasPremiumAccess)
                    }
                )
                .environmentObject(settings)
                .zIndex(30)
            }
        }
        .task {
            refresh()
        }
        .onChange(of: settings.currentPrayer?.id) { _ in refresh() }
        .onChange(of: settings.nextPrayer?.id) { _ in refresh() }
        .onChange(of: settings.currentLocation?.city) { _ in refresh() }
        .onChange(of: revenueCat.hasBuyMeKopi) { _ in refresh() }
    }

    private var dimmedOverlayVisible: Bool {
        viewModel.showOnboarding || prayerTrackerPromptVisible
    }

    private var hasPremiumAccess: Bool {
        revenueCat.hasBuyMeKopi || revenueCat.hasPremiumWidgetsUnlocked
    }

    private var currentDayViewModel: ForYouDayViewModel? {
        viewModel.dayViewModels.first(where: { Calendar.current.isDateInToday($0.plan.date) })
            ?? viewModel.dayViewModels.first
    }

    private var currentPrayerEntry: ForYouTimelineEntry? {
        currentDayViewModel?.plan.timelineEntries
            .filter { $0.kind == .prayer }
            .last(where: { $0.time <= Date() })
        ?? currentDayViewModel?.plan.timelineEntries.first(where: { $0.kind == .prayer })
    }

    private var nextPrayerEntry: ForYouTimelineEntry? {
        guard let entries = currentDayViewModel?.plan.timelineEntries.filter({ $0.kind == .prayer }),
              !entries.isEmpty else { return nil }

        return entries.first(where: { $0.time > Date() }) ?? entries.last
    }

    private var collapsedHeaderVisible: Bool {
        scrollOffset > 64
    }

    private var prayerEntries: [ForYouTimelineEntry] {
        currentDayViewModel?.plan.timelineEntries.filter { $0.kind == .prayer } ?? []
    }

    private var defaultPrayerSelection: ForYouPrayerCardSelection? {
        guard !prayerEntries.isEmpty else { return nil }

        if let focusedEntryID = currentDayViewModel?.focusedEntryID,
           prayerEntries.contains(where: { $0.id == focusedEntryID }) {
            return .main(focusedEntryID)
        }

        return prayerEntries.first.map { .main($0.id) }
    }

    private var currentPrayerSelection: ForYouPrayerCardSelection? {
        guard !prayerEntries.isEmpty else { return nil }

        if let currentPrayer = prayerEntries.last(where: { $0.time <= Date() }) {
            return .main(currentPrayer.id)
        }

        return prayerEntries.first.map { .main($0.id) }
    }

    private var prayerSelection: ForYouPrayerCardSelection? {
        if let selectedPrayerCard,
           prayerCardSequence.contains(selectedPrayerCard) {
            return selectedPrayerCard
        }

        return defaultPrayerSelection
    }

    private func scrollToPrayerTimeline() {
        settings.hapticFeedback()
        if let currentPrayerSelection {
            selectedPrayerCard = currentPrayerSelection
        }
        scrollTarget = (
            scrollID: currentPrayerSelection?.entryID ?? ForYouDayView.prayerTimelineSectionID,
            token: UUID()
        )
    }

    // Unified ordered sequence of every focusable item in the feed:
    // prayer main card → wirid strip → doa strip → zikir card → next prayer → …
    private enum ScrollItem: Equatable {
        case prayer(ForYouPrayerCardSelection)
        case zikir(String) // entry.id

        var scrollID: String {
            switch self {
            case .prayer(let sel): return sel.scrollID
            case .zikir(let id): return id
            }
        }

        var prayerSelection: ForYouPrayerCardSelection? {
            if case .prayer(let sel) = self { return sel }
            return nil
        }
    }

    private var scrollSequence: [ScrollItem] {
        guard let vm = currentDayViewModel else { return [] }
        var result: [ScrollItem] = []
        for entry in vm.plan.timelineEntries {
            switch entry.kind {
            case .prayer:
                result.append(.prayer(.main(entry.id)))
                for tab in forYouPrayerTabs(for: entry) {
                    result.append(.prayer(.tab(entry.id, tab)))
                }
            case .zikir:
                result.append(.zikir(entry.id))
            }
        }
        return result
    }

    private var prayerCardSequence: [ForYouPrayerCardSelection] {
        prayerEntries.flatMap { entry in
            [ForYouPrayerCardSelection.main(entry.id)] + forYouPrayerTabs(for: entry).map { .tab(entry.id, $0) }
        }
    }

    private func cyclePrayerSelection(direction: Int) {
        guard !scrollSequence.isEmpty else { return }

        // Find where we currently are in the unified sequence.
        let currentScrollID = scrollTarget?.scrollID ?? scrollSequence.first?.scrollID ?? ""
        let currentIndex = scrollSequence.firstIndex(where: { $0.scrollID == currentScrollID }) ?? 0
        let nextIndex = (currentIndex + direction + scrollSequence.count) % scrollSequence.count
        let next = scrollSequence[nextIndex]

        // Scroll to the stable anchor first, then expand the prayer tab after
        // scroll commits — prevents layout shift overshoot.
        scrollTarget = (scrollID: next.scrollID, token: UUID())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.80)) {
                // nil collapses any open tab when landing on a zikir card.
                selectedPrayerCard = next.prayerSelection
            }
        }
    }

    private func pageCycleControlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ForYouPalette.ink)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(
                            Circle()
                                .stroke(ForYouPalette.stroke, lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func refresh() {
        viewModel.configure(settings: settings, hasPremiumAccess: hasPremiumAccess)
    }
}

private struct ForYouSwipeOnboardingView: View {
    let initialProfile: ForYouUserProfile
    let currentPrayerTitle: String
    let currentPrayerIcon: String
    let onComplete: (ForYouUserProfile) -> Void

    @EnvironmentObject private var settings: Settings
    @AppStorage("forYou.didSeeSwipeHint.v1") private var didSeeSwipeHint = false
    @FocusState private var isNameFocused: Bool

    @State private var cardIndex = 0
    @State private var draftName: String
    @State private var selectedReminderStyle: ForYouReminderStyle
    @State private var wantsPrayerTrackerCard: Bool?
    @State private var swipeOffset: CGFloat = 0
    @State private var demoOffset: CGFloat = 0
    @State private var swipeDecision: PrayerTrackerStatus?
    @State private var textPhase = false
    @State private var showConfetti = false

    init(
        initialProfile: ForYouUserProfile,
        currentPrayerTitle: String,
        currentPrayerIcon: String,
        onComplete: @escaping (ForYouUserProfile) -> Void
    ) {
        self.initialProfile = initialProfile
        self.currentPrayerTitle = currentPrayerTitle
        self.currentPrayerIcon = currentPrayerIcon
        self.onComplete = onComplete
        _draftName = State(initialValue: initialProfile.firstName ?? "")
        _selectedReminderStyle = State(initialValue: initialProfile.reminderStyle ?? .gentle)
        _wantsPrayerTrackerCard = State(initialValue: initialProfile.wantsPrayerTrackerCard)
    }

    private enum CardKind: Int, CaseIterable {
        case intro
        case name
        case reminderStyle
        case prayerTracker
        case prayerCheckIn

        var isSwipeable: Bool {
            switch self {
            case .prayerTracker, .prayerCheckIn: true
            case .intro, .name, .reminderStyle: false
            }
        }
    }

    private var currentCard: CardKind {
        CardKind(rawValue: cardIndex) ?? .intro
    }

    private var canAdvanceCurrentCard: Bool {
        switch currentCard {
        case .intro:
            true
        case .name:
            !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .reminderStyle:
            true
        case .prayerTracker, .prayerCheckIn:
            false
        }
    }

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayName: String {
        trimmedName.isEmpty ? "Rizhan" : trimmedName
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()

            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(CardKind.allCases, id: \.rawValue) { kind in
                        Capsule(style: .continuous)
                            .fill(kind.rawValue <= cardIndex ? settings.accentColor.color : Color.primary.opacity(0.12))
                            .frame(width: kind.rawValue == cardIndex ? 26 : 8, height: 6)
                            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: cardIndex)
                    }
                }
                .padding(.top, 16)

                ZStack {
                    if cardIndex + 1 < CardKind.allCases.count {
                        cardView(for: CardKind(rawValue: cardIndex + 1) ?? .prayerCheckIn, isBackground: true)
                            .scaleEffect(0.94)
                            .offset(y: 14)
                            .opacity(0.35)
                    }

                    onboardingForegroundCard
                }
                .frame(maxWidth: 430)

                if !currentCard.isSwipeable && currentCard != .name {
                    Button(action: advanceButtonTapped) {
                        Text(buttonLabel)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(canAdvanceCurrentCard ? settings.accentColor.color : Color.primary.opacity(0.14))
                            )
                    }
                    .disabled(!canAdvanceCurrentCard)
                    .buttonStyle(.plain)
                    .frame(maxWidth: 430)
                } else {
                    Text(isMalayAppLanguage() ? "Leret kiri untuk Tidak, kanan untuk Ya" : "Swipe left for No, right for Yes")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.secondary)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 20)

            if showConfetti {
                ForYouConfettiBurstView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            updateTextPhase(for: currentCard)
        }
        .onChange(of: cardIndex) { _ in
            updateTextPhase(for: currentCard)
        }
        .task(id: cardIndex) {
            isNameFocused = false
            runSwipeHintIfNeeded()
        }
    }

    @ViewBuilder
    private var onboardingForegroundCard: some View {
        let foreground = cardView(for: currentCard, isBackground: false)
            .offset(x: swipeOffset + demoOffset)
            .rotationEffect(.degrees(currentCard.isSwipeable ? Double((swipeOffset + demoOffset) / 24) : 0))

        if currentCard.isSwipeable {
            foreground.gesture(swipeGesture)
        } else {
            foreground
        }
    }

    private func cardView(for kind: CardKind, isBackground: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            switch kind {
            case .intro:
                animatedTextBlock(
                    eyebrow: "Today",
                    title: isMalayAppLanguage() ? "Selamat datang ke Today" : "Welcome to Today",
                    subtitle: isMalayAppLanguage() ? "Kami akan sediakan Today supaya terasa lebih peribadi, lebih lembut, dan lebih berguna setiap kali anda kembali." : "We’ll shape Today so it feels more personal, softer, and more useful every time you come back."
                )

                introRow(icon: "sparkles", text: isMalayAppLanguage() ? "Bina tab Today mengikut rentak anda" : "Shape Today around your rhythm")
                introRow(icon: "bell.badge", text: isMalayAppLanguage() ? "Laraskan nada peringatan mengikut nama anda" : "Tune reminder tone around your name")
                introRow(icon: "checkmark.circle", text: isMalayAppLanguage() ? "Tambah semakan ringkas untuk solat semasa" : "Add a quick check-in for the current prayer")

            case .name:
                animatedTextBlock(
                    eyebrow: isMalayAppLanguage() ? "Kad 2" : "Card 2",
                    title: isMalayAppLanguage() ? "Siapa nama anda?" : "What is your name?",
                    subtitle: isMalayAppLanguage() ? "Kami akan gunakan nama anda untuk menjadikan tab Today terasa lebih peribadi." : "We’ll use your name to make Today feel more personal."
                )

                TextField(isMalayAppLanguage() ? "Nama anda" : "Your name", text: $draftName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isNameFocused)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .onChange(of: draftName) { value in
                        if value.count > 15 {
                            draftName = String(value.prefix(15))
                        }
                    }

                HStack {
                    Spacer()
                    Text("\(draftName.count)/15")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.secondary)
                }

                Button(action: advanceButtonTapped) {
                    Text(isMalayAppLanguage() ? "Selesai" : "Done")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(canAdvanceCurrentCard ? settings.accentColor.color : Color.primary.opacity(0.14))
                        )
                }
                .disabled(!canAdvanceCurrentCard)
                .buttonStyle(.plain)

            case .reminderStyle:
                animatedTextBlock(
                    eyebrow: isMalayAppLanguage() ? "Kad 3" : "Card 3",
                    title: isMalayAppLanguage() ? "Bagaimana anda mahu diingatkan?" : "How should reminders sound?",
                    subtitle: isMalayAppLanguage() ? "Pilih gaya yang terasa paling sesuai untuk anda, \(displayName)." : "Choose the tone that feels right for you, \(displayName)."
                )

                VStack(spacing: 12) {
                    ForEach(ForYouReminderStyle.allCases) { style in
                        Button(action: { selectedReminderStyle = style }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(label(for: style))
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(Color.primary)
                                    Spacer()
                                    if selectedReminderStyle == style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(settings.accentColor.color)
                                    }
                                }

                                Text(example(for: style))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(selectedReminderStyle == style ? settings.accentColor.color.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

            case .prayerTracker:
                animatedTextBlock(
                    eyebrow: isMalayAppLanguage() ? "Kad 4" : "Card 4",
                    title: isMalayAppLanguage() ? "Mahukan kad penjejak solat?" : "Do you want a prayer tracker card?",
                    subtitle: isMalayAppLanguage() ? "Kami boleh tanya setiap kali anda buka tab ini, supaya anda cepat semak ritma hari anda." : "We can ask each time you open this tab, so you can quickly check in with your prayer rhythm."
                )

                swipeDecisionFooter

            case .prayerCheckIn:
                animatedTextBlock(
                    eyebrow: isMalayAppLanguage() ? "Kad 5" : "Card 5",
                    title: isMalayAppLanguage() ? "Sudahkah anda menunaikan \(currentPrayerTitle)?" : "Have you prayed \(currentPrayerTitle)?",
                    subtitle: isMalayAppLanguage() ? "Leret untuk jawab. Jika sudah, kami akan raikan sedikit." : "Swipe to answer. If you have, we’ll celebrate a little."
                )

                HStack(spacing: 14) {
                    Image(systemName: currentPrayerIcon)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(settings.accentColor.color)
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(settings.accentColor.color.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentPrayerTitle)
                            .font(.title3.weight(.semibold))
                        Text(isMalayAppLanguage() ? "Jawab dengan leretan yang ringkas." : "Answer with a simple swipe.")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()
                }

                swipeDecisionFooter
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 430, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(onboardingCardFill(for: kind, isBackground: isBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(onboardingCardStroke(for: kind, isBackground: isBackground), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(isBackground ? 0.05 : 0.10), radius: 24, x: 0, y: 12)
        .allowsHitTesting(!isBackground)
    }

    private var swipeDecisionFooter: some View {
        HStack {
            Label(isMalayAppLanguage() ? "Tidak" : "No", systemImage: "arrow.left")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(swipeDecision == .missed ? Color.white : Color.red.opacity(0.82))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(swipeDecision == .missed ? Color.red : Color.red.opacity(0.12))
                )
            Spacer()
            Label(isMalayAppLanguage() ? "Ya" : "Yes", systemImage: "arrow.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(swipeDecision == .prayed ? Color.white : Color.green.opacity(0.82))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(swipeDecision == .prayed ? Color.green : Color.green.opacity(0.12))
                )
        }
    }

    private func animatedTextBlock(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)
                .opacity(textPhase ? 1 : 0)
                .offset(y: textPhase ? 0 : 8)
                .animation(.easeOut(duration: 0.22), value: textPhase)

            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
                .opacity(textPhase ? 1 : 0)
                .offset(y: textPhase ? 0 : 10)
                .animation(.easeOut(duration: 0.26).delay(0.04), value: textPhase)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(textPhase ? 1 : 0)
                .offset(y: textPhase ? 0 : 12)
                .animation(.easeOut(duration: 0.28).delay(0.08), value: textPhase)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                swipeOffset = value.translation.width
                if value.translation.width > 32 {
                    swipeDecision = .prayed
                } else if value.translation.width < -32 {
                    swipeDecision = .missed
                } else {
                    swipeDecision = nil
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 90
                if value.translation.width > threshold {
                    completeSwipe(answer: true)
                } else if value.translation.width < -threshold {
                    completeSwipe(answer: false)
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        swipeOffset = 0
                        swipeDecision = nil
                    }
                }
            }
    }

    private func completeSwipe(answer: Bool) {
        let exitOffset: CGFloat = answer ? 520 : -520
        withAnimation(.easeIn(duration: 0.16)) {
            swipeOffset = exitOffset
        }

        let isLastCard = currentCard == .prayerCheckIn
        if isLastCard && answer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
                showConfetti = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            swipeOffset = 0
            swipeDecision = nil
            switch currentCard {
            case .prayerTracker:
                wantsPrayerTrackerCard = answer
                settings.hapticFeedback()
                cardIndex = min(cardIndex + 1, CardKind.allCases.count - 1)
            case .prayerCheckIn:
                settings.hapticFeedback()
                completeOnboarding(afterCelebration: answer)
            case .intro, .name, .reminderStyle:
                break
            }
        }
    }

    private func advanceButtonTapped() {
        guard canAdvanceCurrentCard else { return }
        settings.hapticFeedback()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            cardIndex = min(cardIndex + 1, CardKind.allCases.count - 1)
        }
    }

    private func completeOnboarding(afterCelebration: Bool) {
        let profile = completedProfile()
        let delay = afterCelebration ? 0.95 : 0.12
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onComplete(profile)
        }
    }

    private func completedProfile() -> ForYouUserProfile {
        var profile = initialProfile
        profile.firstName = trimmedName
        profile.reminderStyle = selectedReminderStyle
        profile.wantsPrayerTrackerCard = wantsPrayerTrackerCard
        profile.consistencyLevel = profile.consistencyLevel ?? (wantsPrayerTrackerCard == true ? .building : .beginner)
        profile.primaryGoal = profile.primaryGoal ?? .preserveFajr
        return profile
    }

    private func runSwipeHintIfNeeded() {
        guard currentCard == .prayerTracker, !didSeeSwipeHint else { return }
        didSeeSwipeHint = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.easeInOut(duration: 0.28)) {
                demoOffset = 56
            }
            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(.easeInOut(duration: 0.22)) {
                demoOffset = -26
            }
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                demoOffset = 0
            }
        }
    }

    private func updateTextPhase(for card: CardKind) {
        if card == .intro {
            textPhase = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                guard currentCard == .intro else { return }
                withAnimation(.easeOut(duration: 0.32)) {
                    textPhase = true
                }
            }
        } else {
            textPhase = true
        }
    }

    private var buttonLabel: String {
        switch currentCard {
        case .intro:
            return isMalayAppLanguage() ? "Jom mula" : "Let's go"
        case .name:
            return isMalayAppLanguage() ? "Selesai" : "Done"
        case .reminderStyle:
            return isMalayAppLanguage() ? "Teruskan" : "Continue"
        case .prayerTracker, .prayerCheckIn:
            return isMalayAppLanguage() ? "Teruskan" : "Continue"
        }
    }

    private func introRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(settings.accentColor.color)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(settings.accentColor.color.opacity(0.12))
                )

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func onboardingCardFill(for kind: CardKind, isBackground: Bool) -> Color {
        guard kind.isSwipeable, !isBackground else {
            return Color(uiColor: .systemBackground)
        }
        switch swipeDecision {
        case .prayed:
            return Color.green.opacity(0.18)
        case .missed:
            return Color.red.opacity(0.18)
        case .pending, .none:
            return Color(uiColor: .systemBackground)
        }
    }

    private func onboardingCardStroke(for kind: CardKind, isBackground: Bool) -> Color {
        guard kind.isSwipeable, !isBackground else {
            return Color.white.opacity(isBackground ? 0.18 : 0.35)
        }
        switch swipeDecision {
        case .prayed:
            return Color.green.opacity(0.42)
        case .missed:
            return Color.red.opacity(0.42)
        case .pending, .none:
            return Color.primary.opacity(0.08)
        }
    }

    private func label(for style: ForYouReminderStyle) -> String {
        switch style {
        case .gentle:
            isMalayAppLanguage() ? "Lembut" : "Gentle"
        case .balanced:
            isMalayAppLanguage() ? "Seimbang" : "Balanced"
        case .focused:
            isMalayAppLanguage() ? "Terus" : "Focused"
        }
    }

    private func example(for style: ForYouReminderStyle) -> String {
        switch style {
        case .gentle:
            return isMalayAppLanguage()
                ? "Masa untuk bertemu Pencipta anda, \(displayName)."
                : "Time to meet your Creator, \(displayName)."
        case .balanced:
            return isMalayAppLanguage()
                ? "Masuk waktu solat, \(displayName). Mari kembali dengan tenang."
                : "It is prayer time, \(displayName). Come back with calm."
        case .focused:
            return isMalayAppLanguage()
                ? "\(displayName), \(currentPrayerTitle) sedang berjalan."
                : "\(displayName), \(currentPrayerTitle) is in."
        }
    }
}

private struct ForYouConfettiBurstView: View {
    @State private var animate = false
    private let pieces = Array(0..<34)
    private let colors: [Color] = [.yellow, .orange, .green, .blue, .pink, .mint]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(colors[index % colors.count])
                        .frame(width: 6, height: 12)
                        .rotationEffect(.degrees(animate ? Double.random(in: 240...720) : 0))
                        .position(
                            x: animate ? CGFloat.random(in: 0...geometry.size.width) : geometry.size.width / 2,
                            y: animate ? geometry.size.height + 40 : -20
                        )
                        .opacity(animate ? 0.94 : 0)
                        .animation(
                            .easeOut(duration: Double.random(in: 1.0...1.8))
                                .delay(Double(index) * 0.014),
                            value: animate
                        )
                }
            }
        }
        .onAppear { animate = true }
    }
}

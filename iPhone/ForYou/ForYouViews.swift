import SwiftUI
import AVFoundation

private enum ForYouPalette {
    static let canvas = Color(red: 0.93, green: 0.93, blue: 0.94)
    static let card = Color.white.opacity(0.82)
    static let softCard = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let stroke = Color.black.opacity(0.08)
    static let ink = Color.black.opacity(0.92)
    static let secondaryInk = Color.black.opacity(0.58)
    static let accentSky = Color(red: 0.61, green: 0.83, blue: 0.93)
    static let darkTile = Color(red: 0.23, green: 0.26, blue: 0.30)
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
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineSpacing(3)
                        .lineLimit(isCompact ? 1 : nil)
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
                                .font(.custom(preferredQuranArabicFontName(settings: settings, size: 16), size: 16))
                                .foregroundStyle(ForYouPalette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
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
                            .fill(.white.opacity(0.75))
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
}

private struct ForYouTimelineRailView: View {
    let entry: ForYouTimelineEntry
    let isFocused: Bool
    let isCompact: Bool
    let extendsToNext: Bool

    @EnvironmentObject private var settings: Settings

    private var connectorGapBridge: CGFloat { extendsToNext ? 12 : 0 }

    var body: some View {
        VStack(spacing: 0) {
            Text(ForYouFormatters.shortTime.string(from: entry.time))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(ForYouPalette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, isCompact ? 6 : 7)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isFocused ? settings.accentColor.color.opacity(0.45) : ForYouPalette.stroke, lineWidth: 1)
                        )
                )

            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(isFocused ? settings.accentColor.color.opacity(0.28) : ForYouPalette.stroke)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .padding(.top, isCompact ? 4 : 6)
                .padding(.bottom, connectorGapBridge)
        }
    }
}

private struct ForYouPrayerTimelineEntryView: View {
    let entry: ForYouTimelineEntry
    let isFocused: Bool
    let extendsToNext: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForYouTimelineRailView(
                entry: entry,
                isFocused: isFocused,
                isCompact: false,
                extendsToNext: extendsToNext
            )

            ForYouPrayerStackedCards(entry: entry)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Prayer expandable tabs

private enum ForYouPrayerTab: String, CaseIterable {
    case wirid = "Wirid"
    case doa   = "Doa"

    var color: Color {
        switch self {
        case .wirid: return ForYouPalette.tabWirid
        case .doa:   return ForYouPalette.tabDoa
        }
    }

    var textColor: Color {
        switch self {
        case .wirid: return Color.black.opacity(0.85)
        case .doa:   return Color.white
        }
    }
}

// Each tab card slides up behind the card above it by this amount,
// so only the label strip peeks out at the bottom.
private let tabCardOverlap: CGFloat = 22
private let tabPeekHeight: CGFloat = 28

private struct ForYouPrayerStackedCards: View {
    let entry: ForYouTimelineEntry
    @State private var expandedTab: ForYouPrayerTab? = nil

    var body: some View {
        VStack(spacing: 0) {
            if expandedTab == nil {
                ForYouTimelineEntryContentCard(entry: entry)
                    .zIndex(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }

            ForEach(Array(orderedTabs.enumerated()), id: \.element) { index, tab in
                tabCard(tab: tab, index: index)
                    .padding(.top, topPadding(for: index))
                    .zIndex(zIndex(for: tab, index: index))
            }
        }
    }

    @ViewBuilder
    private func tabCard(tab: ForYouPrayerTab, index: Int) -> some View {
        let isExpanded = expandedTab == tab
        let hiddenHeight = isExpanded ? 0 : tabCardOverlap

        VStack(spacing: 0) {
            Color.clear.frame(height: hiddenHeight)

            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.80)) {
                    expandedTab = isExpanded ? nil : tab
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

            if isExpanded {
                ForYouPrayerTabPanel(entry: entry, tab: tab)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(tab.color)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var orderedTabs: [ForYouPrayerTab] {
        guard let expandedTab else { return ForYouPrayerTab.allCases }
        return [expandedTab] + ForYouPrayerTab.allCases.filter { $0 != expandedTab }
    }

    private func topPadding(for index: Int) -> CGFloat {
        if expandedTab == nil {
            return -tabCardOverlap
        }

        return index == 0 ? 0 : -tabCardOverlap
    }

    private func zIndex(for tab: ForYouPrayerTab, index: Int) -> Double {
        if let expandedTab, expandedTab == tab {
            return 20
        }

        return Double(ForYouPrayerTab.allCases.count - index)
    }
}

// The card-only portion of ForYouTimelineEntryView (right column content)
// used by ForYouPrayerStackedCards so the time pill / connector stays separate
private struct ForYouTimelineEntryContentCard: View {
    let entry: ForYouTimelineEntry
    @EnvironmentObject private var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .fixedSize(horizontal: false, vertical: true)

            if let arabicText = entry.arabicText {
                Text(arabicText)
                    .font(.custom(preferredQuranArabicFontName(settings: settings, size: 18), size: 18))
                    .foregroundStyle(ForYouPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineSpacing(3)
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
                            .font(.custom(preferredQuranArabicFontName(settings: settings, size: 16), size: 16))
                            .foregroundStyle(ForYouPalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
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
                        .fill(.white.opacity(0.75))
                )
            }

            if let reference = entry.reference {
                Text(reference)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)
                    .lineLimit(1)
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

private struct ForYouPrayerTabPanel: View {
    let entry: ForYouTimelineEntry
    let tab: ForYouPrayerTab

    @StateObject private var player = ForYouAudioPlayer()
    @EnvironmentObject private var settings: Settings

    private var content: (arabic: String, transliteration: String, meaning: String) {
        switch tab {
        case .wirid:
            return wiridContent(for: entry.title)
        case .doa:
            return doaContent(for: entry.title)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(isMalayAppLanguage() ? "Sesuai untuk waktu ini" : "Fits this time")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)

                Text(contentTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(ForYouPalette.ink)
                    .lineLimit(1)

                Text(content.arabic)
                    .font(.custom(preferredQuranArabicFontName(settings: settings, size: 18), size: 18))
                    .foregroundStyle(ForYouPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineSpacing(4)

                Text(content.meaning)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().opacity(0.35)

                Text(content.transliteration)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        player.togglePlayback(for: audioFileName(tab: tab, prayer: entry.title))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(tab.color)

                            Text(player.isPlaying ? (isMalayAppLanguage() ? "Berhenti" : "Pause") : (isMalayAppLanguage() ? "Dengar" : "Play"))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(ForYouPalette.secondaryInk)
                        }
                    }

                    Spacer()

                    if player.duration > 0 {
                        Text(player.progressText)
                            .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(ForYouPalette.secondaryInk)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.95))
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .onDisappear { player.stop() }
    }

    private var contentTitle: String {
        switch tab {
        case .wirid:
            return isMalayAppLanguage() ? "Wirid selepas solat" : "Post-prayer wirid"
        case .doa:
            return isMalayAppLanguage() ? "Doa selepas solat" : "Post-prayer dua"
        }
    }

    private func audioFileName(tab: ForYouPrayerTab, prayer: String) -> String {
        let base = prayer.lowercased().replacingOccurrences(of: " ", with: "_")
        return "\(base)_\(tab.rawValue.lowercased())"
    }

    private func wiridContent(for prayer: String) -> (arabic: String, transliteration: String, meaning: String) {
        let p = prayer.lowercased()
        if p.contains("fajr") || p.contains("subuh") {
            return (
                "أَسْتَغْفِرُ اللهَ وَأَتُوبُ إِلَيْهِ",
                "Astaghfirullaah wa atuubu ilayh",
                "I seek forgiveness from Allah and repent to Him. (×100)"
            )
        } else if p.contains("dhuhr") || p.contains("zuhur") {
            return (
                "سُبْحَانَ اللهِ وَبِحَمْدِهِ",
                "Subhaanallaahi wa bihamdih",
                "Glory be to Allah and His is the praise. (×100)"
            )
        } else if p.contains("asr") {
            return (
                "لَا إِلٰهَ إِلَّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ",
                "Laa ilaaha illallaahu wahdahu laa shareeka lah",
                "None has the right to be worshipped except Allah alone. (×100)"
            )
        } else if p.contains("maghrib") {
            return (
                "اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ",
                "Allaahumma antas-salaamu wa minkas-salaam",
                "O Allah, You are Peace and from You is peace. (×3)"
            )
        } else {
            return (
                "سُبْحَانَ اللهِ وَالْحَمْدُ لِلَّهِ وَاللهُ أَكْبَرُ",
                "Subhaanallaah, alhamdu lillaah, Allaahu akbar",
                "Glory be to Allah, Praise be to Allah, Allah is the Greatest. (×33 each)"
            )
        }
    }

    private func doaContent(for prayer: String) -> (arabic: String, transliteration: String, meaning: String) {
        let p = prayer.lowercased()
        if p.contains("fajr") || p.contains("subuh") {
            return (
                "اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا",
                "Allaahumma bika asbahnaa wa bika amsaynaa",
                "O Allah, by Your grace we enter the morning and by Your grace we enter the evening."
            )
        } else if p.contains("dhuhr") || p.contains("zuhur") {
            return (
                "رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي",
                "Rabbish-rah lee sadree wa yassir lee amree",
                "My Lord, expand my chest and ease my affairs."
            )
        } else if p.contains("asr") {
            return (
                "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ",
                "Allaahumma innee a'oodhu bika minal-hammi wal-hazan",
                "O Allah, I seek refuge in You from worry and grief."
            )
        } else if p.contains("maghrib") {
            return (
                "اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ أَصْبَحْنَا",
                "Allaahumma bika amsaynaa wa bika asbahnaa",
                "O Allah, by Your grace we enter the evening and by Your grace we enter the morning."
            )
        } else {
            return (
                "اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي",
                "Allaahumma innaka 'afuwwun tuhibbul-'afwa fa'fu 'annee",
                "O Allah, You are Pardoning and love pardon, so pardon me."
            )
        }
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
                        .fill(.white.opacity(0.75))
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
    let highlightedEntry: ForYouTimelineEntry?

    var body: some View {
        GeometryReader { geometry in
            let shellInset: CGFloat = 5
            let panelSpacing: CGFloat = 5
            let panelHeight = geometry.size.height - (shellInset * 2)
            let availableWidth = geometry.size.width - (shellInset * 2)
            let rightWidth = floor((availableWidth - panelSpacing) * 0.43)
            let leftWidth = availableWidth - panelSpacing - rightWidth
            let smallPanelHeight = floor((panelHeight - panelSpacing) / 2)

            HStack(spacing: panelSpacing) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: highlightedEntry?.icon ?? "sunrise")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(ForYouPalette.ink)
                            .frame(width: 34, height: 34, alignment: .topLeading)

                        Text(highlightedEntry?.title ?? (isMalayAppLanguage() ? "Subuh" : "Fajr"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(ForYouPalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.top, 1)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(shortWeekday)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(ForYouPalette.ink)

                        Text(plan.locationLine ?? "Kuala Lumpur")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundStyle(ForYouPalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .frame(width: leftWidth, height: panelHeight, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color(red: 0.83, green: 0.83, blue: 0.83))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(Color.black, lineWidth: 2)
                        )
                )

                VStack(spacing: panelSpacing) {
                    HStack(spacing: 7) {
                        Image(systemName: highlightedEntry?.momentType == .night ? "moon.stars" : "sun.max")
                            .font(.system(size: 15, weight: .medium))

                        Text(nextTime)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 15, weight: .medium))

                        Text(weatherText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(.white)
                    .frame(width: rightWidth, height: smallPanelHeight, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(ForYouPalette.darkTile)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    )
                }
            }
            .padding(shellInset)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.97))
        )
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .topLeading)
    }

    private var shortWeekday: String {
        ForYouFormatters.weekday.string(from: plan.date).prefix(3).capitalized
    }

    private var nextTime: String {
        guard let highlightedEntry else { return "--:--" }
        return ForYouFormatters.shortTime.string(from: highlightedEntry.time)
    }

    private var weatherText: String {
        "30°"
    }
}

private struct ForYouDayView: View {
    let viewModel: ForYouDayViewModel
    let completedIDs: Set<String>
    let onToggleCompletion: (String) -> Void

    @State private var selectedPageIndex: Int?

    init(
        viewModel: ForYouDayViewModel,
        completedIDs: Set<String>,
        onToggleCompletion: @escaping (String) -> Void
    ) {
        self.viewModel = viewModel
        self.completedIDs = completedIDs
        self.onToggleCompletion = onToggleCompletion
        _selectedPageIndex = State(initialValue: Self.resolveInitialPageIndex(for: viewModel.plan))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(dateLine)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.ink)

                    Text(yearLine)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk.opacity(0.55))
                }

                LazyVStack(spacing: 0) {
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
            .background(background)

            if viewModel.isLocked {
                Rectangle()
                    .fill(.black.opacity(0.14))
                    .blur(radius: 16)

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
        .scaleEffect(viewModel.isLocked ? 0.982 : 1)
        .opacity(viewModel.isLocked ? 0.92 : 1)
        .offset(y: -10)
        .blur(radius: viewModel.isLocked ? 7 : 0)
        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: viewModel.isLocked)
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
        if let focused = page?.first(where: { $0.id == focusedEntryID }) {
            return focused
        }
        return page?.first ?? viewModel.plan.timelineEntries.first
    }

    private func highlightedEntry(for pageIndex: Int) -> ForYouTimelineEntry? {
        let page = timelinePages.indices.contains(pageIndex) ? timelinePages[pageIndex] : nil
        if let focused = page?.first(where: { $0.id == focusedEntryID }) {
            return focused
        }
        return page?.first ?? viewModel.plan.timelineEntries.first
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
        guard viewModel.plan.timelineEntries.indices.contains(initialSegmentIndex) else { return nil }
        return viewModel.plan.timelineEntries[initialSegmentIndex].id
    }

    private var firstPageEntryCount: Int { 1 }
    private var subsequentPageEntryCount: Int { 2 }

    private var timelinePages: [[ForYouTimelineEntry]] {
        let entries = viewModel.plan.timelineEntries
        guard !entries.isEmpty else { return [] }

        var pages: [[ForYouTimelineEntry]] = []
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

    @ViewBuilder
    private func pageContent(index: Int, page: [ForYouTimelineEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if index == 0 {
                ForYouSummaryHeader(
                    plan: viewModel.plan,
                    highlightedEntry: highlightedEntry(for: index)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(weekdayLine)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.ink)
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
            }

            ForEach(page) { entry in
                VStack(alignment: .leading, spacing: 0) {
                    if entry.kind == .prayer {
                        ForYouPrayerTimelineEntryView(
                            entry: entry,
                            isFocused: entry.id == focusedEntryID,
                            extendsToNext: entry.id != page.last?.id
                        )
                    } else {
                        ForYouTimelineEntryView(
                            entry: entry,
                            isFocused: entry.id == focusedEntryID,
                            extendsToNext: entry.id != page.last?.id
                        )
                    }
                }
                .id(entry.id)
            }
        }
        .padding(.bottom, 16)
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

struct ForYouRootView: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var revenueCat: RevenueCatManager
    @StateObject private var viewModel = ForYouFeedViewModel()

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
                            ForYouDayView(
                                viewModel: todayItem,
                                completedIDs: viewModel.completedIDs,
                                onToggleCompletion: viewModel.toggleCompletion(for:)
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .onAppear {
                        if let id = currentDayViewModel?.focusedEntryID {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo(id, anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            refresh()
        }
        .onChange(of: settings.currentPrayer?.id) { _ in refresh() }
        .onChange(of: settings.nextPrayer?.id) { _ in refresh() }
        .onChange(of: settings.currentLocation?.city) { _ in refresh() }
        .onChange(of: revenueCat.hasBuyMeKopi) { _ in refresh() }
        .sheet(isPresented: $viewModel.showOnboarding) {
            ForYouOnboardingView(initialProfile: viewModel.profile) { profile in
                viewModel.saveProfile(profile, settings: settings, hasPremiumAccess: hasPremiumAccess)
            }
            .environmentObject(settings)
        }
        .preferredColorScheme(.light)
    }

    private var hasPremiumAccess: Bool {
        revenueCat.hasBuyMeKopi || revenueCat.hasPremiumWidgetsUnlocked
    }

    private var currentDayViewModel: ForYouDayViewModel? {
        viewModel.dayViewModels.first(where: { Calendar.current.isDateInToday($0.plan.date) })
            ?? viewModel.dayViewModels.first
    }

    private func refresh() {
        viewModel.configure(settings: settings, hasPremiumAccess: hasPremiumAccess)
    }
}

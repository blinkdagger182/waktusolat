import SwiftUI
import AVFoundation
import UIKit

private enum ForYouPalette {
    static let canvas    = Color(uiColor: .systemGroupedBackground)
    static let card      = Color(uiColor: .secondarySystemBackground).opacity(0.82)
    static let softCard  = Color(uiColor: .secondarySystemGroupedBackground)
    static let stroke    = Color.primary.opacity(0.08)
    static let ink       = Color.primary
    static let secondaryInk = Color.secondary
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
                            Text(arabicText)
                                .font(.custom(preferredQuranArabicFontName(settings: settings, size: 16), size: 16))
                                .foregroundStyle(ForYouPalette.ink)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .trailing)
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
    let selection: ForYouPrayerCardSelection
    let onSelectionChange: (ForYouPrayerCardSelection) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForYouTimelineRailView(
                entry: entry,
                isFocused: isFocused,
                isCompact: false,
                extendsToNext: extendsToNext
            )

            ForYouPrayerStackedCards(
                entry: entry,
                selection: selection,
                onSelectionChange: onSelectionChange
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Prayer expandable tabs

private enum ForYouPrayerTab: String, CaseIterable, Identifiable {
    case wirid = "Wirid"
    case doa   = "Doa"

    var id: String { rawValue }

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

// Each tab card slides up behind the card above it by this amount,
// so only the label strip peeks out at the bottom.
private let tabCardOverlap: CGFloat = 22
private let tabPeekHeight: CGFloat = 28

private struct ForYouPrayerStackedCards: View {
    let entry: ForYouTimelineEntry
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
                collapsed: expandedTab != nil
            )
            .zIndex(10)
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))

            ForEach(Array(ForYouPrayerTab.allCases.enumerated()), id: \.element) { index, tab in
                tabCard(tab: tab, index: index)
                    .padding(.top, topPadding(for: index))
                    .zIndex(zIndex(for: tab, index: index))
            }
        }
        .sheet(item: $presentedTab) { tab in
            NavigationView {
                ForYouPrayerTabModalView(entry: entry, tab: tab)
                    .navigationTitle(tab == .wirid ? (isMalayAppLanguage() ? "Wirid" : "Wirid") : (isMalayAppLanguage() ? "Doa" : "Dua"))
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
        return Double(ForYouPrayerTab.allCases.count - index)
    }
}

// The card-only portion of ForYouTimelineEntryView (right column content)
// used by ForYouPrayerStackedCards so the time pill / connector stays separate
private struct ForYouTimelineEntryContentCard: View {
    let entry: ForYouTimelineEntry
    var collapsed: Bool = false
    @EnvironmentObject private var settings: Settings

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

            Text(entry.subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ForYouPalette.secondaryInk)
                .lineLimit(collapsed ? 1 : nil)
                .fixedSize(horizontal: false, vertical: true)

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
                        Text(arabicText)
                            .font(.custom(preferredQuranArabicFontName(settings: settings, size: 16), size: 16))
                            .foregroundStyle(ForYouPalette.ink)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
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
                .fill(ForYouPalette.softCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ForYouPalette.stroke, lineWidth: 1)
                )
        )
    }
}

private struct ForYouPrayerTabModalView: View {
    let entry: ForYouTimelineEntry
    let tab: ForYouPrayerTab

    var body: some View {
        ScrollView(showsIndicators: false) {
            ForYouPrayerTabPanel(entry: entry, tab: tab, mode: .full)
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
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
    @EnvironmentObject private var settings: Settings

    private struct PanelSection: Identifiable {
        let id: String
        let title: String
        let arabic: String
        let transliteration: String
        let meaning: String
        let metadata: String?
    }

    private struct PanelContent {
        let title: String
        let sections: [PanelSection]
    }

    private var content: PanelContent {
        switch tab {
        case .wirid:
            return wiridContent(for: canonicalPrayerName(from: entry.id))
        case .doa:
            return doaContent(for: canonicalPrayerName(from: entry.id))
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
                    .foregroundStyle(ForYouPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if mode == .preview {
                        previewContent
                    } else {
                        fullContent
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
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .onDisappear { player.stop() }
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
                        .foregroundStyle(tab.color)
                        .fixedSize(horizontal: false, vertical: true)

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
                            .foregroundStyle(tab.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(tab.color.opacity(0.10))
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

                if index < content.sections.count - 1 {
                    Divider().opacity(0.35)
                }
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
            expandedSectionIDs.insert(id)
        }
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
                    metadata: metadata.isEmpty ? nil : metadata.joined(separator: "\n")
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
                    metadata: item.note
                )
            }
        )
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
    let currentPrayerEntry: ForYouTimelineEntry?
    let nextPrayerEntry: ForYouTimelineEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Widget card
            GeometryReader { geometry in
                let shellInset: CGFloat = 5
                let panelSpacing: CGFloat = 5
                let panelHeight = geometry.size.height - (shellInset * 2)
                let availableWidth = geometry.size.width - (shellInset * 2)
                let rightWidth = floor((availableWidth - panelSpacing) * 0.43)
                let leftWidth = availableWidth - panelSpacing - rightWidth
                let smallPanelHeight = floor((panelHeight - panelSpacing) / 2)

                HStack(spacing: panelSpacing) {
                    // Left panel — icon + prayer name left-middle, weekday + location below
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 0)

                        HStack(spacing: 8) {
                            Image(systemName: currentPrayerEntry?.icon ?? "sunrise")
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
                        // Top-right — next prayer name
                        HStack(spacing: 6) {
                            Image(systemName: nextPrayerEntry?.icon ?? "arrow.right.circle")
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

                        // Bottom-right — next prayer time
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
                .padding(shellInset)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )

            // Date below the widget (replaces the top header)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(shortDate)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.ink)

                Text(yearLine)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk.opacity(0.55))
            }
            .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shortWeekday: String {
        ForYouFormatters.weekday.string(from: plan.date).prefix(3).capitalized
    }

    private var shortDate: String {
        ForYouFormatters.monthDay.string(from: plan.date)
    }

    private var yearLine: String {
        ForYouFormatters.year.string(from: plan.date)
    }

    private var nextPrayerTime: String {
        guard let nextPrayerEntry else { return "--:--" }
        return ForYouFormatters.shortTime.string(from: nextPrayerEntry.time)
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

private struct ForYouDayView: View {
    static let prayerTimelineSectionID = "for-you-prayer-timeline-section"

    let viewModel: ForYouDayViewModel
    let completedIDs: Set<String>
    let onToggleCompletion: (String) -> Void
    let selection: ForYouPrayerCardSelection?
    let onSelectionChange: (ForYouPrayerCardSelection) -> Void
    let onScrollToPrayerTimeline: () -> Void

    @State private var selectedPageIndex: Int?

    init(
        viewModel: ForYouDayViewModel,
        completedIDs: Set<String>,
        onToggleCompletion: @escaping (String) -> Void,
        selection: ForYouPrayerCardSelection?,
        onSelectionChange: @escaping (ForYouPrayerCardSelection) -> Void,
        onScrollToPrayerTimeline: @escaping () -> Void
    ) {
        self.viewModel = viewModel
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
        viewModel.plan.timelineEntries.filter { $0.kind == .prayer }
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
            [ForYouPrayerCardSelection.main(entry.id)] + ForYouPrayerTab.allCases.map { .tab(entry.id, $0) }
        }
    }

    private func setPrayerSelection(_ selection: ForYouPrayerCardSelection) {
        onSelectionChange(selection)
    }

    @ViewBuilder
    private func pageContent(index: Int, page: [ForYouTimelineEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if index == 0 {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hello Rizhan")
                        .font(ForYouTypography.playfairHeadline(size: 31))
                        .foregroundStyle(ForYouPalette.ink)
                        .accessibilityAddTraits(.isHeader)

                    Button(action: onScrollToPrayerTimeline) {
                        ForYouSummaryHeader(
                            plan: viewModel.plan,
                            currentPrayerEntry: currentPrayerEntry,
                            nextPrayerEntry: nextPrayerEntry
                        )
                    }
                    .buttonStyle(ForYouHeroJumpButtonStyle())
                    .accessibilityLabel(isMalayAppLanguage() ? "Lompat ke bahagian waktu solat" : "Jump to prayer times section")
                }

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
                    .id(Self.prayerTimelineSectionID)
            }

            ForEach(page) { entry in
                VStack(alignment: .leading, spacing: 0) {
                    if entry.kind == .prayer {
                        ForYouPrayerTimelineEntryView(
                            entry: entry,
                            isFocused: entry.id == focusedEntryID,
                            extendsToNext: entry.id != page.last?.id,
                            selection: prayerSelection ?? .main(entry.id),
                            onSelectionChange: { selection in
                                setPrayerSelection(selection)
                            }
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

private struct ForYouHeroJumpButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
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
    @EnvironmentObject private var bottomBarVisibility: BottomBarVisibilityController
    @StateObject private var viewModel = ForYouFeedViewModel()
    @State private var selectedPrayerCard: ForYouPrayerCardSelection?
    @State private var scrollTarget: (scrollID: String, token: UUID?)?
    @State private var scrollOffset: CGFloat = 0
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
                            ForYouDayView(
                                viewModel: todayItem,
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
                    .background(
                        ScrollOffsetObserver { offset in
                            scrollOffset = offset
                            onScrollOffsetChange?(offset)
                        }
                    )
                    .onAppear {
                        onScrollOffsetChange?(0)
                        if let id = currentDayViewModel?.focusedEntryID {
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
        }
        .overlay(alignment: .top) {
            if let todayItem = currentDayViewModel {
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
        .overlay(alignment: .bottom) {
            if !prayerCardSequence.isEmpty {
                HStack(spacing: 10) {
                    pageCycleControlButton(systemName: "chevron.left") {
                        bottomBarVisibility.suppressNextShow()
                        cyclePrayerSelection(direction: -1)
                    }

                    pageCycleControlButton(systemName: "chevron.right") {
                        bottomBarVisibility.suppressNextShow()
                        cyclePrayerSelection(direction: 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(ForYouPalette.stroke, lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 4)
                .padding(.bottom, bottomBarVisibility.isHidden ? 18 : 104)
                .zIndex(10)
                .animation(.easeOut(duration: 0.18), value: bottomBarVisibility.isHidden)
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
                for tab in ForYouPrayerTab.allCases {
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
            [ForYouPrayerCardSelection.main(entry.id)] + ForYouPrayerTab.allCases.map { .tab(entry.id, $0) }
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

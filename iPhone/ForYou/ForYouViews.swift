import SwiftUI

private enum ForYouPalette {
    static let canvas = Color(red: 0.93, green: 0.93, blue: 0.94)
    static let card = Color.white.opacity(0.82)
    static let softCard = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let stroke = Color.black.opacity(0.08)
    static let ink = Color.black.opacity(0.92)
    static let secondaryInk = Color.black.opacity(0.58)
    static let accentSky = Color(red: 0.61, green: 0.83, blue: 0.93)
    static let darkTile = Color(red: 0.23, green: 0.26, blue: 0.30)
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
            .padding(14)
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

    private var startTimeText: String {
        ForYouFormatters.shortTime.string(from: segment.startWindow)
    }
}

private struct ForYouPremiumPreviewView: View {
    let plan: ForYouDailyPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isMalayAppLanguage() ? "Hari seterusnya sudah disediakan" : "Your next day is prepared")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))

            Text(isMalayAppLanguage() ? "Buka perjalanan kamu" : "Unlock your journey")
                .font(.title3.weight(.bold))
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
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
                .blur(radius: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.black.opacity(0.20))
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
    let nextSegment: ForYouDaySegment?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: nextSegment?.type.icon ?? "sunrise")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(ForYouPalette.ink)

                    Text(nextSegment?.title ?? (isMalayAppLanguage() ? "Subuh" : "Fajr"))
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.ink)
                }

                Text(shortWeekday)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.ink)

                Text(plan.locationLine ?? "Kuala Lumpur")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(ForYouPalette.canvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.black, lineWidth: 2.5)
                    )
            )

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: nextSegment?.type == .night ? "moon.stars" : "sun.max")
                        .font(.system(size: 24, weight: .medium))
                    Text(nextTime)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                }
                .foregroundStyle(ForYouPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 53)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(ForYouPalette.accentSky)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.black, lineWidth: 2.5)
                        )
                )

                HStack(spacing: 10) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 24, weight: .medium))
                    Text(relativeText)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 53)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(ForYouPalette.darkTile)
                )
            }
            .frame(width: 132)
        }
    }

    private var shortWeekday: String {
        ForYouFormatters.weekday.string(from: plan.date).prefix(3).capitalized
    }

    private var nextTime: String {
        guard let nextSegment else { return "--:--" }
        return ForYouFormatters.shortTime.string(from: nextSegment.startWindow)
    }

    private var relativeText: String {
        guard let nextSegment else { return "--" }
        let minutes = max(1, Int(nextSegment.startWindow.timeIntervalSince(Date()) / 60))
        if minutes >= 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            return remaining == 0 ? "\(hours)h" : "\(hours)h \(remaining)m"
        }
        return "\(minutes)m"
    }
}

private struct ForYouDayView: View {
    let viewModel: ForYouDayViewModel
    let nextPlan: ForYouDailyPlan?
    let completedIDs: Set<String>
    let isActive: Bool
    let onToggleCompletion: (String) -> Void

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(dateLine)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.ink)

                    Text(yearLine)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(ForYouPalette.secondaryInk.opacity(0.55))
                }

                ForYouSummaryHeader(
                    plan: viewModel.plan,
                    nextSegment: leadingSegment
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

                VStack(spacing: 10) {
                    ForEach(viewModel.plan.segments) { segment in
                        ForYouDaySegmentView(
                            segment: segment,
                            isCompleted: completedIDs.contains(segment.id),
                            onToggleCompletion: { onToggleCompletion(segment.id) }
                        )
                    }
                }

                Spacer(minLength: 0)

                if !viewModel.isLocked {
                    ForYouPremiumPreviewView(plan: nextPlan)
                }

                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 18)

            if viewModel.isLocked {
                Rectangle()
                    .fill(.black.opacity(0.14))
                    .ignoresSafeArea()
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
        .padding(.vertical, 10)
        .scaleEffect(viewModel.isLocked ? 0.982 : (isActive ? 1 : 0.988))
        .opacity(viewModel.isLocked ? 0.92 : (isActive ? 1 : 0.97))
        .offset(y: isActive ? 0 : 8)
        .blur(radius: viewModel.isLocked ? 7 : 0)
        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: viewModel.isLocked)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: isActive)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
            .fill(ForYouPalette.canvas)
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .ignoresSafeArea()
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let source = viewModel.plan.sourceLine {
                Text(source)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(ForYouPalette.secondaryInk)
            }
        }
    }

    private var leadingSegment: ForYouDaySegment? {
        viewModel.plan.segments.first
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
                GeometryReader { geometry in
                    TabView(selection: $viewModel.selectedIndex) {
                        ForEach(Array(viewModel.dayViewModels.enumerated()), id: \.element.id) { index, item in
                            ForYouDayView(
                                viewModel: item,
                                nextPlan: index + 1 < viewModel.dayViewModels.count ? viewModel.dayViewModels[index + 1].plan : nil,
                                completedIDs: viewModel.completedIDs,
                                isActive: viewModel.selectedIndex == index,
                                onToggleCompletion: viewModel.toggleCompletion(for:)
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .rotationEffect(.degrees(-90))
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(width: geometry.size.height - 18, height: geometry.size.width)
                    .rotationEffect(.degrees(90), anchor: .topLeading)
                    .offset(x: geometry.size.width, y: 18)
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

    private func refresh() {
        viewModel.configure(settings: settings, hasPremiumAccess: hasPremiumAccess)
    }
}

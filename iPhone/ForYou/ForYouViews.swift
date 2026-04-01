import SwiftUI

private enum ForYouPalette {
    static let base = Color(red: 0.05, green: 0.06, blue: 0.08)
    static let card = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let line = Color.white.opacity(0.08)
}

private enum ForYouFormatters {
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
        case .morning: return "sunrise.fill"
        case .dhuha: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .morning:
            return LinearGradient(colors: [Color(red: 0.35, green: 0.47, blue: 0.78), Color(red: 0.45, green: 0.31, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dhuha:
            return LinearGradient(colors: [Color(red: 0.83, green: 0.49, blue: 0.18), Color(red: 0.94, green: 0.67, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .evening:
            return LinearGradient(colors: [Color(red: 0.67, green: 0.42, blue: 0.17), Color(red: 0.48, green: 0.28, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .night:
            return LinearGradient(colors: [Color(red: 0.15, green: 0.20, blue: 0.33), Color(red: 0.08, green: 0.09, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
                ForYouPalette.base.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isMalayAppLanguage() ? "Bina rentak harian kamu" : "Shape your daily rhythm")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            Text(isMalayAppLanguage() ? "Tiga pilihan ringkas supaya For You terasa lembut, bukan berat." : "Three quick choices so For You feels guided, not crowded.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
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
        .preferredColorScheme(.dark)
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
                .foregroundStyle(.white)

            ForEach(options, id: \.id) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .strokeBorder(.white.opacity(selection.wrappedValue.id == option.id ? 0 : 0.14), lineWidth: 1)
                            .background(
                                Circle()
                                    .fill(selection.wrappedValue.id == option.id ? settings.accentColor.color : .clear)
                            )
                            .frame(width: 18, height: 18)

                        Text(description(option))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.88))

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(ForYouPalette.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(selection.wrappedValue.id == option.id ? settings.accentColor.color.opacity(0.5) : .white.opacity(0.08), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(segment.type.displayTitle, systemImage: segment.type.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))

                    Text(segment.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Text(durationText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.10)))
            }

            Text(windowText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))

            if let arabicText = segment.arabicText {
                Text(arabicText)
                    .font(.custom(preferredQuranArabicFontName(settings: settings, size: 24), size: 24))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineSpacing(5)
                    .minimumScaleFactor(0.85)
            }

            Text(segment.shortDescription)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)

            HStack {
                if let contentReference = segment.contentReference {
                    Text(contentReference)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer(minLength: 8)

                if segment.ctaType == .markDone {
                    Button {
                        onToggleCompletion()
                    } label: {
                        Label(
                            isCompleted ? (isMalayAppLanguage() ? "Selesai" : "Done") : (isMalayAppLanguage() ? "Tanda selesai" : "Mark as done"),
                            systemImage: isCompleted ? "checkmark.circle.fill" : "circle"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(isCompleted ? 0.20 : 0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(segment.type.gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private var durationText: String {
        let unit = isMalayAppLanguage() ? "min" : "min"
        return "\(segment.durationMinutes) \(unit)"
    }

    private var windowText: String {
        let start = ForYouFormatters.shortTime.string(from: segment.startWindow)
        let end = ForYouFormatters.shortTime.string(from: segment.endWindow)
        return "\(start) – \(end)"
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
                .foregroundStyle(.white)

            Text(isMalayAppLanguage() ? "Hari ini sudah kamu rasa. Hari-hari seterusnya menunggu." : "You have today. The days ahead are waiting.")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(reason ?? (isMalayAppLanguage() ? "Buka pelan yang diperibadikan, disediakan lebih awal untuk rentak ibadah kamu." : "Unlock the prepared days ahead with a more personal daily rhythm."))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)

            Text(isMalayAppLanguage() ? "Pengalaman hari ini kekal penuh. Esok hanya dipratonton dengan lembut." : "Today stays fully open. Tomorrow is only softly previewed.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(26)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
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

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.plan.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if let subtitle = viewModel.plan.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }

                VStack(spacing: 14) {
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)

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
            .fill(
                LinearGradient(
                    colors: [ForYouPalette.base, Color(red: 0.08, green: 0.10, blue: 0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 220, height: 220)
                    .blur(radius: 10)
                    .offset(x: 80, y: -30)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 180, height: 180)
                    .blur(radius: 10)
                    .offset(x: -40, y: 30)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(ForYouPalette.line, lineWidth: 1)
            )
            .ignoresSafeArea()
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let location = viewModel.plan.locationLine {
                Text(location)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }

            if let source = viewModel.plan.sourceLine {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }
}

struct ForYouRootView: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var revenueCat: RevenueCatManager
    @StateObject private var viewModel = ForYouFeedViewModel()

    var body: some View {
        ZStack {
            ForYouPalette.base.ignoresSafeArea()

            if viewModel.dayViewModels.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text(isMalayAppLanguage() ? "Menyusun hari kamu..." : "Preparing your day...")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.68))
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
                    .frame(width: geometry.size.height, height: geometry.size.width)
                    .rotationEffect(.degrees(90), anchor: .topLeading)
                    .offset(x: geometry.size.width)
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
        .preferredColorScheme(.dark)
    }

    private var hasPremiumAccess: Bool {
        revenueCat.hasBuyMeKopi || revenueCat.hasPremiumWidgetsUnlocked
    }

    private func refresh() {
        viewModel.configure(settings: settings, hasPremiumAccess: hasPremiumAccess)
    }
}

import Foundation

struct ForYouDayViewModel: Identifiable {
    let plan: ForYouDailyPlan
    let isLocked: Bool

    var id: String { plan.id }

    /// The entry ID to auto-scroll to — the last entry whose time has passed, or the first.
    var focusedEntryID: String? {
        let entries = plan.timelineEntries
        guard !entries.isEmpty else { return nil }
        if Calendar.current.isDateInToday(plan.date) {
            let now = Date()
            return (entries.last(where: { $0.time <= now }) ?? entries.first)?.id
        }
        return entries.first?.id
    }
}

@MainActor
final class ForYouFeedViewModel: ObservableObject {
    @Published private(set) var dayViewModels: [ForYouDayViewModel] = []
    @Published var selectedIndex: Int = 1
    @Published var profile: ForYouUserProfile = .default
    @Published var showOnboarding = false
    @Published var completedIDs: Set<String> = []

    private let generator = ForYouPlanGeneratorService()
    private var lastSignature = ""

    func configure(settings: Settings, hasPremiumAccess: Bool) {
        let loadedProfile = ForYouUserProfileService.load()
        profile = loadedProfile
        completedIDs = ForYouCompletionStore.completedIDs()
        showOnboarding = !loadedProfile.isComplete

        let signature = makeSignature(settings: settings, profile: loadedProfile, hasPremiumAccess: hasPremiumAccess)
        guard signature != lastSignature else { return }
        lastSignature = signature

        let plans = generator.generatePlans(
            anchorDate: Date(),
            settings: settings,
            profile: loadedProfile,
            hasPremiumAccess: hasPremiumAccess
        )

        dayViewModels = plans.enumerated().map { index, plan in
            ForYouDayViewModel(plan: plan, isLocked: index > 1 && !hasPremiumAccess)
        }
        selectedIndex = min(max(selectedIndex, 0), max(dayViewModels.count - 1, 0))

        Task { [weak self] in
            guard let self else { return }
            let enrichedPlans = await generator.enrichPlansWithWeather(plans, settings: settings)
            guard self.lastSignature == signature else { return }
            self.dayViewModels = enrichedPlans.enumerated().map { index, plan in
                ForYouDayViewModel(plan: plan, isLocked: index > 1 && !hasPremiumAccess)
            }
            self.selectedIndex = min(max(self.selectedIndex, 0), max(self.dayViewModels.count - 1, 0))
        }
    }

    func saveProfile(_ profile: ForYouUserProfile, settings: Settings, hasPremiumAccess: Bool) {
        ForYouUserProfileService.save(profile)
        self.profile = profile
        showOnboarding = false
        lastSignature = ""
        configure(settings: settings, hasPremiumAccess: hasPremiumAccess)
    }

    func toggleCompletion(for segmentID: String) {
        let willComplete = !completedIDs.contains(segmentID)
        ForYouCompletionStore.setCompleted(willComplete, id: segmentID)
        completedIDs = ForYouCompletionStore.completedIDs()
    }

    private func makeSignature(settings: Settings, profile: ForYouUserProfile, hasPremiumAccess: Bool) -> String {
        let location = settings.currentLocation?.city ?? "nil"
        let currentPrayer = settings.currentPrayer?.nameTransliteration ?? "nil"
        let nextPrayer = settings.nextPrayer?.nameTransliteration ?? "nil"
        return "\(location)|\(currentPrayer)|\(nextPrayer)|\(settings.prayerCalculation)|\(hasPremiumAccess)|\(profile.consistencyLevel?.rawValue ?? "nil")|\(profile.primaryGoal?.rawValue ?? "nil")|\(profile.reminderStyle?.rawValue ?? "nil")"
    }
}

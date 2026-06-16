import SwiftUI
import CoreLocation
import UserNotifications
import WidgetKit
#if os(iOS)
import AVFoundation
import AudioToolbox
import UIKit

private enum AzanPreviewAudioCoordinator {
    static var player: AVAudioPlayer?

    static func stop() {
        player?.stop()
        player = nil
    }

    static func play(url: URL) {
        stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 1.0
            player?.prepareToPlay()
            player?.play()
        } catch {
            player = nil
        }
    }
}
#endif

struct SettingsAdhanView: View {
    @EnvironmentObject var settings: Settings
    
    @State private var showingMap = false
    
    @State private var showAlert: AlertType?
    enum AlertType: Identifiable {
        case travelTurnOnAutomatic, travelTurnOffAutomatic

        var id: Int {
            switch self {
            case .travelTurnOnAutomatic: return 1
            case .travelTurnOffAutomatic: return 2
            }
        }
    }
    
    @State var showNotifications: Bool
    
    var body: some View {
        List {
            #if !os(watchOS)
            if showNotifications {
                Section(header: Text("NOTIFICATIONS")) {
                    NavigationLink(destination: NotificationView()) {
                        Label(appLocalized("Notification Settings"), systemImage: "bell.badge")
                    }
                    
                }
            }
            #endif

            #if os(iOS)
            Section(header: Text(appLocalized("AZAN SOUND"))) {
                Picker(appLocalized("Notification Sound"), selection: Binding(
                    get: { settings.notificationSoundOption },
                    set: {
                        settings.setNotificationSoundOption($0)
                        playAzanPreviewIfNeeded(for: $0)
                    }
                )) {
                    ForEach(NotificationSoundOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                if settings.notificationSoundOption == .azan {
                    Picker(appLocalized("Playback"), selection: Binding(
                        get: { settings.azanAudioClipMode },
                        set: {
                            settings.azanAudioClipMode = $0
                            playAzanPreviewIfNeeded(for: .azan)
                        }
                    )) {
                        ForEach(AzanAudioClipMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(appLocalized("Azan Voice"), selection: Binding(
                        get: { settings.azanAudioTrack },
                        set: {
                            settings.azanAudioTrack = $0
                            playAzanPreviewIfNeeded(for: .azan)
                        }
                    )) {
                        ForEach(AzanAudioTrack.allCases) { track in
                            Text(track.title).tag(track)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        playAzanPreviewIfNeeded(for: .azan)
                    } label: {
                        Label(appLocalized("Play Preview"), systemImage: "play.circle.fill")
                            .font(.subheadline)
                    }

                    Text(appLocalized("Tip: Choose Takbir for a short intro clip, or Full Azan for complete recitation."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            #endif
            
            Section(header: Text("TRAVELING MODE")) {
                #if !os(watchOS)
                Button(action: {
                    settings.hapticFeedback()
                    
                    showingMap = true
                }) {
                    HStack {
                        Text("Set Home City")
                            .font(.subheadline)
                            .foregroundColor(settings.accentColor.color)
                        if !(settings.homeLocation?.city.isEmpty ?? true) {
                            Spacer()
                            Text(settings.homeLocation?.city ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .sheet(isPresented: $showingMap) {
                    MapView(choosingPrayerTimes: false)
                        .environmentObject(settings)
                }
                
                Toggle("Traveling Mode Turns on Automatically", isOn: $settings.travelAutomatic.animation(.easeInOut))
                    .font(.subheadline)
                    .tint(settings.accentColor.toggleTint)
                #endif
                
                VStack(alignment: .leading) {
                    #if !os(watchOS)
                    Toggle("Traveling Mode", isOn: Binding(
                        get: { settings.travelingMode },
                        set: { settings.travelingModeManuallyToggled = true; settings.travelingMode = $0 }
                    ).animation(.easeInOut))
                        .font(.subheadline)
                        .tint(settings.accentColor.toggleTint)
                        .disabled(settings.travelAutomatic)
                    
                    Text("If you are traveling more than 48 mi (77.25 km), then it is permissible to pray Qasr, where you combine Dhuhr and Asr (2 rakahs each) and Maghrib and Isha (3 and 2 rakahs). Allah said in the Quran, “And when you (Muslims) travel in the land, there is no sin on you if you shorten As-Salah (the prayer)” [Quran, An-Nisa, 4:101]. \(settings.travelAutomatic ? "This feature turns on and off automatically, but you can also control it manually here." : "You can control traveling mode manually here.")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                    #else
                    Toggle("Traveling Mode", isOn: Binding(
                        get: { settings.travelingMode },
                        set: { settings.travelingModeManuallyToggled = true; settings.travelingMode = $0 }
                    ).animation(.easeInOut))
                        .font(.subheadline)
                        .tint(settings.accentColor.toggleTint)
                    #endif
                }
            }
            
        }
        .applyConditionalListStyle(defaultView: true)
        .navigationTitle(appLocalized("Waktu Solat Settings"))
        .onAppear {
            applyRegionDefaultCalculation()
        }
        .onChange(of: settings.currentLocation?.countryCode) { _ in
            applyRegionDefaultCalculation()
        }
        .onChange(of: settings.homeLocation) { _ in
            settings.fetchPrayerTimes() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if settings.travelTurnOnAutomatic {
                        showAlert = .travelTurnOnAutomatic
                    } else if settings.travelTurnOffAutomatic {
                        showAlert = .travelTurnOffAutomatic
                    }
                }
            }
        }
        .onChange(of: settings.travelAutomatic) { newValue in
            if newValue {
                settings.fetchPrayerTimes() {
                    if settings.homeLocation == nil {
                        withAnimation {
                            settings.travelingMode = false
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if settings.travelTurnOnAutomatic {
                                showAlert = .travelTurnOnAutomatic
                            } else if settings.travelTurnOffAutomatic {
                                showAlert = .travelTurnOffAutomatic
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog("", isPresented: Binding(
            get: { showAlert != nil },
            set: { if !$0 { showAlert = nil } }
        ), titleVisibility: .visible) {
            switch showAlert {
            case .travelTurnOnAutomatic:
                Button("Override: Turn Off", role: .destructive) {
                    settings.travelingModeManuallyToggled = true
                    withAnimation {
                        settings.travelingMode = false
                    }
                    settings.travelAutomatic = false
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                    settings.fetchPrayerTimes(force: true)
                }
                
                Button("Confirm: Keep On", role: .cancel) {
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                }
                
            case .travelTurnOffAutomatic:
                Button("Override: Keep On", role: .destructive) {
                    settings.travelingModeManuallyToggled = true
                    withAnimation {
                        settings.travelingMode = true
                    }
                    settings.travelAutomatic = false
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                    settings.fetchPrayerTimes(force: true)
                }
                
                Button("Confirm: Turn Off", role: .cancel) {
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                }
                
            case .none:
                EmptyView()
            }
        } message: {
            switch showAlert {
            case .travelTurnOnAutomatic:
                Text("Waktu Solat has automatically detected that you are traveling, so your prayers will be shortened.")
            case .travelTurnOffAutomatic:
                Text("Waktu Solat has automatically detected that you are no longer traveling, so your prayers will not be shortened.")
            case .none:
                EmptyView()
            }
        }
    }

    private func applyRegionDefaultCalculation() {
        let countryCode = settings.currentLocation?.countryCode?.uppercased() ?? ""

        guard !countryCode.isEmpty else {
            if settings.shouldUseMalaysiaPrayerAPI(for: settings.currentLocation) {
                settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
                settings.hanafiMadhab = false
            } else if settings.prayerCalculation == "Singapore" {
                settings.prayerCalculation = "Auto (By Location)"
            }
            return
        }

        switch countryCode {
        case "MY":
            settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
            settings.hanafiMadhab = false
        case "SG":
            settings.prayerCalculation = "Majlis Ugama Islam Singapura, Singapore"
        case "BN":
            settings.prayerCalculation = "Kementerian Hal Ehwal Ugama (MORA)"
            settings.hanafiMadhab = false
        case "ID":
            settings.prayerCalculation = "KEMENAG - Kementerian Agama Republik Indonesia"
            settings.hanafiMadhab = false
        case "GB":
            settings.prayerCalculation = "Moonsighting Committee Worldwide"
        case "US", "CA":
            settings.prayerCalculation = "Muslim World League"
        default:
            if settings.prayerCalculation == "Singapore" {
                settings.prayerCalculation = "Auto (By Location)"
            }
        }
    }

    #if os(iOS)
    private func playAzanPreviewIfNeeded(for option: NotificationSoundOption) {
        switch option {
        case .azan:
            guard let url = resolvedAzanPreviewURL() else {
                AzanPreviewAudioCoordinator.stop()
                return
            }
            AzanPreviewAudioCoordinator.play(url: url)
        case .iosDefault:
            AzanPreviewAudioCoordinator.stop()
            AudioServicesPlaySystemSound(1007)
        }
    }

    private func resolvedAzanPreviewURL() -> URL? {
        for name in settings.selectedAzanSoundCandidates {
            let ns = name as NSString
            let base = ns.deletingPathExtension
            let ext = ns.pathExtension
            guard !base.isEmpty, !ext.isEmpty else { continue }
            if let url = Bundle.main.url(forResource: base, withExtension: ext) {
                return url
            }
        }
        return nil
    }
    #endif
}

struct LiveActivitySettingsView: View {
    @EnvironmentObject var settings: Settings

    #if DEBUG
    private enum DebugTimingMode: String, CaseIterable, Identifiable {
        case relative
        case absolute
        var id: String { rawValue }
        var title: String {
            switch self {
            case .relative: return "Minutes from now"
            case .absolute: return "Exact time"
            }
        }
    }
    #endif

    #if DEBUG
    @State private var debugTimingMode: DebugTimingMode = .relative
    @State private var debugMinutesUntilPrayer: Int = 2
    @State private var debugExactPrayerTime: Date = Date().addingTimeInterval(2 * 60)
    @State private var debugSelectedPrayerName: String = "Test Prayer"
    @State private var debugLastStartedTargetTime: Date?
    private let debugPrayerNames: [String] = [
        "Test Prayer", "Fajr", "Shurooq", "Dhuhr", "Jumuah", "Asr", "Maghrib", "Isha"
    ]
    #endif

    var body: some View {
        List {
            Section(header: Text("LIVE ACTIVITY TIMING")) {
                HStack {
                    Text("Show Before Prayer")
                        .font(.subheadline)
                    Spacer()
                    Text("5 minutes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Live Activity appears 5 minutes before prayer time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            }

            Section(header: Text("LIVE ACTIVITY PRAYERS")) {
                Toggle("Fajr", isOn: $settings.liveActivityFajrEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Shurooq", isOn: $settings.liveActivitySunriseEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Dhuhr (Jumuah)", isOn: $settings.liveActivityDhuhrEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Asr", isOn: $settings.liveActivityAsrEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Maghrib", isOn: $settings.liveActivityMaghribEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Isha", isOn: $settings.liveActivityIshaEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
            }

            #if false
            Section(header: Text("TRAVEL COMBINED PRAYERS")) {
                Toggle("Combined Traveling Dhuhr and Asr", isOn: $settings.liveActivityDhuhrAsrEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Combined Traveling Maghrib and Isha", isOn: $settings.liveActivityMaghribIshaEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Text("Used when Traveling Mode combines prayers.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            }
            #endif

            /*
            #if DEBUG
            if #available(iOS 16.2, *) {
                Section(header: Text("DEBUG LIVE ACTIVITY")) {
                    Picker("Prayer Label", selection: $debugSelectedPrayerName) {
                        ForEach(debugPrayerNames, id: \.self) { prayer in
                            Text(prayer).tag(prayer)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Debug Timing Mode", selection: $debugTimingMode) {
                        ForEach(DebugTimingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if debugTimingMode == .relative {
                        Stepper(
                            "Minutes Until Prayer: \(debugMinutesUntilPrayer)",
                            value: $debugMinutesUntilPrayer,
                            in: 1...180
                        )
                    } else {
                        DatePicker(
                            "Prayer Time",
                            selection: $debugExactPrayerTime,
                            in: Date().addingTimeInterval(60)...Date().addingTimeInterval(24 * 60 * 60),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    Text("Starts a debug Live Activity immediately with your custom countdown so you can test without waiting for the real next prayer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)

                    if let target = debugLastStartedTargetTime {
                        TimelineView(.periodic(from: Date(), by: 1)) { context in
                            let now = context.date
                            let remaining = max(0, Int(target.timeIntervalSince(now)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Now: \(now.formatted(date: .omitted, time: .standard))")
                                Text("Target: \(target.formatted(date: .abbreviated, time: .standard))")
                                Text("Remaining: \(remaining)s")
                            }
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }

                    Button {
                        settings.hapticFeedback()
                        if debugTimingMode == .relative {
                            let target = Calendar.current.date(byAdding: .minute, value: debugMinutesUntilPrayer, to: Date()) ?? Date().addingTimeInterval(Double(debugMinutesUntilPrayer) * 60)
                            debugLastStartedTargetTime = target
                            settings.startDebugLiveNextPrayerActivity(
                                prayerName: debugSelectedPrayerName,
                                minutesUntilPrayer: debugMinutesUntilPrayer
                            )
                        } else {
                            debugLastStartedTargetTime = debugExactPrayerTime
                            settings.startDebugLiveNextPrayerActivity(
                                prayerName: debugSelectedPrayerName,
                                minutesUntilPrayer: 1,
                                debugPrayerTime: debugExactPrayerTime
                            )
                        }
                    } label: {
                        Label("Start Custom Debug Live Activity", systemImage: "play.circle")
                            .foregroundColor(settings.accentColor.color)
                    }
                    .font(.subheadline)

                    Button(role: .destructive) {
                        settings.hapticFeedback()
                        settings.stopDebugLiveNextPrayerActivity()
                        debugLastStartedTargetTime = nil
                    } label: {
                        Label("Stop Debug Live Activity", systemImage: "stop.circle")
                    }
                    .font(.subheadline)
                }
            }
            #endif
            */
        }
        .applyConditionalListStyle(defaultView: true)
        .navigationTitle("Live Activity Options")
    }
}

struct NotificationView: View {
    @EnvironmentObject var settings: Settings
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showAlert: Bool = false
    @State private var notifSettings: UNNotificationSettings?
    @State private var requestAccessAlertMessage: String?
    @State private var locationAccessAlertMessage: String?
    @State private var todayPrayerCheckInEnabled: Bool = ForYouUserProfileService.load().wantsPrayerTrackerCard ?? true
    @State private var draftFirstName: String = {
        ForYouUserProfileService.load().firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }()

    var body: some View {
        List {
            #if !os(watchOS)
            Section {
                permissionCard
            }
            #endif

            Section(footer: locationPermissionFooter) {
                EmptyView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            
            Section(header: Text(appLocalized("PRAYER REMINDERS"))) {
                NavigationLink(destination: MoreNotificationView()) {
                    Label(appLocalized("Prayer Notifications"), systemImage: "bell.fill")
                        .font(.subheadline)
                }
            }

            prayerMessageStyleSection

            Section(header: Text(appLocalized("DAILY ZIKIR REMINDERS"))) {
                Toggle(appLocalized("Send Daily Zikir Notifications"), isOn: $settings.zikirNotificationsEnabled.animation(.easeInOut))
                    .font(.subheadline)
                    .tint(settings.accentColor.toggleTint)

                if settings.zikirNotificationsEnabled {
                    NotificationStylePreviewCard(
                        appName: "Waktu Solat",
                        title: zikirPreviewTitle,
                        messageBody: zikirPreviewBody,
                        accentColor: settings.accentColor.color
                    )
                    .listRowSeparator(.hidden)

                    Picker(appLocalized("Zikir Notification Style"), selection: Binding(
                        get: { settings.zikirNotificationMessageStyle },
                        set: { settings.zikirNotificationMessageStyle = $0 }
                    )) {
                        ForEach(ZikirNotificationMessageStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(appLocalized("Zikir notifications rotate through morning, midday, evening, and night using the same prayer-aware timing as the zikir widget."))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(settings.zikirNotificationMessageStyle.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(appLocalized("Send a short Arabic zikir throughout the day, timed around your prayer windows."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

        }
        .task { await refresh() }
        .onAppear {
            syncNotificationState()
            let profile = ForYouUserProfileService.load()
            todayPrayerCheckInEnabled = profile.wantsPrayerTrackerCard ?? true
            draftFirstName = profile.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            syncForYouReminderStyleWithPrayerStyle()
        }
        .onChange(of: scenePhase) { _ in
            if scenePhase == .active {
                syncNotificationState()
            }
        }
        .confirmationDialog("", isPresented: $showAlert, titleVisibility: .visible) {
            Button("Open Settings") { openSystemSettings() }
            Button("Ignore", role: .cancel) { }
        } message: {
            Text("Please go to Settings and enable notifications to be notified of prayer times.")
        }
        .confirmationDialog("Notifications", isPresented: Binding(
            get: { requestAccessAlertMessage != nil },
            set: { if !$0 { requestAccessAlertMessage = nil } }
        ), titleVisibility: .visible) {
            Button("OK", role: .cancel) { requestAccessAlertMessage = nil }
            Button("Open Settings") {
                requestAccessAlertMessage = nil
                openSystemSettings()
            }
        } message: {
            if let msg = requestAccessAlertMessage {
                Text(msg)
            }
        }
        .confirmationDialog("Location Access", isPresented: Binding(
            get: { locationAccessAlertMessage != nil },
            set: { if !$0 { locationAccessAlertMessage = nil } }
        ), titleVisibility: .visible) {
            Button("OK", role: .cancel) { locationAccessAlertMessage = nil }
            Button("Open Settings") {
                locationAccessAlertMessage = nil
                openSystemSettings()
            }
        } message: {
            if let msg = locationAccessAlertMessage {
                Text(msg)
            }
        }
        .applyConditionalListStyle(defaultView: true)
        .navigationTitle(appLocalized("Notification Settings"))
    }

    private var prayerPreviewTitle: String {
        switch settings.prayerNotificationMessageStyle {
        case .standard:
            return "Waktu Solat"
        case .gentle:
            return isMalayAppLanguage() ? "Peringatan Solat" : "Prayer Reminder"
        case .concise:
            return localizedPrayerName("Asr")
        }
    }

    private var prayerPreviewBody: String {
        let personalizedSuffix = personalizedTodayNotificationSuffix
        switch settings.prayerNotificationMessageStyle {
        case .standard:
            return isMalayAppLanguage()
                ? "Waktu Asar pada 4:25 PTG di Subang Jaya, Selangor\(personalizedSuffix)"
                : "Time for Asr at 4:25 PM in Subang Jaya, Selangor\(personalizedSuffix)"
        case .gentle:
            return isMalayAppLanguage()
                ? "Kini masuk waktu Asar di Subang Jaya, Selangor\(personalizedSuffix)."
                : "It's now time for Asr in Subang Jaya, Selangor\(personalizedSuffix)."
        case .concise:
            return isMalayAppLanguage()
                ? "Asar • 4:25 PTG • Subang Jaya, Selangor\(personalizedSuffix)"
                : "Asr • 4:25 PM • Subang Jaya, Selangor\(personalizedSuffix)"
        }
    }

    private var personalizedTodayNotificationSuffix: String {
        guard todayPrayerCheckInEnabled else { return "" }
        let name = draftFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "" }
        return isMalayAppLanguage() ? " untuk \(name)" : ", \(name)"
    }

    private var prayerMessageStyleSection: some View {
        Section(header: Text(appLocalized("PRAYER MESSAGE STYLE"))) {
            NotificationStylePreviewCard(
                appName: "Waktu Solat",
                title: prayerPreviewTitle,
                messageBody: prayerPreviewBody,
                accentColor: settings.accentColor.color
            )
            .listRowSeparator(.hidden)

            Picker(appLocalized("Prayer Notification Style"), selection: Binding(
                get: { settings.prayerNotificationMessageStyle },
                set: {
                    settings.prayerNotificationMessageStyle = $0
                    syncForYouReminderStyleWithPrayerStyle()
                }
            )) {
                ForEach(PrayerNotificationMessageStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.menu)

            Text(settings.prayerNotificationMessageStyle.summary)
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle(appLocalized("Prayer Check-in Cards"), isOn: $todayPrayerCheckInEnabled.animation(.easeInOut))
                .font(.subheadline)
                .tint(settings.accentColor.toggleTint)
                .onChange(of: todayPrayerCheckInEnabled) { newValue in
                    updateForYouProfile {
                        $0.wantsPrayerTrackerCard = newValue
                    }
                }

            HStack {
                Text(isMalayAppLanguage() ? "Nama" : "Name")
                    .font(.subheadline)
                TextField(isMalayAppLanguage() ? "Nama anda" : "Your name", text: $draftFirstName)
                    .font(.subheadline)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: draftFirstName) { newValue in
                        updateForYouProfile {
                            $0.firstName = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? nil
                                : newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
            }
        }
    }

    private var zikirPreviewTitle: String {
        switch settings.zikirNotificationMessageStyle {
        case .guided:
            return isMalayAppLanguage() ? "Zikir petang" : "Evening Zikir"
        case .reflective:
            return isMalayAppLanguage() ? "Makna zikir" : "Zikir Reflection"
        case .concise:
            return "سُبْحَانَ اللَّهِ"
        }
    }

    @ViewBuilder
    private var locationPermissionFooter: some View {
        Button {
            handleLocationPermissionFooterTapped()
        } label: {
            Text(locationPermissionFooterText)
                .font(.caption)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundColor(.blue)
    }

    private var locationPermissionFooterText: String {
        isMalayAppLanguage()
            ? "Waktu berfungsi lebih baik apabila lokasi ditetapkan kepada Sentiasa Dibenarkan, terutama untuk widget, mod perjalanan automatik, dan peringatan solat yang lebih tepat."
            : "Waktu works better when location is set to Always Allow, especially for widgets, automatic travel mode, and more reliable prayer reminders."
    }

    private var zikirPreviewBody: String {
        switch settings.zikirNotificationMessageStyle {
        case .guided:
            return isMalayAppLanguage()
                ? "Ulang dengan hadir hati\nسُبْحَانَ اللَّهِ وَبِحَمْدِهِ"
                : "Repeat with presence\nسُبْحَانَ اللَّهِ وَبِحَمْدِهِ"
        case .reflective:
            return isMalayAppLanguage()
                ? "Maha Suci Allah dan segala puji bagi-Nya.\nسُبْحَانَ اللَّهِ وَبِحَمْدِهِ"
                : "Glory be to Allah and praise be to Him.\nسُبْحَانَ اللَّهِ وَبِحَمْدِهِ"
        case .concise:
            return isMalayAppLanguage()
                ? "Maha Suci Allah • Subang Jaya, Selangor"
                : "Glory be to Allah • Subang Jaya, Selangor"
        }
    }

    private func updateForYouProfile(_ mutate: (inout ForYouUserProfile) -> Void) {
        var profile = ForYouUserProfileService.load()
        mutate(&profile)
        profile.consistencyLevel = profile.consistencyLevel ?? .beginner
        profile.primaryGoal = profile.primaryGoal ?? .preserveFajr
        profile.reminderStyle = profile.reminderStyle ?? forYouReminderStyle(for: settings.prayerNotificationMessageStyle)
        profile.wantsPrayerTrackerCard = profile.wantsPrayerTrackerCard ?? todayPrayerCheckInEnabled
        ForYouUserProfileService.save(profile)
    }

    private func syncForYouReminderStyleWithPrayerStyle() {
        updateForYouProfile {
            $0.reminderStyle = forYouReminderStyle(for: settings.prayerNotificationMessageStyle)
        }
    }

    private func forYouReminderStyle(for style: PrayerNotificationMessageStyle) -> ForYouReminderStyle {
        switch style {
        case .gentle:
            return .gentle
        case .standard:
            return .balanced
        case .concise:
            return .focused
        }
    }

    #if !os(watchOS)
    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Prayer Reminders", systemImage: "bell.badge")
                    .font(.headline)
                    .foregroundColor(settings.accentColor.color)

                Spacer()

                Text(permissionPillText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(permissionPillTextColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(permissionPillColor))
                    .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                    .padding(.trailing, -6)
            }
            .animation(.easeInOut(duration: 0.25), value: permissionPillText)

            if let s = notifSettings {
                VStack(spacing: 8) {
                    infoRow("Status", statusText(s.authorizationStatus))
                    infoRow("Alerts", notificationSettingText(s.alertSetting))
                    infoRow("Sounds", notificationSettingText(s.soundSetting))
                }
                .font(.footnote)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            Text("Turn on notifications to get prayer reminders and live countdown support. Waktu Solat will only show Apple's system prompt after you tap the button below.")
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Button {
                    settings.hapticFeedback()
                    Task { @MainActor in await onRequestAccessTapped() }
                } label: {
                    smallButton("Enable Reminders", systemImage: "checkmark.seal")
                }
                .buttonStyle(.plain)

                Button {
                    settings.hapticFeedback()
                    openSystemSettings()
                } label: {
                    smallButton("Open Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.25), value: notifSettings?.authorizationStatus.rawValue)
    }
    #endif
    
    private var permissionPillText: String {
        statusText(notifSettings?.authorizationStatus ?? .notDetermined)
    }
    
    private var permissionPillColor: Color {
        guard let status = notifSettings?.authorizationStatus else { return .secondary }
        switch status {
        case .authorized, .provisional, .ephemeral:
            return settings.accentColor.toggleTint
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .secondary
        }
    }

    private var permissionPillTextColor: Color {
        switch settings.accentColor {
        case .adaptive, .yellow, .mint, .lightPink:
            return .black
        default:
            return .white
        }
    }
    
    private func infoRow(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left).foregroundColor(.secondary)
            Spacer()
            Text(right).foregroundColor(.primary)
        }
    }
    
    private func statusText(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "Not asked"
        case .denied: return "Denied"
        case .authorized: return "Allowed"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
    
    private func notificationSettingText(_ s: UNNotificationSetting) -> String {
        switch s {
        case .enabled: return "On"
        case .disabled: return "Off"
        case .notSupported: return "N/A"
        @unknown default: return "Unknown"
        }
    }
    
    private func smallButton(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(settings.accentColor.color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(settings.accentColor.color.opacity(0.35), lineWidth: 1)
        )
    }
    
    private func openSystemSettings() {
        #if !os(watchOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
    }

    private func handleLocationPermissionFooterTapped() {
        #if !os(watchOS)
        switch Settings.locationManager.authorizationStatus {
        case .authorizedWhenInUse, .notDetermined:
            settings.requestLocationAuthorization()
        case .authorizedAlways:
            locationAccessAlertMessage = isMalayAppLanguage()
                ? "Akses lokasi anda sudah ditetapkan kepada Sentiasa Dibenarkan."
                : "Location access is already set to Always Allow."
        case .denied, .restricted:
            locationAccessAlertMessage = isMalayAppLanguage()
                ? "Untuk menukar kepada Sentiasa Dibenarkan, buka aplikasi Settings iPhone dan benarkan akses lokasi di sana."
                : "To change this to Always Allow, open the iPhone Settings app and update location access there."
        default:
            openSystemSettings()
        }
        #endif
    }
    
    @MainActor
    private func refresh() async {
        let center = UNUserNotificationCenter.current()
        notifSettings = await center.notificationSettings()
    }
    
    private func syncNotificationState() {
        Task { @MainActor in
            await refresh()
            settings.fetchPrayerTimes(notification: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if settings.showNotificationAlert,
                       notifSettings?.authorizationStatus == .denied {
                        showAlert = true
                    }
                }
            }
        }
    }
    
    @MainActor
    private func onRequestAccessTapped() async {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        switch current.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            requestAccessAlertMessage = "Notifications are already turned on."
        case .denied:
            requestAccessAlertMessage = "Notifications are turned off. Open Settings to enable them."
        case .notDetermined:
            let granted = await settings.requestNotificationAuthorization()
            await refresh()
            if granted {
                settings.fetchPrayerTimes(notification: true)
            }
        @unknown default:
            requestAccessAlertMessage = "Unable to change notification settings."
        }
    }
}

private struct NotificationStylePreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let appName: String
    let title: String
    let messageBody: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("CurrentAppIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(appIconBorderColor, lineWidth: 0.8)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(headerPrimaryTextColor)

                    Spacer(minLength: 8)

                    Text(isMalayAppLanguage() ? "12m lalu" : "12m ago")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(headerSecondaryTextColor)
                        .fixedSize(horizontal: true, vertical: false)
                }

                if showsStandaloneTitle {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                }

                Text(messageBody)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.92)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 364)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 10, x: 0, y: 4)
        .listRowInsets(EdgeInsets())
        .padding(.vertical, 2)
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.9)
            : Color(UIColor.secondarySystemBackground)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.black.opacity(0.08)
    }

    private var appIconBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.10)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color.primary
    }

    private var headerPrimaryTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color.black.opacity(0.9)
    }

    private var headerSecondaryTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.62)
            : Color.black.opacity(0.5)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? .black.opacity(0.2)
            : .black.opacity(0.08)
    }

    private var showsStandaloneTitle: Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAppName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalizedTitle.isEmpty && normalizedTitle.caseInsensitiveCompare(normalizedAppName) != .orderedSame
    }
}

struct WidgetPreviewGalleryView: View {
    private struct SelectionSnapshot {
        let prayerTimesStyleRaw: String
        let countdownBarStyleRaw: String
        let zikirAlignmentRaw: String
        let nextPrayerCircleStyleRaw: String
        let prayerListStyleRaw: String
        let dailyVerseStyleRaw: String
    }

    @EnvironmentObject var settings: Settings
    @EnvironmentObject var revenueCat: RevenueCatManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(LockScreenPrayerTimesStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var prayerTimesStyleRaw = LockScreenPrayerTimesStyle.prayerTimelineWithLocation.rawValue
    @AppStorage(LockScreenPrayerCountdownBarStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var countdownBarStyleRaw = LockScreenPrayerCountdownBarStyle.withLocation.rawValue
    @AppStorage(WidgetZikirAlignment.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var zikirAlignmentRaw = WidgetZikirAlignment.center.rawValue
    @AppStorage(NextPrayerCircleStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var nextPrayerCircleStyleRaw = NextPrayerCircleStyle.classic.rawValue
    @AppStorage(PrayerListWidgetStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var prayerListStyleRaw = PrayerListWidgetStyle.classic.rawValue
    @AppStorage(DailyVerseWidgetStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var dailyVerseStyleRaw = DailyVerseWidgetStyle.classic.rawValue
    #if DEBUG
    @AppStorage(premiumWidgetsDebugOverrideStorageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var premiumWidgetsDebugOverrideRaw = 0
    #endif
    @State private var pendingLockedSelectionSnapshot: SelectionSnapshot?

    private var selectedPrayerTimesStyle: LockScreenPrayerTimesStyle {
        LockScreenPrayerTimesStyle(rawValue: prayerTimesStyleRaw) ?? .prayerCountdownWithLocation
    }

    private var prayerTimesStyle: LockScreenPrayerTimesStyle {
        (LockScreenPrayerTimesStyle(rawValue: prayerTimesStyleRaw) ?? .prayerCountdownWithLocation).resolvedForWidgetAccess
    }

    private var selectedCountdownBarStyle: LockScreenPrayerCountdownBarStyle {
        LockScreenPrayerCountdownBarStyle(rawValue: countdownBarStyleRaw) ?? .withLocation
    }

    private var countdownBarStyle: LockScreenPrayerCountdownBarStyle {
        (LockScreenPrayerCountdownBarStyle(rawValue: countdownBarStyleRaw) ?? .withLocation).resolvedForWidgetAccess
    }

    private var selectedZikirAlignment: WidgetZikirAlignment {
        WidgetZikirAlignment(rawValue: zikirAlignmentRaw) ?? .center
    }

    private var zikirAlignment: WidgetZikirAlignment {
        (WidgetZikirAlignment(rawValue: zikirAlignmentRaw) ?? .center).resolvedForWidgetAccess
    }

    private var selectedNextPrayerCircleStyle: NextPrayerCircleStyle {
        NextPrayerCircleStyle(rawValue: nextPrayerCircleStyleRaw) ?? .classic
    }

    private var nextPrayerCircleStyle: NextPrayerCircleStyle {
        (NextPrayerCircleStyle(rawValue: nextPrayerCircleStyleRaw) ?? .classic).resolvedForWidgetAccess
    }

    private var selectedPrayerListStyle: PrayerListWidgetStyle {
        PrayerListWidgetStyle(rawValue: prayerListStyleRaw) ?? .classic
    }

    private var prayerListStyle: PrayerListWidgetStyle {
        (PrayerListWidgetStyle(rawValue: prayerListStyleRaw) ?? .classic).resolvedForWidgetAccess
    }

    private var selectedDailyVerseStyle: DailyVerseWidgetStyle {
        DailyVerseWidgetStyle(rawValue: dailyVerseStyleRaw) ?? .classic
    }

    private var dailyVerseStyle: DailyVerseWidgetStyle {
        (DailyVerseWidgetStyle(rawValue: dailyVerseStyleRaw) ?? .classic).resolvedForWidgetAccess
    }

    private var sortedNextPrayerCircleStyles: [NextPrayerCircleStyle] {
        orderedStyles(NextPrayerCircleStyle.allCases) { $0.requiresPremiumWidgets }
    }

    private var sortedPrayerTimesStyles: [LockScreenPrayerTimesStyle] {
        orderedStyles(LockScreenPrayerTimesStyle.allCases) { $0.requiresPremiumWidgets }
    }

    private var sortedPrayerListStyles: [PrayerListWidgetStyle] {
        orderedStyles(PrayerListWidgetStyle.allCases) { $0.requiresPremiumWidgets }
    }

    private var sortedCountdownBarStyles: [LockScreenPrayerCountdownBarStyle] {
        orderedStyles(LockScreenPrayerCountdownBarStyle.allCases) { $0.requiresPremiumWidgets }
    }

    private var sortedZikirAlignments: [WidgetZikirAlignment] {
        orderedStyles(WidgetZikirAlignment.allCases) { $0.requiresPremiumWidgets }
    }

    private var sortedDailyVerseStyles: [DailyVerseWidgetStyle] {
        orderedStyles(DailyVerseWidgetStyle.allCases) { $0.requiresPremiumWidgets }
    }

    private func orderedStyles<Style>(_ styles: [Style], requiresPremium: (Style) -> Bool) -> [Style] {
        styles.filter { !requiresPremium($0) } + styles.filter(requiresPremium)
    }

    private var hasPremiumWidgetAccess: Bool {
        #if DEBUG
        _ = premiumWidgetsDebugOverrideRaw
        return premiumWidgetsUnlocked()
        #else
        revenueCat.hasPremiumWidgetsUnlocked
        #endif
    }

    private var unlockCTAForegroundColor: Color {
        if settings.accentColor == .adaptive {
            return colorScheme == .dark ? .black : .white
        }

        #if os(iOS)
        let resolved = UIColor(settings.accentColor.color).resolvedColor(with: UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .white
        }

        let luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
        return luminance > 0.67 ? .black : .white
        #else
        return .white
        #endif
    }

    private func captureSelectionSnapshot() -> SelectionSnapshot {
        SelectionSnapshot(
            prayerTimesStyleRaw: prayerTimesStyleRaw,
            countdownBarStyleRaw: countdownBarStyleRaw,
            zikirAlignmentRaw: zikirAlignmentRaw,
            nextPrayerCircleStyleRaw: nextPrayerCircleStyleRaw,
            prayerListStyleRaw: prayerListStyleRaw,
            dailyVerseStyleRaw: dailyVerseStyleRaw
        )
    }

    private func restoreSelectionSnapshot(_ snapshot: SelectionSnapshot) {
        prayerTimesStyleRaw = snapshot.prayerTimesStyleRaw
        countdownBarStyleRaw = snapshot.countdownBarStyleRaw
        zikirAlignmentRaw = snapshot.zikirAlignmentRaw
        nextPrayerCircleStyleRaw = snapshot.nextPrayerCircleStyleRaw
        prayerListStyleRaw = snapshot.prayerListStyleRaw
        dailyVerseStyleRaw = snapshot.dailyVerseStyleRaw
    }

    private func handleWidgetStyleSelection(requiresPremiumWidgets: Bool, action: () -> Void) {
        settings.hapticFeedback()

        if requiresPremiumWidgets && !hasPremiumWidgetAccess {
            pendingLockedSelectionSnapshot = captureSelectionSnapshot()
        } else {
            pendingLockedSelectionSnapshot = nil
        }

        withAnimation(.easeInOut) {
            action()
        }

        guard hasPremiumWidgetAccess || !requiresPremiumWidgets else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .openSupportDonationPaywall, object: nil)
            }
            return
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !hasPremiumWidgetAccess {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Waktu Pro")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("All widget styles, themes, and more")
                            .font(.caption)
                            .foregroundStyle(settings.accentColor.color)

                        Text("Prayer times and azan stay free, always.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)

                        Button {
                            settings.hapticFeedback()
                            NotificationCenter.default.post(name: .openSupportDonationPaywall, object: nil)
                        } label: {
                            Text("Get Waktu Pro")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(unlockCTAForegroundColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(settings.accentColor.color)
                        .padding(.top, 8)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Bulatan Solat Seterusnya" : "Next Prayer Circle",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih gaya untuk widget bulatan solat seterusnya."
                        : "Choose the style for the circular next prayer widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedNextPrayerCircleStyles) { style in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: style.requiresPremiumWidgets) {
                                        nextPrayerCircleStyleRaw = style.rawValue
                                    }
                                } label: {
                                    NextPrayerCircleStyleCard(
                                        style: style,
                                        isSelected: selectedNextPrayerCircleStyle == style,
                                        isLocked: style.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Waktu Solat" : "Prayer Times",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih gaya titik atau graf untuk widget waktu solat pada skrin kunci."
                        : "Choose the dotted or graph styles for the Lock Screen prayer times widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedPrayerTimesStyles) { style in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: style.requiresPremiumWidgets) {
                                        prayerTimesStyleRaw = style.rawValue
                                    }
                                } label: {
                                    PrayerTimesStyleCard(
                                        style: style,
                                        isSelected: selectedPrayerTimesStyle == style,
                                        isLocked: style.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Senarai Solat" : "Prayer List",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih gaya untuk widget senarai solat pada skrin kunci."
                        : "Choose the style for the Lock Screen prayer list widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedPrayerListStyles) { style in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: style.requiresPremiumWidgets) {
                                        prayerListStyleRaw = style.rawValue
                                    }
                                } label: {
                                    PrayerListStyleCard(
                                        style: style,
                                        isSelected: selectedPrayerListStyle == style,
                                        isLocked: style.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Kiraan Detik Solat" : "Prayer Countdown Bar",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih paparan bar kiraan detik untuk widget kiraan detik solat."
                        : "Choose the progress-bar presentation for the Lock Screen prayer countdown widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedCountdownBarStyles) { style in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: style.requiresPremiumWidgets) {
                                        countdownBarStyleRaw = style.rawValue
                                    }
                                } label: {
                                    PrayerCountdownBarStyleCard(
                                        style: style,
                                        isSelected: selectedCountdownBarStyle == style,
                                        isLocked: style.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Zikir & Selawat" : "Zikir & Selawat",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih gaya susunan untuk widget zikir pada skrin kunci."
                        : "Choose the layout style for the Lock Screen zikir widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedZikirAlignments) { alignment in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: alignment.requiresPremiumWidgets) {
                                        zikirAlignmentRaw = alignment.rawValue
                                    }
                                } label: {
                                    ZikirStyleCard(
                                        alignment: alignment,
                                        isSelected: selectedZikirAlignment == alignment,
                                        isLocked: alignment.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Inspirasi Al-Quran Harian" : "Daily Quran Inspiration",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih gaya untuk widget inspirasi Al-Quran harian pada skrin kunci."
                        : "Choose the style for the Lock Screen daily Quran widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedDailyVerseStyles) { style in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: style.requiresPremiumWidgets) {
                                        dailyVerseStyleRaw = style.rawValue
                                    }
                                } label: {
                                    DailyVerseStyleCard(
                                        style: style,
                                        isSelected: selectedDailyVerseStyle == style,
                                        isLocked: style.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Text(isMalayAppLanguage()
                     ? "Pilihan ini menandakan gaya pilihan anda di dalam aplikasi. iOS masih memerlukan pengguna menambah widget sebenar pada skrin kunci secara manual."
                     : "This marks your preferred style inside the app. iOS still requires users to add the actual widget to the Lock Screen manually.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onReceive(NotificationCenter.default.publisher(for: .supportDonationPaywallDismissed)) { _ in
            guard !hasPremiumWidgetAccess, let snapshot = pendingLockedSelectionSnapshot else { return }
            withAnimation(.easeInOut) {
                restoreSelectionSnapshot(snapshot)
            }
            pendingLockedSelectionSnapshot = nil
        }
        .onChange(of: revenueCat.hasPremiumWidgetsUnlocked) { unlocked in
            if unlocked {
                pendingLockedSelectionSnapshot = nil
            }
        }
        .navigationTitle(appLocalized("Widgets"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func previewSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)

            content()
        }
    }
}

enum WidgetsTabSegment: String, CaseIterable, Identifiable {
    case home
    case lock
    case live

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return isMalayAppLanguage() ? "Skrin Utama" : "Home Screen"
        case .lock:
            return isMalayAppLanguage() ? "Skrin Kunci" : "Lock Screen"
        case .live:
            return isMalayAppLanguage() ? "Aktiviti Langsung" : "Live Activity"
        }
    }
}

struct WidgetsTabView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var revenueCat: RevenueCatManager
    @State private var selectedSegment: WidgetsTabSegment = .home

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $selectedSegment) {
                    ForEach(WidgetsTabSegment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Group {
                    switch selectedSegment {
                    case .home:
                        HomeWidgetPresetManagerView()
                            .environmentObject(settings)
                            .environmentObject(revenueCat)
                    case .lock:
                        WidgetPreviewGalleryView()
                            .environmentObject(settings)
                            .environmentObject(revenueCat)
                    case .live:
                        LiveActivityWidgetSettingsView()
                            .environmentObject(settings)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(appLocalized("Widgets"))
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }
}

private struct HomeWidgetPresetManagerView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var revenueCat: RevenueCatManager
    @State private var selectedSlot: HomeWidgetPresetSlot?
    @State private var showingTasbihCustomization = false
    @State private var refreshID = UUID()

    private var hasPremiumWidgetAccess: Bool {
        premiumWidgetsUnlocked() || revenueCat.hasPremiumWidgetsUnlocked
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text(isMalayAppLanguage()
                     ? "Pilih gaya untuk preset widget yang akan digunakan oleh widget Waktu di Skrin Utama."
                     : "Choose the style for each saved Home Screen widget preset.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                presetSection(size: .small)
                presetSection(size: .medium)
                presetSection(size: .large)
                tasbihCounterSection

                Text(isMalayAppLanguage()
                     ? "Tambah widget Waktu pada Skrin Utama, kemudian pilih preset atau Tasbih Counter yang dikonfigurasi di sini."
                     : "Add Waktu widgets to your Home Screen, then choose one of these presets or the Tasbih Counter configured here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(refreshID)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            HomeWidgetPresetStore.seedDefaultsIfNeeded()
        }
        .sheet(item: $selectedSlot) { slot in
            HomeWidgetStyleSelectorSheet(
                slot: slot,
                hasPremiumWidgetAccess: hasPremiumWidgetAccess,
                onChange: {
                    refreshID = UUID()
                }
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $showingTasbihCustomization) {
            TasbihCounterCustomizationSheet {
                refreshID = UUID()
            }
            .environmentObject(settings)
        }
    }

    @ViewBuilder
    private func presetSection(size: HomeWidgetPresetSize) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sectionTitle(for: size))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(HomeWidgetPresetSlot.slots(for: size)) { slot in
                    Button {
                        settings.hapticFeedback()
                        selectedSlot = slot
                    } label: {
                        HomeWidgetPresetRow(
                            slot: slot,
                            style: HomeWidgetPresetStore.style(for: slot),
                            isLocked: HomeWidgetPresetStore.style(for: slot).requiresPremiumWidgets && !hasPremiumWidgetAccess
                        )
                    }
                    .buttonStyle(.plain)

                    if slot != HomeWidgetPresetSlot.slots(for: size).last {
                        Divider()
                            .padding(.leading, 132)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(for size: HomeWidgetPresetSize) -> String {
        switch size {
        case .small:
            return isMalayAppLanguage() ? "Widget Kecil" : "Small Widgets"
        case .medium:
            return isMalayAppLanguage() ? "Widget Sederhana" : "Medium Widgets"
        case .large:
            return isMalayAppLanguage() ? "Widget Besar" : "Large Widgets"
        }
    }

    private var tasbihCounterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isMalayAppLanguage() ? "Widget Interaktif" : "Interactive Widgets")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            Button {
                settings.hapticFeedback()
                showingTasbihCustomization = true
            } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tasbih Counter")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(isMalayAppLanguage() ? "Ketik untuk edit" : "Tap to customize")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(width: 88, alignment: .leading)

                    HStack(spacing: 8) {
                        HomeTasbihCounterSmallPreviewCard(theme: TasbihCounterStore.theme(), compact: true)
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        HomeTasbihCounterMediumPreviewCard(theme: TasbihCounterStore.theme(), compact: true)
                            .frame(width: 118, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeWidgetPresetRow: View {
    @EnvironmentObject var settings: Settings

    let slot: HomeWidgetPresetSlot
    let style: HomeWidgetStyle
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(isMalayAppLanguage() ? "Ketik untuk edit" : "Tap to edit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: 96, alignment: .leading)

            HomeWidgetPreviewCanvas(style: style, size: slot.size, displaySize: previewSize)
                .overlay {
                    if isLocked {
                        RoundedRectangle(cornerRadius: HomeWidgetCanvasMetrics.cornerRadius(for: slot.size, displaySize: previewSize), style: .continuous)
                            .fill(.regularMaterial)
                        Image(systemName: "lock.fill")
                            .font(.headline)
                            .foregroundStyle(settings.accentColor.color)
                    }
                }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private var previewSize: CGSize {
        switch slot.size {
        case .small:
            return CGSize(width: 86, height: 86)
        case .medium:
            return HomeWidgetCanvasMetrics.thumbnailSize(for: .medium, width: 142)
        case .large:
            return HomeWidgetCanvasMetrics.thumbnailSize(for: .large, width: 96)
        }
    }
}

private struct TasbihCounterCustomizationSheet: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.dismiss) private var dismiss

    let onChange: () -> Void

    @State private var selectedTheme = TasbihCounterStore.theme()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 14) {
                        HomeTasbihCounterSmallPreviewCard(theme: selectedTheme)
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

                        HomeTasbihCounterMediumPreviewCard(theme: selectedTheme)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(HomeWidgetCanvasMetrics.designSize(for: .medium), contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(isMalayAppLanguage() ? "Tema" : "Theme")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            ForEach(TasbihCounterTheme.allCases) { theme in
                                Button {
                                    settings.hapticFeedback()
                                    selectedTheme = theme
                                    TasbihCounterStore.setTheme(theme)
                                    WidgetCenter.shared.reloadTimelines(ofKind: TasbihCounterStore.widgetKind)
                                    onChange()
                                } label: {
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(HomeTasbihCounterPreviewPalette(theme: theme).accent)
                                            .frame(width: 26, height: 26)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(theme.title)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text(theme.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if selectedTheme == theme {
                                            Image(systemName: "checkmark")
                                                .font(.title3.weight(.bold))
                                                .foregroundStyle(settings.accentColor.color)
                                        }
                                    }
                                    .padding(14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if theme != TasbihCounterTheme.allCases.last {
                                    Divider()
                                        .padding(.leading, 54)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 16)
                    }

                    Button(role: .destructive) {
                        settings.hapticFeedback()
                        TasbihCounterStore.reset()
                        WidgetCenter.shared.reloadTimelines(ofKind: TasbihCounterStore.widgetKind)
                        onChange()
                    } label: {
                        Label(isMalayAppLanguage() ? "Set Semula Kiraan" : "Reset Counts", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tasbih Counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appLocalized("Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct HomeTasbihCounterPreviewPalette {
    let theme: TasbihCounterTheme

    var background: LinearGradient {
        switch theme {
        case .gold:
            return LinearGradient(
                colors: [Color(red: 0.06, green: 0.07, blue: 0.06), Color(red: 0.10, green: 0.12, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dawn:
            return LinearGradient(
                colors: [Color(red: 0.94, green: 0.91, blue: 0.82), Color(red: 0.78, green: 0.88, blue: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .slate:
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.10, blue: 0.13), Color(red: 0.14, green: 0.18, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var accent: Color {
        switch theme {
        case .gold:
            return Color(red: 0.83, green: 0.72, blue: 0.42)
        case .dawn:
            return Color(red: 0.10, green: 0.38, blue: 0.48)
        case .slate:
            return Color(red: 0.40, green: 0.68, blue: 0.92)
        }
    }

    var primaryText: Color {
        theme == .dawn ? .black : .white
    }

    var secondaryText: Color {
        primaryText.opacity(theme == .dawn ? 0.62 : 0.60)
    }

    var buttonText: Color {
        theme == .slate ? .black : (theme == .dawn ? .white : .black)
    }

    var rowBackground: Color {
        primaryText.opacity(theme == .dawn ? 0.12 : 0.045)
    }

    var rowActiveBackground: Color {
        primaryText.opacity(theme == .dawn ? 0.20 : 0.10)
    }
}

private struct HomeTasbihCounterSmallPreviewCard: View {
    let theme: TasbihCounterTheme
    var compact = false

    private var palette: HomeTasbihCounterPreviewPalette {
        HomeTasbihCounterPreviewPalette(theme: theme)
    }

    var body: some View {
        ZStack {
            palette.background

            VStack(alignment: .leading, spacing: compact ? 4 : 10) {
                VStack(alignment: .leading, spacing: compact ? 1 : 4) {
                    Text("SubhanAllah")
                        .font(.system(size: compact ? 8 : 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text("17 / 33")
                        .font(.system(size: compact ? 14 : 28, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                ProgressView(value: 17, total: 33)
                    .tint(palette.accent)
                    .scaleEffect(x: 1, y: compact ? 0.7 : 1.4, anchor: .center)

                Spacer(minLength: 0)

                Text("+1")
                    .font(.system(size: compact ? 9 : 18, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.buttonText)
                    .frame(maxWidth: .infinity, minHeight: compact ? 14 : 34)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: compact ? 5 : 10, style: .continuous))
            }
            .padding(compact ? 6 : 16)
        }
    }
}

private struct HomeTasbihCounterMediumPreviewCard: View {
    let theme: TasbihCounterTheme
    var compact = false

    private var palette: HomeTasbihCounterPreviewPalette {
        HomeTasbihCounterPreviewPalette(theme: theme)
    }

    var body: some View {
        ZStack {
            palette.background

            HStack(alignment: .center, spacing: compact ? 8 : 14) {
                VStack(alignment: .leading, spacing: compact ? 5 : 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Morning Dhikr")
                            .font(.system(size: compact ? 11 : 18, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(1)
                        if !compact {
                            Text("Tasbih, Tahmid, Takbir")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    VStack(spacing: compact ? 3 : 6) {
                        HomeTasbihCounterPreviewRow(title: "SubhanAllah", count: 17, target: 33, active: true, compact: compact, palette: palette)
                        HomeTasbihCounterPreviewRow(title: "Alhamdulillah", count: 0, target: 33, active: false, compact: compact, palette: palette)
                        HomeTasbihCounterPreviewRow(title: "Allahu Akbar", count: 0, target: 34, active: false, compact: compact, palette: palette)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                VStack(spacing: compact ? 4 : 8) {
                    Text("17/100")
                        .font(.system(size: compact ? 9 : 14, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.accent)
                        .monospacedDigit()
                        .lineLimit(1)

                    Text("+1")
                        .font(.system(size: compact ? 11 : 18, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.buttonText)
                        .frame(width: compact ? 38 : 74, height: compact ? 22 : 46)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: compact ? 7 : 12, style: .continuous))

                    Text("Reset")
                        .font(.system(size: compact ? 8 : 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .frame(width: compact ? 38 : 74, height: compact ? 18 : 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: compact ? 7 : 10, style: .continuous)
                                .stroke(palette.primaryText.opacity(0.35), lineWidth: 1)
                        )
                }
                .frame(minWidth: compact ? 42 : 82, idealWidth: compact ? 42 : 82, maxWidth: compact ? 42 : 82, maxHeight: .infinity)
            }
            .padding(compact ? 8 : 16)
        }
    }
}

private struct HomeTasbihCounterPreviewRow: View {
    let title: String
    let count: Int
    let target: Int
    let active: Bool
    let compact: Bool
    let palette: HomeTasbihCounterPreviewPalette

    var body: some View {
        HStack(spacing: compact ? 5 : 10) {
            Capsule()
                .fill(active ? palette.accent : palette.primaryText.opacity(0.16))
                .frame(width: compact ? 2 : 4)

            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: compact ? 8 : 13, weight: active ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(active ? palette.primaryText : palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 2)

                Text("\(count)/\(target)")
                    .font(.system(size: compact ? 8 : 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(active ? palette.accent : palette.secondaryText)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, compact ? 5 : 10)
        .padding(.vertical, compact ? 4 : 8)
        .background(
            RoundedRectangle(cornerRadius: compact ? 7 : 12, style: .continuous)
                .fill(active ? palette.rowActiveBackground : palette.rowBackground)
        )
    }
}

private struct HomeWidgetStyleSelectorSheet: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.dismiss) private var dismiss

    let slot: HomeWidgetPresetSlot
    let hasPremiumWidgetAccess: Bool
    let onChange: () -> Void

    @State private var selectedStyle: HomeWidgetStyle

    init(slot: HomeWidgetPresetSlot, hasPremiumWidgetAccess: Bool, onChange: @escaping () -> Void) {
        self.slot = slot
        self.hasPremiumWidgetAccess = hasPremiumWidgetAccess
        self.onChange = onChange
        _selectedStyle = State(initialValue: HomeWidgetPresetStore.style(for: slot))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HomeWidgetHeroPreview(style: selectedStyle, size: slot.size)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    VStack(spacing: 0) {
                        ForEach(HomeWidgetStyle.styles(for: slot.size)) { style in
                            Button {
                                settings.hapticFeedback()
                                selectedStyle = style
                                guard !style.requiresPremiumWidgets || hasPremiumWidgetAccess else {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        NotificationCenter.default.post(name: .openSupportDonationPaywall, object: nil)
                                    }
                                    return
                                }
                                HomeWidgetPresetStore.setStyle(style, for: slot)
                                WidgetCenter.shared.reloadAllTimelines()
                                onChange()
                            } label: {
                                HStack(spacing: 14) {
                                    HomeWidgetPreviewCanvas(
                                        style: style,
                                        size: slot.size,
                                        displaySize: HomeWidgetCanvasMetrics.thumbnailSize(for: slot.size, width: 74)
                                    )

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(style.title)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            if style.requiresPremiumWidgets {
                                                PremiumWidgetBadge()
                                            }
                                        }
                                        Text(style.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    if selectedStyle == style {
                                        Image(systemName: "checkmark")
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(settings.accentColor.color)
                                    } else if style.requiresPremiumWidgets && !hasPremiumWidgetAccess {
                                        Image(systemName: "lock.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if style != HomeWidgetStyle.styles(for: slot.size).last {
                                Divider()
                                    .padding(.leading, 102)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(slot.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appLocalized("Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appLocalized("Save")) {
                        if !selectedStyle.requiresPremiumWidgets || hasPremiumWidgetAccess {
                            HomeWidgetPresetStore.setStyle(selectedStyle, for: slot)
                            WidgetCenter.shared.reloadAllTimelines()
                            onChange()
                        }
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

private enum HomeWidgetCanvasMetrics {
    static func designSize(for size: HomeWidgetPresetSize) -> CGSize {
        switch size {
        case .small:
            return CGSize(width: 170, height: 170)
        case .medium:
            return CGSize(width: 364, height: 170)
        case .large:
            return CGSize(width: 364, height: 382)
        }
    }

    static func thumbnailSize(for size: HomeWidgetPresetSize, width: CGFloat) -> CGSize {
        let design = designSize(for: size)
        return CGSize(width: width, height: width * design.height / design.width)
    }

    static func cornerRadius(for size: HomeWidgetPresetSize, displaySize: CGSize) -> CGFloat {
        let base = designSize(for: size)
        let scale = min(displaySize.width / base.width, displaySize.height / base.height)
        return max(12, 32 * scale)
    }
}

private struct HomeWidgetHeroPreview: View {
    let style: HomeWidgetStyle
    let size: HomeWidgetPresetSize

    var body: some View {
        GeometryReader { proxy in
            let horizontalInset = heroHorizontalInset
            let availableWidth = max(1, proxy.size.width - horizontalInset)
            let design = HomeWidgetCanvasMetrics.designSize(for: size)
            let displayWidth = min(availableWidth, design.width)
            let displaySize = CGSize(width: displayWidth, height: displayWidth * design.height / design.width)

            HomeWidgetPreviewCanvas(style: style, size: size, displaySize: displaySize)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: heroHeight)
    }

    private var heroHeight: CGFloat {
        switch size {
        case .small:
            return 250
        case .medium:
            return 190
        case .large:
            return 410
        }
    }

    private var heroHorizontalInset: CGFloat {
        if size == .small {
            return 54
        }
        if size == .large && style == .metro {
            return 48
        }
        return 0
    }
}

private struct HomeWidgetPreviewCanvas: View {
    @Environment(\.colorScheme) private var colorScheme

    let style: HomeWidgetStyle
    let size: HomeWidgetPresetSize
    let displaySize: CGSize

    var body: some View {
        let designSize = HomeWidgetCanvasMetrics.designSize(for: size)
        let scale = min(displaySize.width / designSize.width, displaySize.height / designSize.height)
        let cornerRadius = HomeWidgetCanvasMetrics.cornerRadius(for: size, displaySize: displaySize)

        ZStack {
            widgetBackground

            HomeWidgetStylePreviewContent(style: style, size: size)
                .frame(width: designSize.width, height: designSize.height)
                .scaleEffect(scale, anchor: .center)
                .frame(width: displaySize.width, height: displaySize.height)
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }

    private var widgetBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemBackground)
    }
}

private struct HomeWidgetStylePreviewContent: View {
    @EnvironmentObject var settings: Settings

    let style: HomeWidgetStyle
    let size: HomeWidgetPresetSize

    var body: some View {
        Group {
            switch style {
            case .simpleCountdown:
                HomeSimpleCountdownPreviewCard(accentColor: settings.accentColor.color)
            case .countdown:
                HomeCountdownSmallPreviewCard(accentColor: settings.accentColor.color)
            case .countdownMedium:
                HomeCountdownMediumPreviewCard(accentColor: settings.accentColor.color)
            case .countdownLarge:
                HomeCountdownLargePreviewCard(accentColor: settings.accentColor.color)
            case .prayerTimesCompact:
                HomePrayerTimesMediumPreviewCard(accentColor: settings.accentColor.color)
            case .prayerTimesGrid:
                HomePrayerTimesMediumGridPreviewCard(accentColor: settings.accentColor.color)
            case .prayerTimesLarge:
                HomePrayerTimesLargePreviewCard(accentColor: settings.accentColor.color)
            case .minimalist:
                if size == .small {
                    HomeMinimalistSmallPreviewCard()
                } else if size == .medium {
                    HomeMinimalistMediumPreviewCard()
                } else {
                    HomeMinimalistLargePreviewCard()
                }
            case .metro:
                switch size {
                case .small:
                    HomeMetroSmallPreviewCard()
                case .medium:
                    HomeMetroMediumPreviewCard()
                case .large:
                    HomeMetroLargePreviewCard()
                }
            case .neo:
                switch size {
                case .small:
                    HomeNeoSmallPreviewCard()
                case .medium:
                    HomeNeoMediumPreviewCard()
                case .large:
                    HomeNeoLargePreviewCard()
                }
            case .neoTransit:
                HomeNeoTransitSmallPreviewCard()
            case .sketch:
                switch size {
                case .small:
                    HomeSketchSmallPreviewCard()
                case .medium:
                    HomeSketchMediumPreviewCard()
                case .large:
                    HomeSketchLargePreviewCard()
                }
            case .proNext:
                HomeProNextPreviewCard()
            case .proIndex:
                HomeProIndexPreviewCard()
            case .proArc:
                HomeProArcPreviewCard()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private struct LiveActivityWidgetSettingsView: View {
    @EnvironmentObject var settings: Settings
    @AppStorage(LiveNotificationStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var selectedStyleRaw = LiveNotificationStyle.current.rawValue

    private var selectedStyle: LiveNotificationStyle {
        LiveNotificationStyle(rawValue: selectedStyleRaw) ?? .current
    }

    var body: some View {
        List {
            Section {
                Toggle(appLocalized("Live Next Prayer Activity"), isOn: $settings.liveNextPrayerEnabled.animation(.easeInOut))
                    .font(.subheadline)
                    .tint(settings.accentColor.toggleTint)

                Text(settings.liveNextPrayerEnabled
                     ? "Live Activity appears \(max(0, settings.liveActivityLeadMinutes)) minutes before prayer time. This timing is fixed for now."
                     : "Shows a live countdown to the next prayer on the Lock Screen when that prayer notification is enabled.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(isMalayAppLanguage() ? "Aktiviti Langsung" : "Live Activity")
            }

            Section {
                ForEach(LiveNotificationStyle.allCases) { style in
                    Button {
                        settings.hapticFeedback()
                        withAnimation {
                            selectedStyleRaw = style.rawValue
                        }
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: style.previewSystemImage)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(settings.accentColor.color)
                                .frame(width: 42, height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(settings.accentColor.color.opacity(0.12))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(style.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(style.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedStyle == style {
                                Image(systemName: "checkmark")
                                    .font(.headline.weight(.bold))
                                    .foregroundColor(settings.accentColor.color)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(isMalayAppLanguage() ? "Gaya" : "Style")
            } footer: {
                Text("The selected style is used by the real Live Activity.")
            }
        }
        .applyConditionalListStyle(defaultView: true)
    }
}

#if DEBUG
struct WidgetPreviewVerificationView: View {
    @EnvironmentObject var settings: Settings

    private let requestedSize: HomeWidgetPresetSize
    private let requestedStyle: HomeWidgetStyle

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let parsedSize = Self.value(after: "--widget-preview-size", in: arguments)
            .flatMap(HomeWidgetPresetSize.init(rawValue:)) ?? .small
        let parsedStyle = Self.value(after: "--widget-preview-style", in: arguments)
            .flatMap(HomeWidgetStyle.init(rawValue:)) ?? HomeWidgetStyle.styles(for: parsedSize).first ?? .simpleCountdown
        requestedSize = parsedSize
        requestedStyle = parsedStyle.supports(parsedSize) ? parsedStyle : (HomeWidgetStyle.styles(for: parsedSize).first ?? .simpleCountdown)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text("Widget Preview Verification")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(requestedSize.rawValue) / \(requestedStyle.rawValue)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("widget-verification-header")

                HomeWidgetPreviewCanvas(
                    style: requestedStyle,
                    size: requestedSize,
                    displaySize: displaySize
                )
                .accessibilityIdentifier("widget-verification-canvas")

                Text("Design canvas \(Int(HomeWidgetCanvasMetrics.designSize(for: requestedSize).width))x\(Int(HomeWidgetCanvasMetrics.designSize(for: requestedSize).height))")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .preferredColorScheme(.light)
        .onAppear {
            HomeWidgetPresetStore.seedDefaultsIfNeeded()
        }
    }

    private var displaySize: CGSize {
        let design = HomeWidgetCanvasMetrics.designSize(for: requestedSize)
        let maxWidth: CGFloat = requestedSize == .small ? 220 : 340
        let width = min(maxWidth, design.width)
        return CGSize(width: width, height: width * design.height / design.width)
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }
}
#endif

struct HomeWidgetPreviewGalleryView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var revenueCat: RevenueCatManager
    @AppStorage(AuraWidgetStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var auraStyleRaw = AuraWidgetStyle.gradient.rawValue
    @State private var activeFilter: WidgetGalleryFilter = .all
    @State private var heroPage: Int = 0

    private enum WidgetGalleryFilter: String, CaseIterable {
        case all = "All"; case pro = "Pro"; case metro = "Metro"; case neo = "Neo"; case sketch = "Sketch"; case aura = "Aura"; case minimalist = "Minimalist"; case lite = "Lite"
    }

    private var selectedAuraStyle: AuraWidgetStyle {
        AuraWidgetStyle(rawValue: auraStyleRaw) ?? .gradient
    }

    private var hasPremiumWidgetAccess: Bool {
        premiumWidgetsUnlocked() || revenueCat.hasPremiumWidgetsUnlocked
    }

    private func selectAuraStyle(_ style: AuraWidgetStyle) {
        settings.hapticFeedback()
        withAnimation(.easeInOut) { auraStyleRaw = style.rawValue }
        if style.requiresPremiumWidgets && !hasPremiumWidgetAccess {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .openSupportDonationPaywall, object: nil)
            }
        } else {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── Hero Carousel ────────────────────────────────
                TabView(selection: $heroPage) {
                    HeroProSlide(hasPremiumWidgetAccess: hasPremiumWidgetAccess)
                        .tag(0)
                    HeroAuraSlide()
                        .tag(1)
                    HeroMinimalSlide()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 230)
                .padding(.top, 8)
                .onReceive(Timer.publish(every: 4, on: .main, in: .common).autoconnect()) { _ in
                    withAnimation(.easeInOut(duration: 0.55)) {
                        heroPage = (heroPage + 1) % 3
                    }
                }

                // ── Filter Tabs ─────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(WidgetGalleryFilter.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { activeFilter = tab }
                            } label: {
                                Text(tab.rawValue)
                                    .font(.system(size: 14, weight: activeFilter == tab ? .semibold : .regular))
                                    .foregroundStyle(activeFilter == tab ? .primary : .secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 100, style: .continuous)
                                            .fill(activeFilter == tab
                                                  ? Color(.secondarySystemGroupedBackground)
                                                  : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 100, style: .continuous)
                            .fill(Color(.systemGroupedBackground))
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // ── Pro Section ─────────────────────────────────
                if activeFilter == .all || activeFilter == .pro {
                    packSectionHeader(
                        title: "Waktu Pro",
                        subtitle: isMalayAppLanguage()
                            ? "Widget premium dengan gaya kaca gelap."
                            : "Premium widgets with dark glass styling."
                    )
                    VStack(spacing: 1) {
                        proWidgetRow(
                            title: isMalayAppLanguage() ? "Solat Seterusnya" : "Next Prayer",
                            description: isMalayAppLanguage()
                                ? "Tunjukkan solat seterusnya dan kiraan detik."
                                : "Shows the next prayer and countdown.",
                            isSelected: hasPremiumWidgetAccess
                        ) {
                            HomeProNextPreviewCard()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        proWidgetRow(
                            title: isMalayAppLanguage() ? "Indeks Solat" : "Prayer Index",
                            description: isMalayAppLanguage()
                                ? "Semua waktu solat dalam susun atur padat."
                                : "View all prayer times in a compact layout.",
                            isSelected: hasPremiumWidgetAccess
                        ) {
                            HomeProIndexPreviewCard()
                                .frame(width: 100, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        proWidgetRow(
                            title: isMalayAppLanguage() ? "Lengkok Matahari" : "Arc",
                            description: isMalayAppLanguage()
                                ? "Laluan matahari dengan penanda masa kini."
                                : "Sun path arc with current-moment marker.",
                            isSelected: hasPremiumWidgetAccess
                        ) {
                            HomeProArcPreviewCard()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        proWidgetRow(
                            title: isMalayAppLanguage() ? "Zikir Pro" : "Zikir",
                            description: isMalayAppLanguage()
                                ? "Zikir Arab dengan terjemahan, bergilir mengikut waktu."
                                : "Arabic adhkar with translation, rotates by time.",
                            isSelected: hasPremiumWidgetAccess
                        ) {
                            HomeProZikirPreviewCard()
                                .frame(width: 100, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        proWidgetRow(
                            title: isMalayAppLanguage() ? "Skrin Kunci" : "Lock Screen",
                            description: isMalayAppLanguage()
                                ? "Kiraan detik solat di skrin kunci anda."
                                : "Glanceable prayer countdown on your Lock Screen.",
                            isSelected: hasPremiumWidgetAccess
                        ) {
                            HomeProLockPreviewCard()
                                .frame(width: 100, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                }

                // ── Metro Section ───────────────────────────────
                if activeFilter == .all || activeFilter == .metro {
                    packSectionHeader(
                        title: "Waktu Metro",
                        subtitle: isMalayAppLanguage()
                            ? "Papan jadual transit untuk waktu solat anda."
                            : "Transit-board tiles for your prayer times."
                    )
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Metro Mini" : "Metro Mini",
                                family: .small
                            ) { HomeMetroSmallPreviewCard() }
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Metro" : "Metro",
                                family: .medium
                            ) { HomeMetroMediumPreviewCard() }
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Metro Max" : "Metro Max",
                                family: .large
                            ) { HomeMetroLargePreviewCard() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }

                // ── Neo Section ─────────────────────────────────
                if activeFilter == .all || activeFilter == .neo {
                    packSectionHeader(
                        title: "Waktu Neo",
                        subtitle: isMalayAppLanguage()
                            ? "Terminal gelap dengan aksen hijau limau."
                            : "Dark terminal aesthetic with lime green accents."
                    )
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            HomeWidgetShowcaseCard(
                                title: "Neo",
                                family: .small
                            ) { HomeNeoSmallPreviewCard() }
                            HomeWidgetShowcaseCard(
                                title: "Neo Board",
                                family: .medium
                            ) { HomeNeoMediumPreviewCard() }
                            HomeWidgetShowcaseCard(
                                title: "Neo Progress",
                                family: .large
                            ) { HomeNeoLargePreviewCard() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }

                // ── Sketch Section ───────────────────────────────
                if activeFilter == .all || activeFilter == .sketch {
                    packSectionHeader(
                        title: "Waktu Sketch",
                        subtitle: isMalayAppLanguage()
                            ? "Kanvas terang dengan gelombang oren dan corak lakaran."
                            : "Light canvas with orange waves and sketch textures."
                    )
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            HomeWidgetShowcaseCard(
                                title: "Sketch",
                                family: .small
                            ) { HomeSketchSmallPreviewCard() }
                            HomeWidgetShowcaseCard(
                                title: "Sketch Progress",
                                family: .medium
                            ) { HomeSketchMediumPreviewCard() }
                            HomeWidgetShowcaseCard(
                                title: "Sketch Max",
                                family: .large
                            ) { HomeSketchLargePreviewCard() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }

                // ── Aura Section ────────────────────────────────
                if activeFilter == .all || activeFilter == .aura {
                    packSectionHeader(
                        title: "Waktu Aura",
                        subtitle: isMalayAppLanguage()
                            ? "Pek warna terinspirasi dari momen solat."
                            : "Colorful packs inspired by prayer moments."
                    )
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(AuraWidgetStyle.allCases) { style in
                                Button {
                                    selectAuraStyle(style)
                                } label: {
                                    HomeAuraStyleCard(
                                        style: style,
                                        isSelected: selectedAuraStyle == style,
                                        isLocked: style.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }

                // ── Minimalist Section ──────────────────────────
                if activeFilter == .all || activeFilter == .minimalist {
                    packSectionHeader(
                        title: "Waktu Minimalist",
                        subtitle: isMalayAppLanguage()
                            ? "Reka bentuk bersih, fokus pada yang penting."
                            : "Clean design, focused on what matters."
                    )
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Minimalist Mini" : "Minimalist Mini",
                                family: .small
                            ) { HomeMinimalistSmallPreviewCard() }
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Minimalist" : "Minimalist",
                                family: .medium
                            ) { HomeMinimalistMediumPreviewCard() }
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Minimalist Max" : "Minimalist Max",
                                family: .large
                            ) { HomeMinimalistLargePreviewCard() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }

                // ── Lite Section (all free widgets) ─────────────
                if activeFilter == .all || activeFilter == .lite {
                    packSectionHeader(
                        title: isMalayAppLanguage() ? "Waktu Lite" : "Waktu Lite",
                        subtitle: isMalayAppLanguage()
                            ? "Semua widget percuma — percuma selama-lamanya."
                            : "All the free widgets — free, always."
                    )
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Next Mini" : "Next Mini",
                                family: .small
                            ) { HomeSimpleCountdownPreviewCard(accentColor: settings.accentColor.color) }
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Countdown Mini" : "Countdown Mini",
                                family: .small
                            ) { HomeCountdownSmallPreviewCard(accentColor: settings.accentColor.color) }
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Countdown" : "Countdown",
                                family: .medium
                            ) { HomeCountdownMediumPreviewCard(accentColor: settings.accentColor.color) }
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Countdown Max" : "Countdown Max",
                                family: .large
                            ) { HomeCountdownLargePreviewCard(accentColor: settings.accentColor.color) }
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Times Compact" : "Times Compact",
                                family: .medium
                            ) { HomePrayerTimesMediumPreviewCard(accentColor: settings.accentColor.color) }
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Times" : "Times",
                                family: .medium
                            ) { HomePrayerTimesMediumGridPreviewCard(accentColor: settings.accentColor.color) }
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Times Max" : "Times Max",
                                family: .large
                            ) { HomePrayerTimesLargePreviewCard(accentColor: settings.accentColor.color) }
                            HomeWidgetShowcaseCard(
                                title: isMalayAppLanguage() ? "Zikir" : "Zikir",
                                family: .small
                            ) { HomeZikirPreviewCard(compact: true) }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }

                // ── Coming Soon ─────────────────────────────────
                if activeFilter == .all {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isMalayAppLanguage() ? "Akan Datang" : "Coming Soon")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(isMalayAppLanguage()
                             ? "Lebih banyak pek widget cantik sedang dalam perjalanan."
                             : "More beautiful packs are on the way.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
                    .padding(.bottom, 12)

                    VStack(spacing: 1) {
                        comingSoonRow(
                            icon: "🪔",
                            title: isMalayAppLanguage() ? "Pek Ramadan" : "Ramadan Pack",
                            description: isMalayAppLanguage()
                                ? "Reka bentuk khas untuk momen Ramadan."
                                : "Special designs for Ramadan moments."
                        )
                        comingSoonRow(
                            icon: "📱",
                            title: isMalayAppLanguage() ? "Widget Skrin Kunci" : "Lock Screen",
                            description: isMalayAppLanguage()
                                ? "Widget dioptimumkan untuk skrin kunci anda."
                                : "Widgets optimized for your lock screen."
                        )
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isMalayAppLanguage() ? "Widget Skrin Utama" : "Home Screen Widgets")
        .navigationBarTitleDisplayMode(.large)
    }

    // ── Sub-views ────────────────────────────────────────────────

    @ViewBuilder
    private func packSectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func proWidgetRow<Preview: View>(
        title: String,
        description: String,
        isSelected: Bool,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        HStack(spacing: 14) {
            preview()

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(pvGold)
                    }
                    Text(isSelected
                         ? (isMalayAppLanguage() ? "Dipilih" : "Selected")
                         : (isMalayAppLanguage() ? "Pro" : "Pro"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(pvGold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 100)
                        .stroke(pvGold.opacity(0.4), lineWidth: 1)
                )
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(14)
    }

    @ViewBuilder
    private func comingSoonRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 48, height: 48)
                Text(icon)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(isMalayAppLanguage() ? "Nanti" : "Soon")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 100)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
        }
        .padding(14)
    }

    @ViewBuilder
    private func previewSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            content()
        }
    }
}

private enum HomeWidgetPreviewFamily {
    case small
    case medium
    case large

    var canvasSize: CGSize {
        switch self {
        case .small:
            return CGSize(width: 150, height: 150)
        case .medium:
            return CGSize(width: 318, height: 150)
        case .large:
            return CGSize(width: 318, height: 330)
        }
    }

    var sizeLabel: String {
        switch self {
        case .small:
            return "systemSmall"
        case .medium:
            return "systemMedium"
        case .large:
            return "systemLarge"
        }
    }
}

private struct HomeWidgetShowcaseCard<Preview: View>: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let family: HomeWidgetPreviewFamily
    let contentPadding: CGFloat
    let isSelected: Bool
    let preview: Preview

    init(
        title: String,
        family: HomeWidgetPreviewFamily,
        contentPadding: CGFloat = 12,
        isSelected: Bool = true,
        @ViewBuilder body: () -> Preview
    ) {
        self.title = title
        self.family = family
        self.contentPadding = contentPadding
        self.isSelected = isSelected
        self.preview = body()
    }

    var cardBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemBackground)
    }

    var bodyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetCanvas(preview: AnyView(preview), family: family)

            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(settings.accentColor.color)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? settings.accentColor.color : .primary)
            }
        }
    }

    @ViewBuilder
    fileprivate func widgetCanvas(preview: AnyView, family: HomeWidgetPreviewFamily) -> some View {
        let size = family.canvasSize
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardBackground)

            LinearGradient(
                colors: [
                    colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                    settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            preview
                .padding(contentPadding)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .frame(width: size.width, height: size.height)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    isSelected ? settings.accentColor.color : Color.black.opacity(0.08),
                    lineWidth: isSelected ? 2.5 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)
    }

    var body: some View { bodyView }
}

private struct HomeAuraPreviewCard: View {
    let square: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.63, blue: 0.34),
                    Color(red: 0.73, green: 0.28, blue: 0.25),
                    Color(red: 0.21, green: 0.13, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [Color.black.opacity(0.08), Color.black.opacity(0.32)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: square ? 3 : 4) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(square ? .subheadline : .headline)
                    Text(localizedPrayerName("Maghrib"))
                        .font((square ? Font.title3 : Font.title2).weight(.bold))
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(square ? "7:31" : "7:31")
                        .font(.system(size: square ? 34 : 42, weight: .bold, design: .rounded))
                    Text("PM")
                        .font((square ? Font.title3 : Font.title2).weight(.semibold))
                }

                HStack(spacing: 5) {
                    Text(isMalayAppLanguage() ? "Dalam" : "In")
                    Text("1h 14m")
                        .monospacedDigit()
                }
                .font((square ? Font.subheadline : Font.title3).weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(square ? 12 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct HomeMidnightAuraPreviewCard: View {
    let square: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            Color(red: 0.05, green: 0.07, blue: 0.14)

            RadialGradient(
                colors: [Color(red: 0.25, green: 0.30, blue: 0.70).opacity(0.40), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: square ? 120 : 180
            )

            VStack(alignment: .leading, spacing: square ? 3 : 4) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(square ? .subheadline : .headline)
                        .foregroundStyle(Color(red: 0.65, green: 0.72, blue: 1.0))
                    Text(localizedPrayerName("Maghrib"))
                        .font((square ? Font.title3 : Font.title2).weight(.bold))
                        .foregroundStyle(.white)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("7:31")
                        .font(.system(size: square ? 34 : 42, weight: .bold, design: .rounded))
                    Text("PM")
                        .font((square ? Font.title3 : Font.title2).weight(.semibold))
                }
                .foregroundStyle(.white)

                HStack(spacing: 5) {
                    Text(isMalayAppLanguage() ? "Dalam" : "In")
                    Text("1h 14m")
                        .monospacedDigit()
                }
                .font((square ? Font.subheadline : Font.title3).weight(.semibold))
                .foregroundStyle(Color(red: 0.65, green: 0.72, blue: 1.0))
            }
            .padding(square ? 12 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct HomeAuraStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: AuraWidgetStyle
    let isSelected: Bool
    let isLocked: Bool

    private var cardBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemBackground)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(cardBackground)
                Group {
                    switch style {
                    case .gradient:
                        HomeAuraPreviewCard(square: false)
                    case .midnight:
                        HomeMidnightAuraPreviewCard(square: false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .frame(width: 260, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        isSelected ? settings.accentColor.color : Color.primary.opacity(0.10),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.10), radius: 8, y: 4)
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color, cornerRadius: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(settings.accentColor.color)
                    }
                    Text(style.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? settings.accentColor.color : .primary)
                }
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: isLocked,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
        }
        .frame(width: 260)
    }
}

private struct HomeSimpleCountdownPreviewCard: View {
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 3) {
                Text(appLocalized("Time left:"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("1:14:22")
                    .font(.caption.monospacedDigit().weight(.semibold))
            }

            Spacer()

            VStack(spacing: 4) {
                Image(systemName: "sunset.fill")
                    .font(.title2)
                Text(localizedPrayerName("Maghrib"))
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(accentColor)

            HStack(spacing: 4) {
                Text("Next:")
                Image(systemName: "moon.stars.fill")
                Text(localizedPrayerName("Isha"))
            }
            .font(.caption)
            .foregroundStyle(accentColor)

            HStack(spacing: 3) {
                Text(appLocalized("Starts at"))
                Text("20:38")
                    .monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private enum HomeMinimalistPreviewTheme {
    case subuh

    static let flatGray = Color(red: 0.902, green: 0.902, blue: 0.918)  // #E6E6EA
    static let flatBlue = Color(red: 0.647, green: 0.773, blue: 0.882)  // #A5C5E1
    static let flatDark = Color(red: 0.157, green: 0.176, blue: 0.208)  // #282D35

    var background: LinearGradient {
        LinearGradient(colors: [Self.flatGray], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var blueTile: LinearGradient {
        LinearGradient(colors: [Self.flatBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var darkTile: LinearGradient {
        LinearGradient(colors: [Self.flatDark], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct HomeMinimalistSmallPreviewCard: View {
    private let theme = HomeMinimalistPreviewTheme.subuh

    var body: some View {
        ZStack {
            theme.background

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    HomeMinimalistSunriseIcon(size: 34)
                    Spacer(minLength: 8)
                    Text("Subuh")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("5:48")
                    .font(.system(size: 40, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text("Mon")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .padding(.top, 2)

                Text("Kuala Lumpur")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.black.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .padding(.top, 4)
            }
            .padding(15)
        }
    }
}

private struct HomeMinimalistMediumPreviewCard: View {
    private let theme = HomeMinimalistPreviewTheme.subuh

    var body: some View {
        ZStack {
            HomeMinimalistPreviewTheme.flatGray

            HStack(spacing: 8) {
                ZStack {
                    theme.background

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            HomeMinimalistSunriseIcon(size: 36)
                            Spacer(minLength: 10)
                            Text("Subuh")
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Text("Mon")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .lineLimit(1)

                        Text("Kuala Lumpur")
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .foregroundStyle(.black.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .padding(.top, 5)
                    }
                    .padding(14)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 8) {
                    HomeMinimalistInfoPreviewTile(
                        background: theme.blueTile,
                        icon: "sun.max",
                        time: "4:32",
                        label: nil,
                        foreground: .black
                    )
                    HomeMinimalistInfoPreviewTile(
                        background: theme.darkTile,
                        icon: nil,
                        time: "7:24",
                        label: "Next",
                        foreground: .white
                    )
                }
                .frame(width: 130)
            }
            .padding(9)
        }
    }
}

private struct HomeMinimalistInfoPreviewTile: View {
    let background: LinearGradient
    let icon: String?
    let time: String
    let label: String?
    let foreground: Color

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 30, weight: .semibold))
                    }
                    Text(time)
                        .font(.system(size: 31, weight: .regular, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }

                if let label {
                    Text(label)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HomeMinimalistLargePreviewCard: View {
    private let theme = HomeMinimalistPreviewTheme.subuh

    var body: some View {
        ZStack {
            HomeMinimalistPreviewTheme.flatGray

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        theme.background

                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top) {
                                HomeMinimalistSunriseIcon(size: 48)
                                Spacer(minLength: 12)
                                Text("Subuh")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundStyle(.black)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 10)

                            Text("5:48")
                                .font(.system(size: 54, weight: .regular, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text("Kuala Lumpur")
                                .font(.system(size: 18, weight: .regular, design: .rounded))
                                .foregroundStyle(.black.opacity(0.86))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .padding(.top, 8)
                        }
                        .padding(18)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(spacing: 10) {
                        HomeMinimalistInfoPreviewTile(
                            background: theme.blueTile,
                            icon: "sun.max",
                            time: "4:32",
                            label: "Subuh",
                            foreground: .black
                        )
                        HomeMinimalistInfoPreviewTile(
                            background: theme.darkTile,
                            icon: nil,
                            time: "7:24",
                            label: "Next",
                            foreground: .white
                        )
                    }
                    .frame(width: 142)
                }

                HStack(spacing: 10) {
                    HomeMinimalistSummaryPreviewTile(title: "Mon", subtitle: "Kuala Lumpur")
                    HomeMinimalistSummaryPreviewTile(title: "1h 18m", subtitle: "Remaining")
                }
                .frame(height: 74)
            }
            .padding(12)
        }
    }
}

private struct HomeMinimalistSummaryPreviewTile: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            Color.white.opacity(0.72)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.black.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct HomeMinimalistSunriseIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Image(systemName: "sun.max")
                .font(.system(size: size, weight: .semibold))
            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.58, weight: .bold))
                .offset(y: -size * 0.68)
        }
        .foregroundStyle(.black)
        .frame(width: size * 1.35, height: size * 1.35)
    }
}

private struct HomeCountdownMediumPreviewCard: View {
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CurvierPreviewPrayerMiniGraph(
                sampleMinutes: [330, 430, 780, 1000, 1166, 1238],
                activeDotIndex: 2
            )
            .frame(height: 16)

            HStack {
                Text(localizedPrayerName("Maghrib"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accentColor)
                Spacer(minLength: 8)
                Text("1:14:22")
                    .font(.title3.monospacedDigit())
                Spacer(minLength: 8)
                Text(localizedPrayerName("Isha"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Subang Jaya, Selangor", systemImage: "location.fill")
                Spacer()
                Text("Next 20:38")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct HomeCountdownSmallPreviewCard: View {
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("24 Ramadan")
                    .foregroundStyle(accentColor)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(localizedPrayerName("Maghrib"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text("1:14:22")
                    .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 5) {
                Text("Next \(localizedPrayerName("Isha"))")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Text("20:38")
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(accentColor)
                Text("Subang Jaya")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

        }
        .lineLimit(1)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct HomeCountdownLargePreviewCard: View {
    let accentColor: Color

    private let rows: [(String, String, String)] = [
        (localizedPrayerName("Fajr"), "5:52", "sun.horizon.fill"),
        (localizedPrayerName("Sunrise"), "7:08", "sunrise.fill"),
        (localizedPrayerName("Dhuhr"), "13:23", "sun.max.fill"),
        (localizedPrayerName("Asr"), "16:46", "sun.min.fill"),
        (localizedPrayerName("Maghrib"), "19:31", "sunset.fill"),
        (localizedPrayerName("Isha"), "20:38", "moon.stars.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("24 Ramadan 1447")
                    .font(.caption)
                    .foregroundStyle(accentColor)
                Spacer()
            }

            CurvierPrayerTimelineGraphPreviewCard(
                currentPrayer: localizedPrayerName("Maghrib"),
                nextPrayer: localizedPrayerName("Isha"),
                nextTime: "20:38",
                footer: nil,
                accentColor: accentColor
            )

            HStack {
                Text(localizedPrayerName("Maghrib"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(accentColor)
                Spacer()
                Text("1:14:22")
                    .font(.headline.monospacedDigit())
                Spacer()
                Text(localizedPrayerName("Isha"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: row.2)
                            Text(row.0)
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(index == 4 ? accentColor : .secondary)

                        Text(row.1)
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(index == 4 ? accentColor : .primary)
                    }
                }
            }
        }
    }
}

private struct HomePrayerTimesMediumPreviewCard: View {
    let accentColor: Color

    private let visiblePrayers: [(String, String, String)] = [
        (localizedPrayerName("Maghrib"), "19:31", "sunset.fill"),
        (localizedPrayerName("Isha"), "20:38", "moon.stars.fill"),
        (localizedPrayerName("Fajr"), "5:52", "sun.horizon.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sunset.fill")
                    .foregroundStyle(accentColor)
                Text(localizedPrayerName("Maghrib"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                Spacer()
                Text("1:14:22")
                    .font(.subheadline.monospacedDigit())
                    .lineLimit(1)
            }

            VStack(spacing: 5) {
                ForEach(Array(visiblePrayers.enumerated()), id: \.offset) { index, prayer in
                    HStack {
                        Image(systemName: prayer.2)
                            .frame(width: 12)
                        Text(prayer.0)
                            .fontWeight(.bold)
                            .lineLimit(1)
                        Spacer()
                        Text(prayer.1)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(index == 0 ? accentColor : (index == 1 ? .secondary : .primary))
                }
            }

            HStack {
                Label("Subang Jaya, Selangor", systemImage: "location.fill")
                Spacer()
                Image("CurrentAppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .cornerRadius(3)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct HomePrayerTimesMediumGridPreviewCard: View {
    let accentColor: Color

    private let rows: [(String, String, String)] = [
        (localizedPrayerName("Fajr"), "5:52", "sun.horizon.fill"),
        (localizedPrayerName("Sunrise"), "7:08", "sunrise.fill"),
        (localizedPrayerName("Dhuhr"), "13:23", "sun.max.fill"),
        (localizedPrayerName("Asr"), "16:46", "sun.min.fill"),
        (localizedPrayerName("Maghrib"), "19:31", "sunset.fill"),
        (localizedPrayerName("Isha"), "20:38", "moon.stars.fill")
    ]

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            Image(systemName: row.2)
                                .font(.subheadline)
                            Text(row.0)
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(index == 4 ? accentColor : .primary)

                        Text(row.1)
                            .font(.subheadline)
                            .foregroundStyle(index == 4 ? accentColor : .secondary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(4)

            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HomePrayerTimesLargePreviewCard: View {
    let accentColor: Color

    private let rows: [(String, String, String)] = [
        (localizedPrayerName("Fajr"), "5:52", "sun.horizon.fill"),
        (localizedPrayerName("Sunrise"), "7:08", "sunrise.fill"),
        (localizedPrayerName("Dhuhr"), "13:23", "sun.max.fill"),
        (localizedPrayerName("Asr"), "16:46", "sun.min.fill"),
        (localizedPrayerName("Maghrib"), "19:31", "sunset.fill"),
        (localizedPrayerName("Isha"), "20:38", "moon.stars.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("24 Ramadan 1447")
                .font(.caption)
                .foregroundStyle(accentColor)
                .lineLimit(1)

            Spacer(minLength: 0)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: row.2)
                            Text(row.0)
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(index == 4 ? accentColor : .primary)

                        Text(row.1)
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(index == 4 ? accentColor : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Label("Subang Jaya, Selangor", systemImage: "location.fill")
                Spacer()
                Image("CurrentAppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .cornerRadius(4)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct HomeZikirPreviewCard: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: compact ? .leading : .center, spacing: compact ? 8 : 10) {
            Text(isMalayAppLanguage() ? "Zikir malam" : "Night Zikir")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: compact ? .leading : .center)

            Text("أَسْتَغْفِرُ ٱللَّٰهَ")
                .font(.system(size: compact ? 20 : 24, weight: .regular, design: .serif))
                .frame(maxWidth: .infinity, alignment: compact ? .leading : .center)

            Text(isMalayAppLanguage() ? "Aku memohon ampun kepada Allah." : "I seek forgiveness from Allah.")
                .font(.system(size: compact ? 11 : 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(compact ? .leading : .center)
                .frame(maxWidth: .infinity, alignment: compact ? .leading : .center)

            Spacer(minLength: 0)

            if !compact {
                Text(isMalayAppLanguage() ? "Dikemas kini mengikut waktu zikir harian." : "Updates with the prayer-aware daily zikir cycle.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct PremiumWidgetBadge: View {
    var body: some View {
        EmptyView()
    }
}

private struct TopRoundedBannerShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(self.radius, rect.width / 2, rect.height)
        var path = Path()

        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: radius, y: rect.minY),
            control: CGPoint(x: 0, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PremiumCardStatusText: View {
    let isSelected: Bool
    let isLocked: Bool
    let summary: String
    let selectedTint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isSelected ? (isMalayAppLanguage() ? "Dipilih" : "Selected") : summary)
                .font(.subheadline)
                .foregroundStyle(isSelected ? selectedTint : .secondary)
                .lineLimit(2)

            if isLocked && !isSelected {
                Text("Premium")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LockedWidgetCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let isLocked: Bool
    let isSelected: Bool
    let cornerRadius: CGFloat
    let accentColor: Color

    private var bannerTextColor: Color {
        #if os(iOS)
        let resolved = UIColor(accentColor).resolvedColor(with: UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
            return luminance > 0.67 ? .black : .white
        }
        #endif
        return colorScheme == .dark ? .white : .black
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLocked && !isSelected {
                    GeometryReader { proxy in
                        let bannerHeight = max(34, proxy.size.height / 6)
                        let bannerRadius = cornerRadius

                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.black.opacity(colorScheme == .dark ? 0.12 : 0.08))

                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Locked")
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(bannerTextColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: bannerHeight)
                            .background(
                                accentColor,
                                in: TopRoundedBannerShape(radius: bannerRadius)
                            )
                            .overlay {
                                TopRoundedBannerShape(radius: bannerRadius)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                            }
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.10))
                                    .frame(height: 0.8)
                            }
                        }
                    }
                }
            }
    }
}

private extension View {
    func lockedWidgetCardStyle(isLocked: Bool, isSelected: Bool, accentColor: Color, cornerRadius: CGFloat = 28) -> some View {
        modifier(LockedWidgetCardModifier(isLocked: isLocked, isSelected: isSelected, cornerRadius: cornerRadius, accentColor: accentColor))
    }
}

private struct NextPrayerCircleStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: NextPrayerCircleStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    Group {
                        if style == .classic {
                            LockScreenCircularPreviewCard(title: localizedPrayerName("Isha"), time: "19:31")
                        } else if style == .minimal {
                            LockScreenCircularMinimalPreviewCard(title: localizedPrayerName("Isha"), time: "19:31")
                        } else if style == .percentageRing {
                            LockScreenCircularPercentagePreviewCard(percentage: 60, iconName: "moon.stars.fill")
                        } else if style == .countdownRing {
                            LockScreenCircularCountdownPreviewCard(title: localizedPrayerName("Maghrib"), progress: 0.34)
                        } else if style == .dualCountdownRing {
                            LockScreenCircularDualCountdownPreviewCard(title: localizedPrayerName("Maghrib"), innerProgress: 0.34, outerProgress: 0.62)
                        } else {
                            LockScreenCircularDualCountdownNextPrayerPreviewCard(title: localizedPrayerName("Isyak"), time: "19:31", innerProgress: 0.34, outerProgress: 0.62)
                        }
                    }
                    .padding(.bottom, 18)
                }
            }
            .frame(width: 160, height: 206)
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color, cornerRadius: 40)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: false,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 160, alignment: .leading)
        }
    }
}

private struct LockScreenCircularPercentagePreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let percentage: Int
    let iconName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            Circle()
                .stroke(Color.primary.opacity(0.25), lineWidth: 6)
                .padding(12)

            Circle()
                .trim(from: 0, to: 0.60)
                .stroke(
                    Color.primary,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(12)

            VStack(spacing: 1) {
                Text("\(percentage)%")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .monospacedDigit()

                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary.opacity(0.85))
            }
            .padding(.top, 2)
        }
        .frame(width: 98, height: 98)
    }
}

private struct PrayerListStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: PrayerListWidgetStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    Group {
                        if style == .classic {
                            LockScreenPrayerListPreviewCard(footer: "Subang Jaya, Selangor")
                        } else if style == .focus {
                            LockScreenPrayerListFocusPreviewCard(footer: "Subang Jaya, Selangor", accentColor: settings.accentColor.color)
                        } else if style == .departuresBoard {
                            LockScreenPrayerListDeparturesPreviewCard(footer: "Subang Jaya, Selangor")
                        } else if style == .departuresBoardNoLocation {
                            LockScreenPrayerListDeparturesPreviewCard(footer: nil)
                        } else if style == .iconBoard {
                            LockScreenPrayerListIconBoardPreviewCard(columns: 3)
                        } else {
                            LockScreenPrayerListIconBoardPreviewCard(columns: 6)
                        }
                    }
                    .frame(width: 188)
                    .padding(.bottom, 20)
                }
            }
            .frame(width: 188, height: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: isLocked,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 188, alignment: .leading)
        }
    }
}

private struct LockScreenPrayerListIconBoardPreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let columns: Int

    private let samples: [(time: String, icon: String, name: String)] = [
        ("6:16", "sun.horizon", "Subuh"),
        ("7:28", "sunrise", "Syuruk"),
        ("1:19", "sun.max", "Zuhur"),
        ("4:42", "sun.min", "Asar"),
        ("7:31", "sunset", "Maghrib"),
        ("8:44", "moon.stars.fill", "Isyak")
    ]

    var body: some View {
        let visibleSamples = Array(samples.prefix(columns))

        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.primary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.primary.opacity(0.10), lineWidth: 1)
            )
            .overlay {
                HStack(alignment: .center, spacing: columns == 3 ? 10 : 6) {
                    ForEach(Array(visibleSamples.enumerated()), id: \.offset) { index, sample in
                        VStack(spacing: 3) {
                            Text(sample.time)
                                .font(.system(size: columns == 3 ? 10 : 8, weight: .bold, design: .rounded))
                                .foregroundStyle(index < 2 ? Color.primary : Color.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .minimumScaleFactor(columns == 3 ? 0.75 : 0.9)

                            Image(systemName: sample.icon)
                                .font(.system(size: columns == 3 ? 15 : 13, weight: .semibold))
                                .foregroundStyle(index < 2 ? Color.primary : Color.secondary)
                                .frame(width: columns == 3 ? 18 : 16, height: columns == 3 ? 18 : 16)

                            Text(sample.name)
                                .font(.system(size: columns == 3 ? 9 : 7, weight: .bold, design: .rounded))
                                .foregroundStyle(index < 2 ? Color.primary : Color.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(columns == 3 ? 0.7 : 0.65)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, columns == 3 ? 12 : 8)
                .padding(.vertical, 10)
            }
            .frame(height: columns == 3 ? 74 : 78)
            .padding(.horizontal, 8)
    }
}
private struct DailyVerseStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: DailyVerseWidgetStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    Group {
                        if style.isCentered == false {
                            LockScreenVersePreviewCard(
                                verse: "Be grateful for the favor of Allah.",
                                reference: "An-Nahl 16:114",
                                style: style
                            )
                        } else {
                            LockScreenVerseCenteredPreviewCard(
                                verse: "Be grateful for the favor of Allah.",
                                reference: "An-Nahl 16:114",
                                style: style
                            )
                        }
                    }
                    .frame(width: 188)
                    .padding(.bottom, 14)
                }
            }
            .frame(width: 188, height: 188)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: isLocked,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 188, alignment: .leading)
        }
    }
}

private struct LockScreenSpotlightCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: LockScreenWidgetPreviewStyle
    let isSelected: Bool

    private var widgetWidth: CGFloat {
        style == .nextPrayerCircular ? 160 : 188
    }

    private var widgetHeight: CGFloat {
        style == .nextPrayerCircular ? 206 : 220
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: style == .nextPrayerCircular ? 40 : 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: style == .nextPrayerCircular ? 40 : 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    widgetBody
                        .frame(width: widgetWidth)
                        .padding(.bottom, style == .nextPrayerCircular ? 18 : 20)
                }
            }
            .frame(width: widgetWidth, height: widgetHeight)
            .overlay(
                RoundedRectangle(cornerRadius: style == .nextPrayerCircular ? 40 : 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: false,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: widgetWidth, alignment: .leading)
        }
    }

    @ViewBuilder
    private var widgetBody: some View {
        switch style {
        case .nextPrayerCircular:
            LockScreenCircularPreviewCard(title: localizedPrayerName("Isha"), time: "19:31")
        case .prayerTimeline:
            PrayerTimelineGraphPreviewCard(
                currentPrayer: localizedPrayerName("Maghrib"),
                nextPrayer: localizedPrayerName("Isha"),
                nextTime: "19:31",
                footer: "Subang Jaya, Selangor",
                accentColor: settings.accentColor.color
            )
        case .prayerList:
            LockScreenPrayerListPreviewCard(footer: "Subang Jaya, Selangor")
        case .prayerCountdown:
            LockScreenCountdownPreviewCard(
                prayer: localizedPrayerName("Isha"),
                timerText: "19:31",
                footer: "Subang Jaya, Selangor",
                accentColor: settings.accentColor.color,
                batteryStyle: false
            )
        case .zikir:
            LockScreenRectangularZikirPreviewCard(
                helperTitle: isMalayAppLanguage() ? "Zikir malam" : "Night Zikir",
                arabic: "أَسْتَغْفِرُ اللَّهَ",
                translation: isMalayAppLanguage() ? "Aku memohon ampun kepada Allah." : "I seek forgiveness from Allah.",
                alignment: .center
            )
        case .dailyVerse:
            LockScreenVersePreviewCard(
                verse: isMalayAppLanguage() ? "Maha Suci Allah dan segala puji bagi-Nya." : "Glory be to Allah and praise be to Him.",
                reference: "Al-Ahzab 56",
                style: .classic
            )
        }
    }
}

private struct PrayerTimesStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: LockScreenPrayerTimesStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    if style == .prayerCountdownWithLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Subang Jaya, Selangor",
                            accentColor: settings.accentColor.color,
                            showsLabels: true,
                            centered: false
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerCountdownWithoutLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: nil,
                            accentColor: settings.accentColor.color,
                            showsLabels: true,
                            centered: false
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerCountdownClassicWithLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Subang Jaya, Selangor",
                            accentColor: settings.accentColor.color,
                            showsLabels: false,
                            centered: false
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerCountdownClassicWithoutLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: nil,
                            accentColor: settings.accentColor.color,
                            showsLabels: false,
                            centered: false
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerCountdownCenteredWithLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Subang Jaya, Selangor",
                            accentColor: settings.accentColor.color,
                            showsLabels: false,
                            centered: true
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerCountdownCenteredWithoutLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: nil,
                            accentColor: settings.accentColor.color,
                            showsLabels: false,
                            centered: true
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerTimelineWithLocation {
                        PrayerTimelineGraphPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Subang Jaya, Selangor",
                            accentColor: settings.accentColor.color
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerTimelineWithoutLocation {
                        PrayerTimelineGraphPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: nil,
                            accentColor: settings.accentColor.color
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerTimelinePlusWithLocation {
                        CurvierPrayerTimelineGraphPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Subang Jaya, Selangor",
                            accentColor: settings.accentColor.color
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else {
                        CurvierPrayerTimelineGraphPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: nil,
                            accentColor: settings.accentColor.color
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    }
                }
            }
            .frame(width: 188, height: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: isLocked,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 188, alignment: .leading)
        }
    }
}

private struct PrayerCountdownBarStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: LockScreenPrayerCountdownBarStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    if style == .withLocation || style == .withoutLocation {
                        LockScreenCountdownPreviewCard(
                            prayer: localizedPrayerName("Maghrib"),
                            timerText: "19:31",
                            footer: style == .withLocation ? "Subang Jaya, Selangor" : "",
                            accentColor: settings.accentColor.color,
                            batteryStyle: false
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .batteryWithLocation || style == .batteryWithoutLocation {
                        LockScreenCountdownPreviewCard(
                            prayer: localizedPrayerName("Maghrib"),
                            timerText: "1h 12m",
                            footer: style == .batteryWithLocation ? "Subang Jaya, Selangor" : "",
                            accentColor: settings.accentColor.color,
                            batteryStyle: true
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    }
                }
            }
            .frame(width: 188, height: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: isLocked,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 188, alignment: .leading)
        }
    }
}

private struct ZikirStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let alignment: WidgetZikirAlignment
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    LockScreenRectangularZikirPreviewCard(
                        helperTitle: isMalayAppLanguage() ? "Zikir malam" : "Night Zikir",
                        arabic: "أَسْتَغْفِرُ اللَّهَ",
                        translation: isMalayAppLanguage() ? "Aku memohon ampun kepada Allah." : "I seek forgiveness from Allah.",
                        alignment: alignment
                    )
                    .frame(width: 188)
                    .padding(.bottom, 20)
                }
            }
            .frame(width: 188, height: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(alignment.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: isLocked,
                    summary: alignment.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 188, alignment: .leading)
        }
    }
}

private struct LockScreenCircularPreviewCard: View {
    let title: String
    let time: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(time)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }
            .padding(8)
        }
        .frame(width: 98, height: 98)
    }
}

private struct LockScreenCircularMinimalPreviewCard: View {
    let title: String
    let time: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            VStack(spacing: 4) {
                Text(time)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(8)
        }
        .frame(width: 98, height: 98)
    }
}

private struct LockScreenCircularCountdownPreviewCard: View {
    let title: String
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: 6)
                .padding(12)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(12)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .padding(20)
        }
        .frame(width: 98, height: 98)
    }
}

private struct LockScreenCircularDualCountdownPreviewCard: View {
    let title: String
    let innerProgress: Double
    let outerProgress: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 4)
                .padding(8)

            Circle()
                .trim(from: 0, to: outerProgress)
                .stroke(Color.primary.opacity(0.46), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(8)

            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: 6)
                .padding(16)

            Circle()
                .trim(from: 0, to: innerProgress)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(16)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .padding(22)
        }
        .frame(width: 98, height: 98)
    }
}

private struct LockScreenCircularDualCountdownNextPrayerPreviewCard: View {
    let title: String
    let time: String
    let innerProgress: Double
    let outerProgress: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 4)
                .padding(8)

            Circle()
                .trim(from: 0, to: outerProgress)
                .stroke(Color.primary.opacity(0.46), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(8)

            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: 6)
                .padding(16)

            Circle()
                .trim(from: 0, to: innerProgress)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(16)

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)

                Text(time)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .padding(16)
        }
        .frame(width: 98, height: 98)
    }
}

private struct LockScreenTimelinePreviewCard: View {
    let currentPrayer: String
    let nextPrayer: String
    let nextTime: String
    let footer: String?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(index < 3 ? Color.primary.opacity(0.92) : Color.primary.opacity(0.26))
                        .frame(width: index == 2 ? 10 : 8, height: index == 2 ? 10 : 8)
                }
            }
            .frame(height: 16)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currentPrayer)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextTime)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextPrayer)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LockScreenPrayerListPreviewCard: View {
    let footer: String

    private let rows: [(String, String)] = [
        (localizedPrayerName("Asr"), "16:46"),
        (localizedPrayerName("Maghrib"), "19:26"),
        (localizedPrayerName("Isha"), "20:38")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    Spacer()
                    Text(row.1)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }

            Text(footer)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .font(.caption)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LockScreenPrayerListFocusPreviewCard: View {
    let footer: String
    let accentColor: Color

    private let rows: [(String, String)] = [
        (localizedPrayerName("Maghrib"), "19:26"),
        (localizedPrayerName("Isha"), "20:38"),
        (localizedPrayerName("Fajr"), "05:52")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(rows[0].0)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                Spacer()
                Text(rows[0].1)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
            }

            ForEach(rows.dropFirst(), id: \.0) { row in
                HStack {
                    Text(row.0)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(row.1)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(footer)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LockScreenPrayerListDeparturesPreviewCard: View {
    let footer: String?

    private let rows: [(String, String)] = [
        (localizedPrayerName("Maghrib").uppercased(), "19:26"),
        (localizedPrayerName("Isha").uppercased(), "20:38"),
        (localizedPrayerName("Fajr").uppercased(), "05:52")
    ]

    var body: some View {
        let compact = footer != nil

        VStack(alignment: .leading, spacing: compact ? 3 : 3) {
            ForEach(rows, id: \.0) { row in
                HStack(spacing: compact ? 6 : 8) {
                    Text(row.0)
                        .font(.system(size: compact ? 8 : 9, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(compact ? 0.7 : 0.75)

                    Spacer(minLength: 4)

                    Text(row.1)
                        .font(.system(size: compact ? 8 : 9, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .padding(.horizontal, compact ? 7 : 8)
                .padding(.vertical, compact ? 2 : 4)
                .background(
                    RoundedRectangle(cornerRadius: compact ? 7 : 8, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 7 : 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.14), lineWidth: 0.8)
                )
            }

            if let footer {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: compact ? 92 : 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LockScreenCountdownPreviewCard: View {
    let prayer: String
    let timerText: String
    let footer: String
    let accentColor: Color
    let batteryStyle: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(prayer)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if batteryStyle {
                    Text(localizedPrayerName("Isyak"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(timerText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if batteryStyle {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.28), lineWidth: 1.4)
                        .frame(height: 28)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accentColor.opacity(0.9))
                        .frame(width: 44, height: 22)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 3)

                    Text(timerText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 28)
            } else {
                ProgressView(value: 0.62)
                    .progressViewStyle(.linear)
                    .tint(accentColor)
            }

            Text(isMalayAppLanguage() ? "Berakhir pada 20:34" : "Ends at 20:34")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(footer)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LockScreenRectangularZikirPreviewCard: View {
    @EnvironmentObject var settings: Settings

    let helperTitle: String
    let arabic: String
    let translation: String
    let alignment: WidgetZikirAlignment

    private var horizontalAlignment: HorizontalAlignment {
        switch alignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center, .centerAmiri:
            return .center
        }
    }

    private var textAlignment: TextAlignment {
        switch alignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center, .centerAmiri:
            return .center
        }
    }

    private var supportingFont: Font {
        alignment == .centerAmiri
            ? .system(size: 10, weight: .regular, design: .serif)
            : .system(size: 10, weight: .regular)
    }

    private var quranArabicFontName: String {
        if alignment == .centerAmiri {
            let amiriCandidates = [
                "AmiriQuran-Regular",
                "Amiri Quran",
                "Amiri-Regular",
                "Amiri"
            ]
            #if os(iOS)
            for name in amiriCandidates where !name.isEmpty {
                if UIFont(name: name, size: 19) != nil {
                    return name
                }
            }
            #endif
        }
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
            if UIFont(name: name, size: 19) != nil {
                return name
            }
        }
        #endif
        return settings.fontArabic
    }

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: 3) {
            Text(helperTitle)
                .font(alignment == .centerAmiri ? .system(size: 10, weight: .medium, design: .serif) : .system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(arabic)
                .font(.custom(quranArabicFontName, size: 19))
                .multilineTextAlignment(textAlignment)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
            Text(translation)
                .font(supportingFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(textAlignment)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center, .centerAmiri:
            return .center
        }
    }
}

private struct CurvierPrayerTimelineGraphPreviewCard: View {
    let currentPrayer: String
    let nextPrayer: String
    let nextTime: String
    let footer: String?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CurvierPreviewPrayerMiniGraph(
                sampleMinutes: [330, 430, 780, 1000, 1166, 1238],
                activeDotIndex: 2
            )

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currentPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextTime)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct CurvierPreviewPrayerMiniGraph: View {
    @Environment(\.colorScheme) private var colorScheme
    let sampleMinutes: [Double]
    let activeDotIndex: Int

    private func normalizedCurveY(_ t: CGFloat) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        let p0: CGFloat = 0.76
        let c1: CGFloat = 0.38
        let c2: CGFloat = 0.02
        let p3: CGFloat = 0.88
        let oneMinusT = 1 - clamped
        return
            (oneMinusT * oneMinusT * oneMinusT * p0) +
            (3 * oneMinusT * oneMinusT * clamped * c1) +
            (3 * oneMinusT * clamped * clamped * c2) +
            (clamped * clamped * clamped * p3)
    }

    private func markerPoints(in size: CGSize) -> [CGPoint] {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let values = sampleMinutes.isEmpty ? [0, 1] : sampleMinutes
        let first = values.first ?? 0
        let last = max(values.last ?? 1, first + 1)
        let range = max(last - first, 1)
        let leftInset = width * 0.03
        let usableWidth = width * 0.94

        return values.map { minute in
            let t = CGFloat((minute - first) / range)
            let x = leftInset + usableWidth * t
            let y = height * normalizedCurveY(t)
            return CGPoint(x: x, y: y)
        }
    }

    private func sampledCurvePath(in size: CGSize) -> Path {
        var path = Path()
        let leftInset = size.width * 0.03
        let usableWidth = size.width * 0.94
        let steps = 48
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(
                x: leftInset + usableWidth * t,
                y: size.height * normalizedCurveY(t)
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    var body: some View {
        GeometryReader { geo in
            let baseLineColor = colorScheme == .light ? Color.black.opacity(0.42) : Color.white.opacity(0.68)
            let futureDotStrokeColor = colorScheme == .light ? Color.black.opacity(0.55) : Color.white.opacity(0.72)
            let activeLineColor = colorScheme == .light ? Color.black.opacity(0.90) : Color.white.opacity(0.95)
            let markers = markerPoints(in: geo.size)
            let peakIndex = markers.enumerated().min(by: { $0.element.y < $1.element.y })?.offset ?? 0
            let clampedActiveIndex = min(max(activeDotIndex, -1), max(markers.count - 1, -1))

            ZStack {
                let curve = sampledCurvePath(in: geo.size)

                ZStack {
                    curve
                        .stroke(baseLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                    ForEach(Array(markers.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(Color.black)
                            .frame(width: index == peakIndex ? 13 : 11, height: index == peakIndex ? 13 : 11)
                            .position(point)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()

                ForEach(Array(markers.enumerated()), id: \.offset) { index, point in
                    let isReached = index <= clampedActiveIndex
                    Circle()
                        .fill(isReached ? activeLineColor : Color.clear)
                        .overlay(
                            Circle().stroke(
                                isReached ? activeLineColor : futureDotStrokeColor,
                                lineWidth: 1.8
                            )
                        )
                        .frame(width: index == peakIndex ? 10 : 8, height: index == peakIndex ? 10 : 8)
                        .position(point)
                }
            }
        }
        .frame(height: 30)
    }
}

private struct LockScreenVersePreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let verse: String
    let reference: String
    let style: DailyVerseWidgetStyle
    private let verseFontSize: CGFloat = 13
    private let referenceFontSize: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reference)
                .font(.custom(style.referenceFontName, size: referenceFontSize))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary.opacity(0.82))
                .lineLimit(1)

            Text(verse)
                .font(.custom(style.verseFontName, size: verseFontSize))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.96) : Color.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.white.opacity(0.18), Color.white.opacity(0.12)]
                            : [Color.black.opacity(0.06), Color.black.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct LockScreenVerseCenteredPreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let verse: String
    let reference: String
    let style: DailyVerseWidgetStyle
    private let verseFontSize: CGFloat = 13
    private let referenceFontSize: CGFloat = 16

    var body: some View {
        VStack(spacing: 4) {
            Text(verse)
                .font(.custom(style.verseFontName, size: verseFontSize))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.96) : Color.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.78)

            Text(reference)
                .font(.custom(style.referenceFontName, size: referenceFontSize))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary.opacity(0.82))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.white.opacity(0.18), Color.white.opacity(0.12)]
                            : [Color.black.opacity(0.06), Color.black.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

struct NotificationSoundSelectionView: View {
    @EnvironmentObject var settings: Settings

    private func playPreviewIfNeeded(for option: NotificationSoundOption) {
        #if os(iOS)
        guard option == .azan,
              let url = resolvedAzanPreviewURL()
        else {
            AzanPreviewAudioCoordinator.stop()
            return
        }
        AzanPreviewAudioCoordinator.play(url: url)
        #endif
    }

    #if os(iOS)
    private func resolvedAzanPreviewURL() -> URL? {
        for name in settings.selectedAzanSoundCandidates {
            let ns = name as NSString
            let base = ns.deletingPathExtension
            let ext = ns.pathExtension
            guard !base.isEmpty, !ext.isEmpty else { continue }
            if let url = Bundle.main.url(forResource: base, withExtension: ext) {
                return url
            }
        }
        return nil
    }
    #endif

    var body: some View {
        List {
            Section(header: Text("ALERT NOTIFICATION SOUND")) {
                ForEach(NotificationSoundOption.allCases) { option in
                    Button {
                        settings.hapticFeedback()
                        settings.setNotificationSoundOption(option)
                        playPreviewIfNeeded(for: option)
                    } label: {
                        HStack {
                            Text(option.title)
                                .foregroundColor(.primary)
                            Spacer()
                            if settings.notificationSoundOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if settings.notificationSoundOption == .azan {
                    Picker("Azan Voice", selection: Binding(
                        get: { settings.azanAudioTrack },
                        set: {
                            settings.azanAudioTrack = $0
                            playPreviewIfNeeded(for: .azan)
                        }
                    )) {
                        ForEach(AzanAudioTrack.allCases) { track in
                            Text(track.title).tag(track)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Playback", selection: Binding(
                        get: { settings.azanAudioClipMode },
                        set: {
                            settings.azanAudioClipMode = $0
                            playPreviewIfNeeded(for: .azan)
                        }
                    )) {
                        ForEach(AzanAudioClipMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .applyConditionalListStyle(defaultView: true)
        .navigationTitle("Notification Sound")
    }
}

struct MoreNotificationView: View {
    @EnvironmentObject var settings: Settings
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showAlert: Bool = false

    private var notificationPageToggleTint: Color {
        settings.accentColor.toggleTint
    }
    
    private func turnOffNaggingModeIfAllOff() {
        if !settings.naggingFajr &&
           !settings.naggingSunrise &&
           !settings.naggingDhuhr &&
           !settings.naggingAsr &&
           !settings.naggingMaghrib &&
           !settings.naggingIsha {
            
            withAnimation {
                settings.naggingMode = false
            }
        }
    }
    
    var body: some View {
        List {
            Section(header: Text(appLocalized("NAGGING MODE"))) {
                Text(appLocalized("Nagging mode helps those who struggle to pray on time. Once enabled, you'll get a notification at the chosen start time before each prayer, then another every 15 minutes, plus final reminders at 10 and 5 minutes remaining."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Toggle(appLocalized("Turn on Nagging Mode"), isOn: Binding(
                    get: { settings.naggingMode },
                    set: { newValue in
                        withAnimation {
                            settings.naggingMode = newValue
                            
                            if newValue {
                                settings.notificationFajr = true
                                settings.notificationSunrise = true
                                settings.notificationDhuhr = true
                                settings.notificationAsr = true
                                settings.notificationMaghrib = true
                                settings.notificationIsha = true
                                
                                settings.naggingFajr = true
                                settings.naggingSunrise = true
                                settings.naggingDhuhr = true
                                settings.naggingAsr = true
                                settings.naggingMaghrib = true
                                settings.naggingIsha = true
                            } else {
                                settings.naggingFajr = false
                                settings.naggingSunrise = false
                                settings.naggingDhuhr = false
                                settings.naggingAsr = false
                                settings.naggingMaghrib = false
                                settings.naggingIsha = false
                            }
                        }
                    }
                ).animation(.easeInOut))
                .font(.subheadline)
                .tint(notificationPageToggleTint)
                
                if settings.naggingMode {
                    Picker(appLocalized("Starting Time"), selection: $settings.naggingStartOffset.animation(.easeInOut)) {
                        Text(appLocalized("45 mins")).tag(45)
                        Text(appLocalized("30 mins")).tag(30)
                        Text(appLocalized("15 mins")).tag(15)
                        Text(appLocalized("10 mins")).tag(10)
                    }
                    #if !os(watchOS)
                    .pickerStyle(.segmented)
                    #endif
                    
                    Group {
                        Toggle(appLocalized("Nagging before Fajr"), isOn: Binding(
                            get: { settings.naggingFajr },
                            set: { newValue in
                                settings.naggingFajr = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                        
                        Toggle(appLocalized("Nagging before Sunrise"), isOn: Binding(
                            get: { settings.naggingSunrise },
                            set: { newValue in
                                settings.naggingSunrise = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                        
                        Toggle(appLocalized("Nagging before Dhuhr"), isOn: Binding(
                            get: { settings.naggingDhuhr },
                            set: { newValue in
                                settings.naggingDhuhr = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                        
                        Toggle(appLocalized("Nagging before Asr"), isOn: Binding(
                            get: { settings.naggingAsr },
                            set: { newValue in
                                settings.naggingAsr = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                        
                        Toggle(appLocalized("Nagging before Maghrib"), isOn: Binding(
                            get: { settings.naggingMaghrib },
                            set: { newValue in
                                settings.naggingMaghrib = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                        
                        Toggle(appLocalized("Nagging before Isha"), isOn: Binding(
                            get: { settings.naggingIsha },
                            set: { newValue in
                                settings.naggingIsha = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                    }
                    .tint(notificationPageToggleTint)
                }
            }
            
            if !settings.naggingMode {
                Section(header: Text(appLocalized("ALL PRAYER NOTIFICATIONS"))) {
                    Toggle(appLocalized("Turn On All Prayer Notifications"), isOn: Binding(
                        get: {
                            settings.notificationFajr &&
                            settings.notificationSunrise &&
                            settings.notificationDhuhr &&
                            settings.notificationAsr &&
                            settings.notificationMaghrib &&
                            settings.notificationIsha
                        },
                        set: { newValue in
                            withAnimation {
                                settings.notificationFajr = newValue
                                settings.notificationSunrise = newValue
                                settings.notificationDhuhr = newValue
                                settings.notificationAsr = newValue
                                settings.notificationMaghrib = newValue
                                settings.notificationIsha = newValue
                            }
                        }
                    ).animation(.easeInOut))
                    .font(.subheadline)
                    .tint(notificationPageToggleTint)
                    
                    Stepper(value: Binding(
                        get: { settings.preNotificationFajr },
                        set: { newValue in
                            withAnimation {
                                settings.preNotificationFajr = newValue
                                settings.preNotificationSunrise = newValue
                                settings.preNotificationDhuhr = newValue
                                settings.preNotificationAsr = newValue
                                settings.preNotificationMaghrib = newValue
                                settings.preNotificationIsha = newValue
                            }
                        }
                    ), in: 0...30, step: 5) {
                        Text(appLocalized("All Prayer Prenotifications:"))
                            .font(.subheadline)
                        Text("\(settings.preNotificationFajr) \(appLocalized(settings.preNotificationFajr != 1 ? "minutes" : "minute"))")
                            .font(.subheadline)
                            .foregroundColor(settings.accentColor.color)
                    }
                }
            }
            
            if !settings.naggingMode {
                NotificationSettingsSection(prayerName: "Fajr", preNotificationTime: $settings.preNotificationFajr, isNotificationOn: $settings.notificationFajr)
                NotificationSettingsSection(prayerName: "Shurooq", preNotificationTime: $settings.preNotificationSunrise, isNotificationOn: $settings.notificationSunrise)
                NotificationSettingsSection(prayerName: "Dhuhr", preNotificationTime: $settings.preNotificationDhuhr, isNotificationOn: $settings.notificationDhuhr)
                NotificationSettingsSection(prayerName: "Asr", preNotificationTime: $settings.preNotificationAsr, isNotificationOn: $settings.notificationAsr)
                NotificationSettingsSection(prayerName: "Maghrib", preNotificationTime: $settings.preNotificationMaghrib, isNotificationOn: $settings.notificationMaghrib)
                NotificationSettingsSection(prayerName: "Isha", preNotificationTime: $settings.preNotificationIsha, isNotificationOn: $settings.notificationIsha)
            } else {
                if !settings.naggingFajr {
                    NotificationSettingsSection(prayerName: "Fajr", preNotificationTime: $settings.preNotificationFajr, isNotificationOn: $settings.notificationFajr)
                }
                if !settings.naggingSunrise {
                    NotificationSettingsSection(prayerName: "Shurooq", preNotificationTime: $settings.preNotificationSunrise, isNotificationOn: $settings.notificationSunrise)
                }
                if !settings.naggingDhuhr {
                    NotificationSettingsSection(prayerName: "Dhuhr", preNotificationTime: $settings.preNotificationDhuhr, isNotificationOn: $settings.notificationDhuhr)
                }
                if !settings.naggingAsr {
                    NotificationSettingsSection(prayerName: "Asr", preNotificationTime: $settings.preNotificationAsr, isNotificationOn: $settings.notificationAsr)
                }
                if !settings.naggingMaghrib {
                    NotificationSettingsSection(prayerName: "Maghrib", preNotificationTime: $settings.preNotificationMaghrib, isNotificationOn: $settings.notificationMaghrib)
                }
                if !settings.naggingIsha {
                    NotificationSettingsSection(prayerName: "Isha", preNotificationTime: $settings.preNotificationIsha, isNotificationOn: $settings.notificationIsha)
                }
            }
        }
        .onAppear { syncNotificationSettingsPage() }
        .onChange(of: scenePhase) { _ in
            if scenePhase == .active {
                syncNotificationSettingsPage()
            }
        }
        .onDisappear {
            settings.fetchPrayerTimes(notification: true)
        }
        .confirmationDialog("", isPresented: $showAlert, titleVisibility: .visible) {
            Button("Open Settings") {
                #if !os(watchOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                #endif
            }
            Button("Ignore", role: .cancel) { }
        } message: {
            Text(appLocalized("Please go to Settings and enable notifications to be notified of prayer times."))
        }
        .applyConditionalListStyle(defaultView: true)
        .navigationTitle(appLocalized("Prayer Notifications"))
    }

    private func syncNotificationSettingsPage() {
        Task { @MainActor in
            let authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            settings.fetchPrayerTimes(notification: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if settings.showNotificationAlert && authorizationStatus == .denied {
                        showAlert = true
                    }
                }
            }
        }
    }
}

private struct PrayerTimelineGraphPreviewCard: View {
    let currentPrayer: String
    let nextPrayer: String
    let nextTime: String
    let footer: String?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PreviewPrayerMiniGraph(
                tint: accentColor,
                dotCount: 6,
                activeDotIndex: 2
            )

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currentPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextTime)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PrayerDotsPreviewCard: View {
    let currentPrayer: String
    let nextPrayer: String
    let nextTime: String
    let footer: String?
    let accentColor: Color
    let showsLabels: Bool
    let centered: Bool
    private let labels = ["SB", "SY", "ZH", "AS", "MG", "IS"]

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 7) {
            HStack(spacing: showsLabels ? 5 : 3) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    VStack(spacing: 3) {
                        Circle()
                            .fill(index <= 4 ? Color.primary.opacity(0.92) : Color.primary.opacity(0.26))
                            .frame(width: index == 4 ? 10 : 8, height: index == 4 ? 10 : 8)

                        if showsLabels {
                            Text(label)
                                .font(.system(size: 7, weight: .semibold, design: .rounded))
                                .foregroundStyle(index == 4 ? accentColor : .secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: showsLabels ? .infinity : nil)
                }
            }
            .frame(height: showsLabels ? 26 : 16)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currentPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextTime)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: centered ? .center : .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PreviewPrayerMiniGraph: View {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color
    let dotCount: Int
    let activeDotIndex: Int

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = max(geo.size.height, 1)
            let p: (CGFloat, CGFloat) -> CGPoint = { x, y in .init(x: x * width, y: y * height) }

            let p0 = p(0.06, 0.70)
            let p1 = p(0.52, 0.10)
            let p2 = p(0.78, 0.26)
            let p3 = p(0.94, 0.66)
            let c01a = p(0.22, 0.70)
            let c01b = p(0.38, 0.08)
            let c12a = p(0.60, 0.10)
            let c12b = p(0.70, 0.24)
            let c23a = p(0.84, 0.30)
            let c23b = p(0.90, 0.66)
            let clampedDots = min(max(dotCount, 2), 6)

            let cubicPoint: (CGPoint, CGPoint, CGPoint, CGPoint, CGFloat) -> CGPoint = { a, b, c, d, t in
                let oneMinusT = 1 - t
                let x = (oneMinusT * oneMinusT * oneMinusT * a.x)
                    + (3 * oneMinusT * oneMinusT * t * b.x)
                    + (3 * oneMinusT * t * t * c.x)
                    + (t * t * t * d.x)
                let y = (oneMinusT * oneMinusT * oneMinusT * a.y)
                    + (3 * oneMinusT * oneMinusT * t * b.y)
                    + (3 * oneMinusT * t * t * c.y)
                    + (t * t * t * d.y)
                return CGPoint(x: x, y: y)
            }

            let baseLineColor = colorScheme == .light ? Color.black.opacity(0.42) : Color.white.opacity(0.68)
            let activeLineColor = colorScheme == .light ? Color.black.opacity(0.90) : Color.white.opacity(0.95)
            let futureDotStrokeColor = colorScheme == .light ? Color.black.opacity(0.55) : Color.white.opacity(0.72)
            let clampedActiveIndex = min(max(activeDotIndex, -1), max(clampedDots - 1, -1))

            let markers: [CGPoint] = {
                let m1 = cubicPoint(p0, c01a, c01b, p1, 0.50)
                let m3 = cubicPoint(p2, c23a, c23b, p3, 0.50)
                return Array([p0, m1, p1, p2, m3, p3].prefix(clampedDots))
            }()

            let peakIndex = markers.enumerated().min(by: { $0.element.y < $1.element.y })?.offset ?? 0

            ZStack {
                let curve = Path { path in
                    path.move(to: p0)
                    path.addCurve(to: p1, control1: c01a, control2: c01b)
                    path.addCurve(to: p2, control1: c12a, control2: c12b)
                    path.addCurve(to: p3, control1: c23a, control2: c23b)
                }

                ZStack {
                    curve
                        .stroke(baseLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                    ForEach(Array(markers.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(Color.black)
                            .frame(
                                width: index == peakIndex ? 13 : 11,
                                height: index == peakIndex ? 13 : 11
                            )
                            .position(point)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()

                ForEach(Array(markers.enumerated()), id: \.offset) { index, point in
                    let isReached = index <= clampedActiveIndex
                    Circle()
                        .fill(isReached ? activeLineColor : Color.clear)
                        .overlay(
                            Circle().stroke(
                                isReached ? activeLineColor : futureDotStrokeColor,
                                lineWidth: 1.8
                            )
                        )
                        .frame(
                            width: index == peakIndex ? 10 : 8,
                            height: index == peakIndex ? 10 : 8
                        )
                        .position(point)
                }
            }
        }
        .frame(height: 20)
    }
}

struct NotificationSettingsSection: View {
    @EnvironmentObject var settings: Settings
    
    let prayerName: String
    
    @Binding var preNotificationTime: Int
    @Binding var isNotificationOn: Bool

    private var notificationPageToggleTint: Color {
        settings.accentColor.toggleTint
    }

    var body: some View {
        Section(header: Text(localizedPrayerName(prayerName).uppercased())) {
            Toggle(appLocalized("Notification"), isOn: $isNotificationOn.animation(.easeInOut))
                .font(.subheadline)
                .tint(notificationPageToggleTint)
            
            if isNotificationOn {
                Stepper(value: $preNotificationTime.animation(.easeInOut), in: 0...30, step: 5) {
                    Text(appLocalized("Prenotification Time:"))
                        .font(.subheadline)
                    
                    Text("\(preNotificationTime) \(appLocalized(preNotificationTime != 1 ? "minutes" : "minute"))")
                        .font(.subheadline)
                        .foregroundColor(settings.accentColor.color)
                }
            }
        }
    }
}


// MARK: - Pro Widget Preview Cards

private let pvGold      = Color(red: 201 / 255, green: 162 / 255, blue: 75 / 255)
private let pvInk       = Color(red: 10 / 255,  green: 10 / 255,  blue: 11 / 255)
private let pvTextMain  = Color(red: 242 / 255, green: 241 / 255, blue: 238 / 255)
private let pvTextDim   = Color(red: 140 / 255, green: 140 / 255, blue: 146 / 255)
private let pvTextFaint = Color(red: 90 / 255,  green: 90 / 255,  blue: 96 / 255)

// Widget 1 · Next (systemSmall)
// HTML: lede-hijri top-left (mono 10px faint) + gold dot top-right
//       prayer name in serif 34px main
//       countdown in mono 13px: bold part gold, " left" dim
//       "Then Isha · 20:38" bottom faint
private struct HomeProNextPreviewCard: View {
    var body: some View {
        ZStack {
            pvInk
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("24 RAMADAN")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(pvTextFaint)
                    Spacer()
                    Circle()
                        .fill(pvGold)
                        .frame(width: 6, height: 6)
                        .shadow(color: pvGold.opacity(0.7), radius: 5)
                }
                Spacer()
                Text(localizedPrayerName("Maghrib"))
                    .font(.system(size: 34, weight: .light, design: .serif))
                    .foregroundStyle(pvTextMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                HStack(spacing: 0) {
                    Text("1:14:22")
                        .foregroundStyle(pvGold)
                    Text(" left")
                        .foregroundStyle(pvTextDim)
                }
                .font(.system(size: 13, design: .monospaced))
                .padding(.top, 4)
                Text("Then \(localizedPrayerName("Isha")) · 20:38")
                    .font(.system(size: 11))
                    .foregroundStyle(pvTextFaint)
                    .padding(.top, 2)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// Widget 2 · Index (systemMedium)
// HTML: header (city faint + hijri mono faint), 3-col grid of 6 prayers
//       current (.on) → gold; past (.past) → faint 55% opacity; future → dim
private struct HomeProIndexPreviewCard: View {
    private struct PrayerCell {
        let key: String; let time: String; let state: CellState
        enum CellState { case past, on, future }
    }
    private let cells: [PrayerCell] = [
        PrayerCell(key: "Fajr",    time: "5:52",  state: .past),
        PrayerCell(key: "Shurooq", time: "7:08",  state: .past),
        PrayerCell(key: "Dhuhr",   time: "13:23", state: .past),
        PrayerCell(key: "Asr",     time: "16:46", state: .past),
        PrayerCell(key: "Maghrib", time: "19:31", state: .on),
        PrayerCell(key: "Isha",    time: "20:38", state: .future),
    ]

    private func labelColor(_ s: PrayerCell.CellState) -> Color {
        switch s { case .on: return pvGold; case .past: return pvTextFaint; case .future: return pvTextFaint }
    }
    private func timeColor(_ s: PrayerCell.CellState) -> Color {
        switch s { case .on: return pvGold; case .past: return pvTextFaint; case .future: return pvTextMain }
    }
    private func opacity(_ s: PrayerCell.CellState) -> Double {
        s == .past ? 0.55 : 1.0
    }

    var body: some View {
        ZStack {
            pvInk
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(isMalayAppLanguage() ? "Subang Jaya, Selangor" : "Subang Jaya, Selangor")
                        .font(.system(size: 11))
                        .foregroundStyle(pvTextFaint)
                    Spacer()
                    Text("24 RAMADAN 1447")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(pvTextFaint)
                }
                .padding(.bottom, 13)

                let cols = Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3)
                LazyVGrid(columns: cols, alignment: .leading, spacing: 14) {
                    ForEach(cells, id: \.key) { cell in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(localizedPrayerName(cell.key))
                                .font(.system(size: 11))
                                .foregroundStyle(labelColor(cell.state))
                                .opacity(opacity(cell.state))
                            Text(cell.time)
                                .font(.system(size: 17, design: .monospaced))
                                .foregroundStyle(timeColor(cell.state))
                                .opacity(opacity(cell.state))
                        }
                    }
                }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// Widget 3 · Arc (systemLarge)
// HTML: header (prayer serif 26px + cd gold mono 13px) + next dim 13px
//       SVG arc: horizon (white 10%), full arc (white 22%), elapsed gold, dot with ring
//       footer: location + sunset time
private struct HomeProArcPreviewCard: View {
    var body: some View {
        ZStack {
            pvInk
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizedPrayerName("Maghrib"))
                            .font(.system(size: 26, weight: .light, design: .serif))
                            .foregroundStyle(pvTextMain)
                        Text("1:14:22 remaining")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(pvGold)
                    }
                    Spacer()
                    Text("Next · \(localizedPrayerName("Isha")) 20:38")
                        .font(.system(size: 13))
                        .foregroundStyle(pvTextDim)
                        .multilineTextAlignment(.trailing)
                }

                Spacer()

                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let p0 = CGPoint(x: w * 5/300, y: h * 120/150)
                    let ctrl = CGPoint(x: w * 0.5, y: h * 8/150)
                    let p2 = CGPoint(x: w * 295/300, y: h * 120/150)
                    let markerT: CGFloat = 0.68
                    let inv = 1 - markerT
                    let mx = inv*inv*p0.x + 2*inv*markerT*ctrl.x + markerT*markerT*p2.x
                    let my = inv*inv*p0.y + 2*inv*markerT*ctrl.y + markerT*markerT*p2.y

                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: h * 120/150))
                            path.addLine(to: CGPoint(x: w, y: h * 120/150))
                        }
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)

                        Path { path in
                            path.move(to: p0)
                            path.addQuadCurve(to: p2, control: ctrl)
                        }
                        .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                        Path { path in
                            path.move(to: p0)
                            path.addQuadCurve(to: CGPoint(x: mx, y: my), control: ctrl)
                        }
                        .stroke(pvGold, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                        Circle()
                            .fill(pvGold)
                            .frame(width: 10, height: 10)
                            .position(x: mx, y: my)
                        Circle()
                            .stroke(pvGold.opacity(0.35), lineWidth: 1)
                            .frame(width: 22, height: 22)
                            .position(x: mx, y: my)
                    }
                }
                .frame(height: 150)

                Spacer()

                HStack {
                    Text("◔ Subang Jaya, Selangor")
                        .font(.system(size: 11))
                        .foregroundStyle(pvTextFaint)
                    Spacer()
                    Text("Sunset 19:31")
                        .font(.system(size: 11))
                        .foregroundStyle(pvTextFaint)
                }
                .padding(.top, 12)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                }
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// Widget 4 · Zikir (systemMedium)
// HTML: zik-lbl (IBM Plex Mono 10px letter-spacing .18em faint),
//       zik-ar (Newsreader/serif 30px rtl main),
//       zik-tr (13px italic dim)
private struct HomeProZikirPreviewCard: View {
    var body: some View {
        ZStack {
            pvInk
            VStack(alignment: .leading, spacing: 0) {
                Text(isMalayAppLanguage() ? "MALAM · ISTIGHFAR" : "NIGHT · ISTIGHFAR")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(pvTextFaint)
                Spacer()
                Text("أَسْتَغْفِرُ ٱللَّٰه")
                    .font(.system(size: 30, weight: .light, design: .serif))
                    .foregroundStyle(pvTextMain)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .environment(\.layoutDirection, .rightToLeft)
                Spacer()
                Text(isMalayAppLanguage() ? "Aku memohon ampun kepada Allah." : "I seek forgiveness from Allah.")
                    .font(.system(size: 13).italic())
                    .foregroundStyle(pvTextDim)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// Widget 5 · Lock (accessoryRectangular — shown at small canvas)
// HTML: horizontal row — circle glyph (36px) + prayer name (Newsreader 20px) / sub (11px faint) + countdown (mono 18px)
private struct HomeProLockPreviewCard: View {
    private let panelTwo = Color(red: 0x16/255, green: 0x16/255, blue: 0x1A/255)

    var body: some View {
        ZStack {
            panelTwo
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        .frame(width: 36, height: 36)
                    Text("☾")
                        .font(.system(size: 15))
                        .foregroundStyle(pvGold)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(localizedPrayerName("Maghrib"))
                        .font(.system(size: 16, weight: .light, design: .serif))
                        .foregroundStyle(pvTextMain)
                        .lineLimit(1)
                    Text("Then \(localizedPrayerName("Isha")) · 20:38")
                        .font(.system(size: 9))
                        .foregroundStyle(pvTextFaint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Text("1:14:22")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(pvTextMain)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)

            VStack {
                Spacer()
                Text("LOCK SCREEN · RECTANGULAR")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(pvTextFaint.opacity(0.6))
                    .padding(.bottom, 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Hero Carousel Slides

private struct HeroSlideContainer<Content: View>: View {
    let background: AnyView
    let content: Content
    init(background: AnyView, @ViewBuilder content: () -> Content) {
        self.background = background; self.content = content()
    }
    var body: some View {
        ZStack {
            background
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// Slide 1 · Pro Pack
private struct HeroProSlide: View {
    let hasPremiumWidgetAccess: Bool
    var body: some View {
        HeroSlideContainer(background: AnyView(Color(red: 0x12/255, green: 0x12/255, blue: 0x14/255))) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(pvGold)
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(pvGold)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 100).stroke(pvGold.opacity(0.45), lineWidth: 1))

                    Text("Waktu Pro Pack")
                        .font(.system(size: 20, weight: .light, design: .serif))
                        .foregroundStyle(pvTextMain)

                    Text("Exclusive dark widgets\nwith gold accents.")
                        .font(.system(size: 11))
                        .foregroundStyle(pvTextDim)
                        .lineLimit(2)

                    Button {
                        if hasPremiumWidgetAccess { return }
                        NotificationCenter.default.post(name: .openSupportDonationPaywall, object: nil)
                    } label: {
                        HStack(spacing: 4) {
                            if hasPremiumWidgetAccess {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 10))
                            }
                            Text(hasPremiumWidgetAccess ? "Included in Waktu Pro" : "Get Waktu Pro")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(pvGold)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 100).stroke(pvGold.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 4)

                VStack(spacing: 5) {
                    HomeProNextPreviewCard()
                        .frame(width: 95, height: 95)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    HomeProIndexPreviewCard()
                        .frame(width: 95, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(width: 95)
            }
            .padding(18)
        }
    }
}

// Slide 2 · Aura Pack
private struct HeroAuraSlide: View {
    var body: some View {
        HeroSlideContainer(background: AnyView(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.63, blue: 0.34),
                    Color(red: 0.73, green: 0.28, blue: 0.25),
                    Color(red: 0.21, green: 0.13, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("AURA")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 100).stroke(Color.white.opacity(0.5), lineWidth: 1))

                    Text("Waktu Aura")
                        .font(.system(size: 20, weight: .light, design: .serif))
                        .foregroundStyle(.white)

                    Text("Colorful gradient widgets\ninspired by prayer moments.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "paintpalette.fill").font(.system(size: 10))
                        Text("2 styles available")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 100).stroke(Color.white.opacity(0.5), lineWidth: 1))
                }

                Spacer(minLength: 4)

                VStack(spacing: 5) {
                    HomeAuraPreviewCard(square: true)
                        .frame(width: 95, height: 95)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    HomeMidnightAuraPreviewCard(square: true)
                        .frame(width: 95, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(width: 95)
            }
            .padding(18)
        }
    }
}

// Slide 3 · Minimal Pack
private struct HeroMinimalSlide: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HeroSlideContainer(background: AnyView(
            colorScheme == .dark
                ? Color(red: 0.12, green: 0.12, blue: 0.14)
                : Color(red: 0.96, green: 0.96, blue: 0.97)
        )) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("MINIMAL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 100).stroke(Color.primary.opacity(0.3), lineWidth: 1))

                    Text("Waktu Minimalist")
                        .font(.system(size: 20, weight: .light, design: .serif))
                        .foregroundStyle(.primary)

                    Text("Clean widgets with\nprayer-aware colors.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle").font(.system(size: 10))
                        Text("Free with Waktu")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 100).stroke(Color.primary.opacity(0.2), lineWidth: 1))
                }

                Spacer(minLength: 4)

                VStack(spacing: 5) {
                    HomeMinimalistSmallPreviewCard()
                        .frame(width: 95, height: 95)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    HomeMinimalistMediumPreviewCard()
                        .frame(width: 95, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(width: 95)
            }
            .padding(18)
        }
    }
}

// MARK: - Neo preview cards

private let pvNeoBlack  = Color(red: 0.07, green: 0.07, blue: 0.08)
private let pvNeoLime   = Color(red: 0.72, green: 0.93, blue: 0.35)
private let pvNeoGray   = Color(red: 0.62, green: 0.62, blue: 0.65)
private let pvNeoSubtle = Color(red: 0.38, green: 0.38, blue: 0.40)
private let pvNeoDotOff = Color(red: 0.26, green: 0.26, blue: 0.27)

private struct HomeNeoSmallPreviewCard: View {
    var body: some View {
        ZStack {
            pvNeoBlack
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    (Text("It's ").foregroundColor(pvNeoGray)
                     + Text("Dhuhr").foregroundColor(pvNeoLime).fontWeight(.semibold)
                     + Text(" now").foregroundColor(pvNeoGray))
                    Text("in KL.").foregroundStyle(pvNeoGray)
                    Text(" ").font(.system(size: 4))
                    (Text("Will be ").foregroundColor(pvNeoGray)
                     + Text("Asar").foregroundColor(pvNeoLime).fontWeight(.semibold))
                    Text("at 16:15.").foregroundStyle(pvNeoGray)
                }
                .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(12)
        }
    }
}

private struct HomeNeoTransitSmallPreviewCard: View {
    var body: some View {
        ZStack {
            pvNeoBlack
            GeometryReader { geo in
                let rows = ["ASAR", "1H 42M", "16:15"]
                let dotSize = PreviewNeoDotMatrixText.dotSize(for: rows, availableWidth: geo.size.width - 20)

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next prayer")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.94))
                            .lineLimit(1)
                        Text("Kuala Lumpur")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(pvNeoGray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.bottom, 7)

                    VStack(alignment: .leading, spacing: 4) {
                        PreviewNeoDotMatrixText(
                            text: rows[0],
                            color: pvNeoLime,
                            offColor: pvNeoDotOff,
                            dotSize: dotSize
                        )
                        PreviewNeoDotMatrixText(
                            text: rows[1],
                            color: .white.opacity(0.92),
                            offColor: pvNeoDotOff,
                            dotSize: dotSize
                        )
                        PreviewNeoDotMatrixText(
                            text: rows[2],
                            color: .white.opacity(0.92),
                            offColor: pvNeoDotOff,
                            dotSize: dotSize
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
            }
        }
    }
}

private struct PreviewNeoDotMatrixText: View {
    let text: String
    let color: Color
    let offColor: Color
    let dotSize: CGFloat

    private static let rows = 7
    private static let columns = 5

    private var characters: [Character] {
        Array(text.uppercased().prefix(7))
    }

    static func dotSize(for lines: [String], availableWidth: CGFloat) -> CGFloat {
        let maxCharacterCount = max(lines.map { Array($0.uppercased().prefix(7)).count }.max() ?? 1, 1)
        let scalableColumns = maxCharacterCount * columns + max(maxCharacterCount - 1, 0)
        let fixedInnerSpacing = CGFloat(maxCharacterCount * (columns - 1))
        return max(2, min(3.2, floor((availableWidth - fixedInnerSpacing) / CGFloat(scalableColumns))))
    }

    var body: some View {
        HStack(spacing: dotSize) {
            ForEach(Array(characters.enumerated()), id: \.offset) { _, character in
                characterView(character)
            }
        }
        .frame(height: CGFloat(Self.rows) * dotSize + CGFloat(Self.rows - 1), alignment: .leading)
    }

    private func characterView(_ character: Character) -> some View {
        let pattern = Self.pattern(for: character)
        return VStack(spacing: 1) {
            ForEach(0..<Self.rows, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<Self.columns, id: \.self) { column in
                        RoundedRectangle(cornerRadius: dotSize * 0.18, style: .continuous)
                            .fill(pattern[row][column] ? color : offColor)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
            }
        }
    }

    private static func pattern(for character: Character) -> [[Bool]] {
        let raw: [String]
        switch character {
        case "0": raw = ["11111", "10001", "10011", "10101", "11001", "10001", "11111"]
        case "1": raw = ["00100", "01100", "00100", "00100", "00100", "00100", "01110"]
        case "2": raw = ["11110", "00001", "00001", "11110", "10000", "10000", "11111"]
        case "3": raw = ["11110", "00001", "00001", "01110", "00001", "00001", "11110"]
        case "4": raw = ["10010", "10010", "10010", "11111", "00010", "00010", "00010"]
        case "5": raw = ["11111", "10000", "10000", "11110", "00001", "00001", "11110"]
        case "6": raw = ["01111", "10000", "10000", "11110", "10001", "10001", "01110"]
        case "7": raw = ["11111", "00001", "00010", "00100", "01000", "01000", "01000"]
        case "8": raw = ["01110", "10001", "10001", "01110", "10001", "10001", "01110"]
        case "9": raw = ["01110", "10001", "10001", "01111", "00001", "00001", "11110"]
        case "A": raw = ["01110", "10001", "10001", "11111", "10001", "10001", "10001"]
        case "B": raw = ["11110", "10001", "10001", "11110", "10001", "10001", "11110"]
        case "C": raw = ["01111", "10000", "10000", "10000", "10000", "10000", "01111"]
        case "D": raw = ["11110", "10001", "10001", "10001", "10001", "10001", "11110"]
        case "E": raw = ["11111", "10000", "10000", "11110", "10000", "10000", "11111"]
        case "F": raw = ["11111", "10000", "10000", "11110", "10000", "10000", "10000"]
        case "G": raw = ["01111", "10000", "10000", "10011", "10001", "10001", "01111"]
        case "H": raw = ["10001", "10001", "10001", "11111", "10001", "10001", "10001"]
        case "I": raw = ["11111", "00100", "00100", "00100", "00100", "00100", "11111"]
        case "J": raw = ["00111", "00010", "00010", "00010", "00010", "10010", "01100"]
        case "K": raw = ["10001", "10010", "10100", "11000", "10100", "10010", "10001"]
        case "L": raw = ["10000", "10000", "10000", "10000", "10000", "10000", "11111"]
        case "M": raw = ["10001", "11011", "10101", "10101", "10001", "10001", "10001"]
        case "N": raw = ["10001", "11001", "10101", "10011", "10001", "10001", "10001"]
        case "O": raw = ["01110", "10001", "10001", "10001", "10001", "10001", "01110"]
        case "P": raw = ["11110", "10001", "10001", "11110", "10000", "10000", "10000"]
        case "Q": raw = ["01110", "10001", "10001", "10001", "10101", "10010", "01101"]
        case "R": raw = ["11110", "10001", "10001", "11110", "10100", "10010", "10001"]
        case "S": raw = ["01111", "10000", "10000", "01110", "00001", "00001", "11110"]
        case "T": raw = ["11111", "00100", "00100", "00100", "00100", "00100", "00100"]
        case "U": raw = ["10001", "10001", "10001", "10001", "10001", "10001", "01110"]
        case "V": raw = ["10001", "10001", "10001", "10001", "10001", "01010", "00100"]
        case "W": raw = ["10001", "10001", "10001", "10101", "10101", "10101", "01010"]
        case "X": raw = ["10001", "10001", "01010", "00100", "01010", "10001", "10001"]
        case "Y": raw = ["10001", "10001", "01010", "00100", "00100", "00100", "00100"]
        case "Z": raw = ["11111", "00001", "00010", "00100", "01000", "10000", "11111"]
        case ":": raw = ["00000", "00100", "00100", "00000", "00100", "00100", "00000"]
        default: raw = ["00000", "00000", "00000", "00000", "00000", "00000", "00000"]
        }
        return raw.map { row in row.map { $0 == "1" } }
    }
}

private struct HomeNeoMediumPreviewCard: View {
    var body: some View {
        ZStack {
            pvNeoBlack
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Next prayer").font(.system(size: 8, weight: .medium)).foregroundStyle(pvNeoGray)
                        Text("Subang Jaya").font(.system(size: 7)).foregroundStyle(pvNeoSubtle)
                    }
                    Spacer()
                    Image(systemName: "ellipsis").font(.system(size: 8)).foregroundStyle(pvNeoSubtle)
                }
                .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4)

                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MAGHRIB")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(pvNeoLime)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text("01:28")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("TODAY").font(.system(size: 6, weight: .semibold, design: .monospaced)).foregroundStyle(pvNeoSubtle)
                        Text("18:42").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(pvNeoGray)
                        Text("18:42").font(.system(size: 8, design: .monospaced)).foregroundStyle(pvNeoSubtle)
                    }
                }
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.bottom, 8)
            }
        }
    }
}

private struct HomeNeoLargePreviewCard: View {
    private let prayers = [("Fajr", true), ("Dhuhr", true), ("Asr", true), ("Maghrib", true), ("Isha", false)]
    var body: some View {
        ZStack {
            pvNeoBlack
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill").font(.system(size: 18)).foregroundStyle(pvNeoLime)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Prayer Progress").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            Text("4 of 5 completed today").font(.system(size: 8)).foregroundStyle(pvNeoGray)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Fri, 17 Jan").font(.system(size: 8)).foregroundStyle(pvNeoGray)
                        Text("4/5").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                        Text("prayers").font(.system(size: 7)).foregroundStyle(pvNeoSubtle)
                    }
                }
                .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 8)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(pvNeoSubtle.opacity(0.3)).frame(height: 8)
                        Capsule().fill(pvNeoLime).frame(width: geo.size.width * 0.8, height: 8)
                    }
                }
                .frame(height: 8).padding(.horizontal, 10).padding(.bottom, 10)

                VStack(spacing: 10) {
                    HStack(spacing: 0) {
                        ForEach(Array(prayers.enumerated()), id: \.element.0) { index, item in
                            let name = item.0
                            let done = item.1
                            VStack(spacing: 4) {
                                Text(name).font(.system(size: 7, weight: done ? .semibold : .regular))
                                    .foregroundStyle(done ? .white : pvNeoSubtle).lineLimit(1).minimumScaleFactor(0.7)
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17))
                                    .foregroundStyle(done ? pvNeoLime : pvNeoSubtle)
                                Text(["05:52", "13:23", "16:46", "19:31", "20:38"][index])
                                    .font(.system(size: 6, weight: .medium, design: .monospaced))
                                    .foregroundStyle(done ? pvNeoGray : pvNeoSubtle)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 8)).foregroundStyle(pvNeoGray)
                        Text("Isha remaining ~2h 15m").font(.system(size: 8, weight: .medium)).foregroundStyle(pvNeoGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity, alignment: .center)

                HStack {
                    Text("4 complete").font(.system(size: 8)).foregroundStyle(pvNeoGray)
                    Spacer()
                    Text("On track")
                        .font(.system(size: 8, weight: .semibold)).foregroundStyle(pvNeoBlack)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(pvNeoLime).clipShape(Capsule())
                }
                .padding(.horizontal, 10).padding(.bottom, 10).padding(.top, 8)
            }
        }
    }
}

// MARK: - Sketch preview cards

private let pvSkBg     = Color(red: 0.93, green: 0.93, blue: 0.93)
private let pvSkBlack  = Color.black
private let pvSkOrange = Color(red: 0.92, green: 0.38, blue: 0.09)
private let pvSkGray   = Color(red: 0.55, green: 0.55, blue: 0.57)
private let pvSkDim    = Color(red: 0.72, green: 0.72, blue: 0.74)

private struct PvSketchWave: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width; let h = size.height
            let offsets: [(Double, Double)] = [(0.0, 0.0), (0.06, 0.05), (0.13, 0.10)]
            for (i, (_, dy)) in offsets.enumerated() {
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: h * (0.65 + dy)))
                wave.addCurve(
                    to: CGPoint(x: w, y: h * (0.32 + dy * 0.4)),
                    control1: CGPoint(x: w * 0.28, y: h * (0.80 + dy)),
                    control2: CGPoint(x: w * 0.60, y: h * (0.28 + dy * 0.4))
                )
                let alpha = Double(offsets.count - i) / Double(offsets.count)
                ctx.stroke(wave, with: .color(pvSkOrange.opacity(alpha * 0.9)),
                           style: StrokeStyle(lineWidth: i == 0 ? 1.8 : 1.2, lineCap: .round))
            }
            let dotR: CGFloat = 4
            let dotX = w * 0.60; let dotY = h * 0.38
            ctx.fill(Path(ellipseIn: CGRect(x: dotX - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2)),
                     with: .color(pvSkOrange))
        }
    }
}

private struct PvSketchHatch: View {
    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                ctx.stroke(p, with: .color(pvSkGray.opacity(0.25)), style: StrokeStyle(lineWidth: 0.8))
                x += 4.5
            }
        }
    }
}

private struct HomeSketchSmallPreviewCard: View {
    var body: some View {
        ZStack {
            pvSkBlack
            ZStack(alignment: .bottom) {
                PvSketchWave()
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Waktu").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            Text("Next prayer").font(.system(size: 8)).foregroundStyle(pvSkGray)
                        }
                        Spacer()
                        Image(systemName: "moon.fill").font(.system(size: 13)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10).padding(.top, 10)
                    Spacer()
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Maghrib").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        Text("18:42").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10).padding(.bottom, 12)
                }
            }
        }
    }
}

private struct HomeSketchMediumPreviewCard: View {
    var body: some View {
        ZStack {
            pvSkBg
            ZStack(alignment: .bottomTrailing) {
                PvSketchHatch().frame(width: 60, height: 38).padding(.trailing, 10).padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Waktu").font(.system(size: 12, weight: .bold)).foregroundStyle(pvSkBlack)
                            Text("Prayer progress").font(.system(size: 8)).foregroundStyle(pvSkGray)
                        }
                        Spacer()
                        Image(systemName: "moon.fill").font(.system(size: 13)).foregroundStyle(pvSkBlack)
                    }
                    .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 5)

                    HStack {
                        Spacer()
                        Text("80%").font(.system(size: 18, weight: .bold)).foregroundStyle(pvSkBlack)
                    }.padding(.trailing, 10).padding(.bottom, 4)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(pvSkDim.opacity(0.4)).frame(height: 9)
                            Capsule().fill(pvSkOrange).frame(width: geo.size.width * 0.8, height: 9)
                        }
                    }
                    .frame(height: 9).padding(.horizontal, 10).padding(.bottom, 5)

                    Text("4 of 5 prayers").font(.system(size: 8)).foregroundStyle(pvSkGray)
                        .padding(.horizontal, 10).padding(.bottom, 8)
                }
            }
        }
    }
}

private struct HomeSketchLargePreviewCard: View {
    private let prayers = [("Fajr", true), ("Dhuhr", true), ("Asr", true), ("Maghrib", true), ("Isha", false)]
    var body: some View {
        ZStack {
            pvSkBg
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("80%").font(.system(size: 24, weight: .bold)).foregroundStyle(pvSkBlack)
                        Text("Waktu today").font(.system(size: 9)).foregroundStyle(pvSkGray)
                    }
                    Spacer()
                    Image(systemName: "moon.fill").font(.system(size: 14)).foregroundStyle(pvSkBlack)
                }
                .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 8)

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    // 5x5 dot mini-grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 5), spacing: 3) {
                        ForEach(0..<25) { i in
                            Circle().fill(i < 16 ? pvSkOrange : pvSkDim.opacity(0.4)).frame(width: 8, height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Mini donut
                    ZStack {
                        Circle().stroke(pvSkDim.opacity(0.4), lineWidth: 6)
                        Circle().trim(from: 0, to: 0.8)
                            .stroke(pvSkOrange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("4/5").font(.system(size: 10, weight: .bold)).foregroundStyle(pvSkBlack)
                    }
                    .frame(width: 64, height: 64)
                }
                .padding(.horizontal, 10)
                .frame(height: 88)
                .padding(.bottom, 6)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    ForEach(prayers, id: \.0) { name, done in
                        VStack(spacing: 3) {
                            Text(name).font(.system(size: 7, weight: done ? .semibold : .regular))
                                .foregroundStyle(done ? pvSkBlack : pvSkGray).lineLimit(1).minimumScaleFactor(0.7)
                            ZStack {
                                if done {
                                    Circle().fill(pvSkOrange)
                                    Image(systemName: "checkmark").font(.system(size: 6, weight: .bold)).foregroundStyle(.white)
                                } else {
                                    Circle().stroke(pvSkDim.opacity(0.5), lineWidth: 1)
                                    PvSketchHatch().clipShape(Circle())
                                }
                            }
                            .frame(width: 16, height: 16)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Metro preview cards

private let pvMtroBg    = Color(red: 0.78, green: 0.78, blue: 0.80)
private let pvMtroBlack = Color(red: 0.08, green: 0.08, blue: 0.09)
private let pvMtroRed   = Color(red: 0.91, green: 0.17, blue: 0.17)
private let pvMtroLight = Color(red: 0.95, green: 0.95, blue: 0.96)
private let pvMtroBlue  = Color(red: 0.17, green: 0.43, blue: 0.78)
private let pvTileR: CGFloat = 8
private let pvSmallTileR: CGFloat = 16

private struct PvMetroClock: View {
    let dark: Bool
    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2; let cy = size.height / 2; let r = min(cx, cy) - 1.5
            let face = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            ctx.fill(face, with: .color(dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)))
            for i in 0..<12 {
                let a = CGFloat(i) / 12 * .pi * 2 - .pi / 2
                let t0 = i % 3 == 0 ? r - 4 : r - 3
                var p = Path(); p.move(to: CGPoint(x: cx + cos(a) * t0, y: cy + sin(a) * t0))
                p.addLine(to: CGPoint(x: cx + cos(a) * r, y: cy + sin(a) * r))
                ctx.stroke(p, with: .color(dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3)),
                           style: StrokeStyle(lineWidth: i % 3 == 0 ? 1.2 : 0.7, lineCap: .round))
            }
            let col = dark ? Color.white : Color.black
            // Hour hand ~10:10
            let ha: CGFloat = (10.0 / 12 * .pi * 2 - .pi / 2)
            let ma: CGFloat = (10.0 / 60 * .pi * 2 - .pi / 2)
            var h = Path(); h.move(to: CGPoint(x: cx, y: cy)); h.addLine(to: CGPoint(x: cx + cos(ha) * r * 0.5, y: cy + sin(ha) * r * 0.5))
            ctx.stroke(h, with: .color(col), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            var m = Path(); m.move(to: CGPoint(x: cx, y: cy)); m.addLine(to: CGPoint(x: cx + cos(ma) * r * 0.72, y: cy + sin(ma) * r * 0.72))
            ctx.stroke(m, with: .color(col), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            let dotR: CGFloat = 2.2
            ctx.fill(Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)), with: .color(col))
        }
    }
}

private struct HomeMetroSmallPreviewCard: View {
    var body: some View {
        ZStack {
            pvMtroBg
            VStack(spacing: 3) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("KL".uppercased())
                            .font(.system(size: 6, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Spacer(minLength: 0)
                        Text("Subuh")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                        Text("05:44")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, 7).padding(.vertical, 7)
                    Spacer(minLength: 2)
                    PvMetroClock(dark: true).frame(width: 32, height: 32).padding(5)
                }
                .background(pvMtroBlack)
                .clipShape(RoundedRectangle(cornerRadius: pvSmallTileR, style: .continuous))

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Next: Zohor")
                            .font(.system(size: 6, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.75))
                        Spacer(minLength: 0)
                        Text("06:12")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("12:45")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                    .padding(.leading, 7).padding(.vertical, 7)
                    Spacer(minLength: 2)
                    PvMetroClock(dark: false).frame(width: 32, height: 32).padding(5)
                }
                .background(pvMtroRed)
                .clipShape(RoundedRectangle(cornerRadius: pvSmallTileR, style: .continuous))
            }
            .padding(4)
        }
    }
}

private struct HomeMetroMediumPreviewCard: View {
    var body: some View {
        ZStack {
            pvMtroBg
            HStack(spacing: 3) {
                VStack(spacing: 3) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Next Prayer").font(.system(size: 6)).foregroundStyle(Color.white.opacity(0.5))
                            Text("Asar").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            Text("00:45").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(pvMtroRed)
                            Text("16:15").font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(Color.white.opacity(0.65))
                        }
                        .padding(.leading, 7).padding(.vertical, 6)
                        Spacer()
                        PvMetroClock(dark: true).frame(width: 28, height: 28).padding(5)
                    }
                    .background(pvMtroBlack)
                    .clipShape(RoundedRectangle(cornerRadius: pvTileR, style: .continuous))

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 3) {
                                Image(systemName: "sunrise.fill").font(.system(size: 7)).foregroundStyle(.orange)
                                Text("06:12").font(.system(size: 8, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                            }
                            HStack(spacing: 3) {
                                Image(systemName: "sunset.fill").font(.system(size: 7)).foregroundStyle(.orange.opacity(0.7))
                                Text("19:24").font(.system(size: 8, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 7).padding(.vertical, 6)
                    .background(pvMtroBlack)
                    .clipShape(RoundedRectangle(cornerRadius: pvTileR, style: .continuous))
                }

                VStack(spacing: 3) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Mon 26").font(.system(size: 11, weight: .bold)).foregroundStyle(.black)
                            Text("June").font(.system(size: 8)).foregroundStyle(Color.black.opacity(0.55))
                            Text("8 Muharram").font(.system(size: 7)).foregroundStyle(Color.black.opacity(0.4))
                        }
                        .padding(.leading, 7).padding(.vertical, 6)
                        Spacer()
                        PvMetroClock(dark: false).frame(width: 28, height: 28).padding(5)
                    }
                    .background(pvMtroLight)
                    .clipShape(RoundedRectangle(cornerRadius: pvTileR, style: .continuous))

                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Maghrib").font(.system(size: 8, weight: .bold)).foregroundStyle(pvMtroRed)
                            Text("19:24").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                        }
                        Spacer()
                        Text("02:10").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(pvMtroRed)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 6)
                    .background(pvMtroBlack)
                    .clipShape(RoundedRectangle(cornerRadius: pvTileR, style: .continuous))
                }
            }
            .padding(4)
        }
    }
}

private struct HomeMetroLargePreviewCard: View {
    var body: some View {
        ZStack {
            pvMtroBg
            VStack(spacing: 3) {
                // Row 1
                HStack(spacing: 3) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Next Prayer").font(.system(size: 6)).foregroundStyle(Color.white.opacity(0.5))
                            Text("Asar").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            Text("00:45").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(pvMtroRed)
                            Text("16:15").font(.system(size: 8, design: .monospaced)).foregroundStyle(Color.white.opacity(0.6))
                        }
                        .padding(.leading, 8).padding(.vertical, 8)
                        Spacer()
                        PvMetroClock(dark: true).frame(width: 36, height: 36).padding(6)
                    }
                    .background(pvMtroBlack)
                    .clipShape(RoundedRectangle(cornerRadius: pvTileR, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text("Mon 26").font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                            Spacer()
                            ZStack {
                                Circle().stroke(Color.black.opacity(0.1), lineWidth: 2)
                                Circle().trim(from: 0, to: 0.62).stroke(pvMtroRed, style: StrokeStyle(lineWidth: 2, lineCap: .round)).rotationEffect(.degrees(-90))
                                Text("62%").font(.system(size: 6, weight: .bold)).foregroundStyle(.black)
                            }.frame(width: 22, height: 22)
                        }
                        Text("June 2025").font(.system(size: 8)).foregroundStyle(Color.black.opacity(0.55))
                        Text("8 Muharram 1447").font(.system(size: 7)).foregroundStyle(Color.black.opacity(0.4))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 8)
                    .background(pvMtroLight)
                    .clipShape(RoundedRectangle(cornerRadius: pvTileR, style: .continuous))
                }

                // Row 2 — prayer strip
                HStack(spacing: 0) {
                    ForEach(Array(["Subuh", "Zohor", "Asar", "Maghrib", "Isyak"].enumerated()), id: \.offset) { idx, name in
                        let isCur = idx == 2
                        VStack(spacing: 1) {
                            Text(name).font(.system(size: 7, weight: isCur ? .bold : .regular))
                                .foregroundStyle(isCur ? .white : Color.white.opacity(0.45)).lineLimit(1).minimumScaleFactor(0.7)
                            Text(["05:44","13:10","16:15","19:24","20:35"][idx])
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(isCur ? pvMtroRed : Color.white.opacity(0.75))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background(isCur ? Color.white.opacity(0.07) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        if idx < 4 {
                            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1).padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .background(pvMtroBlack)
                .clipShape(RoundedRectangle(cornerRadius: pvTileR, style: .continuous))

                // Row 3
                HStack(spacing: 3) {
                    HStack(spacing: 5) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 3) {
                                Image(systemName: "sunrise.fill").font(.system(size: 7)).foregroundStyle(.white.opacity(0.9))
                                Text("06:12").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                            }
                            HStack(spacing: 3) {
                                Image(systemName: "sunset.fill").font(.system(size: 7)).foregroundStyle(.white.opacity(0.7))
                                Text("19:24").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 8)
                    .background(pvMtroBlue)
                    .clipShape(RoundedRectangle(cornerRadius: pvTileR, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next").font(.system(size: 7)).foregroundStyle(Color.white.opacity(0.4))
                        Text("Maghrib").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        Text("19:24").font(.system(size: 8, design: .monospaced)).foregroundStyle(Color.white.opacity(0.65))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(pvMtroBlack)
                    .clipShape(RoundedRectangle(cornerRadius: pvTileR, style: .continuous))

                    VStack(spacing: 3) {
                        Image(systemName: "timer").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        Text("02:10").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                        Text("away").font(.system(size: 7)).foregroundStyle(Color.white.opacity(0.7))
                    }
                    .padding(.vertical, 8).frame(width: 48)
                    .background(pvMtroRed)
                    .clipShape(RoundedRectangle(cornerRadius: pvTileR, style: .continuous))
                }
            }
            .padding(4)
        }
    }
}

#Preview {
    SettingsAdhanView(showNotifications: true)
        .environmentObject(Settings.shared)
}

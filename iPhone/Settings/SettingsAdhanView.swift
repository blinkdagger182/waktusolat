import SwiftUI
import UserNotifications
import WidgetKit
#if os(iOS)
import AVFoundation
import AudioToolbox
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
                    
                    #if os(iOS)
                    Toggle(appLocalized("Live Next Prayer Activity"), isOn: $settings.liveNextPrayerEnabled.animation(.easeInOut))
                        .font(.subheadline)
                        .tint(settings.accentColor.toggleTint)

                    if settings.liveNextPrayerEnabled {
                        HStack {
                            Text(appLocalized("Show Before Prayer"))
                                .font(.subheadline)
                            Spacer()
                            Text("\(max(0, settings.liveActivityLeadMinutes)) \(appLocalized("minutes"))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text("Live Activity appears \(max(0, settings.liveActivityLeadMinutes)) minutes before prayer time. This timing is fixed for now.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    } else {
                        Text("Shows a live countdown to the next prayer on the Lock Screen when that prayer notification is enabled.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    }

                    /*
                    #if DEBUG
                    if #available(iOS 16.2, *) {
                        Button {
                            settings.hapticFeedback()
                            settings.startDebugLiveNextPrayerActivity(prayerName: "Test Prayer", minutesUntilPrayer: 2)
                        } label: {
                            Label("Start Test Live Activity (2 min)", systemImage: "timer")
                                .foregroundColor(settings.accentColor.color)
                        }
                        .font(.subheadline)
                    }
                    #endif
                    */
                    #endif
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
    #if os(iOS)
    @State private var previewPlayer: AVAudioPlayer?
    #endif
    
    var body: some View {
        List {
            #if !os(watchOS)
            Section {
                permissionCard
            }
            #endif
            
            Section(header: Text(appLocalized("PRAYER REMINDERS"))) {
                NavigationLink(destination: MoreNotificationView()) {
                    Label(appLocalized("Prayer Notifications"), systemImage: "bell.fill")
                        .font(.subheadline)
                }
            }

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
                    set: { settings.prayerNotificationMessageStyle = $0 }
                )) {
                    ForEach(PrayerNotificationMessageStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.menu)

                Text(settings.prayerNotificationMessageStyle.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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

            Section(header: Text(appLocalized("NOTIFICATION SOUND"))) {
                Picker(
                    selection: Binding(
                        get: { settings.notificationSoundOption },
                        set: {
                            settings.setNotificationSoundOption($0)
                            playPreviewIfNeeded(for: $0)
                        }
                    )
                ) {
                    ForEach(NotificationSoundOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                } label: {
                    Label(appLocalized("Notification Sound"), systemImage: "speaker.wave.2.fill")
                        .font(.subheadline)
                }
                .pickerStyle(.menu)
            }
        }
        .task { await refresh() }
        .onAppear { syncNotificationState() }
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
        switch settings.prayerNotificationMessageStyle {
        case .standard:
            return isMalayAppLanguage()
                ? "Waktu Asar pada 4:25 PTG di Taiping, Perak"
                : "Time for Asr at 4:25 PM in Taiping, Perak"
        case .gentle:
            return isMalayAppLanguage()
                ? "Kini masuk waktu Asar di Taiping, Perak."
                : "It's now time for Asr in Taiping, Perak."
        case .concise:
            return isMalayAppLanguage()
                ? "Asar • 4:25 PTG • Taiping, Perak"
                : "Asr • 4:25 PM • Taiping, Perak"
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
                ? "Maha Suci Allah • Taiping, Perak"
                : "Glory be to Allah • Taiping, Perak"
        }
    }

    private func playPreviewIfNeeded(for option: NotificationSoundOption) {
        #if os(iOS)
        switch option {
        case .azan:
            guard let url = Bundle.main.url(forResource: "azan_waktu", withExtension: "mp3") else {
                previewPlayer?.stop()
                previewPlayer = nil
                return
            }
            do {
                previewPlayer = try AVAudioPlayer(contentsOf: url)
                previewPlayer?.prepareToPlay()
                previewPlayer?.play()
            } catch {
                previewPlayer = nil
            }
        case .iosDefault:
            previewPlayer?.stop()
            previewPlayer = nil
            AudioServicesPlaySystemSound(1007)
        }
        #endif
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
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
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
    @EnvironmentObject var settings: Settings
    @AppStorage(LockScreenPrayerCountdownStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var countdownStyleRaw = LockScreenPrayerCountdownStyle.prayerCountdownWithLocation.rawValue
    @AppStorage(WidgetZikirAlignment.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var zikirAlignmentRaw = WidgetZikirAlignment.center.rawValue

    private var countdownStyle: LockScreenPrayerCountdownStyle {
        LockScreenPrayerCountdownStyle(rawValue: countdownStyleRaw) ?? .prayerCountdownWithLocation
    }

    private var zikirAlignment: WidgetZikirAlignment {
        WidgetZikirAlignment(rawValue: zikirAlignmentRaw) ?? .center
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                previewSection(
                    title: isMalayAppLanguage() ? "Kiraan Detik Solat" : "Prayer Countdown",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih antara dua gaya untuk widget kiraan detik solat pada skrin kunci."
                        : "Choose between the two Lock Screen styles for the prayer countdown widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(LockScreenPrayerCountdownStyle.allCases) { style in
                                Button {
                                    settings.hapticFeedback()
                                    withAnimation(.easeInOut) {
                                        countdownStyleRaw = style.rawValue
                                    }
                                    WidgetCenter.shared.reloadAllTimelines()
                                } label: {
                                    PrayerCountdownStyleCard(
                                        style: style,
                                        isSelected: countdownStyle == style
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
                            ForEach(WidgetZikirAlignment.allCases) { alignment in
                                Button {
                                    settings.hapticFeedback()
                                    withAnimation(.easeInOut) {
                                        zikirAlignmentRaw = alignment.rawValue
                                    }
                                    WidgetCenter.shared.reloadAllTimelines()
                                } label: {
                                    ZikirStyleCard(
                                        alignment: alignment,
                                        isSelected: zikirAlignment == alignment
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
        .navigationTitle(appLocalized("Widget Previews"))
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

private struct LockScreenSpotlightCard: View {
    @EnvironmentObject var settings: Settings

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
                    .fill(Color.black)

                LinearGradient(
                    colors: [Color.white.opacity(0.05), settings.accentColor.color.opacity(0.12)],
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
                    .foregroundStyle(.white.opacity(0.92))
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
                    .stroke(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(isSelected
                     ? (isMalayAppLanguage() ? "Dipilih" : "Selected")
                     : style.summary)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? settings.accentColor.color : .secondary)
                    .lineLimit(2)
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
                footer: "Taiping, Perak",
                accentColor: settings.accentColor.color
            )
        case .prayerList:
            LockScreenPrayerListPreviewCard(footer: "Taiping, Perak")
        case .prayerCountdown:
            LockScreenCountdownPreviewCard(
                prayer: localizedPrayerName("Isha"),
                timerText: "19:31",
                footer: "Taiping, Perak",
                accentColor: settings.accentColor.color
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
                reference: "Al-Ahzab 56"
            )
        }
    }
}

private struct PrayerCountdownStyleCard: View {
    @EnvironmentObject var settings: Settings

    let style: LockScreenPrayerCountdownStyle
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black)

                LinearGradient(
                    colors: [Color.white.opacity(0.05), settings.accentColor.color.opacity(0.12)],
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
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    if style == .prayerCountdownWithLocation {
                        LockScreenTimelinePreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Taiping, Perak",
                            accentColor: settings.accentColor.color
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerCountdownWithoutLocation {
                        LockScreenTimelinePreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: nil,
                            accentColor: settings.accentColor.color
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerTimelineWithLocation {
                        PrayerTimelineGraphPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Taiping, Perak",
                            accentColor: settings.accentColor.color
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else {
                        PrayerTimelineGraphPreviewCard(
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
                    .stroke(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(isSelected
                     ? (isMalayAppLanguage() ? "Dipilih" : "Selected")
                     : style.summary)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? settings.accentColor.color : .secondary)
                    .lineLimit(2)
            }
            .frame(width: 188, alignment: .leading)
        }
    }
}

private struct ZikirStyleCard: View {
    @EnvironmentObject var settings: Settings

    let alignment: WidgetZikirAlignment
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black)

                LinearGradient(
                    colors: [Color.white.opacity(0.05), settings.accentColor.color.opacity(0.12)],
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
                    .foregroundStyle(.white.opacity(0.92))
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
                    .stroke(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(alignment.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(isSelected
                     ? (isMalayAppLanguage() ? "Dipilih" : "Selected")
                     : alignment.summary)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? settings.accentColor.color : .secondary)
                    .lineLimit(2)
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
                    .foregroundStyle(accentColor)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextTime)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextPrayer)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
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

private struct LockScreenCountdownPreviewCard: View {
    let prayer: String
    let timerText: String
    let footer: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(prayer)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(timerText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            ProgressView(value: 0.62)
                .progressViewStyle(.linear)
                .tint(accentColor)

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
        case .center:
            return .center
        }
    }

    private var textAlignment: TextAlignment {
        switch alignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center:
            return .center
        }
    }

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: 3) {
            Text(helperTitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(arabic)
                .font(.system(size: 19, weight: .regular))
                .multilineTextAlignment(textAlignment)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
            Text(translation)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(textAlignment)
                .lineLimit(1)
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
        case .center:
            return .center
        }
    }
}

private struct LockScreenVersePreviewCard: View {
    let verse: String
    let reference: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verse)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(3)

            Spacer(minLength: 0)

            Text(reference)
                .font(.system(size: 10, weight: .semibold))
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

struct NotificationSoundSelectionView: View {
    @EnvironmentObject var settings: Settings
    #if os(iOS)
    @State private var previewPlayer: AVAudioPlayer?
    #endif

    private func playPreviewIfNeeded(for option: NotificationSoundOption) {
        #if os(iOS)
        guard option == .azan,
              let url = Bundle.main.url(forResource: "azan_waktu", withExtension: "mp3")
        else {
            previewPlayer?.stop()
            previewPlayer = nil
            return
        }
        do {
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.prepareToPlay()
            previewPlayer?.play()
        } catch {
            previewPlayer = nil
        }
        #endif
    }

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
                Path { path in
                    path.move(to: p0)
                    path.addCurve(to: p1, control1: c01a, control2: c01b)
                    path.addCurve(to: p2, control1: c12a, control2: c12b)
                    path.addCurve(to: p3, control1: c23a, control2: c23b)
                }
                .stroke(baseLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

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


#Preview {
    SettingsAdhanView(showNotifications: true)
        .environmentObject(Settings.shared)
}

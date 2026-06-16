import SwiftUI
import WidgetKit
#if os(iOS)
import UIKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
private enum LiveActivityTheme {
    private static let appGroupSuite = "group.app.riskcreatives.waktu"

    static func style() -> LiveNotificationStyle {
        let raw = UserDefaults(suiteName: appGroupSuite)?.string(forKey: LiveNotificationStyle.storageKey)
        return LiveNotificationStyle(rawValue: raw ?? "") ?? .current
    }

    static func accentUIColor() -> UIColor {
        let raw = UserDefaults(suiteName: appGroupSuite)?.string(forKey: "accentColor") ?? "adaptive"
        switch raw {
        case "red": return .systemRed
        case "orange": return .systemOrange
        case "yellow": return .systemYellow
        case "green": return .systemGreen
        case "blue": return .systemBlue
        case "indigo": return .systemIndigo
        case "cyan": return .systemCyan
        case "teal": return .systemTeal
        case "mint": return .systemMint
        case "purple": return .systemPurple
        case "brown": return .brown
        case "lightPink": return UIColor(red: 1.0, green: 182.0 / 255.0, blue: 193.0 / 255.0, alpha: 1)
        case "hotPink", "pink": return UIColor(red: 1.0, green: 105.0 / 255.0, blue: 180.0 / 255.0, alpha: 1)
        default: return .label
        }
    }

    static func hijriFooterText() -> String {
        let defaults = UserDefaults(suiteName: appGroupSuite)
        let offset = defaults?.integer(forKey: "hijriOffset") ?? 0
        var sourcePrayers: [Prayer] = []
        var location: Location?
        if let data = defaults?.data(forKey: "prayersData"),
           let cached = try? Settings.decoder.decode(Prayers.self, from: data) {
            sourcePrayers = cached.fullPrayers.isEmpty ? cached.prayers : cached.fullPrayers
        }
        if let locationData = defaults?.data(forKey: "currentLocation"),
           let decodedLocation = try? Settings.decoder.decode(Location.self, from: locationData) {
            location = decodedLocation
        }

        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let referenceDate = Settings.islamicReferenceDate(prayers: sourcePrayers)
        let effectiveOffset = Settings.effectiveHijriOffset(baseOffset: offset, location: location)
        let date = calendar.date(byAdding: .day, value: effectiveOffset, to: referenceDate) ?? referenceDate
        let day = calendar.component(.day, from: date)

        let monthFormatter = DateFormatter()
        monthFormatter.calendar = calendar
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "MMMM"
        let monthName = monthFormatter.string(from: date)
        return "\(day) \(monthName)"
    }

    static func prayerTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h.mm"
        return formatter.string(from: date)
    }

    static func palette(for colorScheme: ColorScheme) -> (bg: Color, fg: Color, muted: Color, track: Color, progress: Color) {
        let accent = accentUIColor()
        let background = colorScheme == .dark
            ? accent.blended(with: .black, fraction: 0.62)
            : accent.blended(with: .white, fraction: 0.18)
        let bgLuma = background.relativeLuminance

        let foreground: UIColor
        if colorScheme == .dark {
            foreground = .white
        } else {
            foreground = bgLuma > 0.58 ? .black : .white
        }

        return (
            bg: Color(background),
            fg: Color(foreground),
            muted: Color(foreground).opacity(0.78),
            track: Color(foreground).opacity(0.16),
            progress: Color(foreground).opacity(0.94)
        )
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct LiveNotificationBrandIcon: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        if LiveActivityTheme.style() == .timeline {
            Image("WaktuLiveIcon")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: size, weight: .bold))
                .foregroundColor(color)
        }
    }
}

private extension UIColor {
    func blended(with other: UIColor, fraction: CGFloat) -> UIColor {
        let clamped = min(max(fraction, 0), 1)
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0
        guard getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return self
        }
        return UIColor(
            red: r1 + (r2 - r1) * clamped,
            green: g1 + (g2 - g1) * clamped,
            blue: b1 + (b2 - b1) * clamped,
            alpha: a1 + (a2 - a1) * clamped
        )
    }

    var relativeLuminance: CGFloat {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0 }
        return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
    }
}

@available(iOS 18.0, *)
struct NextPrayerLiveActivityWidgetWithCarPlay: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerLiveActivityAttributes.self) { context in
            CarPlayAwareContentView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(localizedPrayerName(context.state.prayerName))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.prayerTime, style: .time)
                        .font(.system(.subheadline, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        LiveActivityCountdownText(
                            prayerTime: context.state.prayerTime,
                            reachedText: appLocalized("It's time for %@", localizedPrayerName(context.state.prayerName)),
                            countdownPrefix: appLocalized("Next in"),
                            compactReachedText: appLocalized("It's time for %@", localizedPrayerName(context.state.prayerName)),
                            isStale: context.isStale,
                            compact: false
                        )
                    }
                }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                LiveActivityCompactTimerText(
                    prayerTime: context.state.prayerTime,
                    prayerName: context.state.prayerName,
                    isStale: context.isStale
                )
            } minimal: {
                LiveNotificationBrandIcon(color: .primary, size: 10)
            }
        }
        .supplementalActivityFamilies([.medium])
    }
}

@available(iOS 18.0, *)
private struct CarPlayAwareContentView: View {
    @Environment(\.activityFamily) private var activityFamily
    @Environment(\.colorScheme) private var colorScheme
    let context: ActivityViewContext<PrayerLiveActivityAttributes>

    var body: some View {
        if activityFamily == .medium {
            CarPlayLiveActivityView(context: context)
        } else {
            NextPrayerLiveActivityContentView(context: context)
        }
    }
}

@available(iOS 18.0, *)
private struct CarPlayLiveActivityView: View {
    let context: ActivityViewContext<PrayerLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedPrayerName(context.state.prayerName))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                if !context.state.city.isEmpty {
                    Text(context.state.city)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            TimelineView(.explicit([.distantPast, context.state.prayerTime])) { _ in
                let now = Date()
                if context.isStale || now >= context.state.prayerTime {
                    Text(appLocalized("It's time for %@", localizedPrayerName(context.state.prayerName)))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .multilineTextAlignment(.trailing)
                } else {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(appLocalized("Next in"))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(timerInterval: now...context.state.prayerTime, countsDown: true)
                            .font(.system(.title3, design: .rounded).weight(.black))
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding()
    }
}

@available(iOSApplicationExtension 16.2, *)
struct NextPrayerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerLiveActivityAttributes.self) { context in
            NextPrayerLiveActivityContentView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(localizedPrayerName(context.state.prayerName))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.prayerTime, style: .time)
                        .font(.system(.subheadline, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        LiveActivityCountdownText(
                            prayerTime: context.state.prayerTime,
                            reachedText: appLocalized("It's time for %@", localizedPrayerName(context.state.prayerName)),
                            countdownPrefix: appLocalized("Next in"),
                            compactReachedText: appLocalized("It's time for %@", localizedPrayerName(context.state.prayerName)),
                            isStale: context.isStale,
                            compact: false
                        )
                    }
                }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                LiveActivityCompactTimerText(
                    prayerTime: context.state.prayerTime,
                    prayerName: context.state.prayerName,
                    isStale: context.isStale
                )
            } minimal: {
                LiveNotificationBrandIcon(color: .primary, size: 10)
            }
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct NextPrayerLiveActivityContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    let context: ActivityViewContext<PrayerLiveActivityAttributes>

    var body: some View {
        if LiveActivityTheme.style() == .timeline {
            TimelineLiveActivityContentView(context: context)
        } else {
            DefaultLiveActivityContentView(context: context)
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct DefaultLiveActivityContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    let context: ActivityViewContext<PrayerLiveActivityAttributes>

    var body: some View {
        let palette = LiveActivityTheme.palette(for: colorScheme)
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.bg)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(localizedPrayerName(context.state.prayerName)) · \(LiveActivityTheme.prayerTimeText(context.state.prayerTime))")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(palette.fg)
                    Spacer()
                    Text(context.state.city)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(palette.muted)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    LiveActivityCountdownText(
                        prayerTime: context.state.prayerTime,
                        reachedText: appLocalized("It's time for %@", localizedPrayerName(context.state.prayerName)),
                        countdownPrefix: appLocalized("Next in"),
                        compactReachedText: appLocalized("It's time for %@", localizedPrayerName(context.state.prayerName)),
                        isStale: context.isStale,
                        compact: false
                    )
                    .foregroundColor(palette.fg)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.82)

                TimelineView(.explicit([.distantPast, context.state.prayerTime])) { timeline in
                    if timeline.date >= context.state.prayerTime {
                        Capsule(style: .continuous)
                            .fill(palette.progress)
                            .frame(height: 14)
                    } else {
                        ProgressView(
                            timerInterval: context.state.startedAt...context.state.prayerTime,
                            countsDown: false
                        )
                        .progressViewStyle(.linear)
                        .labelsHidden()
                        .tint(palette.progress)
                        .scaleEffect(x: 1, y: 2.2, anchor: .center)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(palette.track)
                                .frame(height: 14)
                        )
                    }
                }

                HStack {
                    Text(LiveActivityTheme.hijriFooterText())
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(palette.muted)
                    Spacer()
                    HStack(spacing: 4) {
                        LiveNotificationBrandIcon(color: palette.muted, size: 12)
                        Text(appLocalized("Waktu"))
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundColor(palette.muted)
                    }
                }
            }
            .padding()
        }
        .activityBackgroundTint(palette.bg)
        .activitySystemActionForegroundColor(palette.fg)
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct TimelineLiveActivityPalette {
    let background: Color
    let primary: Color
    let secondary: Color
    let track: Color
    let inactiveDotFill: Color
    let inactiveDotStroke: Color
    let accent: Color

    init(isNight: Bool, accent: Color) {
        self.accent = isNight ? Color(red: 0.47, green: 0.82, blue: 0.58) : accent
        background = isNight ? Color(red: 0.035, green: 0.047, blue: 0.062) : .white
        primary = isNight ? .white : .black
        secondary = isNight ? Color.white.opacity(0.62) : Color.black.opacity(0.58)
        track = isNight ? Color.white.opacity(0.22) : Color.black.opacity(0.22)
        inactiveDotFill = isNight ? Color(red: 0.035, green: 0.047, blue: 0.062) : .white
        inactiveDotStroke = isNight ? Color.white.opacity(0.36) : Color.black.opacity(0.28)
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct TimelineLiveActivityContentView: View {
    let context: ActivityViewContext<PrayerLiveActivityAttributes>

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { timeline in
            let liveNow = timeline.date
            let model = LiveActivityPrayerTimeline.make(
                prayerName: context.state.prayerName,
                prayerTime: context.state.prayerTime,
                startedAt: context.state.startedAt,
                city: context.state.city,
                now: liveNow
            )
            let palette = TimelineLiveActivityPalette(isNight: model.isNightMode, accent: model.accent)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(localizedPrayerName(context.state.prayerName))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(palette.primary)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(model.targetTimeText)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundColor(palette.primary)
                        Text(model.city)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(palette.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(model.remainingValueText)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(palette.accent)
                        .monospacedDigit()
                    Text(model.remainingUnitText)
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundColor(palette.primary)
                    Text(model.remainingSuffixText)
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundColor(palette.primary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)

                PrayerTimelineProgressView(model: model)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.background)
            )
        }
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.black)
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerTimelineProgressView: View {
    let model: LiveActivityPrayerTimeline

    var body: some View {
        let palette = TimelineLiveActivityPalette(isNight: model.isNightMode, accent: model.accent)

        VStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let y = proxy.size.height / 2
                let safeActiveIndex = min(max(model.activeIndex, 0), model.markers.count - 1)
                let previousMarker = model.markers[max(safeActiveIndex - 1, 0)]
                let activeMarker = model.markers[safeActiveIndex]
                let activeX = width * (previousMarker.position + (activeMarker.position - previousMarker.position) * model.progress)

                ZStack(alignment: .leading) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(palette.track, lineWidth: 2)

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: activeX, y: y))
                    }
                    .stroke(palette.accent, lineWidth: 3)

                    ForEach(model.markers.indices, id: \.self) { index in
                        let marker = model.markers[index]
                        Circle()
                            .fill(marker.isActive ? palette.accent : palette.inactiveDotFill)
                            .frame(width: marker.isActive ? 13 : 9, height: marker.isActive ? 13 : 9)
                            .overlay(
                                Circle()
                                    .stroke(marker.isActive ? palette.background : palette.inactiveDotStroke, lineWidth: 2)
                            )
                            .shadow(color: marker.isActive ? palette.accent.opacity(0.35) : .clear, radius: 4)
                            .position(x: width * marker.position, y: y)
                    }
                }
            }
            .frame(height: 18)

            HStack {
                ForEach(model.markers) { marker in
                    Text(marker.label)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(marker.isActive ? palette.accent : palette.secondary)
                        .fontWeight(marker.isActive ? .semibold : .regular)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct LiveActivityPrayerTimeline {
    struct Marker: Identifiable {
        let id: String
        let label: String
        let position: CGFloat
        let isActive: Bool
    }

    let prayerName: String
    let prayerTime: Date
    let previousPrayerTime: Date
    let city: String
    let markers: [Marker]
    let activeIndex: Int
    let progress: CGFloat
    let remainingValueText: String
    let remainingUnitText: String
    let remainingSuffixText: String
    let subtitle: String
    let targetTimeText: String
    let accent: Color
    let isNightMode: Bool

    static func make(
        prayerName: String,
        prayerTime: Date,
        startedAt: Date,
        city: String,
        now: Date
    ) -> Self {
        let prayers = cachedPrayers()
        let canonicalNext = canonicalKey(prayerName)
        let activeIndex = canonicalPrayerOrder.firstIndex(of: canonicalNext) ?? 0
        let previousTime = previousPrayerTime(
            beforeActiveIndex: activeIndex,
            prayers: prayers,
            activeTime: prayerTime,
            fallback: startedAt
        )

        let denominator = max(prayerTime.timeIntervalSince(previousTime), 60)
        let rawProgress = (now.timeIntervalSince(previousTime) / denominator)
        let progress = CGFloat(min(max(rawProgress, 0), 1))

        let markerCount = canonicalPrayerOrder.count
        let markers = canonicalPrayerOrder.enumerated().map { index, key in
            Marker(
                id: key,
                label: compactPrayerLabel(key),
                position: CGFloat(index) / CGFloat(markerCount - 1),
                isActive: index == activeIndex
            )
        }

        let remaining = max(prayerTime.timeIntervalSince(now), 0)
        let roundedMinutes = max(Int(ceil(remaining / 60)), 0)
        let remainingValue: String
        let remainingUnit: String
        if roundedMinutes >= 60 {
            let hours = roundedMinutes / 60
            let minutes = roundedMinutes % 60
            remainingValue = minutes == 0 ? "\(hours)" : "\(hours)h \(minutes)"
            remainingUnit = minutes == 0 ? "hr" : "min"
        } else {
            remainingValue = "\(max(roundedMinutes, 1))"
            remainingUnit = "min"
        }

        let resolvedCity = city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? cachedCityFallback()
            : city
        let targetName = localizedPrayerName(prayerName)
        let isNightMode = canonicalNext == "fajr" || canonicalNext == "isha"

        return LiveActivityPrayerTimeline(
            prayerName: prayerName,
            prayerTime: prayerTime,
            previousPrayerTime: previousTime,
            city: resolvedCity,
            markers: markers,
            activeIndex: activeIndex,
            progress: progress,
            remainingValueText: remainingValue,
            remainingUnitText: remainingUnit,
            remainingSuffixText: "until \(targetName)",
            subtitle: "\(targetName) is approaching",
            targetTimeText: targetTimeFormatter.string(from: prayerTime),
            accent: Color(red: 0.05, green: 0.34, blue: 0.18),
            isNightMode: isNightMode
        )
    }

    private static func cachedPrayers() -> [Prayer] {
        let defaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
        guard let data = defaults?.data(forKey: "prayersData"),
              let cached = try? Settings.decoder.decode(Prayers.self, from: data) else {
            return []
        }
        return cached.fullPrayers.isEmpty ? cached.prayers : cached.fullPrayers
    }

    private static func cachedCityFallback() -> String {
        let defaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
        if let locationData = defaults?.data(forKey: "currentLocation"),
           let location = try? Settings.decoder.decode(Location.self, from: locationData),
           !location.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return location.city
        }
        return appLocalized("Current Location")
    }

    private static let canonicalPrayerOrder = ["fajr", "shurooq", "dhuhr", "asr", "maghrib", "isha"]

    private static func previousPrayerTime(
        beforeActiveIndex activeIndex: Int,
        prayers: [Prayer],
        activeTime: Date,
        fallback: Date
    ) -> Date {
        guard activeIndex > 0 else { return fallback < activeTime ? fallback : activeTime.addingTimeInterval(-15 * 60) }
        let previousKey = canonicalPrayerOrder[activeIndex - 1]
        guard let previousPrayer = prayers.first(where: { canonicalKey($0.nameTransliteration) == previousKey }) else {
            return fallback < activeTime ? fallback : activeTime.addingTimeInterval(-15 * 60)
        }
        return latestOccurrence(of: previousPrayer.time, before: activeTime)
    }

    private static func latestOccurrence(of time: Date, before reference: Date) -> Date {
        var candidate = time
        while candidate >= reference {
            candidate = Calendar.current.date(byAdding: .day, value: -1, to: candidate)
                ?? candidate.addingTimeInterval(-86_400)
        }
        while let next = Calendar.current.date(byAdding: .day, value: 1, to: candidate),
              next < reference {
            candidate = next
        }
        return candidate
    }

    private static func canonicalKey(_ name: String) -> String {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "subuh", "fajr": return "fajr"
        case "syuruk", "shurooq", "sunrise": return "shurooq"
        case "zuhur", "dhuhr", "jumuah": return "dhuhr"
        case "asar", "asr": return "asr"
        case "maghrib", "magrib": return "maghrib"
        case "isyak", "isha", "isya": return "isha"
        default: return normalized
        }
    }

    private static func compactPrayerLabel(_ name: String) -> String {
        switch canonicalKey(name) {
        case "fajr": return localizedPrayerName("Fajr")
        case "shurooq": return localizedPrayerName("Shurooq")
        case "dhuhr": return localizedPrayerName("Dhuhr")
        case "asr": return localizedPrayerName("Asr")
        case "maghrib": return localizedPrayerName("Maghrib")
        case "isha": return localizedPrayerName("Isha")
        default: return localizedPrayerName(name)
        }
    }

    private static let targetTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

@available(iOSApplicationExtension 16.2, *)
private struct LiveActivityCountdownText: View {
    let prayerTime: Date
    let reachedText: String
    let countdownPrefix: String?
    let compactReachedText: String
    let isStale: Bool
    let compact: Bool

    var body: some View {
        TimelineView(.explicit([.distantPast, prayerTime])) { timeline in
            let liveNow = Date()
            if isStale || liveNow >= prayerTime {
                if compact {
                    Text(compactReachedText)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                } else {
                    HStack {
                        Text(reachedText)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                        Spacer()
                        Text(appLocalized("Tap to Dismiss"))
                            .font(.system(.caption, design: .rounded))
                            .opacity(0.55)
                    }
                }
            } else if let countdownPrefix, !compact {
                HStack(spacing: 6) {
                    Text(countdownPrefix)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text(timerInterval: liveNow...prayerTime, countsDown: true)
                        .font(.system(.title3, design: .rounded).weight(.black))
                }
            } else {
                Text(timerInterval: liveNow...prayerTime, countsDown: true)
                    .font(compact ? .system(.caption2, design: .rounded).weight(.semibold)
                                  : .system(.subheadline, design: .rounded).weight(.bold))
            }
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct LiveActivityCompactTimerText: View {
    let prayerTime: Date
    let prayerName: String
    let isStale: Bool

    private var shortPrayerLabel: String {
        let localized = localizedPrayerName(prayerName)
        return String(localized.prefix(4))
    }

    private func shortRemainingString(now: Date) -> String {
        let remaining = max(prayerTime.timeIntervalSince(now), 0)
        let minutes = Int(remaining / 60)
        let hours = minutes / 60
        if hours >= 1 {
            return "\(hours)h"
        }
        return "\(max(minutes, 1))m"
    }

    var body: some View {
        TimelineView(.explicit([.distantPast, prayerTime])) { timeline in
            let liveNow = Date()
            if isStale || liveNow >= prayerTime {
                Text(shortPrayerLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
            } else {
                Text(shortRemainingString(now: liveNow))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }
}
#endif

@main
struct Widgets: WidgetBundle {
    var body: some Widget {
        if #available(iOS 17.0, *) {
            SmallPresetOneWidget()
            SmallPresetTwoWidget()
            MediumPresetOneWidget()
            MediumPresetTwoWidget()
            MediumPresetThreeWidget()
            LargePresetOneWidget()
            LargePresetTwoWidget()
        }

        // Standalone interactive widgets stay visible in the picker.
        if #available(iOS 17.0, *) {
            TasbihCounterWidget()
        }

        #if os(iOS)
        if #available(iOS 16.1, *) {
            ProLockWidget()
            LockScreen1Widget()
            LockScreen2Widget()
            LockScreen3Widget()
            LockScreen6Widget()
            LockScreenZikirWidget()
            // LockScreen5Widget()
            LockScreenVerseWidget()
        }
        #endif
        #if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            NextPrayerLiveActivityWidget()
        }
        if #available(iOS 18.0, *) {
            NextPrayerLiveActivityWidgetWithCarPlay()
        }
        #endif
    }
}

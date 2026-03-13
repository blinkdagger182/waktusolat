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
        let offset = UserDefaults(suiteName: appGroupSuite)?.integer(forKey: "hijriOffset") ?? 0
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let date = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
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

@available(iOSApplicationExtension 16.2, *)
struct NextPrayerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerLiveActivityAttributes.self) { context in
            NextPrayerLiveActivityContentView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.prayerName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.prayerTime, style: .time)
                        .font(.system(.subheadline, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Text("Next in")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text(timerInterval: Date()...context.state.prayerTime, countsDown: true)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                    }
                }
            } compactLeading: {
                Text("WK")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.prayerTime, countsDown: true)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
            } minimal: {
                Text("WK")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
            }
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct NextPrayerLiveActivityContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    let context: ActivityViewContext<PrayerLiveActivityAttributes>

    var body: some View {
        let palette = LiveActivityTheme.palette(for: colorScheme)
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.bg)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(context.state.prayerName) · \(LiveActivityTheme.prayerTimeText(context.state.prayerTime))")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(palette.fg)
                    Spacer()
                    Text(context.state.city)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(palette.muted)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text("Next in")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(palette.fg.opacity(0.92))
                    Text(timerInterval: Date()...context.state.prayerTime, countsDown: true)
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundColor(palette.fg)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.82)

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

                HStack {
                    Text(LiveActivityTheme.hijriFooterText())
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(palette.muted)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(palette.muted)
                        Text("Waktu")
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
#endif

@main
struct Widgets: WidgetBundle {
    var body: some Widget {
        SimpleWidget()
        GraphicPrayerWidget()
        // GraphicPrayerSquareWidget() // Temporarily disabled for App Store submission
        CountdownWidget()
        Prayers2Widget()
        PrayersWidget()
        #if os(iOS)
        if #available(iOS 16.1, *) {
            LockScreen1Widget()
            LockScreen2Widget()
            LockScreen3Widget()
            LockScreen4Widget()
            LockScreenVerseWidget()
            #if canImport(ActivityKit)
            if #available(iOSApplicationExtension 16.2, *) {
                NextPrayerLiveActivityWidget()
            }
            #endif
        }
        #endif
    }
}

import SwiftUI
import WidgetKit

private struct PrayerCountdownBarWindow {
    let start: Date
    let end: Date
}

private func countdownBarPrayerWindow(for entry: PrayersProvider.Entry) -> PrayerCountdownBarWindow? {
    guard let nextPrayer = entry.nextPrayer else { return nil }

    let source = (entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers).sorted { $0.time < $1.time }
    let now = entry.date

    if let currentPrayer = entry.currentPrayer, currentPrayer.time < nextPrayer.time, currentPrayer.time <= now {
        return PrayerCountdownBarWindow(start: currentPrayer.time, end: nextPrayer.time)
    }

    if let previousPrayer = source.last(where: { $0.time < nextPrayer.time && $0.time <= now }) {
        return PrayerCountdownBarWindow(start: previousPrayer.time, end: nextPrayer.time)
    }

    let fallbackStart = min(now, nextPrayer.time.addingTimeInterval(-4 * 60 * 60))
    return PrayerCountdownBarWindow(start: fallbackStart, end: nextPrayer.time)
}

@available(iOSApplicationExtension 16.0, *)
struct LockScreen6EntryView: View {
    var entry: PrayersProvider.Entry

    private func progressValue(at now: Date, for window: PrayerCountdownBarWindow) -> Double {
        let total = max(window.end.timeIntervalSince(window.start), 1)
        let elapsed = min(max(now.timeIntervalSince(window.start), 0), total)
        return elapsed / total
    }

    private func endTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.caption)
            } else if let nextPrayer = entry.nextPrayer,
                      let window = countdownBarPrayerWindow(for: entry) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: nextPrayer.image.contains("/") ? "hourglass" : nextPrayer.image)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 14)

                        Text(widgetPrayerDisplayName(nextPrayer.nameTransliteration))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 8)

                    Text(nextPrayer.time, style: .timer)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                }

                TimelineView(.periodic(from: entry.date, by: 1)) { context in
                    ProgressView(value: progressValue(at: context.date, for: window))
                        .progressViewStyle(.linear)
                }

                Text("Ends at \(endTimeText(nextPrayer.time))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                WidgetLocationFooter(entry: entry, widgetKind: "LockScreen6Widget")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .multilineTextAlignment(.leading)
    }
}

@available(iOSApplicationExtension 16.0, *)
struct LockScreen6Widget: Widget {
    let kind: String = "LockScreen6Widget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                if #available(iOS 17.0, *) {
                    LockScreen6EntryView(entry: entry)
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    LockScreen6EntryView(entry: entry)
                }
            }
            .supportedFamilies([.accessoryRectangular])
            .configurationDisplayName("Prayer Countdown Bar")
            .description("Shows the next prayer with a live countdown bar.")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                LockScreen6EntryView(entry: entry)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Prayer Countdown Bar")
            .description("Shows the next prayer with a live countdown bar.")
        }
        #endif
    }
}

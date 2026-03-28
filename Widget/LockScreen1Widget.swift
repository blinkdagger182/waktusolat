import SwiftUI
import WidgetKit

struct LockScreen1EntryView: View {
    var entry: PrayersProvider.Entry
    @AppStorage(NextPrayerCircleStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var styleRaw = NextPrayerCircleStyle.classic.rawValue

    private var style: NextPrayerCircleStyle {
        (NextPrayerCircleStyle(rawValue: styleRaw) ?? .classic).resolvedForWidgetAccess
    }

    private func currentPrayerForRing(nextPrayer: Prayer) -> Prayer? {
        if let current = entry.currentPrayer {
            return current
        }

        let sorted = entry.prayers.sorted { $0.time < $1.time }
        guard let nextIndex = sorted.firstIndex(where: { $0.id == nextPrayer.id }) else {
            return sorted.last
        }
        let previousIndex = nextIndex > 0 ? nextIndex - 1 : sorted.count - 1
        guard sorted.indices.contains(previousIndex) else { return nil }
        return sorted[previousIndex]
    }

    private func remainingPrayerProgress(nextPrayer: Prayer) -> Double {
        let now = entry.date
        var target = nextPrayer.time
        if target <= now {
            target = target.addingTimeInterval(24 * 60 * 60)
        }
        let remaining = max(target.timeIntervalSince(now), 0)
        return min(max(remaining / (24 * 60 * 60), 0), 1)
    }

    private func prayerWindowRemainingProgress(nextPrayer: Prayer) -> Double {
        let now = entry.date
        guard let current = currentPrayerForRing(nextPrayer: nextPrayer) else {
            return 0
        }

        var start = current.time
        var end = nextPrayer.time

        if end <= start {
            end = end.addingTimeInterval(24 * 60 * 60)
        }

        var adjustedNow = now
        if adjustedNow < start {
            adjustedNow = adjustedNow.addingTimeInterval(24 * 60 * 60)
        }

        let total = max(end.timeIntervalSince(start), 1)
        let remaining = max(end.timeIntervalSince(adjustedNow), 0)
        return min(max(remaining / total, 0), 1)
    }

    private var remainingDayProgress: Double {
        let calendar = Calendar.current
        let now = entry.date
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        let total = endOfDay.timeIntervalSince(startOfDay)
        guard total > 0 else { return 0 }
        let remaining = endOfDay.timeIntervalSince(now)
        return min(max(remaining / total, 0), 1)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.caption)
            } else if let nextPrayer = entry.nextPrayer {
                switch style {
                case .classic:
                    HStack(spacing: 2) {
                        if !nextPrayer.nameTransliteration.contains("/") {
                            Image(systemName: nextPrayer.image)
                                .font(.system(size: 9, weight: .semibold))
                        }

                        Text(widgetPrayerDisplayName(nextPrayer, in: entry))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)
                            .allowsTightening(true)
                            .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Text(widgetPrayerDisplayTime(nextPrayer, in: entry), style: .time)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                case .minimal:
                    Text(widgetPrayerDisplayTime(nextPrayer, in: entry), style: .time)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(widgetPrayerDisplayName(nextPrayer, in: entry))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .allowsTightening(true)

                case .percentageRing:
                    let currentPrayer = currentPrayerForRing(nextPrayer: nextPrayer) ?? nextPrayer
                    let percentage = Int((prayerWindowRemainingProgress(nextPrayer: nextPrayer) * 100).rounded())

                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.18), lineWidth: 6)

                        Circle()
                            .trim(from: 0, to: prayerWindowRemainingProgress(nextPrayer: nextPrayer))
                            .stroke(
                                Color.primary,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 1) {
                            Text("\(percentage)%")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Image(systemName: currentPrayer.image)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(widgetIsShurooq(currentPrayer, in: entry) ? .primary : .primary)
                        }
                        .padding(.top, 2)
                    }
                    .frame(width: 54, height: 54)

                case .countdownRing:
                    let progress = remainingPrayerProgress(nextPrayer: nextPrayer)
                    let label = widgetPrayerDisplayName(currentPrayerForRing(nextPrayer: nextPrayer) ?? nextPrayer, in: entry)

                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.18), lineWidth: 6)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                Color.primary,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        Text(label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.55)
                            .padding(10)
                    }
                    .frame(width: 54, height: 54)

                case .dualCountdownRing:
                    let innerProgress = remainingPrayerProgress(nextPrayer: nextPrayer)
                    let outerProgress = remainingDayProgress
                    let label = widgetPrayerDisplayName(currentPrayerForRing(nextPrayer: nextPrayer) ?? nextPrayer, in: entry)

                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.10), lineWidth: 4)

                        Circle()
                            .trim(from: 0, to: outerProgress)
                            .stroke(
                                Color.primary.opacity(0.46),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        Circle()
                            .stroke(Color.primary.opacity(0.18), lineWidth: 6)
                            .padding(8)

                        Circle()
                            .trim(from: 0, to: innerProgress)
                            .stroke(
                                Color.primary,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .padding(8)

                        Text(label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.55)
                            .padding(16)
                    }
                    .frame(width: 58, height: 58)

                case .dualCountdownRingNextPrayer:
                    let innerProgress = remainingPrayerProgress(nextPrayer: nextPrayer)
                    let outerProgress = remainingDayProgress
                    let nextPrayerLabel = widgetPrayerDisplayName(nextPrayer, in: entry)

                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.10), lineWidth: 4)

                        Circle()
                            .trim(from: 0, to: outerProgress)
                            .stroke(
                                Color.primary.opacity(0.46),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        Circle()
                            .stroke(Color.primary.opacity(0.18), lineWidth: 6)
                            .padding(8)

                        Circle()
                            .trim(from: 0, to: innerProgress)
                            .stroke(
                                Color.primary,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .padding(8)

                        VStack(spacing: 1) {
                            Text(nextPrayerLabel)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.55)

                            Text(widgetPrayerDisplayTime(nextPrayer, in: entry), style: .time)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }
                        .padding(16)
                    }
                    .frame(width: 58, height: 58)
                }
            }
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
    }
}

struct LockScreen1Widget: Widget {
    let kind: String = "LockScreen1Widget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                if #available(iOS 17.0, *) {
                    LockScreen1EntryView(entry: entry)
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    LockScreen1EntryView(entry: entry)
                }
            }
            .supportedFamilies([.accessoryCircular])
            .configurationDisplayName("Next Prayer Circle")
            .description("Shows the next upcoming prayer in a circular Lock Screen widget")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                LockScreen1EntryView(entry: entry)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Next Prayer Circle")
            .description("Shows the next upcoming prayer in a circular Lock Screen widget")
        }
        #endif
    }
}

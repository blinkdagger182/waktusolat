import SwiftUI
import WidgetKit

// MARK: - Design tokens

private let neoBlack  = Color(red: 0.07, green: 0.07, blue: 0.08)
private let neoLime   = Color(red: 0.72, green: 0.93, blue: 0.35)
private let neoGray   = Color(red: 0.62, green: 0.62, blue: 0.65)
private let neoSubtle = Color(red: 0.38, green: 0.38, blue: 0.40)

private let neoTimeFmt: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"; return f
}()
private let neoDateFmt: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE, d MMM"; return f
}()

// MARK: - Prayer progress

private struct NeoPrayerData {
    struct Item {
        let name: String
        let short: String
        let time: Date
        let isDone: Bool
    }
    let items: [Item]
    var done: Int { items.filter(\.isDone).count }
    var total: Int { items.count }
    var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
    var nextRemaining: Item? { items.first { !$0.isDone } }

    func remainingLabel(from now: Date) -> String? {
        guard let n = nextRemaining else { return nil }
        let s = max(Int(n.time.timeIntervalSince(now)), 0)
        let h = s / 3600; let m = (s % 3600) / 60
        return h > 0 ? "~\(h)h \(m)m" : "~\(m)m"
    }

    func isOnTrack(now: Date) -> Bool {
        let passedPrayers = items.filter { $0.time < now }.count
        return done >= passedPrayers
    }
}

private func neoProgress(from entry: PrayersEntry) -> NeoPrayerData {
    let source = entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers
    let keys: [(String, String)] = [
        ("fajr", "Fajr"), ("dhuhr", "Dhuhr"), ("asr", "Asr"), ("maghrib", "Maghrib"), ("isha", "Isha")
    ]
    let items: [NeoPrayerData.Item] = keys.compactMap { key, short in
        guard let p = source.first(where: {
            let n = $0.nameTransliteration.lowercased()
            return n.contains(key)
                || (key == "dhuhr" && (n.contains("zuhur") || n.contains("jumuah")))
                || (key == "isha"  && (n.contains("isya") || n.contains("isyak")))
                || (key == "fajr"  && n.contains("subuh"))
                || (key == "maghrib" && n.contains("magrib"))
        }) else { return nil }
        return .init(name: localizedPrayerName(p.nameTransliteration),
                     short: short, time: p.time,
                     isDone: p.time < entry.date)
    }
    return NeoPrayerData(items: items)
}

// MARK: - Locked view

private struct NeoLockedView: View {
    var body: some View {
        ZStack {
            neoBlack
            VStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.title3).foregroundStyle(neoLime)
                Text("Waktu Pro")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(neoLime)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - SMALL — prose sentence
// ═══════════════════════════════════════════════════════

private struct NeoSmallView: View {
    let entry: PrayersEntry

    private var current: Prayer? { entry.currentPrayer ?? entry.prayers.first }
    private var next: Prayer?    { entry.nextPrayer }

    var body: some View {
        ZStack {
            neoBlack
            if !premiumWidgetsUnlocked() {
                NeoLockedView()
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    (Text("It's ").foregroundColor(neoGray)
                     + Text(localizedPrayerName(current?.nameTransliteration ?? "—"))
                         .foregroundColor(neoLime).fontWeight(.semibold)
                     + Text(" now").foregroundColor(neoGray))
                        .font(.system(size: 18, weight: .medium))

                    Text("in \(entry.currentCity).")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(neoGray)

                    Text(" ")
                        .font(.system(size: 6))

                    (Text("Will be ").foregroundColor(neoGray)
                     + Text(localizedPrayerName(next?.nameTransliteration ?? "—"))
                         .foregroundColor(neoLime).fontWeight(.semibold))
                        .font(.system(size: 18, weight: .medium))

                    Text("at \(next.map { neoTimeFmt.string(from: $0.time) } ?? "--:--").")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(neoGray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(18)
            }
        }
    }
}

struct NeoSmallWidget: Widget {
    let kind = "NeoSmallWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                NeoSmallView(entry: entry).containerBackground(for: .widget) { neoBlack }
            } else {
                NeoSmallView(entry: entry)
            }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Neo")
        .description("A prose sentence describing your current and next prayer.")
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - MEDIUM — departure board
// ═══════════════════════════════════════════════════════

private struct NeoMediumView: View {
    let entry: PrayersEntry

    private var current: Prayer? { entry.currentPrayer ?? entry.prayers.first }
    private var next: Prayer?    { entry.nextPrayer }

    private func countdown(to target: Date, from now: Date) -> String {
        let s = max(Int(target.timeIntervalSince(now)), 0)
        let h = s / 3600; let m = (s % 3600) / 60; let sec = s % 60
        if h > 0 { return String(format: "%02d:%02d", h, m) }
        return String(format: "%02d:%02d", m, sec)
    }

    var body: some View {
        ZStack {
            neoBlack
            if !premiumWidgetsUnlocked() {
                NeoLockedView()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Next prayer")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(neoGray)
                            Text(entry.currentCity)
                                .font(.system(size: 11))
                                .foregroundStyle(neoSubtle)
                        }
                        Spacer()
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundStyle(neoSubtle)
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

                    // Big prayer name — dot-matrix style
                    Text((current?.nameTransliteration.uppercased() ?? "------"))
                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                        .foregroundStyle(neoLime)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 16)

                    Spacer(minLength: 6)

                    // Bottom row: countdown + time
                    HStack(alignment: .bottom) {
                        Text(next.map { countdown(to: $0.time, from: entry.date) } ?? "--:--")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("TODAY")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(neoSubtle)
                            Text(next.map { neoTimeFmt.string(from: $0.time) } ?? "--:--")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(neoGray)
                            Text(next.map { neoTimeFmt.string(from: $0.time) } ?? "--:--")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(neoSubtle)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
        }
    }
}

struct NeoMediumWidget: Widget {
    let kind = "NeoMediumWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                NeoMediumView(entry: entry).containerBackground(for: .widget) { neoBlack }
            } else {
                NeoMediumView(entry: entry)
            }
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Neo Board")
        .description("Departure-board countdown to the next prayer.")
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - LARGE — prayer progress tracker
// ═══════════════════════════════════════════════════════

private struct NeoLargeView: View {
    let entry: PrayersEntry

    private var progress: NeoPrayerData { neoProgress(from: entry) }

    var body: some View {
        ZStack {
            neoBlack
            if !premiumWidgetsUnlocked() {
                NeoLockedView()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(alignment: .top) {
                        HStack(spacing: 10) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(neoLime)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Prayer Progress")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("\(progress.done) of \(progress.total) prayers completed today")
                                    .font(.system(size: 12))
                                    .foregroundStyle(neoGray)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(neoDateFmt.string(from: entry.date))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(neoGray)
                            Text("\(progress.done)/\(progress.total)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("prayers")
                                .font(.system(size: 10))
                                .foregroundStyle(neoSubtle)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 16)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(neoSubtle.opacity(0.3))
                                .frame(height: 14)
                            Capsule()
                                .fill(neoLime)
                                .frame(width: geo.size.width * progress.fraction, height: 14)
                        }
                    }
                    .frame(height: 14)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                    // Prayer checkmark row
                    HStack(spacing: 0) {
                        ForEach(progress.items, id: \.short) { item in
                            VStack(spacing: 6) {
                                Text(item.short)
                                    .font(.system(size: 12, weight: item.isDone ? .semibold : .regular))
                                    .foregroundStyle(item.isDone ? .white : neoSubtle)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(item.isDone ? neoLime : neoSubtle)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 12)

                    Spacer()

                    // Footer
                    HStack {
                        if let next = progress.nextRemaining {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundStyle(neoGray)
                                Text("\(next.name) remaining")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(neoGray)
                                Text(progress.remainingLabel(from: entry.date) ?? "")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(neoSubtle)
                            }
                        }
                        Spacer()
                        Text(progress.isOnTrack(now: entry.date) ? "On track" : "Keep going")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(neoBlack)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(neoLime)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16).padding(.top, 14)
                }
            }
        }
    }
}

struct NeoLargeWidget: Widget {
    let kind = "NeoLargeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                NeoLargeView(entry: entry).containerBackground(for: .widget) { neoBlack }
            } else {
                NeoLargeView(entry: entry)
            }
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Neo Progress")
        .description("Daily prayer progress tracker with completion status.")
    }
}

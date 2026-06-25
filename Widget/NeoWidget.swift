import SwiftUI
import WidgetKit

// MARK: - Design tokens

private let neoBlack  = Color(red: 0.07, green: 0.07, blue: 0.08)
private let neoLime   = Color(red: 0.72, green: 0.93, blue: 0.35)
private let neoGray   = Color(red: 0.62, green: 0.62, blue: 0.65)
private let neoSubtle = Color(red: 0.38, green: 0.38, blue: 0.40)
private let neoDotOff = Color(red: 0.26, green: 0.26, blue: 0.27)

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
        return "~\(widgetApproxRemainingText(until: n.time, from: now, compact: true))"
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

struct NeoSmallView: View {
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

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

struct NeoTransitSmallView: View {
    let entry: PrayersEntry

    private var next: Prayer? { entry.nextPrayer }

    var body: some View {
        ZStack {
            neoBlack
            if !premiumWidgetsUnlocked() {
                NeoLockedView()
            } else {
                GeometryReader { geo in
                    let nextName = next.map { localizedPrayerName($0.nameTransliteration) } ?? "Waktu"
                    let remaining = next.map { widgetApproxRemainingText(until: $0.time, from: entry.date, compact: true) } ?? "--"
                    let time = next.map { neoTimeFmt.string(from: $0.time) } ?? "--:--"
                    let rows = [nextName.uppercased(), remaining.uppercased(), time]
                    let dotSize = NeoDotMatrixText.dotSize(for: rows, availableWidth: geo.size.width - 20)

                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next prayer")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.94))
                                .lineLimit(1)
                            Text(entry.currentCity.isEmpty ? "Current location" : entry.currentCity)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(neoGray)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.bottom, 7)

                        VStack(alignment: .leading, spacing: 4) {
                            NeoDotMatrixText(
                                text: rows[0],
                                color: neoLime,
                                offColor: neoDotOff,
                                dotSize: dotSize
                            )
                            NeoDotMatrixText(
                                text: rows[1],
                                color: .white.opacity(0.92),
                                offColor: neoDotOff,
                                dotSize: dotSize
                            )
                            NeoDotMatrixText(
                                text: rows[2],
                                color: .white.opacity(0.92),
                                offColor: neoDotOff,
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
        .contentMarginsDisabled()
    }
}

struct NeoDotMatrixText: View {
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
        .accessibilityHidden(true)
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

private struct NeoMixedTile<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(neoSubtle.opacity(0.42), lineWidth: 1)
            }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - MEDIUM — Neo + Neo Transit mix
// ═══════════════════════════════════════════════════════

struct NeoMediumView: View {
    let entry: PrayersEntry

    var body: some View {
        ZStack {
            neoBlack
            if !premiumWidgetsUnlocked() {
                NeoLockedView()
            } else {
                HStack(spacing: 10) {
                    NeoMixedTile {
                        NeoSmallView(entry: entry)
                    }
                    NeoMixedTile {
                        NeoTransitSmallView(entry: entry)
                    }
                }
                .padding(10)
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
        .description("Neo sentence and Neo Transit next-prayer board.")
        .contentMarginsDisabled()
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - LARGE — Neo + Neo Transit mix
// ═══════════════════════════════════════════════════════

struct NeoLargeView: View {
    let entry: PrayersEntry

    var body: some View {
        ZStack {
            neoBlack
            if !premiumWidgetsUnlocked() {
                NeoLockedView()
            } else {
                VStack(spacing: 10) {
                    NeoMixedTile {
                        NeoTransitSmallView(entry: entry)
                    }
                    NeoMixedTile {
                        NeoSmallView(entry: entry)
                    }
                }
                .padding(12)
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
        .description("Large Neo mix with sentence and Neo Transit board.")
        .contentMarginsDisabled()
    }
}

struct NeoTransitLockScreenRectangularView: View {
    let entry: PrayersEntry
    var scale: CGFloat = 1

    private var next: Prayer? { widgetResolvedCurrentAndNextPrayers(in: entry).next }

    var body: some View {
        GeometryReader { geo in
            let rows = [
                neoWidgetPrayerDisplayName(next, in: entry).uppercased(),
                next.map { neoTimeFmt.string(from: $0.time) } ?? "--:--"
            ]
            let dotSize = max(1.4, NeoDotMatrixText.dotSize(for: rows, availableWidth: geo.size.width) * scale)

            VStack(alignment: .leading, spacing: scale < 1 ? 2 : 4) {
                NeoDotMatrixText(
                    text: rows[0],
                    color: neoLime,
                    offColor: Color.primary.opacity(0.18),
                    dotSize: dotSize
                )
                NeoDotMatrixText(
                    text: rows[1],
                    color: Color.primary.opacity(0.92),
                    offColor: Color.primary.opacity(0.18),
                    dotSize: dotSize
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: scale < 1 ? .center : .leading)
        }
    }
}

private func neoWidgetPrayerDisplayName(_ prayer: Prayer?, in entry: PrayersEntry) -> String {
    guard let prayer else { return "Waktu" }
    return widgetPrayerDisplayName(prayer, in: entry)
}

@available(iOS 16.0, *)
struct NeoTransitLockScreenWidget: Widget {
    let kind = "NeoTransitLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            NeoTransitLockScreenRectangularView(entry: entry)
        }
        .supportedFamilies([.accessoryRectangular])
        .configurationDisplayName("Neo Transit")
        .description("Dot-matrix style next prayer for the Lock Screen.")
        .contentMarginsDisabled()
    }
}

struct NeoTransitLockScreenSmallWidget: Widget {
    let kind = "NeoTransitLockScreenSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                NeoTransitSmallView(entry: entry).containerBackground(for: .widget) { neoBlack }
            } else {
                NeoTransitSmallView(entry: entry)
            }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Neo Transit")
        .description("Neo Transit next-prayer board for the Lock Screen.")
        .contentMarginsDisabled()
    }
}

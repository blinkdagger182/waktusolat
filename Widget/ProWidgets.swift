import SwiftUI
import WidgetKit

// MARK: - Compat

private extension View {
    @ViewBuilder func proAccentable() -> some View {
        if #available(iOS 16.0, *) {
            self.widgetAccentable()
        } else {
            self
        }
    }

    @ViewBuilder func proKerning(_ value: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            self.kerning(value)
        } else {
            self
        }
    }
}

// MARK: - Design Tokens

private let proGold      = Color(red: 201 / 255, green: 162 / 255, blue: 75 / 255)
private let proInk       = Color(red: 10 / 255,  green: 10 / 255,  blue: 11 / 255)
private let proPanel     = Color(red: 18 / 255,  green: 18 / 255,  blue: 20 / 255)
private let proTextMain  = Color(red: 242 / 255, green: 241 / 255, blue: 238 / 255)
private let proTextDim   = Color(red: 140 / 255, green: 140 / 255, blue: 146 / 255)
private let proTextFaint = Color(red: 90 / 255,  green: 90 / 255,  blue: 96 / 255)

private enum ProFont {
    static func serif(_ size: CGFloat) -> Font {
        .custom("Newsreader16pt-Regular", fixedSize: size)
    }

    static func mono(_ size: CGFloat) -> Font {
        .custom("IBMPlexMono-Regular", fixedSize: size)
    }

    static func monoMedium(_ size: CGFloat) -> Font {
        .custom("IBMPlexMono-Medium", fixedSize: size)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter-Regular", fixedSize: size).weight(weight)
    }
}

// MARK: - Shared Helpers

private struct ProLockedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(proGold)
            Text("Waktu Pro")
                .font(ProFont.monoMedium(11))
                .foregroundStyle(proGold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func proHijriLabel(for entry: PrayersEntry) -> String {
    var cal = Calendar(identifier: .islamicUmmAlQura)
    cal.locale = Locale(identifier: "en_US_POSIX")
    let source = entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers
    let ref = Settings.islamicReferenceDate(prayers: source)
    let off = Settings.effectiveHijriOffset(
        baseOffset: entry.hijriOffset,
        isMalaysia: entry.countryCode?.uppercased() == "MY"
    )
    let date = cal.date(byAdding: .day, value: off, to: ref) ?? ref
    let day  = cal.component(.day, from: date)
    let fmt  = DateFormatter()
    fmt.calendar   = cal
    fmt.locale     = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "MMMM"
    return "\(day) \(fmt.string(from: date).uppercased())"
}

// Returns (current, next) or nil if prayer data is unavailable.
private func resolvedPair(in entry: PrayersEntry) -> (current: Prayer, next: Prayer)? {
    let r = widgetResolvedCurrentAndNextPrayers(in: entry)
    guard let c = r.current, let n = r.next else { return nil }
    return (c, n)
}

// ─────────────────────────────────────────────────────────────
// MARK: - 01 · Next  (systemSmall)
// ─────────────────────────────────────────────────────────────

struct ProNextEntryView: View {
    let entry: PrayersEntry

    var body: some View {
        ZStack {
            proPanel
            if !premiumWidgetsUnlocked() {
                ProLockedView()
            } else if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.system(size: 11))
                    .foregroundStyle(proTextDim)
                    .multilineTextAlignment(.center)
                    .padding(18)
            } else if let pair = resolvedPair(in: entry) {
                nextBody(current: pair.current, next: pair.next)
            }
        }
    }

    private func nextBody(current: Prayer, next: Prayer) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(proHijriLabel(for: entry))
                    .font(ProFont.mono(10))
                    .proKerning(1.2)
                    .foregroundStyle(proTextFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Circle()
                    .fill(proGold)
                    .frame(width: 6, height: 6)
                    .shadow(color: proGold.opacity(0.7), radius: 5)
            }

            Spacer(minLength: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(widgetPrayerDisplayName(current, in: entry))
                    .font(ProFont.serif(34))
                    .proKerning(-0.68)
                    .foregroundStyle(proTextMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                HStack(spacing: 0) {
                    Text(widgetApproxRemainingText(until: widgetPrayerDisplayTime(next, in: entry), from: entry.date, compact: true))
                        .monospacedDigit()
                        .foregroundStyle(proGold)
                    Text(" left")
                        .foregroundStyle(proTextDim)
                }
                .font(ProFont.mono(13))
                .proKerning(0)

                HStack(spacing: 3) {
                    Text("Then")
                    Text(widgetPrayerDisplayName(next, in: entry))
                    Text("·")
                    Text(widgetPrayerDisplayTime(next, in: entry), style: .time)
                }
                .font(ProFont.sans(11))
                .foregroundStyle(proTextFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }
}

struct ProNextWidget: Widget {
    let kind = "ProNextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                ProNextEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                ProNextEntryView(entry: entry)
            }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Next — Pro")
        .description("Current prayer, countdown, and what follows.")
        .contentMarginsDisabled()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - 02 · Index  (systemMedium)
// ─────────────────────────────────────────────────────────────

private enum ProSlotState { case past, current, future }

struct ProIndexEntryView: View {
    let entry: PrayersEntry

    private var displayPrayers: [Prayer] {
        Array(widgetResolvedPrayers(in: entry).sorted { $0.time < $1.time }.prefix(6))
    }

    private func slotState(for prayer: Prayer, in all: [Prayer]) -> ProSlotState {
        let now = entry.date
        if prayer.time > now { return .future }
        if let recent = all.filter({ $0.time <= now }).max(by: { $0.time < $1.time }),
           recent.id == prayer.id { return .current }
        return .past
    }

    var body: some View {
        ZStack {
            proPanel
            if !premiumWidgetsUnlocked() {
                ProLockedView()
            } else if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.system(size: 11))
                    .foregroundStyle(proTextDim)
                    .multilineTextAlignment(.center)
            } else {
                indexBody
            }
        }
    }

    private var indexBody: some View {
        let prayers = displayPrayers
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(entry.currentCity)
                    .font(ProFont.sans(11))
                    .foregroundStyle(proTextFaint)
                    .lineLimit(1)
                Spacer()
                Text(proHijriLabel(for: entry))
                    .font(ProFont.mono(10))
                    .proKerning(1.0)
                    .foregroundStyle(proTextFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.bottom, 13)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 14
            ) {
                ForEach(prayers) { prayer in
                    let state = slotState(for: prayer, in: prayers)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(widgetPrayerDisplayName(prayer, in: entry))
                            .font(ProFont.sans(11))
                            .proKerning(0.44)
                            .foregroundStyle(indexLabelColor(state))
                        Text(widgetPrayerDisplayTime(prayer, in: entry), style: .time)
                            .font(ProFont.mono(17))
                            .proKerning(-0.17)
                            .monospacedDigit()
                            .foregroundStyle(indexTimeColor(state))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
    }

    private func indexLabelColor(_ state: ProSlotState) -> Color {
        switch state {
        case .past:    return proTextFaint.opacity(0.55)
        case .current: return proGold
        case .future:  return proTextFaint
        }
    }

    private func indexTimeColor(_ state: ProSlotState) -> Color {
        switch state {
        case .past:    return proTextFaint.opacity(0.55)
        case .current: return proGold
        case .future:  return proTextMain
        }
    }
}

struct ProIndexWidget: Widget {
    let kind = "ProIndexWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                ProIndexEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                ProIndexEntryView(entry: entry)
            }
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Index — Pro")
        .description("All six prayer times as a typographic table.")
        .contentMarginsDisabled()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - 03 · Arc  (systemLarge)
// ─────────────────────────────────────────────────────────────

private struct SunArcView: View {
    let progress: Double

    private let arcGold = Color(red: 201 / 255, green: 162 / 255, blue: 75 / 255)

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let p0   = CGPoint(x: w * 0.02, y: h * 0.82)
            let ctrl = CGPoint(x: w * 0.50, y: h * 0.05)
            let p2   = CGPoint(x: w * 0.98, y: h * 0.82)

            func quad(_ tt: CGFloat) -> CGPoint {
                let inv = 1 - tt
                return CGPoint(
                    x: inv * inv * p0.x + 2 * inv * tt * ctrl.x + tt * tt * p2.x,
                    y: inv * inv * p0.y + 2 * inv * tt * ctrl.y + tt * tt * p2.y
                )
            }

            // Horizon line
            var horizon = Path()
            horizon.move(to: CGPoint(x: 0, y: h * 0.82))
            horizon.addLine(to: CGPoint(x: w, y: h * 0.82))
            ctx.stroke(horizon, with: .color(.white.opacity(0.10)), lineWidth: 1)

            // Full arc (dim)
            var fullArc = Path()
            fullArc.move(to: p0)
            fullArc.addQuadCurve(to: p2, control: ctrl)
            ctx.stroke(
                fullArc,
                with: .color(.white.opacity(0.22)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )

            let t = CGFloat(max(0, min(progress, 1)))
            let cp = quad(t)

            // Elapsed arc (gold) — sampled segments
            if t > 0.001 {
                let steps = 48
                var elapsed = Path()
                for step in 0 ... steps {
                    let pt = quad(t * CGFloat(step) / CGFloat(steps))
                    step == 0 ? elapsed.move(to: pt) : elapsed.addLine(to: pt)
                }
                ctx.stroke(
                    elapsed,
                    with: .color(arcGold),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
            }

            // Outer ring
            let rR: CGFloat = 11
            ctx.stroke(
                Path(ellipseIn: CGRect(x: cp.x - rR, y: cp.y - rR, width: rR * 2, height: rR * 2)),
                with: .color(arcGold.opacity(0.35)),
                lineWidth: 1
            )

            // Filled dot
            let dR: CGFloat = 5
            ctx.fill(
                Path(ellipseIn: CGRect(x: cp.x - dR, y: cp.y - dR, width: dR * 2, height: dR * 2)),
                with: .color(arcGold)
            )
        }
    }
}

struct ProArcEntryView: View {
    let entry: PrayersEntry

    private var sortedPrayers: [Prayer] {
        let src = entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers
        return src.sorted { $0.time < $1.time }
    }

    private func findPrayer(keys: Set<String>) -> Prayer? {
        sortedPrayers.first {
            keys.contains($0.nameTransliteration.trimmingCharacters(in: .whitespaces).lowercased())
        }
    }

    private var fajrPrayer:    Prayer? { findPrayer(keys: ["subuh", "fajr"]) }
    private var maghribPrayer: Prayer? { findPrayer(keys: ["maghrib", "magrib"]) }
    private var ishaPrayer:    Prayer? { findPrayer(keys: ["isyak", "isha", "isya"]) }

    private var arcProgress: Double {
        guard let start = fajrPrayer?.time, let end = ishaPrayer?.time else { return 0.5 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0.5 }
        return max(0, min(entry.date.timeIntervalSince(start) / total, 1))
    }

    var body: some View {
        ZStack {
            proPanel
            if !premiumWidgetsUnlocked() {
                ProLockedView()
            } else if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.system(size: 11))
                    .foregroundStyle(proTextDim)
                    .multilineTextAlignment(.center)
            } else {
                arcBody
            }
        }
    }

    private var arcBody: some View {
        let pair    = resolvedPair(in: entry)
        let sunset  = maghribPrayer
        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pair.map { widgetPrayerDisplayName($0.current, in: entry) } ?? "—")
                        .font(ProFont.serif(26))
                        .proKerning(-0.26)
                        .foregroundStyle(proTextMain)
                        .lineLimit(1)

                    if let next = pair?.next {
                        HStack(spacing: 0) {
                            Text(widgetApproxRemainingText(until: widgetPrayerDisplayTime(next, in: entry), from: entry.date, compact: true))
                                .monospacedDigit()
                                .foregroundStyle(proGold)
                            Text(" remaining")
                                .foregroundStyle(proTextDim)
                        }
                        .font(ProFont.mono(13))
                    }
                }

                Spacer(minLength: 4)

                if let next = pair?.next {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Next")
                            .font(ProFont.sans(11))
                            .foregroundStyle(proTextFaint)
                        HStack(spacing: 3) {
                            Text(widgetPrayerDisplayName(next, in: entry))
                            Text(widgetPrayerDisplayTime(next, in: entry), style: .time)
                        }
                        .font(ProFont.sans(13))
                        .foregroundStyle(proTextDim)
                    }
                }
            }

            // Arc canvas
            SunArcView(progress: arcProgress)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 6)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.bottom, 12)

            // Footer
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "location.circle")
                        .font(.system(size: 10))
                    Text(entry.currentCity)
                        .lineLimit(1)
                }
                Spacer()
                if let s = sunset {
                    HStack(spacing: 3) {
                        Text("Sunset")
                        Text(s.time, style: .time)
                    }
                }
            }
            .font(ProFont.sans(11))
            .foregroundStyle(proTextFaint)
        }
        .padding(22)
    }
}

struct ProArcWidget: Widget {
    let kind = "ProArcWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                ProArcEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                ProArcEntryView(entry: entry)
            }
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Arc — Pro")
        .description("Sun arc with labelled horizon and live countdown.")
        .contentMarginsDisabled()
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - 05 · Lock  (accessoryRectangular)
// ─────────────────────────────────────────────────────────────

private struct ProLockEntryView: View {
    let entry: PrayersEntry

    var body: some View {
        if !premiumWidgetsUnlocked() {
            Label("Waktu Pro", systemImage: "lock.fill")
                .font(ProFont.mono(11))
                .proAccentable()
        } else if entry.prayers.isEmpty {
            Text("Open app")
                .font(.caption2)
        } else if let pair = resolvedPair(in: entry) {
            lockBody(current: pair.current, next: pair.next)
        }
    }

    private func lockBody(current: Prayer, next: Prayer) -> some View {
        HStack(spacing: 8) {
            Image(systemName: prayerGlyph(for: current))
                .font(.system(size: 15))
                .proAccentable()
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(widgetPrayerDisplayName(current, in: entry))
                    .font(ProFont.serif(17))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 2) {
                    Text("Then")
                    Text(widgetPrayerDisplayName(next, in: entry))
                    Text("·")
                    Text(widgetPrayerDisplayTime(next, in: entry), style: .time)
                }
                .font(ProFont.sans(10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 4)

            Text(widgetPrayerDisplayTime(next, in: entry), style: .timer) // home-widget-audit: allow-live-timer-lock-screen
                .font(ProFont.mono(18))
                .monospacedDigit()
                .proAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }

    private func prayerGlyph(for prayer: Prayer) -> String {
        switch prayer.nameTransliteration.trimmingCharacters(in: .whitespaces).lowercased() {
        case "subuh", "fajr":                return "sun.horizon"
        case "syuruk", "shurooq", "sunrise": return "sunrise"
        case "dhuhr", "zuhur", "jumuah":     return "sun.max"
        case "asar", "asr":                  return "sun.min"
        case "maghrib", "magrib":            return "sunset"
        case "isyak", "isha", "isya":        return "moon.stars"
        default:                              return "clock"
        }
    }
}

struct ProLockWidget: Widget {
    let kind = "ProLockWidget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                if #available(iOS 17.0, *) {
                    ProLockEntryView(entry: entry)
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    ProLockEntryView(entry: entry)
                }
            }
            .supportedFamilies([.accessoryRectangular])
            .configurationDisplayName("Lock — Pro")
            .description("Glanceable prayer countdown on your Lock Screen.")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                ProLockEntryView(entry: entry)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Lock — Pro")
            .description("Glanceable prayer countdown on your Lock Screen.")
        }
        #endif
    }
}

import SwiftUI
import WidgetKit

// MARK: - Design tokens

private let mtroBg    = Color(red: 0.78, green: 0.78, blue: 0.80)   // outer bezel
private let mtroBlack = Color(red: 0.08, green: 0.08, blue: 0.09)   // dark tile
private let mtroRed   = Color(red: 0.91, green: 0.17, blue: 0.17)   // red tile / accent
private let mtroLight = Color(red: 0.95, green: 0.95, blue: 0.96)   // light tile
private let mtroBlue  = Color(red: 0.17, green: 0.43, blue: 0.78)   // blue tile
private let mtroWhite = Color.white
private let tileRadius: CGFloat = 11
private let smallTileRadius: CGFloat = 24

// MARK: - Helpers

private let mtroTimeFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "HH:mm"
    return f
}()

private func mtroTime(_ d: Date) -> String { mtroTimeFmt.string(from: d) }

private func mtroCountdown(to target: Date, from now: Date) -> String {
    let s = max(Int(target.timeIntervalSince(now)), 0)
    let h = s / 3600; let m = (s % 3600) / 60; let sec = s % 60
    if h > 0 { return String(format: "%02d:%02d", h, m) }
    return String(format: "%02d:%02d", m, sec)
}

private func mtroHijriLabel(for entry: PrayersEntry) -> (day: String, month: String, year: String) {
    var cal = Calendar(identifier: .islamicUmmAlQura)
    cal.locale = Locale(identifier: "en_US_POSIX")
    let source = entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers
    let ref = Settings.islamicReferenceDate(prayers: source)
    let off = Settings.effectiveHijriOffset(baseOffset: entry.hijriOffset,
                                             isMalaysia: entry.countryCode?.uppercased() == "MY")
    let date = cal.date(byAdding: .day, value: off, to: ref) ?? ref
    let day   = "\(cal.component(.day, from: date))"
    let fmt   = DateFormatter()
    fmt.calendar = cal; fmt.locale = Locale(identifier: "en_US_POSIX"); fmt.dateFormat = "MMMM"
    let month = fmt.string(from: date)
    let year  = "\(cal.component(.year, from: date)) AH"
    return (day, month, year)
}

private func mtroSunrise(in prayers: [Prayer]) -> Prayer? {
    prayers.first { p in
        let n = p.nameTransliteration.lowercased()
        return n.contains("syuruk") || n.contains("shurooq") || n.contains("sunrise")
    }
}

private func mtroMaghrib(in prayers: [Prayer]) -> Prayer? {
    prayers.first { $0.nameTransliteration.lowercased().contains("maghrib") }
}

private let mtroDayFmt: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE d"; return f
}()
private let mtroMonthFmt: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "MMM yyyy"; return f
}()

// MARK: - Analog Clock

struct MetroClockView: View {
    let date: Date
    let style: Style

    enum Style { case dark, light, red }

    private var handColor: Color { style == .light ? .black : .white }
    private var tickColor: Color { style == .light ? Color.black.opacity(0.4) : Color.white.opacity(0.45) }
    private var accentColor: Color { style == .light ? mtroRed : mtroRed }
    private var faceColor: Color {
        switch style {
        case .dark: return Color.white.opacity(0.06)
        case .light: return Color.black.opacity(0.05)
        case .red: return Color.white.opacity(0.12)
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2; let cy = size.height / 2
            let r  = min(cx, cy) - 2
            let center = CGPoint(x: cx, y: cy)

            // Face circle
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                     with: .color(faceColor))

            // Hour ticks
            for i in 0..<12 {
                let a  = CGFloat(i) / 12 * .pi * 2 - .pi / 2
                let t0 = i % 3 == 0 ? r - 6 : r - 4
                let p1 = CGPoint(x: cx + cos(a) * t0, y: cy + sin(a) * t0)
                let p2 = CGPoint(x: cx + cos(a) * r,  y: cy + sin(a) * r)
                var path = Path(); path.move(to: p1); path.addLine(to: p2)
                ctx.stroke(path, with: .color(tickColor),
                           style: StrokeStyle(lineWidth: i % 3 == 0 ? 1.5 : 0.8, lineCap: .round))
            }

            // Hands
            let cal = Calendar.current
            let hr  = CGFloat(cal.component(.hour,   from: date) % 12)
                      + CGFloat(cal.component(.minute, from: date)) / 60
            let mn  = CGFloat(cal.component(.minute, from: date))
                      + CGFloat(cal.component(.second, from: date)) / 60

            let ha = hr / 12 * .pi * 2 - .pi / 2
            let ma = mn / 60 * .pi * 2 - .pi / 2

            func drawHand(angle: CGFloat, length: CGFloat, width: CGFloat, color: Color) {
                let tip = CGPoint(x: cx + cos(angle) * length, y: cy + sin(angle) * length)
                var p = Path(); p.move(to: center); p.addLine(to: tip)
                ctx.stroke(p, with: .color(color),
                           style: StrokeStyle(lineWidth: width, lineCap: .round))
            }

            drawHand(angle: ha, length: r * 0.52, width: 2.2, color: handColor)
            drawHand(angle: ma, length: r * 0.75, width: 1.6, color: handColor)

            // Red accent second marker (decorative, uses entry.date second)
            let sec = CGFloat(Calendar.current.component(.second, from: date))
            let sa  = sec / 60 * .pi * 2 - .pi / 2
            drawHand(angle: sa, length: r * 0.82, width: 1.0, color: accentColor)

            // Center dot
            let dotR: CGFloat = 3
            ctx.fill(Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)),
                     with: .color(handColor))
        }
    }
}

// MARK: - Shared locked overlay

private struct MetroLockedView: View {
    var body: some View {
        ZStack {
            mtroBlack
            VStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(mtroRed)
                Text("Waktu Pro")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(mtroRed)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - SMALL (systemSmall) — two stacked tiles
// ═══════════════════════════════════════════════════════

struct MetroSmallView: View {
    let entry: PrayersEntry

    private var current: Prayer? { entry.currentPrayer ?? entry.prayers.first }
    private var next:    Prayer? { entry.nextPrayer }
    private var source:  [Prayer] { entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers }

    var body: some View {
        ZStack {
            mtroBg
            if !premiumWidgetsUnlocked() {
                MetroLockedView()
            } else {
                VStack(spacing: 4) {
                    // ── Top tile (dark) ──
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.currentCity.uppercased())
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.45))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                            Text(localizedPrayerName(current?.nameTransliteration ?? "—"))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.75)
                            Text(current.map { mtroTime($0.time) } ?? "--:--")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(.leading, 10)
                        .padding(.vertical, 10)
                        Spacer(minLength: 4)
                        MetroClockView(date: entry.date, style: .dark)
                            .frame(width: 54, height: 54)
                            .padding(6)
                    }
                    .background(mtroBlack)
                    .clipShape(RoundedRectangle(cornerRadius: smallTileRadius, style: .continuous))

                    // ── Bottom tile (red) ──
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(next.map { "Next: \(localizedPrayerName($0.nameTransliteration))" } ?? "Next: —")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.75))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(next.map { mtroCountdown(to: $0.time, from: entry.date) } ?? "--:--")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text(next.map { mtroTime($0.time) } ?? "--:--")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                        .padding(.leading, 10)
                        .padding(.vertical, 10)
                        Spacer(minLength: 4)
                        MetroClockView(date: next?.time ?? entry.date, style: .red)
                            .frame(width: 54, height: 54)
                            .padding(6)
                    }
                    .background(mtroRed)
                    .clipShape(RoundedRectangle(cornerRadius: smallTileRadius, style: .continuous))
                }
                .padding(6)
            }
        }
    }
}

struct MetroSmallWidget: Widget {
    let kind = "MetroSmallWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                MetroSmallView(entry: entry)
                    .containerBackground(for: .widget) { mtroBg }
            } else {
                MetroSmallView(entry: entry)
            }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Metro Mini")
        .description("Current and next prayer in a transit-board tile layout.")
        .contentMarginsDisabled()
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - MEDIUM (systemMedium) — 2 × 2 grid
// ═══════════════════════════════════════════════════════

struct MetroMediumView: View {
    let entry: PrayersEntry

    private var current: Prayer? { entry.currentPrayer ?? entry.prayers.first }
    private var next:    Prayer? { entry.nextPrayer }
    private var source:  [Prayer] { entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers }
    private var hijri:   (day: String, month: String, year: String) { mtroHijriLabel(for: entry) }
    private var sunrise: Prayer? { mtroSunrise(in: source) }
    private var sunset:  Prayer? { mtroMaghrib(in: source) }

    var body: some View {
        ZStack {
            mtroBg
            if !premiumWidgetsUnlocked() {
                MetroLockedView()
            } else {
                HStack(spacing: 4) {
                    // ── Left column ──
                    VStack(spacing: 4) {
                        // Next prayer tile
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Next Prayer")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Text(localizedPrayerName(current?.nameTransliteration ?? "—"))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                Text(next.map { mtroCountdown(to: $0.time, from: entry.date) } ?? "--:--")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundStyle(mtroRed)
                                    .lineLimit(1)
                                Text(current.map { mtroTime($0.time) } ?? "--:--")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                            .padding(.leading, 10)
                            .padding(.vertical, 8)
                            Spacer(minLength: 2)
                            MetroClockView(date: entry.date, style: .dark)
                                .frame(width: 46, height: 46)
                                .padding(6)
                        }
                        .background(mtroBlack)
                        .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))

                        // Sunrise / Sunset tile
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sunrise.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.orange)
                                    Text(sunrise.map { mtroTime($0.time) } ?? "--:--")
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.white)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "sunset.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.orange.opacity(0.7))
                                    Text(sunset.map { mtroTime($0.time) } ?? "--:--")
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.white)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("Sunrise")
                                    .font(.system(size: 8)).foregroundStyle(Color.white.opacity(0.4))
                                Text("Sunset")
                                    .font(.system(size: 8)).foregroundStyle(Color.white.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(mtroBlack)
                        .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
                    }

                    // ── Right column ──
                    VStack(spacing: 4) {
                        // Date tile
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(mtroDayFmt.string(from: entry.date))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.black)
                                Text(hijri.month)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.black.opacity(0.55))
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                Text(hijri.day + " " + hijri.month)
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.black.opacity(0.45))
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Text(hijri.year)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(Color.black.opacity(0.4))
                            }
                            .padding(.leading, 10)
                            .padding(.vertical, 8)
                            Spacer(minLength: 2)
                            MetroClockView(date: entry.date, style: .light)
                                .frame(width: 46, height: 46)
                                .padding(6)
                        }
                        .background(mtroLight)
                        .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))

                        // Next prayer detail tile (city + times)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.currentCity)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .lineLimit(1).minimumScaleFactor(0.8)
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(localizedPrayerName(next?.nameTransliteration ?? "—"))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(mtroRed)
                                    Text(next.map { mtroTime($0.time) } ?? "--:--")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Text(next.map { mtroCountdown(to: $0.time, from: entry.date) } ?? "--:--")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundStyle(mtroRed)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(mtroBlack)
                        .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
                    }
                }
                .padding(6)
            }
        }
    }
}

struct MetroMediumWidget: Widget {
    let kind = "MetroMediumWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                MetroMediumView(entry: entry)
                    .containerBackground(for: .widget) { mtroBg }
            } else {
                MetroMediumView(entry: entry)
            }
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Metro")
        .description("Prayer countdown, date, and sun times in a transit-board tile layout.")
        .contentMarginsDisabled()
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - LARGE (systemLarge) — dashboard
// ═══════════════════════════════════════════════════════

struct MetroLargeView: View {
    let entry: PrayersEntry

    private var current: Prayer? { entry.currentPrayer ?? entry.prayers.first }
    private var next:    Prayer? { entry.nextPrayer }
    private var source:  [Prayer] { entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers }
    private var hijri:   (day: String, month: String, year: String) { mtroHijriLabel(for: entry) }
    private var sunrise: Prayer? { mtroSunrise(in: source) }
    private var sunset:  Prayer? { mtroMaghrib(in: source) }

    // Five canonical prayer columns for the middle row
    private var prayerRow: [(name: String, time: String, isCurrent: Bool)] {
        let canonical = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
        return canonical.compactMap { key in
            guard let p = source.first(where: {
                let n = $0.nameTransliteration.lowercased()
                return n.contains(key) || (key == "dhuhr" && (n.contains("zuhur") || n.contains("jumuah")))
                       || (key == "isha" && (n.contains("isya") || n.contains("isyak")))
                       || (key == "fajr" && n.contains("subuh"))
                       || (key == "maghrib" && n.contains("magrib"))
            }) else { return nil }
            let isCurrent = p.nameTransliteration.lowercased() == (current?.nameTransliteration.lowercased() ?? "")
            return (name: localizedPrayerName(p.nameTransliteration), time: mtroTime(p.time), isCurrent: isCurrent)
        }
    }

    // Day progress 0..1
    private var dayProgress: Double {
        let cal = Calendar.current
        let start = cal.startOfDay(for: entry.date)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        return min(max(entry.date.timeIntervalSince(start) / end.timeIntervalSince(start), 0), 1)
    }

    var body: some View {
        ZStack {
            mtroBg
            if !premiumWidgetsUnlocked() {
                MetroLockedView()
            } else {
                VStack(spacing: 4) {
                    // ── Row 1: main + date ──
                    HStack(spacing: 4) {
                        // Next prayer tile
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Next Prayer")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Text(localizedPrayerName(current?.nameTransliteration ?? "—"))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                Text(next.map { mtroCountdown(to: $0.time, from: entry.date) } ?? "--:--")
                                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                                    .foregroundStyle(mtroRed)
                                    .lineLimit(1)
                                Text(current.map { mtroTime($0.time) } ?? "--:--")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.65))
                            }
                            .padding(.leading, 12)
                            .padding(.vertical, 10)
                            Spacer(minLength: 4)
                            MetroClockView(date: entry.date, style: .dark)
                                .frame(width: 58, height: 58)
                                .padding(8)
                        }
                        .background(mtroBlack)
                        .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))

                        // Date tile
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(mtroDayFmt.string(from: entry.date))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.black)
                                    Text(mtroMonthFmt.string(from: entry.date))
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.black.opacity(0.55))
                                }
                                Spacer()
                                ZStack {
                                    Circle()
                                        .stroke(Color.black.opacity(0.12), lineWidth: 3)
                                    Circle()
                                        .trim(from: 0, to: dayProgress)
                                        .stroke(mtroRed, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                    Text("\(Int(dayProgress * 100))%")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.black)
                                }
                                .frame(width: 32, height: 32)
                            }
                            Spacer(minLength: 0)
                            Text(hijri.day + " " + hijri.month)
                                .font(.system(size: 9))
                                .foregroundStyle(Color.black.opacity(0.5))
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Text(hijri.year)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.black.opacity(0.4))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(mtroLight)
                        .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
                    }

                    // ── Row 2: prayer strip ──
                    HStack(spacing: 0) {
                        ForEach(Array(prayerRow.enumerated()), id: \.offset) { idx, p in
                            VStack(spacing: 2) {
                                Text(p.name)
                                    .font(.system(size: 9, weight: p.isCurrent ? .bold : .regular))
                                    .foregroundStyle(p.isCurrent ? .white : Color.white.opacity(0.5))
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Text(p.time)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(p.isCurrent ? mtroRed : Color.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(p.isCurrent ? Color.white.opacity(0.07) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            if idx < prayerRow.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 1)
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .background(mtroBlack)
                    .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))

                    // ── Row 3: bottom tiles ──
                    HStack(spacing: 4) {
                        // Sunrise / Sunset
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 5) {
                                Image(systemName: "sunrise.fill")
                                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.9))
                                Text(sunrise.map { mtroTime($0.time) } ?? "--:--")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                            HStack(spacing: 5) {
                                Image(systemName: "sunset.fill")
                                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                                Text(sunset.map { mtroTime($0.time) } ?? "--:--")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                            Text(entry.currentCity)
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(mtroBlue)
                        .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))

                        // Next prayer detail
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.45))
                            Text(localizedPrayerName(next?.nameTransliteration ?? "—"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Text(next.map { mtroTime($0.time) } ?? "--:--")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.65))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(mtroBlack)
                        .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))

                        // Countdown accent tile
                        VStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Text(next.map { mtroCountdown(to: $0.time, from: entry.date) } ?? "--")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text("away")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: 72)
                        .background(mtroRed)
                        .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
                    }
                }
                .padding(6)
            }
        }
    }
}

struct MetroLargeWidget: Widget {
    let kind = "MetroLargeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                MetroLargeView(entry: entry)
                    .containerBackground(for: .widget) { mtroBg }
            } else {
                MetroLargeView(entry: entry)
            }
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Metro Max")
        .description("Full prayer dashboard with countdown, prayer strip, and sun times.")
        .contentMarginsDisabled()
    }
}

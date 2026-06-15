import SwiftUI
import WidgetKit

private enum MinimalistPrayerTheme {
    case subuh
    case dhuhr
    case asr
    case maghrib
    case isha
    case fallback

    init(prayerName: String) {
        let key = prayerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "subuh", "fajr":
            self = .subuh
        case "zuhur", "dhuhr", "jumuah":
            self = .dhuhr
        case "asar", "asr":
            self = .asr
        case "maghrib", "magrib":
            self = .maghrib
        case "isyak", "isha", "isya":
            self = .isha
        default:
            self = .fallback
        }
    }

    var title: String {
        switch self {
        case .subuh: return localizedPrayerName("Fajr")
        case .dhuhr: return localizedPrayerName("Dhuhr")
        case .asr: return localizedPrayerName("Asr")
        case .maghrib: return localizedPrayerName("Maghrib")
        case .isha: return localizedPrayerName("Isha")
        case .fallback: return appLocalized("Waktu")
        }
    }

    var primarySymbol: String {
        switch self {
        case .subuh, .dhuhr, .asr: return "sun.max"
        case .maghrib: return "sunset"
        case .isha: return "moon.fill"
        case .fallback: return "sun.max"
        }
    }

    var secondarySymbol: String {
        switch self {
        case .isha, .maghrib: return "moon.fill"
        default: return "sun.max"
        }
    }

    var usesDarkInk: Bool {
        switch self {
        case .isha:
            return false
        default:
            return true
        }
    }

    var nextTileUsesDarkInk: Bool { false } // bottom tile is always dark charcoal → white text

    // Flat light gray for all daytime prayers; soft blue for Maghrib; dark for Isha
    static let flatGray  = Color(red: 0.902, green: 0.902, blue: 0.918)   // #E6E6EA
    static let flatBlue  = Color(red: 0.647, green: 0.773, blue: 0.882)   // #A5C5E1
    static let flatDark  = Color(red: 0.157, green: 0.176, blue: 0.208)   // #282D35

    var background: LinearGradient {
        switch self {
        case .maghrib:
            return LinearGradient(colors: [Self.flatBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .isha:
            return LinearGradient(colors: [Self.flatDark], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Self.flatGray], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var topTileBackground: LinearGradient {
        LinearGradient(colors: [Self.flatBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var bottomTileBackground: LinearGradient {
        LinearGradient(colors: [Self.flatDark], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct MinimalistWaktuEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: PrayersEntry

    private var resolved: (current: Prayer?, next: Prayer?) {
        widgetResolvedCurrentAndNextPrayers(in: entry, at: entry.date)
    }

    private var displayPrayer: Prayer? {
        resolved.current ?? resolved.next
    }

    private var nextPrayer: Prayer? {
        resolved.next
    }

    private var theme: MinimalistPrayerTheme {
        MinimalistPrayerTheme(prayerName: displayPrayer?.nameTransliteration ?? nextPrayer?.nameTransliteration ?? "")
    }

    private var foreground: Color {
        theme.usesDarkInk ? .black : .white
    }

    var body: some View {
        Group {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                switch widgetFamily {
                case .systemMedium:
                    mediumBody
                default:
                    smallBody
                }
            }
        }
        .minimumScaleFactor(0.72)
    }

    private var smallBody: some View {
        ZStack {
            theme.background

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(foreground.opacity(0.88), lineWidth: 3)
                .padding(3)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    MinimalistPrayerIcon(theme: theme, color: foreground, size: 34)
                    Spacer(minLength: 8)
                    Text(displayPrayer.map { widgetPrayerDisplayName($0, in: entry) } ?? theme.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Spacer(minLength: 8)

                if let prayer = displayPrayer {
                    Text(widgetPrayerDisplayTime(prayer, in: entry), style: .time)
                        .font(.system(size: 40, weight: .regular, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }

                Text(weekdayText)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .padding(.top, 2)

                Text(entry.currentCity.isEmpty ? appLocalized("Current Location") : entry.currentCity)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(foreground.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .padding(.top, 4)
            }
            .padding(15)
        }
    }

    private var mediumBody: some View {
        ZStack {
            MinimalistPrayerTheme.flatGray

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.black, lineWidth: 3)
                .padding(2)

            HStack(spacing: 8) {
                mainMediumTile
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 8) {
                    if let current = displayPrayer {
                        infoTile(
                            background: theme.topTileBackground,
                            icon: theme.primarySymbol,
                            time: widgetPrayerDisplayTime(current, in: entry),
                            foreground: .black,
                            label: nil
                        )
                    }

                    if let next = nextPrayer {
                        infoTile(
                            background: theme.bottomTileBackground,
                            icon: nil,
                            time: widgetPrayerDisplayTime(next, in: entry),
                            foreground: theme.nextTileUsesDarkInk ? .black : .white,
                            label: appLocalized("Next")
                        )
                    }
                }
                .frame(width: 130)
            }
            .padding(9)
        }
    }

    private var mainMediumTile: some View {
        ZStack {
            theme.background

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(foreground.opacity(0.95), lineWidth: 2.5)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    MinimalistPrayerIcon(theme: theme, color: foreground, size: 36)
                    Spacer(minLength: 10)
                    Text(displayPrayer.map { widgetPrayerDisplayName($0, in: entry) } ?? theme.title)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                }

                Spacer(minLength: 8)

                Text(weekdayText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(foreground)
                    .lineLimit(1)

                Text(entry.currentCity.isEmpty ? appLocalized("Current Location") : entry.currentCity)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(foreground.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.top, 5)
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func infoTile(
        background: LinearGradient,
        icon: String?,
        time: Date,
        foreground: Color,
        label: String?
    ) -> some View {
        ZStack {
            background

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.95), lineWidth: 2.5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 30, weight: .semibold))
                    }

                    Text(time, style: .time)
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

    private var weekdayText: String {
        let formatter = DateFormatter()
        formatter.locale = appLocale()
        formatter.dateFormat = "EEE"
        return formatter.string(from: entry.date)
    }
}

private struct MinimalistPrayerIcon: View {
    let theme: MinimalistPrayerTheme
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Image(systemName: theme.primarySymbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color)

            if theme == .subuh || theme == .asr {
                Image(systemName: theme == .subuh ? "arrow.up" : "arrow.down")
                    .font(.system(size: size * 0.58, weight: .bold))
                    .foregroundStyle(color)
                    .offset(y: -size * 0.68)
            }
        }
        .frame(width: size * 1.35, height: size * 1.35)
    }
}

struct MinimalistWaktuWidget: Widget {
    let kind: String = "MinimalistWaktuWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                MinimalistWaktuEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                MinimalistWaktuEntryView(entry: entry)
                    .padding(0)
            }
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Waktu Minimalist")
        .description("Minimalist prayer time widgets with per-prayer colors.")
        .contentMarginsDisabled()
    }
}

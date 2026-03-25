import SwiftUI
import WidgetKit

private struct ZikirEntry: TimelineEntry {
    let date: Date
    let title: String
    let message: String
    let footnote: String
}

private struct ZikirSegment {
    let hourRange: ClosedRange<Int>
    let titleEN: String
    let titleMS: String
    let messageEN: String
    let messageMS: String
    let footnoteEN: String
    let footnoteMS: String
}

private struct ZikirProvider: TimelineProvider {
    private let calendar = Calendar(identifier: .gregorian)

    private let segments: [ZikirSegment] = [
        .init(
            hourRange: 5...10,
            titleEN: "Morning Zikir",
            titleMS: "Zikir Pagi",
            messageEN: "Begin the morning with istighfar and selawat.",
            messageMS: "Mulakan pagi dengan istighfar dan selawat.",
            footnoteEN: "After Fajr",
            footnoteMS: "Selepas Subuh"
        ),
        .init(
            hourRange: 11...15,
            titleEN: "Midday Reminder",
            titleMS: "Zikir Tengah Hari",
            messageEN: "Pause for tasbih, tahmid, and a short selawat.",
            messageMS: "Berhenti seketika untuk tasbih, tahmid, dan selawat ringkas.",
            footnoteEN: "Before and after Dhuhr",
            footnoteMS: "Sebelum dan selepas Zuhur"
        ),
        .init(
            hourRange: 16...18,
            titleEN: "Afternoon Selawat",
            titleMS: "Selawat Petang",
            messageEN: "Keep the tongue moist with istighfar before Maghrib.",
            messageMS: "Basahkan lidah dengan istighfar sebelum Maghrib.",
            footnoteEN: "Asr to sunset",
            footnoteMS: "Asar hingga matahari terbenam"
        ),
        .init(
            hourRange: 19...23,
            titleEN: "Night Reflection",
            titleMS: "Zikir Malam",
            messageEN: "Close the day with selawat and gratitude.",
            messageMS: "Akhiri hari dengan selawat dan kesyukuran.",
            footnoteEN: "After Maghrib and Isha",
            footnoteMS: "Selepas Maghrib dan Isyak"
        ),
        .init(
            hourRange: 0...4,
            titleEN: "Quiet Reminder",
            titleMS: "Peringatan Tenang",
            messageEN: "Keep a gentle dhikr before rest or qiyam.",
            messageMS: "Teruskan zikir ringkas sebelum berehat atau qiyam.",
            footnoteEN: "Night hours",
            footnoteMS: "Waktu malam"
        )
    ]

    func placeholder(in context: Context) -> ZikirEntry {
        entry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (ZikirEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZikirEntry>) -> Void) {
        let now = Date()
        let currentEntry = entry(for: now)

        let nextRefresh: Date
        if let nextHour = calendar.date(byAdding: .hour, value: 1, to: now),
           let topOfHour = calendar.dateInterval(of: .hour, for: nextHour)?.start {
            nextRefresh = topOfHour
        } else {
            nextRefresh = now.addingTimeInterval(3600)
        }

        completion(Timeline(entries: [currentEntry], policy: .after(nextRefresh)))
    }

    private func entry(for date: Date) -> ZikirEntry {
        let hour = calendar.component(.hour, from: date)
        let segment = segments.first(where: { $0.hourRange.contains(hour) }) ?? segments[0]
        let isMalay = isMalayAppLanguage()
        return ZikirEntry(
            date: date,
            title: isMalay ? segment.titleMS : segment.titleEN,
            message: isMalay ? segment.messageMS : segment.messageEN,
            footnote: isMalay ? segment.footnoteMS : segment.footnoteEN
        )
    }
}

private struct ZikirEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ZikirEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(entry.message)
                    .font(.caption2)
                    .lineLimit(2)
                Text(entry.footnote)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(entry.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                Spacer(minLength: 0)
                Text(entry.footnote)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct ZikirWidget: Widget {
    let kind: String = "ZikirWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZikirProvider()) { entry in
            if #available(iOS 17.0, *) {
                ZikirEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                ZikirEntryView(entry: entry)
                    .padding()
            }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Zikir & Selawat")
        .description("Short zikir and selawat reminders that change throughout the day.")
    }
}

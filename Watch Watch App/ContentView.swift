import SwiftUI

private struct WatchPrayerListSection: View {
    let prayers: [WatchPrayer]
    let nextPrayerID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(prayers.enumerated()), id: \.element.id) { _, prayer in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(prayer.displayName)
                            .font(.subheadline.weight(prayer.id == nextPrayerID ? .semibold : .regular))
                        Text(prayer.time, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if prayer.id == nextPrayerID {
                        Image(systemName: "arrow.forward.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ContentView: View {
    @State private var store = WatchPrayerStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                nextPrayerCard
                prayerList()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .task {
            store.reload()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            store.reload()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Waktu")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(store.displayLocation)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var nextPrayerCard: some View {
        if let nextPrayer = store.nextPrayer {
            VStack(alignment: .leading, spacing: 6) {
                Text("Next Prayer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(nextPrayer.displayName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(nextPrayer.time, style: .timer)
                        .font(.headline.monospacedDigit())
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(nextPrayer.time, style: .time)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
            )
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Open the iPhone app")
                    .font(.headline)
                Text("Refresh prayer times on iPhone first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func prayerList() -> some View {
        WatchPrayerListSection(
            prayers: Array(store.todayPrayers),
            nextPrayerID: store.nextPrayer?.id
        )
    }
}

#Preview {
    ContentView()
}

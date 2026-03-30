import SwiftUI

struct WatchAzanView: View {
    @EnvironmentObject private var store: WatchPrayerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerCard
                timelineCard
                prayerList
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .navigationTitle("Waktu")
        .task {
            store.reload()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.city)
                .font(.headline)
                .lineLimit(2)

            Text(store.sourceLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var timelineCard: some View {
        if store.prayers.isEmpty {
            Text(store.emptyStateMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                let currentPrayer = store.currentPrayer(now: now)
                let nextPrayer = store.nextPrayer(now: now)
                let currentInfo = currentPrayer.map { store.displayInfo(for: $0, now: now) }
                let nextInfo = nextPrayer.map { store.displayInfo(for: $0, now: now) }

                VStack(alignment: .leading, spacing: 8) {
                    if let nextInfo, let nextPrayer {
                        Text(store.language.isMalay ? "Seterusnya" : "Next")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline) {
                            Text(WatchPrayerPresentation.displayedName(for: nextPrayer, language: store.language))
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(store.accentColor.color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                            Spacer(minLength: 8)
                            Text(nextInfo.time, style: .time)
                                .font(.headline.monospacedDigit())
                        }

                        Text(nextInfo.time, style: .timer)
                            .font(.system(.body, design: .rounded).monospacedDigit().weight(.semibold))
                    }

                    if let currentInfo {
                        Divider()
                        Text(store.language.isMalay ? "Sekarang: \(currentInfo.nameTransliteration)" : "Now: \(currentInfo.nameTransliteration)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var prayerList: some View {
        VStack(spacing: 8) {
            ForEach(store.prayers) { prayer in
                WatchPrayerRow(prayer: prayer)
                    .environmentObject(store)
            }
        }
    }
}

private struct WatchPrayerRow: View {
    @EnvironmentObject private var store: WatchPrayerStore
    let prayer: WatchPrayer

    var body: some View {
        let info = store.displayInfo(for: prayer)
        let helpers = store.shurooqHelpersByPrayerID[prayer.id]

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: prayer.image)
                    .font(.headline)
                    .foregroundStyle(info.isDerivedDhuha ? .primary : store.accentColor.color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(WatchPrayerPresentation.displayedName(for: prayer, language: store.language))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    Text(info.time, style: .time)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(info.nameArabic)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if let helpers {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Ishraq: \(helpers.ishraq.formatted(date: .omitted, time: .shortened))")
                    if !info.isDerivedDhuha {
                        Text("Dhuha: \(helpers.dhuha.formatted(date: .omitted, time: .shortened))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    WatchAzanView()
        .environmentObject(WatchPrayerStore())
}

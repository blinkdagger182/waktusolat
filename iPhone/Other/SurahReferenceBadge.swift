import SwiftUI

struct SurahReferenceBadge: View {
    let title: String
    let reference: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Text(reference)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.white.opacity(0.52))
        )
    }
}

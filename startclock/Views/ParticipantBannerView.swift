import SwiftUI

struct ParticipantBannerView: View {
    let previous: [StartEntry]   // last interval — dimmed
    let current:  [StartEntry]   // this interval — full brightness
    let next:     [StartEntry]   // next interval — slightly dimmed
    let showSeconds: Bool        // decided per start list, not per entry

    @EnvironmentObject var settings: AppSettings

    private var textColor: Color { settings.invertedMode ? .black : .white }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Previous ──────────────────────────────────────────────
            if !previous.isEmpty {
                rows(Array(previous.suffix(3)), dim: 0.38)
                separator
            }

            // ── Current ───────────────────────────────────────────────
            rows(Array(current.prefix(6)), dim: 1.0)

            // ── Next ──────────────────────────────────────────────────
            if !next.isEmpty {
                separator
                rows(Array(next.prefix(3)), dim: 0.55)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.yellow.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func rows(_ entries: [StartEntry], dim: Double) -> some View {
        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
            HStack(spacing: 0) {
                Text(entry.startTimeString(showSeconds: showSeconds))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .frame(width: showSeconds ? 80 : 58, alignment: .leading)

                Text(entry.name.uppercased())
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !entry.className.isEmpty {
                    Text(entry.className)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 90, alignment: .trailing)
                }
            }
            .padding(.vertical, 2)
            .opacity(dim)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(height: 0.5)
            .padding(.vertical, 4)
    }
}

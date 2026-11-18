import SwiftUI

struct ParticipantBannerView: View {
    let departed: [StartEntry]      // already running — fading out
    let departedOpacity: Double
    let current:  [StartEntry]      // the group in focus
    let next:     [StartEntry]      // the one after that
    let showSeconds: Bool
    /// Multiplier from Settings — the start crew reads this from a few metres away.
    let scale: Double

    @EnvironmentObject var settings: AppSettings

    private var textColor: Color { settings.invertedMode ? .black : .white }

    private var nameSize:   CGFloat { 15 * scale }
    private var classSize:  CGFloat { 13 * scale }
    private var timeWidth:  CGFloat { (showSeconds ? 80 : 58) * scale }
    private var classWidth: CGFloat { 90 * scale }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Already gone ──────────────────────────────────────────
            if !departed.isEmpty {
                rows(Array(departed.suffix(3)), dim: departedOpacity)
                separator
            }

            // ── In focus ──────────────────────────────────────────────
            rows(Array(current.prefix(6)), dim: 1.0)

            // ── After that ────────────────────────────────────────────
            if !next.isEmpty {
                separator
                rows(Array(next.prefix(3)), dim: 0.55)
            }
        }
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 10 * scale)
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
                    .font(.system(size: nameSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .frame(width: timeWidth, alignment: .leading)

                Text(entry.name.uppercased())
                    .font(.system(size: nameSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !entry.className.isEmpty {
                    Text(entry.className)
                        .font(.system(size: classSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: classWidth, alignment: .trailing)
                }
            }
            .padding(.vertical, 2 * scale)
            .opacity(dim)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(height: 0.5)
            .padding(.vertical, 4 * scale)
    }
}

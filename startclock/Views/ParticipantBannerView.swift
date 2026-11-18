import SwiftUI

struct ParticipantBannerView: View {
    let departed: [StartEntry]      // already running — fading out
    let departedOpacity: Double
    let current:  [StartEntry]      // the group in focus
    let next:     [StartEntry]      // the one after that
    let showSeconds: Bool
    /// Multiplier from Settings — the start crew reads this from a few metres away.
    let scale: Double
    /// Height the banner may take without starving the clock.
    let maxHeight: CGFloat

    @EnvironmentObject var settings: AppSettings

    private var textColor: Color { settings.invertedMode ? .black : .white }

    private var rowHeight:  CGFloat { nameSize * 1.3 + 4 * scale }
    /// Padding, the two separators and the "+N more" line — everything that is
    /// not a row. Reserved whether or not that line shows, so a mis-estimate
    /// leaves the banner too short rather than over the clock.
    private var chromeHeight: CGFloat { 36 * scale + 1 + classSize * 1.3 + 2 * scale }

    private var allocation: StartSchedule.RowAllocation {
        let fits = Int((maxHeight - chromeHeight) / max(rowHeight, 1))
        return StartSchedule.rowAllocation(
            fitting: fits,
            departed: departed.count,
            current: current.count,
            next: next.count
        )
    }

    private var nameSize:   CGFloat { 15 * scale }
    private var classSize:  CGFloat { 13 * scale }
    private var timeWidth:  CGFloat { (showSeconds ? 80 : 58) * scale }
    private var classWidth: CGFloat { 90 * scale }

    var body: some View {
        let shown = allocation

        VStack(alignment: .leading, spacing: 0) {

            // ── Already gone ──────────────────────────────────────────
            if shown.departed > 0 {
                rows(Array(departed.suffix(shown.departed)), dim: departedOpacity)
                separator
            }

            // ── In focus ──────────────────────────────────────────────
            rows(Array(current.prefix(shown.current)), dim: 1.0)

            if shown.hiddenCurrent > 0 {
                Text("+\(shown.hiddenCurrent) more")
                    .font(.system(size: classSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2 * scale)
            }

            // ── After that ────────────────────────────────────────────
            if shown.next > 0 {
                separator
                rows(Array(next.prefix(shown.next)), dim: 0.55)
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

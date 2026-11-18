import SwiftUI

struct ParticipantBannerView: View {
    let departed: [StartEntry]      // already running — fading out
    let departedOpacity: Double
    let current:  [StartEntry]      // the group in focus
    let next:     [StartEntry]      // the one after that
    let showSeconds: Bool
    /// Multiplier from Settings — the start crew reads this from a few metres
    /// away. The banner may go below it, but never above.
    let scale: Double
    let maxHeight: CGFloat
    let availableWidth: CGFloat

    @EnvironmentObject var settings: AppSettings

    private var fit: StartSchedule.BannerFit {
        StartSchedule.fit(
            currentCount: current.count,
            requestedScale: scale,
            availableHeight: Double(maxHeight),
            availableWidth: Double(availableWidth)
        )
    }

    var body: some View {
        let fit = self.fit

        VStack(alignment: .leading, spacing: 0) {
            if fit.showsContext {
                withContext(fit)
            } else {
                // A whole minute's worth of runners — they get the banner.
                columns(fit)
                if fit.hidden > 0 {
                    Text("+\(fit.hidden) more")
                        .font(.system(size: classSize(fit.scale), weight: .semibold, design: .monospaced))
                        .foregroundStyle(settings.secondaryTextColor)
                        .padding(.top, 2 * fit.scale)
                }
            }
        }
        .padding(.horizontal, 14 * fit.scale)
        .padding(.vertical, 10 * fit.scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        // A material background washes the text out; a solid panel keeps every
        // row at full contrast against the screen behind it.
        .background(settings.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(settings.panelBorder, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Layouts

    @ViewBuilder
    private func withContext(_ fit: StartSchedule.BannerFit) -> some View {
        // The starting group is already known to fit; the groups around it take
        // what is left, shortest-lived first.
        let shown = StartSchedule.rowAllocation(
            fitting: StartSchedule.rowsThatFit(height: Double(maxHeight), scale: fit.scale),
            departed: departed.count,
            current: current.count,
            next: next.count
        )

        if shown.departed > 0 {
            rows(Array(departed.suffix(shown.departed)), dim: departedOpacity, scale: fit.scale)
            separator(fit.scale)
        }

        rows(Array(current.prefix(shown.current)), dim: 1.0, scale: fit.scale)

        if shown.next > 0 {
            separator(fit.scale)
            rows(Array(next.prefix(shown.next)), dim: 0.78, scale: fit.scale)
        }
    }

    @ViewBuilder
    private func columns(_ fit: StartSchedule.BannerFit) -> some View {
        let shown = Array(current.prefix(fit.rowsPerColumn * fit.columns))
        let chunks = stride(from: 0, to: shown.count, by: max(fit.rowsPerColumn, 1)).map {
            Array(shown[$0 ..< min($0 + fit.rowsPerColumn, shown.count)])
        }

        HStack(alignment: .top, spacing: 18 * fit.scale) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                VStack(alignment: .leading, spacing: 0) {
                    rows(chunk, dim: 1.0, scale: fit.scale)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Rows

    private func nameSize(_ scale: Double) -> CGFloat  { 15 * scale }
    private func classSize(_ scale: Double) -> CGFloat { 13 * scale }

    @ViewBuilder
    private func rows(_ entries: [StartEntry], dim: Double, scale: Double) -> some View {
        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
            HStack(spacing: 0) {
                Text(entry.startTimeString(showSeconds: showSeconds))
                    .font(.system(size: nameSize(scale), weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.highlightColor)
                    .frame(width: (showSeconds ? 80 : 58) * scale, alignment: .leading)

                Text(entry.name.uppercased())
                    .font(.system(size: nameSize(scale), weight: .semibold, design: .monospaced))
                    .foregroundStyle(settings.primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !entry.className.isEmpty {
                    Text(entry.className)
                        .font(.system(size: classSize(scale), weight: .semibold, design: .monospaced))
                        .foregroundStyle(settings.secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 90 * scale, alignment: .trailing)
                }
            }
            .padding(.vertical, 2 * scale)
            .opacity(dim)
        }
    }

    private func separator(_ scale: Double) -> some View {
        Rectangle()
            .fill(settings.separatorColor)
            .frame(height: 0.5)
            .padding(.vertical, 4 * scale)
    }
}

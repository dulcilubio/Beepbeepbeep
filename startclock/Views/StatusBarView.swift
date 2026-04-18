import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var gnss: GNSSTimeManager

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(sourceLabel)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(statusColor)
                if gnss.syncStatus == .driftWarning {
                    Text("DRIFT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if settings.gaFramTidEnabled && settings.gaFramTidOffsetMin > 0 {
                Text("+\(settings.gaFramTidOffsetMin) min")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.yellow)
            }
        }
    }

    private var sourceLabel: String {
        switch gnss.syncStatus {
        case .acquiring:
            return "ACQUIRING…"
        default:
            switch gnss.timeSource {
            case .gnss:   return "GNSS"
            case .ntp:    return "NTP"
            case .device: return "DEVICE"
            }
        }
    }

    private var statusColor: Color {
        switch gnss.syncStatus {
        case .acquiring:    return .yellow
        case .synced:       return .green
        case .driftWarning: return .orange
        case .unavailable:  return .red
        }
    }
}

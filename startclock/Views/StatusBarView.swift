import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var gnss: GNSSTimeManager
    @EnvironmentObject var liveresultat: LiveResultatManager
    @EnvironmentObject var eventor: EventorManager

    /// True when beeps are enabled but the audio session is not playing —
    /// typically during a call, or just after one.
    var audioAlert: Bool = false

    var body: some View {
        ZStack {
            // Left / right elements
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
                    if settings.fakeTimeEnabled {
                        Text("TEST")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.purple)
                    }
                    if gnss.hasLargeCorrection {
                        // The clock has been shifted away from device time by
                        // more than a second — say so, and by how much.
                        Text(correctionLabel)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    if audioAlert {
                        Text("NO AUDIO")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                }

                Spacer()

                if settings.gaFramTidEnabled && settings.gaFramTidOffsetMin > 0 {
                    Text("+\(settings.gaFramTidOffsetMin) min")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.yellow)
                }
            }

            // Competition / class name — centered, won't shift left/right elements
            if let centerText = centerLabel {
                Text(centerText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 80) // keep clear of left/right items
            }
        }
    }

    private var correctionLabel: String {
        String(format: "%+.1f s", gnss.appliedOffset)
    }

    private var centerLabel: String? {
        if liveresultat.hasActiveCompetition {
            guard !liveresultat.savedClassNames.isEmpty else { return liveresultat.savedCompName }
            return "\(liveresultat.savedCompName) · \(liveresultat.classFilterLabel)"
        }
        if eventor.hasActiveList, let name = eventor.importedList?.name {
            guard !eventor.classFilters.isEmpty else { return name }
            return "\(name) · \(eventor.classFilterLabel)"
        }
        return nil
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

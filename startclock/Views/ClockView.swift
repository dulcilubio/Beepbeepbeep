import SwiftUI
import UIKit

struct ClockView: View {
    @EnvironmentObject var settings: AppSettings
    let date: Date

    private var components: (h: Int, m: Int, s: Int) {
        let cal = Calendar.current
        return (
            cal.component(.hour,   from: date),
            cal.component(.minute, from: date),
            cal.component(.second, from: date)
        )
    }

    private var clockColor: Color {
        let pos = components.s % settings.startInterval
        if pos == 0 {
            return .green
        } else if settings.startInterval - pos <= 5 {
            return .orange
        } else {
            return settings.invertedMode ? .black : .white
        }
    }

    private func resolvedFont(size: CGFloat) -> Font {
        let uiWeight: UIFont.Weight     = settings.clockBold ? .bold    : .regular
        let swiftWeight: Font.Weight    = settings.clockBold ? .bold    : .regular

        switch settings.clockFont {
        case "sfpro":
            return .system(size: size, weight: swiftWeight, design: .default)
        case "sfCondensed":
            return Font(UIFont.systemFont(ofSize: size, weight: uiWeight, width: .condensed))
        case "sfCompressed":
            return Font(UIFont.systemFont(ofSize: size, weight: uiWeight, width: .compressed))
        case "newYork":
            return .system(size: size, weight: swiftWeight, design: .serif)
        case "courierNew":
            let name = settings.clockBold ? "CourierNewPS-BoldMT" : "CourierNewPSMT"
            return .custom(name, size: size)
        default:
            return .system(size: size, weight: swiftWeight, design: .default)
        }
    }

    var body: some View {
        let c         = components
        let timeStr   = String(format: "%02d:%02d:%02d", c.h, c.m, c.s)
        let color     = clockColor

        Group {
            switch settings.clockFont {
            case "digital":
                SevenSegmentClockView(timeString: timeStr, color: color)
            case "flapBoard":
                FlapClockView(timeString: timeStr, color: color)
            default:
                GeometryReader { geo in
                    let bold = settings.clockBold
                    let widthDivisor: CGFloat = {
                        switch settings.clockFont {
                        case "sfpro":        return bold ? 4.55 : 4.15
                        case "sfCondensed":  return bold ? 3.55 : 3.20
                        case "sfCompressed": return bold ? 3.05 : 2.65
                        case "newYork":      return bold ? 4.75 : 4.35
                        default:             return bold ? 4.75 : 4.35
                        }
                    }()
                    let fontSize = min(geo.size.width / widthDivisor, geo.size.height * 0.92)

                    Text(timeStr)
                        .font(resolvedFont(size: fontSize))
                        .monospacedDigit()
                        .foregroundStyle(color)
                        .minimumScaleFactor(0.88)
                        .lineLimit(1)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .animation(.none, value: c.s)
    }
}

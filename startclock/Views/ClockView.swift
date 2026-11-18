import SwiftUI
import UIKit

/// Which highlight the clock should use for the current instant.
/// Resolved by ContentView so that fixed-interval and auto (start-list) modes
/// share one source of truth with the beep scheduler.
enum ClockHighlight {
    case none      // ordinary tick
    case warning   // within 5 s before a start
    case go        // exactly on a start
}

struct ClockView: View {
    @EnvironmentObject var settings: AppSettings
    let date: Date
    var highlight: ClockHighlight = .none

    private var components: (h: Int, m: Int, s: Int) {
        let cal = Calendar.current
        return (
            cal.component(.hour,   from: date),
            cal.component(.minute, from: date),
            cal.component(.second, from: date)
        )
    }

    private var clockColor: Color {
        switch highlight {
        case .go:      return .green
        case .warning: return .orange
        case .none:    return settings.invertedMode ? .black : .white
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
            case "analog", "analogSeconds":
                GeometryReader { geo in
                    let secondsOnly = settings.clockFont == "analogSeconds"
                    let fontSize = min(geo.size.height * 0.13, geo.size.width / 5.2)
                    VStack(spacing: 4) {
                        Text(timeStr)
                            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(color)
                            .lineLimit(1)
                        AnalogClockView(date: date, secondsOnly: secondsOnly, accentColor: color)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            case "hourOnly", "minuteOnly", "secondOnly":
                GeometryReader { geo in
                    let bold = settings.clockBold
                    // Two digits — roughly half the divisor of the full HH:MM:SS string
                    let widthDivisor: CGFloat = bold ? 1.25 : 1.15
                    let fontSize = min(geo.size.width / widthDivisor, geo.size.height * 0.92)
                    let value: Int = {
                        switch settings.clockFont {
                        case "hourOnly":   return c.h
                        case "minuteOnly": return c.m
                        default:           return c.s
                        }
                    }()
                    Text(String(format: "%02d", value))
                        .font(.system(size: fontSize,
                                      weight: bold ? .bold : .regular,
                                      design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(color)
                        .minimumScaleFactor(0.88)
                        .lineLimit(1)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
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

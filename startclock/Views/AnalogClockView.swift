import SwiftUI

struct AnalogClockView: View {
    let date: Date
    let secondsOnly: Bool
    let accentColor: Color   // .green = go, .orange = warning, otherwise neutral

    private var cal: Calendar { .current }

    private var secondAngle: Angle {
        let s  = Double(cal.component(.second,     from: date))
        let ns = Double(cal.component(.nanosecond, from: date))
        return .degrees((s + ns / 1_000_000_000) / 60 * 360)
    }
    private var minuteAngle: Angle {
        let m  = Double(cal.component(.minute,     from: date))
        let s  = Double(cal.component(.second,     from: date))
        let ns = Double(cal.component(.nanosecond, from: date))
        return .degrees((m + (s + ns / 1e9) / 60) / 60 * 360)
    }
    private var hourAngle: Angle {
        let h  = Double(cal.component(.hour,   from: date)).truncatingRemainder(dividingBy: 12)
        let m  = Double(cal.component(.minute, from: date))
        let s  = Double(cal.component(.second, from: date))
        return .degrees((h + m / 60 + s / 3600) / 12 * 360)
    }

    private var secondHandColor: Color {
        if accentColor == .green  { return .green }
        if accentColor == .orange { return .orange }
        return .red
    }

    var body: some View {
        GeometryReader { geo in
            let avail = min(geo.size.width, geo.size.height)
            let size  = avail * 0.92     // square case edge length
            let r     = size * 0.390     // clock-face radius

            ZStack {
                // ── Orange body ──────────────────────────────────────────
                RoundedRectangle(cornerRadius: size * 0.13)
                    .fill(LinearGradient(
                        colors: [Color(red: 1.00, green: 0.60, blue: 0.02),
                                 Color(red: 0.88, green: 0.45, blue: 0.00)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.40), radius: 14, x: 3, y: 6)

                // ── Chrome bezel ─────────────────────────────────────────
                Circle()
                    .fill(AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(white: 0.52), location: 0.00),
                            .init(color: Color(white: 0.94), location: 0.15),
                            .init(color: Color(white: 0.62), location: 0.32),
                            .init(color: Color(white: 0.92), location: 0.50),
                            .init(color: Color(white: 0.54), location: 0.68),
                            .init(color: Color(white: 0.90), location: 0.85),
                            .init(color: Color(white: 0.52), location: 1.00),
                        ]),
                        center: .center))
                    .frame(width: r * 2.22, height: r * 2.22)

                // ── White clock face ──────────────────────────────────────
                Circle()
                    .fill(Color.white)
                    .frame(width: r * 2, height: r * 2)

                // ── Tick marks ────────────────────────────────────────────
                let margin: CGFloat = r * 0.038
                ForEach(0..<60) { i in
                    let major = i % 5 == 0
                    let h: CGFloat = major ? r * 0.132 : r * 0.066
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: major ? r * 0.046 : r * 0.018, height: h)
                        .offset(y: -(r - margin - h / 2))
                        .rotationEffect(.degrees(Double(i) * 6))
                }

                // ── Hour hand (full mode only) ────────────────────────────
                if !secondsOnly {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: r * 0.072, height: r * 0.60)
                        // center = -(tip - tail)/2; tip ≈ 0.52r, tail ≈ 0.08r
                        .offset(y: -(r * 0.22))
                        .rotationEffect(hourAngle)

                    // ── Minute hand ───────────────────────────────────────
                    Capsule()
                        .fill(Color.black)
                        .frame(width: r * 0.046, height: r * 0.80)
                        // tip ≈ 0.73r, tail ≈ 0.07r → center = -0.33r
                        .offset(y: -(r * 0.33))
                        .rotationEffect(minuteAngle)
                }

                // ── Second hand (needle + tail as one rect) ───────────────
                // tip at -0.80r, tail at +0.22r → height 1.02r, center -0.29r
                Rectangle()
                    .fill(secondHandColor)
                    .frame(width: r * 0.020, height: r * 1.02)
                    .offset(y: -(r * 0.29))
                    .rotationEffect(secondAngle)

                // ── Center cap ────────────────────────────────────────────
                Circle()
                    .fill(Color.white)
                    .frame(width: r * 0.09, height: r * 0.09)
                    .overlay(Circle().stroke(Color(white: 0.44), lineWidth: 1.0))

                // ── Orienteering O-control marker (bottom-right) ──────────
                OControlMarker(size: r * 0.30)
                    .offset(x: r * 0.60, y: r * 0.60)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// The classic orienteering control kite: white upper-left, orange lower-right.
private struct OControlMarker: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
            Path { p in
                p.move(to: .init(x: size, y: 0))
                p.addLine(to: .init(x: size, y: size))
                p.addLine(to: .init(x: 0,    y: size))
                p.closeSubpath()
            }
            .fill(Color(red: 1.0, green: 0.55, blue: 0.00))
            Rectangle()
                .stroke(Color(white: 0.55), lineWidth: 0.7)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.28), radius: 2, x: 1, y: 1)
    }
}

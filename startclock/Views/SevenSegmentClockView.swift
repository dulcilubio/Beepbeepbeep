import SwiftUI

// Segment bits: bit0=a(top), bit1=b(top-right), bit2=c(bot-right),
//               bit3=d(bot),  bit4=e(bot-left),  bit5=f(top-left), bit6=g(mid)
private let segBits: [Character: UInt8] = [
    "0": 63, "1": 6,   "2": 91,  "3": 79,
    "4": 102,"5": 109, "6": 125, "7": 7,
    "8": 127,"9": 111
]

// Chamfered hexagon for a horizontal segment
private func hSeg(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> Path {
    let e = h / 2
    var p = Path()
    p.move(to:    CGPoint(x: x + e,     y: y))
    p.addLine(to: CGPoint(x: x + w - e, y: y))
    p.addLine(to: CGPoint(x: x + w,     y: y + e))
    p.addLine(to: CGPoint(x: x + w - e, y: y + h))
    p.addLine(to: CGPoint(x: x + e,     y: y + h))
    p.addLine(to: CGPoint(x: x,         y: y + e))
    p.closeSubpath()
    return p
}

// Chamfered hexagon for a vertical segment
private func vSeg(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> Path {
    let e = w / 2
    var p = Path()
    p.move(to:    CGPoint(x: x + e, y: y))
    p.addLine(to: CGPoint(x: x + w, y: y + e))
    p.addLine(to: CGPoint(x: x + w, y: y + h - e))
    p.addLine(to: CGPoint(x: x + e, y: y + h))
    p.addLine(to: CGPoint(x: x,     y: y + h - e))
    p.addLine(to: CGPoint(x: x,     y: y + e))
    p.closeSubpath()
    return p
}

// Returns the 7 segment paths and their on/off state for a digit
private func digitSegments(bits: UInt8, ox: CGFloat, oy: CGFloat,
                            w: CGFloat, h: CGFloat) -> [(Path, Bool)] {
    let t = w * 0.15
    let g = t * 0.45
    func on(_ bit: Int) -> Bool { (bits >> bit) & 1 == 1 }
    return [
        (hSeg(x: ox+g+t,    y: oy+g,       w: w-2*(g+t), h: t), on(0)),
        (vSeg(x: ox+w-t-g,  y: oy+g+t,     w: t, h: h/2-t-2*g), on(1)),
        (vSeg(x: ox+w-t-g,  y: oy+h/2+g,   w: t, h: h/2-t-2*g), on(2)),
        (hSeg(x: ox+g+t,    y: oy+h-t-g,   w: w-2*(g+t), h: t), on(3)),
        (vSeg(x: ox+g,      y: oy+h/2+g,   w: t, h: h/2-t-2*g), on(4)),
        (vSeg(x: ox+g,      y: oy+g+t,     w: t, h: h/2-t-2*g), on(5)),
        (hSeg(x: ox+g+t,    y: oy+h/2-t/2, w: w-2*(g+t), h: t), on(6)),
    ]
}

struct SevenSegmentClockView: View {
    let timeString: String
    let color: Color

    private let digitAspect: CGFloat = 0.54
    private let colonAspect: CGFloat = 0.22
    private let gapAspect:   CGFloat = 0.04

    var body: some View {
        GeometryReader { geo in
            let chars   = Array(timeString)
            let nDigits = CGFloat(chars.filter { $0 != ":" }.count)
            let nColons = CGFloat(chars.filter { $0 == ":" }.count)
            let nGaps   = CGFloat(chars.count - 1)

            let divisor = nDigits * digitAspect + nColons * colonAspect + nGaps * gapAspect
            let dh      = min(geo.size.width / divisor, geo.size.height * 0.95)
            let dw      = dh * digitAspect
            let cw      = dh * colonAspect
            let gap     = dh * gapAspect
            let totalW  = nDigits * dw + nColons * cw + nGaps * gap
            let startX  = (geo.size.width  - totalW) / 2
            let startY  = (geo.size.height - dh)     / 2
            let dim     = color.opacity(0.10)
            let active  = color

            Canvas { ctx, _ in
                var x = startX
                for (i, ch) in chars.enumerated() {
                    if ch == ":" {
                        let dotR = dh * 0.07
                        let cx   = x + cw / 2
                        let dot1 = CGRect(x: cx-dotR, y: startY+dh*0.27-dotR,
                                          width: dotR*2, height: dotR*2)
                        let dot2 = CGRect(x: cx-dotR, y: startY+dh*0.63-dotR,
                                          width: dotR*2, height: dotR*2)
                        ctx.fill(Path(ellipseIn: dot1), with: .color(active))
                        ctx.fill(Path(ellipseIn: dot2), with: .color(active))
                        x += cw
                    } else {
                        let b = segBits[ch] ?? 0
                        for (path, isOn) in digitSegments(bits: b, ox: x, oy: startY,
                                                          w: dw, h: dh) {
                            ctx.fill(path, with: .color(isOn ? active : dim))
                        }
                        x += dw
                    }
                    if i < chars.count - 1 { x += gap }
                }
            }
        }
    }
}

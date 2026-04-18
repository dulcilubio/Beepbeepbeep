import SwiftUI
import UIKit

struct FlapClockView: View {
    let timeString: String
    let color: Color

    private let cellWidthRatio:  CGFloat = 0.68
    private let colonWidthRatio: CGFloat = 0.26
    private let gapRatio:        CGFloat = 0.028
    private let cornerRatio:     CGFloat = 0.07

    var body: some View {
        GeometryReader { geo in
            let chars   = Array(timeString)
            let nDigits = CGFloat(chars.filter { $0 != ":" }.count)
            let nColons = CGFloat(chars.filter { $0 == ":" }.count)
            let nGaps   = CGFloat(chars.count - 1)

            let divisor = nDigits * cellWidthRatio + nColons * colonWidthRatio + nGaps * gapRatio
            let ch      = min(geo.size.width / divisor, geo.size.height * 0.92)
            let gap     = ch * gapRatio
            let corner  = ch * cornerRatio

            HStack(spacing: gap) {
                ForEach(Array(timeString.enumerated()), id: \.offset) { _, c in
                    if c == ":" {
                        flapColon(height: ch, width: ch * colonWidthRatio)
                    } else {
                        flapDigit(char: c, height: ch, width: ch * cellWidthRatio, corner: corner)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private func flapDigit(char: Character, height: CGFloat, width: CGFloat, corner: CGFloat) -> some View {
        let fontSize = height * 0.76
        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(Color(white: 0.13))

            // Top half slightly lighter (flap highlight)
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color(white: 0.19))
                    .frame(height: height * 0.5)
                    .clipped()
                Spacer(minLength: 0)
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: corner))

            Text(String(char))
                .font(flapFont(size: fontSize))
                .monospacedDigit()
                .foregroundStyle(color)

            // Split-flap divider
            Rectangle()
                .fill(Color.black.opacity(0.65))
                .frame(width: width, height: max(1, height * 0.018))
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner))
    }

    @ViewBuilder
    private func flapColon(height: CGFloat, width: CGFloat) -> some View {
        let dotSize = height * 0.13
        VStack(spacing: height * 0.21) {
            Circle().fill(color).frame(width: dotSize, height: dotSize)
            Circle().fill(color).frame(width: dotSize, height: dotSize)
        }
        .frame(width: width, height: height)
    }

    private func flapFont(size: CGFloat) -> Font {
        let uiFont = UIFont.systemFont(ofSize: size, weight: .black, width: .condensed)
        return Font(uiFont)
    }
}

import SwiftUI

/// Picks a clock face by showing it, not by naming it. Every tile is the real
/// ClockView running the real time, so what you see is what the start crew gets.
struct ClockStylePickerView: View {
    @EnvironmentObject var settings: AppSettings

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        // One timeline for the whole grid — twelve clocks on twelve timers
        // would be wasteful, and once a second is all a preview needs.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(ClockStyle.allCases) { style in
                        tile(style, date: context.date)
                    }
                }
                .padding(16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Clock style")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Bold belongs here: its effect is visible in every tile.
                Toggle("Bold", isOn: $settings.clockBold)
                    .toggleStyle(.button)
                    .disabled(!settings.clockStyle.usesBold)
            }
        }
    }

    @ViewBuilder
    private func tile(_ style: ClockStyle, date: Date) -> some View {
        let isSelected = settings.clockStyle == style

        Button {
            settings.clockStyle = style
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    // The face sits on the same background it will run on, so
                    // inverted mode previews honestly too.
                    RoundedRectangle(cornerRadius: 10)
                        .fill(settings.invertedMode ? Color.white : Color.black)

                    ClockView(
                        date: date,
                        highlight: .none,
                        style: style,
                        bold: style.usesBold ? settings.clockBold : true
                    )
                    .padding(style.prefersSquarePreview ? 6 : 10)
                }
                .frame(height: style.prefersSquarePreview ? 118 : 70)

                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    Text(style.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

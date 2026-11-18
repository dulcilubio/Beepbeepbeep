import SwiftUI
import AVFoundation
import UIKit

struct ControlsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var gnss: GNSSTimeManager
    @EnvironmentObject var nowPlaying: NowPlayingManager
    @Binding var showSettings: Bool

    /// Set while the screen is forced to full brightness, holding the level to
    /// go back to. Sunlight at a start is the one place this matters, and
    /// auto-brightness keeps pulling the screen back down.
    @State private var brightnessBeforeBoost: CGFloat?

    private var isBoosted: Bool { brightnessBeforeBoost != nil }

    var body: some View {
        HStack {
            controlButton(
                systemImage: settings.beepEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                isActive: settings.beepEnabled,
                label: "Beeps"
            ) {
                settings.beepEnabled.toggle()
            }

            Spacer()

            // Light changes during a start — cloud, shade, low evening sun.
            controlButton(
                systemImage: "circle.lefthalf.filled",
                isActive: settings.invertedMode,
                label: "Outdoor mode"
            ) {
                settings.invertedMode.toggle()
            }

            Spacer()

            controlButton(
                systemImage: isBoosted ? "sun.max.fill" : "sun.min",
                isActive: isBoosted,
                label: "Full brightness"
            ) {
                toggleBrightness()
            }

            Spacer()

            controlButton(systemImage: "xmark.circle.fill", isActive: false, label: "Quit") {
                // Leaving the app does not stop the beeps — that is deliberate,
                // so the clock survives a glance at something else. This is how
                // the start crew stops it for good without the app switcher.
                nowPlaying.clear()
                restoreBrightness()
                gnss.stop()
                try? AVAudioSession.sharedInstance().setActive(false)
                exit(0)
            }

            Spacer()

            controlButton(systemImage: "gearshape.fill", isActive: false, label: "Settings") {
                showSettings = true
            }
        }
    }

    @ViewBuilder
    private func controlButton(
        systemImage: String,
        isActive: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(isActive ? settings.primaryTextColor : settings.secondaryTextColor)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
    }

    private func toggleBrightness() {
        if let previous = brightnessBeforeBoost {
            UIScreen.main.brightness = previous
            brightnessBeforeBoost = nil
        } else {
            brightnessBeforeBoost = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
        }
    }

    private func restoreBrightness() {
        if let previous = brightnessBeforeBoost {
            UIScreen.main.brightness = previous
        }
    }
}

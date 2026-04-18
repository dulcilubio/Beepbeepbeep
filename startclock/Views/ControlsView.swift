import SwiftUI
import AVFoundation

struct ControlsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var gnss: GNSSTimeManager
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
            // Beep toggle
            Button {
                settings.beepEnabled.toggle()
            } label: {
                Image(systemName: settings.beepEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(settings.beepEnabled
                        ? (settings.invertedMode ? Color.black : Color.white)
                        : Color.gray)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Settings button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.gray)
                    .frame(width: 44, height: 44)
            }

            // Exit button
            Button {
                gnss.stop()
                try? AVAudioSession.sharedInstance().setActive(false)
                exit(0)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.gray)
                    .frame(width: 44, height: 44)
            }
        }
    }
}

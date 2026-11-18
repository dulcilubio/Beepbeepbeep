import MediaPlayer

/// Shows the clock as "Now Playing" on the Lock Screen and in Control Centre
/// while it runs in the background.
///
/// The app keeps beeping once it leaves the foreground, which is the point —
/// but then nothing on screen says so, and not everyone knows how to swipe an
/// app back. Because the session plays audio, iOS will list it among the media
/// controls, where one tap returns to the clock and the pause button silences
/// the beeps without having to find the app at all.
@MainActor
final class NowPlayingManager: ObservableObject {

    private let info = MPNowPlayingInfoCenter.default()
    private let commands = MPRemoteCommandCenter.shared()
    private var setBeepsEnabled: ((Bool) -> Void)?
    private var artwork: MPMediaItemArtwork?

    /// `setBeepsEnabled` is called when the Lock Screen controls are used.
    func start(setBeepsEnabled: @escaping (Bool) -> Void) {
        self.setBeepsEnabled = setBeepsEnabled

        if artwork == nil, let icon = UIImage(named: "LaunchIcon") {
            artwork = MPMediaItemArtwork(boundsSize: icon.size) { _ in icon }
        }

        commands.playCommand.removeTarget(nil)
        commands.pauseCommand.removeTarget(nil)
        commands.togglePlayPauseCommand.removeTarget(nil)
        commands.stopCommand.removeTarget(nil)

        commands.playCommand.addTarget { [weak self] _ in
            self?.setBeepsEnabled?(true)
            return .success
        }
        // Pause and stop mute the beeps; they never stop the clock itself,
        // which has to keep running whatever the start crew taps.
        commands.pauseCommand.addTarget { [weak self] _ in
            self?.setBeepsEnabled?(false)
            return .success
        }
        commands.stopCommand.addTarget { [weak self] _ in
            self?.setBeepsEnabled?(false)
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.setBeepsEnabled?(!self.beepsAreOn)
            return .success
        }

        for command in [commands.nextTrackCommand, commands.previousTrackCommand,
                        commands.seekForwardCommand, commands.seekBackwardCommand,
                        commands.changePlaybackPositionCommand] {
            command.isEnabled = false
        }
    }

    private var beepsAreOn = true

    func update(title: String, subtitle: String, beepsOn: Bool) {
        beepsAreOn = beepsOn

        var nowPlaying: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: subtitle,
            // A clock has no duration and no position to scrub to.
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: beepsOn ? 1.0 : 0.0,
        ]
        if let artwork { nowPlaying[MPMediaItemPropertyArtwork] = artwork }

        info.nowPlayingInfo = nowPlaying
        info.playbackState = beepsOn ? .playing : .paused
    }

    func clear() {
        info.nowPlayingInfo = nil
        info.playbackState = .stopped
    }
}

import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var currentTrackID: Track.ID?
    @Published private(set) var isPlaying = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var isMuted = false {
        didSet { player?.volume = isMuted ? 0 : preferredVolume }
    }

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var fadeTimer: Timer?
    private let preferredVolume: Float = 0.9

    override init() {
        super.init()
        configureAudioSession()
    }

    func play(_ track: Track, crossfade: Bool = true) {
        if currentTrackID == track.id, let player {
            player.play()
            isPlaying = true
            startProgressUpdates()
            return
        }

        guard let url = Bundle.main.url(forResource: track.audioResource, withExtension: "mp3") else {
            return
        }

        do {
            let nextPlayer = try AVAudioPlayer(contentsOf: url)
            nextPlayer.delegate = self
            nextPlayer.prepareToPlay()
            nextPlayer.currentTime = min(track.startTime, max(0, nextPlayer.duration - 1))
            nextPlayer.volume = crossfade ? 0 : (isMuted ? 0 : preferredVolume)

            stopFade()
            let previousPlayer = player
            player = nextPlayer
            currentTrackID = track.id
            duration = nextPlayer.duration
            elapsed = nextPlayer.currentTime
            nextPlayer.play()
            isPlaying = true
            startProgressUpdates()

            if crossfade {
                crossfade(from: previousPlayer, to: nextPlayer)
            } else {
                previousPlayer?.stop()
            }
        } catch {
            isPlaying = false
        }
    }

    func toggle(_ track: Track) {
        if currentTrackID != track.id {
            play(track)
        } else if isPlaying {
            pause()
        } else {
            player?.play()
            isPlaying = true
            startProgressUpdates()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressUpdates()
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        player.currentTime = max(0, min(1, fraction)) * player.duration
        elapsed = player.currentTime
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopProgressUpdates()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            // The feed remains usable without audio, for example in SwiftUI previews.
        }
    }

    private func startProgressUpdates() {
        stopProgressUpdates()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.elapsed = player.currentTime
                self.duration = player.duration
            }
        }
    }

    private func stopProgressUpdates() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func crossfade(from oldPlayer: AVAudioPlayer?, to newPlayer: AVAudioPlayer) {
        let steps = 12
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { [weak self, weak oldPlayer, weak newPlayer] timer in
            Task { @MainActor in
                guard let self, let newPlayer else {
                    timer.invalidate()
                    return
                }
                step += 1
                let progress = Float(step) / Float(steps)
                oldPlayer?.volume = self.preferredVolume * (1 - progress)
                newPlayer.volume = self.isMuted ? 0 : self.preferredVolume * progress
                if step >= steps {
                    oldPlayer?.stop()
                    timer.invalidate()
                    self.fadeTimer = nil
                }
            }
        }
    }

    private func stopFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    deinit {
        progressTimer?.invalidate()
        fadeTimer?.invalidate()
    }
}

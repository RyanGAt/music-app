import AVFoundation
import Combine
import Foundation

/// Streams remote catalogue previews and local development fallback files.
@MainActor
final class AudioPlayer: ObservableObject {
    @Published private(set) var currentTrackID: Track.ID?
    @Published private(set) var isPlaying = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var errorMessage: String?
    @Published var isMuted = false {
        didSet { player.isMuted = isMuted }
    }

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var loadTask: Task<Void, Never>?

    init() {
        configureAudioSession()
        let defaults = UserDefaults.standard
        player.volume = defaults.object(forKey: "previewVolume") == nil
            ? 0.9
            : Float(defaults.double(forKey: "previewVolume"))
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed = time.seconds.isFinite ? max(0, time.seconds) : 0
                if let itemDuration = self.player.currentItem?.duration.seconds,
                   itemDuration.isFinite {
                    self.duration = itemDuration
                }
            }
        }
    }

    func play(_ track: Track, startingAt fraction: Double? = nil, restart: Bool = false) {
        if currentTrackID == track.id, player.currentItem != nil {
            if restart { player.seek(to: .zero); elapsed = 0 }
            player.play()
            isPlaying = true
            return
        }
        guard let previewURL = track.previewURL else {
            errorMessage = "No preview is available for this song."
            pause()
            return
        }

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let asset = AVURLAsset(url: previewURL)
            do {
                let (isPlayable, assetDuration) = try await asset.load(.isPlayable, .duration)
                guard isPlayable else {
                    throw PlaybackError.unplayable
                }
                guard !Task.isCancelled else { return }
                let item = AVPlayerItem(asset: asset)
                self.observeEnd(of: item)
                self.player.replaceCurrentItem(with: item)
                self.player.isMuted = self.isMuted
                self.currentTrackID = track.id
                self.duration = assetDuration.seconds.isFinite ? assetDuration.seconds : 0
                if let fraction, self.duration > 0 {
                    let start = CMTime(
                        seconds: max(0, min(1, fraction)) * self.duration,
                        preferredTimescale: 600
                    )
                    await self.player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
                    self.elapsed = start.seconds
                } else {
                    self.elapsed = 0
                }
                self.errorMessage = nil
                self.player.play()
                self.isPlaying = true
            } catch is CancellationError {
                return
            } catch {
                self.errorMessage = "This preview couldn't be played."
                self.isPlaying = false
            }
        }
    }

    func toggle(_ track: Track) {
        if currentTrackID != track.id {
            play(track)
        } else if isPlaying {
            pause()
        } else {
            player.play()
            isPlaying = true
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func setVolume(_ volume: Double) {
        player.volume = Float(max(0, min(1, volume)))
    }

    func seek(to fraction: Double) {
        guard duration > 0 else { return }
        let time = CMTime(seconds: max(0, min(1, fraction)) * duration, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func observeEnd(of item: AVPlayerItem) {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isPlaying = false }
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = "Audio is unavailable on this device."
        }
    }

    deinit {
        loadTask?.cancel()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    private enum PlaybackError: Error { case unplayable }
}

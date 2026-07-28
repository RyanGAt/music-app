import SwiftUI
import SwiftData

struct TrackPage: View {
    let track: Track

    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var savedTracks: [SavedTrack]
    @State private var dragProgress: Double?
    @State private var spotifyMatch: SpotifyMatchState = .idle

    private var isCurrent: Bool { audioPlayer.currentTrackID == track.id }
    private var displayedProgress: Double {
        if let dragProgress { return dragProgress }
        guard isCurrent, audioPlayer.duration > 0 else { return 0 }
        return audioPlayer.elapsed / audioPlayer.duration
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: track.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    RadialGradient(
                        colors: [.white.opacity(0.16), .clear],
                        center: .topTrailing,
                        startRadius: 10,
                        endRadius: 360
                    )
                }
                .overlay(Color.black.opacity(0.18))
                .ignoresSafeArea()

            Circle()
                .fill(track.gradientColors.last?.opacity(0.38) ?? .clear)
                .frame(width: 420, height: 420)
                .blur(radius: 65)
                .offset(x: -150, y: 250)

            VStack(spacing: 0) {
                header
                    .padding(.top, 12)

                Spacer()

                artwork

                Spacer(minLength: 36)

                metadata

                controls
                    .padding(.top, 24)
                    .padding(.bottom, 38)
            }
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .contain)
        .task(id: track.id) {
            spotifyMatch = .matching
            spotifyMatch = await SpotifyMatcher.shared.match(track)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                Text("SOUNDSCROLL")
                    .tracking(2.2)
            }
            .font(.caption.weight(.bold))

            Spacer()

            Button {
                audioPlayer.isMuted.toggle()
            } label: {
                Image(systemName: audioPlayer.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audioPlayer.isMuted ? "Unmute" : "Mute")
        }
        .foregroundStyle(.white.opacity(0.92))
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.34), radius: 35, y: 22)

            VStack(spacing: 20) {
                AsyncImage(url: track.artworkURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "waveform")
                        .font(.system(size: 80, weight: .ultraLight))
                        .symbolEffect(.variableColor.iterative, isActive: isCurrent && audioPlayer.isPlaying)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                if let moment = track.moment {
                    Text("“\(moment)”")
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 18)
                }
            }
            .foregroundStyle(.white)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 360)
    }

    private var metadata: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(track.album.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.58))
                Text(track.title)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Button { toggleLike() } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLiked ? "Unlike song" : "Like song")
        }
    }

    private var controls: some View {
        VStack(spacing: 18) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22)).frame(height: 4)
                    Capsule().fill(.white).frame(width: width * displayedProgress, height: 4)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragProgress = max(0, min(1, value.location.x / width))
                        }
                        .onEnded { value in
                            let progress = max(0, min(1, value.location.x / width))
                            if isCurrent {
                                audioPlayer.seek(to: progress)
                            } else {
                                audioPlayer.play(track, startingAt: progress)
                            }
                            dragProgress = nil
                        }
                )
            }
            .frame(height: 20)
            .accessibilityLabel("Playback progress")
            .accessibilityValue("\(Int(displayedProgress * 100)) percent")

            HStack {
                Text(time(audioPlayer.elapsed, when: isCurrent))
                Spacer()
                Button {
                    audioPlayer.toggle(track)
                } label: {
                    Image(systemName: isCurrent && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 58, height: 58)
                        .background(.white, in: Circle())
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isCurrent && audioPlayer.isPlaying ? "Pause" : "Play")
                Spacer()
                Text("−\(time(max(0, audioPlayer.duration - audioPlayer.elapsed), when: isCurrent))")
            }
            .font(.caption.monospacedDigit().weight(.medium))
            .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 10) {
                destinationButton("Apple Music", systemImage: "music.note", url: track.appleMusicURL)
                spotifyButton
                ShareLink(item: track.appleMusicURL ?? spotifySearchURL, subject: Text(track.title), message: Text("\(track.title) by \(track.artist)")) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 38, height: 38).background(.white.opacity(0.13), in: Circle())
                }
                .accessibilityLabel("Share song")
            }
        }
    }

    @ViewBuilder
    private var spotifyButton: some View {
        switch spotifyMatch {
        case .exact(let url):
            destinationButton("Spotify", systemImage: "arrow.up.right", url: url)
        case .matching:
            HStack { ProgressView(); Text("Matching…") }
                .font(.caption).frame(maxWidth: .infinity).frame(height: 38)
                .background(.white.opacity(0.13), in: Capsule())
        case .failed:
            destinationButton("Spotify match failed", systemImage: "exclamationmark.circle", url: spotifySearchURL)
        case .idle, .unavailable:
            destinationButton("Search Spotify", systemImage: "magnifyingglass", url: spotifySearchURL)
        }
    }

    private var spotifySearchURL: URL {
        let query = "\(track.title) \(track.artist)"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        return URL(string: "https://open.spotify.com/search/\(encoded)") ?? URL(string: "https://open.spotify.com")!
    }

    private var isLiked: Bool { savedTracks.contains { $0.trackID == track.id } }

    private func toggleLike() {
        if let saved = savedTracks.first(where: { $0.trackID == track.id }) {
            modelContext.delete(saved)
        } else {
            modelContext.insert(SavedTrack(track: track))
        }
    }

    @ViewBuilder
    private func destinationButton(_ title: String, systemImage: String, url: URL?) -> some View {
        if let url {
            Button { openURL(url) } label: {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(.white.opacity(0.13), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func time(_ interval: TimeInterval, when visible: Bool) -> String {
        let value = visible && interval.isFinite ? max(0, Int(interval)) : 0
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

#if DEBUG
#Preview {
    TrackPage(track: Track.developmentFallback[0])
        .environmentObject(AudioPlayer())
        .modelContainer(for: SavedTrack.self, inMemory: true)
}
#endif

import SwiftUI

struct FeedView: View {
    let tracks: [Track]

    @EnvironmentObject private var audioPlayer: AudioPlayer
    @State private var selectedTrackID: Track.ID?
    @State private var hasStartedListening = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(tracks) { track in
                        TrackPage(track: track)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(track.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $selectedTrackID)
            .ignoresSafeArea()
            .onAppear { selectedTrackID = tracks.first?.id }
            .onChange(of: selectedTrackID) { _, newID in
                guard hasStartedListening,
                      let track = tracks.first(where: { $0.id == newID }) else { return }
                audioPlayer.play(track)
            }

            if !hasStartedListening, let firstTrack = tracks.first {
                ListeningGate {
                    hasStartedListening = true
                    audioPlayer.play(firstTrack, crossfade: false)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: hasStartedListening)
    }
}

private struct ListeningGate: View {
    let start: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 54, weight: .light))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(hex: 0x7B68EE))

                VStack(spacing: 6) {
                    Text("SoundScroll")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("One swipe. One perfect moment.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                }

                Button(action: start) {
                    Label("Start listening", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .frame(height: 52)
                        .background(.white, in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Begins playback of the visible song")
            }
            .padding(32)
        }
    }
}

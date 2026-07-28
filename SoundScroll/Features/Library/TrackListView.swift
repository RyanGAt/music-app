import SwiftUI

struct TrackListView: View {
    let emptyTitle: String
    let emptyMessage: String
    let tracks: [Track]

    @EnvironmentObject private var audioPlayer: AudioPlayer

    var body: some View {
        Group {
                if tracks.isEmpty {
                    ContentUnavailableView(emptyTitle, systemImage: "waveform", description: Text(emptyMessage))
                } else {
                    List(tracks) { track in
                        HStack(spacing: 14) {
                            AsyncImage(url: track.artworkURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                LinearGradient(colors: track.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .overlay { Image(systemName: "waveform").foregroundStyle(.white) }
                            }
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.title).font(.headline).lineLimit(1)
                                Text(track.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button { audioPlayer.toggle(track) } label: {
                                Image(systemName: audioPlayer.currentTrackID == track.id && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .frame(width: 40, height: 40)
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    }
                    .listStyle(.plain)
                }
        }
    }
}

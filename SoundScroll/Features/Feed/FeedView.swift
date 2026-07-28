import SwiftData
import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ListeningEvent.playedAt, order: .reverse) private var history: [ListeningEvent]
    @StateObject private var catalog = AppleMusicCatalog()
    @State private var selectedTrackID: Track.ID?
    @State private var hasStartedListening = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if catalog.tracks.isEmpty {
                catalogueState
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(catalog.tracks) { track in
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
                .ignoresSafeArea(edges: .top)
                .onChange(of: selectedTrackID) { _, newID in
                    guard hasStartedListening,
                          let track = catalog.tracks.first(where: { $0.id == newID }) else { return }
                    beginListening(to: track)
                }

                if !hasStartedListening, let firstTrack = catalog.tracks.first {
                    ListeningGate {
                        hasStartedListening = true
                        selectedTrackID = selectedTrackID ?? firstTrack.id
                        beginListening(to: firstTrack)
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: hasStartedListening)
        .task {
            await catalog.load()
            selectedTrackID = catalog.tracks.first?.id
        }
    }

    @ViewBuilder
    private var catalogueState: some View {
        switch catalog.state {
        case .idle, .loading:
            ProgressView("Finding fresh sounds…")
                .tint(.white)
                .foregroundStyle(.white)
        case .unavailable(let message):
            ContentUnavailableView {
                Label("Catalogue unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await catalog.load() } }
                    .buttonStyle(.borderedProminent)
            }
        case .loaded:
            EmptyView()
        }
    }

    private func beginListening(to track: Track) {
        audioPlayer.play(track)
        guard history.first?.trackID != track.id else { return }
        modelContext.insert(ListeningEvent(track: track))
        if history.count >= 100 {
            history.dropFirst(99).forEach(modelContext.delete)
        }
    }
}

private struct ListeningGate: View {
    let start: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 54, weight: .light))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(hex: 0x7B68EE))
                VStack(spacing: 6) {
                    Text("SoundScroll").font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("One swipe. One perfect moment.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.68))
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

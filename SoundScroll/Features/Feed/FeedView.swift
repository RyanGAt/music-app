import SwiftData
import SwiftUI
import UIKit

struct FeedView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ListeningEvent.playedAt, order: .reverse) private var history: [ListeningEvent]
    @StateObject private var catalog = AppleMusicCatalog()
    @State private var selectedTrackID: Track.ID?
    @State private var hasStartedListening = false
    @AppStorage("preferredGenres") private var storedGenres = DiscoveryPreferences.defaultGenres.joined(separator: ",")
    @AppStorage("allowExplicitContent") private var allowExplicit = false
    @AppStorage("autoplayPreviews") private var autoplay = true
    @AppStorage("hapticsEnabled") private var haptics = true

    private var genres: [String] { DiscoveryPreferences.genres(from: storedGenres) }

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
                                .onAppear {
                                    guard let index = catalog.tracks.firstIndex(of: track),
                                          index >= catalog.tracks.count - 4 else { return }
                                    Task { await catalog.loadMore(genres: genres, allowExplicit: allowExplicit) }
                                }
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
                    if haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
                    if autoplay { beginListening(to: track, restart: true) }
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

            if let error = audioPlayer.errorMessage {
                VStack { Spacer(); Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold)).padding(12).background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 12) }
            }

            if catalog.isLoadingMore {
                VStack { Spacer(); ProgressView("Loading more…").padding(10).background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 8) }
            }
        }
        .animation(.easeOut(duration: 0.3), value: hasStartedListening)
        .task(id: "\(storedGenres)-\(allowExplicit)") {
            await catalog.reload(genres: genres, allowExplicit: allowExplicit)
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
        case .offline:
            unavailable("You're offline", "Connect to the internet to discover Apple Music previews.", "wifi.slash")
        case .noResults:
            unavailable("No songs found", "Try selecting different discovery genres in Settings.", "music.note.list")
        case .failed(let message):
            unavailable("Couldn't load music", message, "exclamationmark.triangle")
        case .loaded:
            EmptyView()
        }
    }

    private func unavailable(_ title: String, _ message: String, _ icon: String) -> some View {
            ContentUnavailableView {
                Label(title, systemImage: icon)
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await catalog.reload(genres: genres, allowExplicit: allowExplicit) } }
                    .buttonStyle(.borderedProminent)
            }
    }

    private func beginListening(to track: Track, restart: Bool = false) {
        audioPlayer.play(track, restart: restart)
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

import SwiftData
import SwiftUI

struct AppShell: View {
    @Query(sort: \SavedTrack.likedAt, order: .reverse) private var likes: [SavedTrack]
    @Query(sort: \ListeningEvent.playedAt, order: .reverse) private var history: [ListeningEvent]

    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Discover", systemImage: "waveform") }

            TrackListView(
                title: "Liked Songs",
                emptyTitle: "No liked songs",
                emptyMessage: "Tap the heart on a song to keep it here.",
                tracks: likes.map(\.track)
            )
            .tabItem { Label("Likes", systemImage: "heart.fill") }

            TrackListView(
                title: "Listening History",
                emptyTitle: "No listening history",
                emptyMessage: "Songs you preview will appear here.",
                tracks: history.map(\.track)
            )
            .tabItem { Label("History", systemImage: "clock.fill") }
        }
        .tint(.white)
    }
}

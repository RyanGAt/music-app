import SwiftData
import SwiftUI

struct LibraryView: View {
    enum Selection: String, CaseIterable, Identifiable {
        case likes = "Liked Songs"
        case history = "History"
        var id: Self { self }
    }

    @Query(sort: \SavedTrack.likedAt, order: .reverse) private var likes: [SavedTrack]
    @Query(sort: \ListeningEvent.playedAt, order: .reverse) private var history: [ListeningEvent]
    @State private var selection = Selection.likes

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library", selection: $selection) {
                    ForEach(Selection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                TrackListView(
                    emptyTitle: selection == .likes ? "No liked songs" : "No listening history",
                    emptyMessage: selection == .likes
                        ? "Tap the heart on a song to keep it here."
                        : "Songs you preview will appear here.",
                    tracks: selection == .likes ? likes.map(\.track) : history.map(\.track)
                )
            }
            .navigationTitle("Library")
            .background(Color.black)
        }
    }
}

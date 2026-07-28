import Foundation
import MusicKit

@MainActor
final class AppleMusicCatalog: ObservableObject {
    enum State: Equatable {
        case idle, loading, loaded, unavailable(String)
    }

    @Published private(set) var tracks: [Track] = []
    @Published private(set) var state: State = .idle

    private let discoveryTerms = ["new music", "indie pop", "alternative", "chill"]

    func load() async {
        guard state != .loading else { return }
        state = .loading

        do {
            var songs: [Song] = []
            for term in discoveryTerms {
                var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
                request.limit = 8
                let response = try await request.response()
                songs.append(contentsOf: response.songs)
            }

            var seen = Set<MusicItemID>()
            tracks = songs
                .filter { seen.insert($0.id).inserted }
                .compactMap(Self.makeTrack)
            guard !tracks.isEmpty else { throw CatalogError.noPreviews }
            state = .loaded
        } catch {
            #if DEBUG
            tracks = Track.developmentFallback
            if !tracks.isEmpty {
                state = .loaded
                return
            }
            #endif
            state = .unavailable("Apple Music previews aren't available right now.")
        }
    }

    private static func makeTrack(from song: Song) -> Track? {
        guard let previewURL = song.previewAssets?.first?.url else { return nil }
        let artworkURL = song.artwork?.url(width: 900, height: 900)
        let spotifyQuery = "\(song.title) \(song.artistName)"
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? song.title

        return Track(
            id: song.id.rawValue,
            title: song.title,
            artist: song.artistName,
            album: song.albumTitle ?? "Apple Music",
            moment: "Press play on something new.",
            previewURL: previewURL,
            artworkURL: artworkURL,
            appleMusicURL: song.url,
            spotifyURL: URL(string: "https://open.spotify.com/search/\(spotifyQuery)"),
            colors: palette(for: song.id.rawValue)
        )
    }

    private static func palette(for value: String) -> [UInt] {
        let palettes: [[UInt]] = [
            [0x242A58, 0x895B74, 0xE39A76],
            [0x071B35, 0x284E74, 0xD34D8C],
            [0x432136, 0xB65345, 0xF3B75B],
            [0x163C38, 0x437967, 0xD9A66C]
        ]
        return palettes[Int(value.hashValue.magnitude % UInt(palettes.count))]
    }

    private enum CatalogError: Error { case noPreviews }
}

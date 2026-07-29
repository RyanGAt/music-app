import Foundation
import MusicKit

@MainActor
final class AppleMusicCatalog: ObservableObject {
    enum State: Equatable {
        case idle, loading, loaded, offline, noResults, failed(String)
    }

    @Published private(set) var tracks: [Track] = []
    @Published private(set) var state: State = .idle
    @Published private(set) var isLoadingMore = false

    private var queryIndex = 0
    private var seenIDs = Set<MusicItemID>()

    func reload(genres: [String], allowExplicit: Bool) async {
        tracks = []
        seenIDs = []
        queryIndex = 0
        state = .loading
        await fetchNext(genres: genres, allowExplicit: allowExplicit, initial: true)
    }

    func loadMore(genres: [String], allowExplicit: Bool) async {
        guard state == .loaded, !isLoadingMore else { return }
        await fetchNext(genres: genres, allowExplicit: allowExplicit, initial: false)
    }

    private func fetchNext(genres: [String], allowExplicit: Bool, initial: Bool) async {
        isLoadingMore = !initial
        defer { isLoadingMore = false }

        let selectedGenres = genres.isEmpty ? DiscoveryPreferences.defaultGenres : genres
        let modifiers = ["new", "essential", "breaking", "chill", "best of", "fresh"]
        let batchQueries = (0..<3).map { offset in
            let index = queryIndex + offset
            return "\(modifiers[(index / selectedGenres.count) % modifiers.count]) \(selectedGenres[index % selectedGenres.count])"
        }
        queryIndex += batchQueries.count

        do {
            var newTracks: [Track] = []
            for term in batchQueries {
                var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
                request.limit = 12
                let response = try await request.response()
                newTracks += response.songs
                    .filter { allowExplicit || $0.contentRating != .explicit }
                    .filter { seenIDs.insert($0.id).inserted }
                    .compactMap(Self.makeTrack)
            }
            tracks.append(contentsOf: newTracks)

            if tracks.isEmpty {
                #if DEBUG
                tracks = Track.developmentFallback
                state = .loaded
                #else
                state = .noResults
                #endif
            } else {
                state = .loaded
            }
        } catch let error as URLError where error.code == .notConnectedToInternet {
            if tracks.isEmpty { useFallback(or: .offline) }
        } catch {
            if tracks.isEmpty {
                let nsError = error as NSError
                let failure: State = nsError.domain == NSURLErrorDomain && nsError.code == URLError.notConnectedToInternet.rawValue
                    ? .offline
                    : .failed("Apple Music couldn't load this discovery session.")
                useFallback(or: failure)
            }
        }
    }

    private static func makeTrack(from song: Song) -> Track? {
        guard let previewURL = song.previewAssets?.first?.url else { return nil }
        return Track(
            id: song.id.rawValue,
            title: song.title,
            artist: song.artistName,
            album: song.albumTitle ?? "Apple Music",
            moment: nil,
            isrc: song.isrc,
            previewURL: previewURL,
            artworkURL: song.artwork?.url(width: 900, height: 900),
            appleMusicURL: song.url,
            spotifyURL: SpotifyMatchCache.shared.url(for: song.id.rawValue),
            colors: palette(for: song.id.rawValue)
        )
    }

    private func useFallback(or failure: State) {
        #if DEBUG
        tracks = Track.developmentFallback
        state = tracks.isEmpty ? failure : .loaded
        #else
        state = failure
        #endif
    }

    private static func palette(for value: String) -> [UInt] {
        let palettes: [[UInt]] = [
            [0x242A58, 0x895B74, 0xE39A76], [0x071B35, 0x284E74, 0xD34D8C],
            [0x432136, 0xB65345, 0xF3B75B], [0x163C38, 0x437967, 0xD9A66C]
        ]
        return palettes[Int(value.hashValue.magnitude % UInt(palettes.count))]
    }
}
